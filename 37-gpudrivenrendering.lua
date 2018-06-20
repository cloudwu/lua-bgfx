local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local RENDER_PASS_HIZ_ID            =0
local RENDER_PASS_HIZ_DOWNSCALE_ID  =1
local RENDER_PASS_OCCLUDE_PROPS_ID  =2
local RENDER_PASS_COMPACT_STREAM_ID =3
local RENDER_PASS_MAIN_ID           =4

local RenderPass_Occlusion = 1
local RenderPass_MainPass  = 2
local RenderPass_All = 3

local s_maxNoofProps = 10
local s_maxNoofInstances = 2048

local canvas = iup.canvas{}

dlg = iup.dialog {
  canvas,
  title = "37-gpudrivenrendering",
  size = "HALFxHALF",
}

local s_cubeVertices = {
	"fff",
	-0.5,  0.5,  0.5,
	 0.5,  0.5,  0.5,
	-0.5, -0.5,  0.5,
	 0.5, -0.5,  0.5,
	-0.5,  0.5, -0.5,
	 0.5,  0.5, -0.5,
	-0.5, -0.5, -0.5,
	 0.5, -0.5, -0.5,
}

local s_cubeIndices = {
	0, 1, 2, -- 0
	1, 3, 2,
	4, 6, 5, -- 2
	5, 6, 7,
	0, 2, 4, -- 4
	4, 2, 6,
	1, 5, 3, -- 6
	5, 7, 3,
	0, 4, 1, -- 8
	4, 5, 1,
	2, 3, 6, -- 10
	6, 3, 7,
}


local ctx = {}

local function renderOcclusionBufferPass()
	-- Setup the occlusion pass projection
	local projmat = math3d.matrix("m_occlusionProj", ctx)
	projmat:projmat(60, ctx.m_hiZwidth/ctx.m_hiZheight, 0.1, 500)
	bgfx.set_view_transform(RENDER_PASS_HIZ_ID, ctx.m_mainView, projmat)

	bgfx.set_view_frame_buffer(RENDER_PASS_HIZ_ID, ctx.m_hiZDepthBuffer)
	bgfx.set_view_rect(RENDER_PASS_HIZ_ID, 0, 0, ctx.m_hiZwidth, ctx.m_hiZheight)

	-- render all instances of the occluder meshes
	for i = 1, ctx.m_noofProps do
		local prop = ctx.m_props[i]

		if (prop.m_renderPass & RenderPass_Occlusion) ~= 0 then
			local numInstances = prop.m_noofInstances

			-- render instances to the occlusion buffer
			local instanceBuffer = ctx.m_OcclusionIB
			instanceBuffer:alloc(numInstances)

			local inst = prop.m_instances
			for j = 1, numInstances do
				local o = inst[j]
				-- we only need the world matrix for the occlusion pass
				instanceBuffer(j-1, o.m_world, o.m_bboxMin, o.m_bboxMax)
			end
			-- Set vertex and index buffer.
			bgfx.set_vertex_buffer(0, prop.m_vertexbufferHandle)
			bgfx.set_index_buffer(prop.m_indexbufferHandle)

			-- Set instance data buffer.
			instanceBuffer:set()

			-- Set render states.
			bgfx.set_state()	--BGFX_STATE_DEFAULT

			-- Submit primitive for rendering to view.
			bgfx.submit(RENDER_PASS_HIZ_ID,ctx.m_programOcclusionPass)
		end
	end
end

-- downscale the occluder depth buffer to create a mipmap chain
local function renderDownscalePass()
	local width = ctx.m_hiZwidth
	local height = ctx.m_hiZheight

	local inputRendertargetSize = math3d.vector()
	for i = 1, ctx.m_noofHiZMips do
		local coordinateScale = i > 1 and 2.0 or 1.0
		inputRendertargetSize:pack( width, height, coordinateScale, coordinateScale)
		bgfx.set_uniform(ctx.u_inputRTSize, inputRendertargetSize)

		if i > 1 then
			-- down scale mip 1 onwards
			width = width // 2
			height = height // 2

			bgfx.set_image(0, bgfx.get_texture(ctx.m_hiZBuffer, 0), i-2, "r")
			bgfx.set_image(1, bgfx.get_texture(ctx.m_hiZBuffer, 0), i-1, "w")
		else
			-- copy mip zero over to the hi Z buffer.
			-- We can't currently use blit as it requires same format and CopyResource is not exposed.
			bgfx.set_image(0, bgfx.get_texture(ctx.m_hiZDepthBuffer, 0), 0, "r")
			bgfx.set_image(1, bgfx.get_texture(ctx.m_hiZBuffer, 0), 0, "w")
		end

		bgfx.dispatch(RENDER_PASS_HIZ_DOWNSCALE_ID, ctx.m_programDownscaleHiZ, width//16, height//16)
	end
end

-- perform the occlusion using the mip chain
local function renderOccludePropsPass()
	-- run the computer shader to determine visibility of each instance
	bgfx.set_texture(0, ctx.s_texOcclusionDepthIn, bgfx.get_texture(ctx.m_hiZBuffer))

	bgfx.set_buffer(1, ctx.m_instanceBoundingBoxes, "r")
	bgfx.set_buffer(2, ctx.m_drawcallInstanceCounts, "w")
	bgfx.set_buffer(3, ctx.m_instancePredicates, "w")

	bgfx.set_uniform(ctx.u_inputRTSize, math3d.vector():pack(ctx.m_hiZwidth, ctx.m_hiZheight, 1 / ctx.m_hiZwidth, 1/ctx.m_hiZheight))

	-- store a rounded-up, power of two instance count for the stream compaction step
	local noofInstancesPowOf2 = 2 ^ (math.floor(math.log(ctx.m_totalInstancesCount) / math.log(2) ) + 1)
	local cullingConfig = math3d.vector():pack( ctx.m_totalInstancesCount, noofInstancesPowOf2 , ctx.m_noofHiZMips, ctx.m_noofProps )
	bgfx.set_uniform(ctx.u_cullingConfig, cullingConfig)

	--set the view/projection transforms so that the compute shader can receive the viewProjection matrix automagically
	bgfx.set_view_transform(RENDER_PASS_OCCLUDE_PROPS_ID, ctx.m_mainView, ctx.m_occlusionProj)

	local groupX = math.max(ctx.m_totalInstancesCount // 64 + 1, 1)

	bgfx.dispatch(RENDER_PASS_OCCLUDE_PROPS_ID, ctx.m_programOccludeProps, groupX, 1, 1)

	-- perform stream compaction to remove occluded instances

	-- the per drawcall data that is constant (noof indices/vertices and offsets to vertex/index buffers)

	bgfx.set_buffer(0, ctx.m_indirectBufferData, "r")
	-- instance data for all instances (pre culling)
	bgfx.set_buffer(1, ctx.m_instanceBuffer, "r")
	-- per instance visibility (output of culling pass)
	bgfx.set_buffer(2, ctx.m_instancePredicates, "r")

	-- how many instances per drawcall
	bgfx.set_buffer(3, ctx.m_drawcallInstanceCounts, "rw")
	-- drawcall data that will drive drawIndirect
	bgfx.set_buffer(4, ctx.m_indirectBuffer, "rw")
	-- culled instance data
	bgfx.set_buffer(5, ctx.m_culledInstanceBuffer, "w")

	bgfx.set_uniform(ctx.u_cullingConfig, cullingConfig)

	bgfx.dispatch(RENDER_PASS_COMPACT_STREAM_ID, ctx.m_programStreamCompaction, 1, 1, 1)
end

-- render the unoccluded props to the screen
local function renderMainPass()
	-- Set view and projection matrix for view 0.
	bgfx.set_view_transform(RENDER_PASS_MAIN_ID, ctx.m_mainView, ctx.m_mainProj)

	-- Set view 0 default viewport.
	bgfx.set_view_rect(RENDER_PASS_MAIN_ID, 0, 0, ctx.m_width, ctx.m_height)

	-- Set render states.
	bgfx.set_state()

	-- Set "material" data (currently a colour only)
	bgfx.set_uniform(ctx.u_colour, table.unpack(ctx.m_materials))

	-- Set vertex and index buffer.
	bgfx.set_vertex_buffer(0, ctx.m_allPropsVertexbufferHandle)
	bgfx.set_index_buffer(ctx.m_allPropsIndexbufferHandle)

	-- Set instance data buffer.
	bgfx.set_instance_data_buffer(ctx.m_culledInstanceBuffer,  0,  ctx.m_totalInstancesCount )

	bgfx.submit(RENDER_PASS_MAIN_ID, ctx.m_programMainPass)
end

local function mainloop()
	math3d.reset()
	bgfx.touch(0)

	-- todo: support mouse
	local mainview = math3d.matrix("m_mainView", ctx)
	mainview:lookatp(50,20,65, 0,0,0)

	local mainproj = math3d.matrix("m_mainProj", ctx)
	mainproj:projmat(60, ctx.m_width / ctx.m_height, 0.1, 500)

	-- submit drawcalls for all passes
	renderOcclusionBufferPass()
	renderDownscalePass()
	renderOccludePropsPass()
	renderMainPass()

	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}

	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
	}

	-- create uniforms
	ctx.u_inputRTSize   = bgfx.create_uniform("u_inputRTSize", "v4")
	ctx.u_cullingConfig = bgfx.create_uniform("u_cullingConfig", "v4")
	ctx.u_colour        = bgfx.create_uniform("u_colour", "v4")

	-- create props
	ctx.m_totalInstancesCount = 0
--	ctx.m_noofProps = 0

	ctx.m_props = {} --new Prop[s_maxNoofProps];

	-- first create space for some materials
	ctx.m_materials = {} --new Material[s_maxNoofProps];
	ctx.m_noofMaterials = 0

	-- Sets up a prop
	local function createCubeMesh(prop)
		prop.m_noofVertices = 8
		prop.m_noofIndices = 36
		prop.m_vertices = s_cubeVertices
		prop.m_indices = s_cubeIndices

		prop.m_vertexbufferHandle = bgfx.create_vertex_buffer(prop.m_vertices, ctx.vdecl)
		prop.m_indexbufferHandle = bgfx.create_index_buffer(prop.m_indices)
	end

	local temp = math3d.vector()
	local function minmax(inst)
		temp:pack(-0.5, -0.5, -0.5, 1.0)
		math3d.vector("m_bboxMin", inst):mul(temp, inst.m_world)
		temp:pack(0.5, 0.5, 0.5, 1.0)
		math3d.vector("m_bboxMax", inst):mul(temp, inst.m_world)
	end

	-- add a ground plane
	do
		local prop = {}
		table.insert(ctx.m_props, prop)
		prop.m_renderPass = RenderPass_MainPass

		createCubeMesh(prop)

		prop.m_noofInstances = 1

		local inst = {}
		prop.m_instances = { inst }

		math3d.matrix("m_world", inst):srt(
					100.0, 0.1, 100.0
					, 0.0, 0.0, 0.0
					, 0.0, 0.0, 0.0
				)

		minmax(inst)

		ctx.m_noofMaterials = ctx.m_noofMaterials + 1
		prop.m_materialID = ctx.m_noofMaterials
		math3d.vector(prop.m_materialID, ctx.m_materials):pack(0,0.6,0,1)

		ctx.m_totalInstancesCount = ctx.m_totalInstancesCount + prop.m_noofInstances
	end

	-- add a few instances of the occluding mesh
	do
		local prop = {}
		table.insert(ctx.m_props, prop)
		prop.m_renderPass = RenderPass_All

		createCubeMesh(prop)

		-- add a few instances of the wall mesh
		prop.m_noofInstances = 25
		prop.m_instances = {}
		for i = 1, prop.m_noofInstances do
			local inst = {}
			table.insert(prop.m_instances, inst)
			-- calculate world position
			math3d.matrix("m_world", inst):srt(
				40.0, 10.0, 0.1
				, 0.0, ( math.random() * 120.0 - 60.0) * 3.1459 / 180.0, 0.0
				, math.random() * 100.0 - 50.0, 5.0, math.random() * 100.0 - 50.0
			)

			minmax(inst)
		end

		--set the material ID. Will be used in the shader to select the material
		ctx.m_noofMaterials = ctx.m_noofMaterials + 1
		prop.m_materialID = ctx.m_noofMaterials
		--add a "material" for this prop
		math3d.vector(prop.m_materialID, ctx.m_materials):pack(0,0,1,0)

		ctx.m_totalInstancesCount = ctx.m_totalInstancesCount + prop.m_noofInstances
	end

	--add a few "regular" props
	do
		-- add cubes
		do
			local prop = {}
			table.insert(ctx.m_props, prop)
			prop.m_renderPass = RenderPass_MainPass

			createCubeMesh(prop)

			prop.m_noofInstances = 200
			prop.m_instances = {}
			for i = 1, prop.m_noofInstances do
				local inst = {}
				table.insert(prop.m_instances, inst)
				math3d.matrix("m_world", inst):srt(
					2.0, 2.0, 2.0
					, 0.0, 0.0, 0.0
					, math.random() * 100.0 - 50.0, 1.0, math.random() * 100.0 - 50.0
				)

				minmax(inst)
			end

			ctx.m_noofMaterials = ctx.m_noofMaterials + 1
			prop.m_materialID = ctx.m_noofMaterials
			math3d.vector(prop.m_materialID, ctx.m_materials):pack(1,1,0,1)
			ctx.m_totalInstancesCount = ctx.m_totalInstancesCount + prop.m_noofInstances
		end

		-- add some more cubes
		do
			local prop = {}
			table.insert(ctx.m_props, prop)
			prop.m_renderPass = RenderPass_MainPass
			createCubeMesh(prop)

			prop.m_noofInstances = 300
			prop.m_instances = {}
			for i = 1, prop.m_noofInstances do
				local inst = {}
				table.insert(prop.m_instances, inst)
				math3d.matrix("m_world", inst):srt(
					2.0, 4.0, 2.0
					, 0.0, 0.0, 0.0
					, math.random() * 100.0 - 50.0, 2.0, math.random() * 100.0 - 50.0
				)

				minmax(inst)
			end

			ctx.m_noofMaterials = ctx.m_noofMaterials + 1
			prop.m_materialID = ctx.m_noofMaterials
			math3d.vector(prop.m_materialID, ctx.m_materials):pack(1,0,0,1)
			ctx.m_totalInstancesCount = ctx.m_totalInstancesCount + prop.m_noofInstances
		end
	end

	-- Setup Occlusion pass
	do
		local samplerFlags = "rt-p+p*pucvc"
		-- Create buffers for the HiZ pass
		ctx.m_hiZDepthBuffer = bgfx.create_frame_buffer(ctx.m_hiZwidth, ctx.m_hiZheight, "D32", samplerFlags)
		local buffer = bgfx.create_texture2d(ctx.m_hiZwidth, ctx.m_hiZheight, true, 1, "R32F", samplerFlags .. "bc")	-- BGFX_TEXTURE_COMPUTE_WRITE
		ctx.m_hiZBuffer = bgfx.create_frame_buffer({buffer}, true)
		-- how many mip will the Hi Z buffer have?
		ctx.m_noofHiZMips = 1 + math.floor(math.log(math.max(ctx.m_hiZwidth, ctx.m_hiZheight),2))
		-- Setup compute shader buffers
		-- The compute shader will write how many unoccluded instances per drawcall there are here
		ctx.m_drawcallInstanceCounts = bgfx.create_dynamic_index_buffer(s_maxNoofProps, "drw")	--BGFX_BUFFER_INDEX32 | BGFX_BUFFER_COMPUTE_READ_WRITE
		-- the compute shader will write the result of the occlusion test for each instance here
		ctx.m_instancePredicates = bgfx.create_dynamic_index_buffer(s_maxNoofInstances, "rw")
		--bounding box for each instance, will be fed to the compute shader to calculate occlusion
		do
			local computeVertexDecl = bgfx.vertex_decl {
				{ "TEXCOORD0", 4, "FLOAT" },
			}
			-- initialise the buffer with the bounding boxes of all instances
			local sizeOfBuffer = 2 * 4 * ctx.m_totalInstancesCount
			local boundingBoxes = { "ffff" }
			for i, prop in ipairs(ctx.m_props) do
				local numInstances = prop.m_noofInstances

				for j = 1, numInstances do
					local v1,v2,v3 = prop.m_instances[j].m_bboxMin:unpack()
					table.insert(boundingBoxes, v1)
					table.insert(boundingBoxes, v2)
					table.insert(boundingBoxes, v3)
					table.insert(boundingBoxes, i-1)	-- store the drawcall ID here to avoid creating a separate buffer

					local v1,v2,v3 = prop.m_instances[j].m_bboxMax:unpack()
					table.insert(boundingBoxes, v1)
					table.insert(boundingBoxes, v2)
					table.insert(boundingBoxes, v3)
					table.insert(boundingBoxes, 0)
				end
			end

			ctx.m_instanceBoundingBoxes = bgfx.create_dynamic_vertex_buffer( boundingBoxes , computeVertexDecl, "r")	-- BGFX_BUFFER_COMPUTE_READ
		end

		-- pre and post occlusion culling instance data buffers
		do
			local instanceBufferVertexDecl = bgfx.vertex_decl {
				{ "TEXCOORD0", 4, "FLOAT" },
				{ "TEXCOORD1", 4, "FLOAT" },
				{ "TEXCOORD2", 4, "FLOAT" },
				{ "TEXCOORD3", 4, "FLOAT" },
			}
			-- initialise the buffer with data for all instances
			-- Currently we only store a world matrix (16 floats)

			--	const int sizeOfBuffer = 16 * m_totalInstancesCount;
			local instanceData = { "ffffffffffffffff" }

			for ii, prop in ipairs(ctx.m_props) do
				local numInstances = prop.m_noofInstances

				for jj = 1, numInstances do
					local temp = { prop.m_instances[jj].m_world:unpack() }
					temp[4] = ii-1	-- store the drawcall ID here to avoid creating a separate buffer
					for k = 1, 16 do
						table.insert(instanceData, temp[k])
					end
				end
			end

			-- pre occlusion buffer
			ctx.m_instanceBuffer = bgfx.create_vertex_buffer(instanceData, instanceBufferVertexDecl, "r")
			-- post occlusion buffer
			ctx.m_culledInstanceBuffer = bgfx.create_dynamic_vertex_buffer(4 * ctx.m_totalInstancesCount, instanceBufferVertexDecl, "w")
		end

		-- we use one "drawcall" per prop to render all its instances
		ctx.m_indirectBuffer = bgfx.create_indirect_buffer(#ctx.m_props)

		-- Create programs from shaders for occlusion pass.
		ctx.m_programOcclusionPass    = util.programLoad("vs_gdr_render_occlusion")
		ctx.m_programDownscaleHiZ     = util.computeLoad "cs_gdr_downscale_hi_z"
		ctx.m_programOccludeProps     = util.computeLoad "cs_gdr_occlude_props"
		ctx.m_programStreamCompaction = util.computeLoad "cs_gdr_stream_compaction"

		-- Set view RENDER_PASS_HIZ_ID clear state.
		bgfx.set_view_clear(RENDER_PASS_HIZ_ID, "D", 0, 1, 0)
	end

	ctx.m_noofProps = #ctx.m_props

	-- Setup Main pass
	do
		-- Set view 0 clear state.
		bgfx.set_view_clear(RENDER_PASS_MAIN_ID, "CD", 0x303030ff , 1, 0)
		-- Create program from shaders.
		ctx.m_programMainPass =  util.programLoad ("vs_gdr_instanced_indirect_rendering", "fs_gdr_instanced_indirect_rendering")
	end

	-- Create static vertex buffer for all props.
	-- Calculate how many vertices/indices the master buffers will need.
	local totalNoofVertices = 0
	local totalNoofIndices = 0
	for i = 1, ctx.m_noofProps do
		local prop = ctx.m_props[i]

		totalNoofVertices = totalNoofVertices + prop.m_noofVertices
		totalNoofIndices = totalNoofIndices + prop.m_noofIndices
	end

	-- CPU data to fill the master buffers
	ctx.m_allPropVerticesDataCPU = { "fff" }	--new PosVertex[totalNoofVertices];
	ctx.m_allPropIndicesDataCPU = {} --new uint16_t[totalNoofIndices];
	ctx.m_indirectBufferDataCPU = {} --new uint32_t[m_noofProps * 3];

	-- Copy data over to the master buffers
	--	PosVertex* propVerticesData = m_allPropVerticesDataCPU;
	--	uint16_t* propIndicesData = m_allPropIndicesDataCPU;

	local vertexBufferOffset = 0
	local indexBufferOffset = 0

	for i = 1, ctx.m_noofProps do
		local prop = ctx.m_props[i]
		for i = 2, #prop.m_vertices do
			table.insert(ctx.m_allPropVerticesDataCPU, prop.m_vertices[i])
		end
		for _, v in ipairs(prop.m_indices) do
			table.insert(ctx.m_allPropIndicesDataCPU, v)
		end

		table.insert(ctx.m_indirectBufferDataCPU, prop.m_noofIndices)
		table.insert(ctx.m_indirectBufferDataCPU, indexBufferOffset)
		table.insert(ctx.m_indirectBufferDataCPU, vertexBufferOffset)

		indexBufferOffset = indexBufferOffset + prop.m_noofIndices
		vertexBufferOffset = vertexBufferOffset + prop.m_noofVertices
	end

	-- Create master vertex buffer
	ctx.m_allPropsVertexbufferHandle = bgfx.create_vertex_buffer(ctx.m_allPropVerticesDataCPU, ctx.vdecl)
	-- Create master index buffer.
	ctx.m_allPropsIndexbufferHandle = bgfx.create_index_buffer(ctx.m_allPropIndicesDataCPU)
	-- Create buffer with const drawcall data which will be copied to the indirect buffer later.
	ctx.m_indirectBufferData = bgfx.create_index_buffer(ctx.m_indirectBufferDataCPU, "rd")

	-- create samplers
	ctx.s_texOcclusionDepthIn = bgfx.create_uniform("s_texOcclusionDepthIn", "i1")

	ctx.m_OcclusionIB = bgfx.instance_buffer "mvv"

	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	ctx.m_width = w
	ctx.m_height = h

	-- find largest pow of two dims less than backbuffer size
	ctx.m_hiZwidth  = 2 ^ math.floor(math.log(w,2))
	ctx.m_hiZheight = 2 ^ math.floor(math.log(h,2))

	if init then
		init(self)
		init = nil
	end
	bgfx.reset(w,h,"v")
end

function canvas:action(x,y)
	mainloop()
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

iup.MainLoop()
iup.Close()
ant.shutdown()
