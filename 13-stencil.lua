local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"
local bgfxu = require "bgfx.util"

local RENDER_VIEWID_RANGE1_PASS_0 = 1
local RENDER_VIEWID_RANGE1_PASS_1 = 2
local RENDER_VIEWID_RANGE1_PASS_2 = 3
local RENDER_VIEWID_RANGE1_PASS_3 = 4
local RENDER_VIEWID_RANGE1_PASS_4 = 5
local RENDER_VIEWID_RANGE1_PASS_5 = 6
local RENDER_VIEWID_RANGE5_PASS_6 = 7
local RENDER_VIEWID_RANGE1_PASS_7 =13
local MAX_LIGHTS = 5

local settings = {
	StencilReflectionScene = true,
	lights = 4,
	reflection = 0.8,
	updateLights = true,
	updateScene = true,
	scene = "StencilReflectionScene",
}

local canvas = iup.canvas {}

local ctrls = {}

local function slider(name, title, min, max)
	local value = assert(settings[name])
	local label = iup.label { title = tostring(value) }
	local function update_value(self)
		local v = tonumber(self.value)
		settings[name] = v
		label.title = string.format("%.2f",v)
	end

	local c = iup.val {
		"HORIZONTAL";
		min = min,
		max = max,
		value = value,
		valuechanged_cb = update_value,
	}

	local s = iup.vbox {
		iup.label { title = title },
		iup.hbox {
			c,
			label
		}
	}
	local function setter(v)
		if type(v) == "boolean" then
			s.visible = v and "YES" or "NO"
		else
			c.value = v
			update_value(c,v)
		end
	end
	return s,setter
end

local function checkbox(name)
	return iup.toggle {
		title = name,
		value = "ON",
		action = function(self, v)
			settings[name] = (v == 1)
		end,
	}
end

do
	local stencil =	iup.toggle {
		title = "Stencil Reflection Scene",
	}
	local projection = iup.toggle {
		title = "Projection Shadows Scene",
	}
	local lights, lights_set = slider("lights", "Lights", 1, MAX_LIGHTS)
	local reflection, reflection_set = slider("reflection", "Reflection value", 0, 1)

	ctrls.panel = iup.frame {
		iup.vbox {
			iup.radio {
				iup.vbox {
					stencil,
					projection,
				},
				value = stencil,
			},
			lights,
			reflection,
			checkbox "updateLights",
			checkbox "updateScene",
		},
		title = "Settings",
		size = "60x60",
	}

	function stencil:action(v)
		if v==1 then
			lights_set(4)
			reflection_set(true)
			settings.scene = "StencilReflectionScene"
		end
	end

	function projection:action(v)
		if v==1 then
			lights_set(1)
			reflection_set(false)
			settings.scene = "ProjectionShadowsScene"
		end
	end
end

dlg = iup.dialog {
	iup.hbox {
		iup.vbox {
			ctrls.panel,
			margin = "10x10",
		},
		canvas,
	},
  title = "12-lod",
  size = "HALFxHALF",
}

local ctx = {}
local Uniforms = {}

local function init_Uniforms()
	math3d.vector("params", Uniforms):pack(1,1,4,4)
		-- m_ambientPass, m_lightingPass, m_lightCount, m_lightIndex
--	math3d.vector("svparams", Uniforms)
	math3d.vector("ambient", Uniforms):pack(0.02, 0.02, 0.02)
	math3d.vector("diffuse", Uniforms):pack(0.2, 0.2, 0.2)
	math3d.vector("specular_shininess", Uniforms):pack(1,1,1,10)	-- 10:shininess
	math3d.vector("color", Uniforms):pack(1,1,1,1)

--		m_time = 0.0f;
	Uniforms.lightPosRadius = {}
	Uniforms.lightRgbInnerR = {}
	Uniforms.tmpLights = {}	-- temp
	for i = 1, MAX_LIGHTS do
		math3d.vector(i, Uniforms.lightPosRadius):pack(0,0,0,1)
		math3d.vector(i, Uniforms.lightRgbInnerR):pack(1,1,1,1)
	end

	Uniforms.u_params = bgfx.create_uniform("u_params", "v4")
	Uniforms.u_ambient = bgfx.create_uniform("u_ambient", "v4")
	Uniforms.u_diffuse = bgfx.create_uniform("u_diffuse", "v4")
	Uniforms.u_specular_shininess = bgfx.create_uniform("u_specular_shininess", "v4")
	Uniforms.u_color = bgfx.create_uniform("u_color", "v4")
	Uniforms.u_lightPosRadius = bgfx.create_uniform("u_lightPosRadius", "v4", MAX_LIGHTS)
	Uniforms.u_lightRgbInnerR = bgfx.create_uniform("u_lightRgbInnerR", "v4", MAX_LIGHTS)
end

local function submitConstUniforms()
	bgfx.set_uniform(Uniforms.u_ambient, Uniforms.ambient)
	bgfx.set_uniform(Uniforms.u_diffuse, Uniforms.diffuse)
	bgfx.set_uniform(Uniforms.u_specular_shininess, Uniforms.specular_shininess)
end

local function submitPerDrawUniforms()
	bgfx.set_uniform(Uniforms.u_params, Uniforms.params)
	bgfx.set_uniform(Uniforms.u_color, Uniforms.color)
	bgfx.set_uniform(Uniforms.u_lightPosRadius, table.unpack(Uniforms.lightPosRadius))
	bgfx.set_uniform(Uniforms.u_lightRgbInnerR, table.unpack(Uniforms.lightRgbInnerR))
end

-- render state

local s_renderStates = {
	StencilReflection_CraftStencil = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBZ",
			DEPTH_TEST = "LESS",
			MSAA = true,
		},
		fstencil = bgfx.make_stencil {
			TEST = "ALWAYS",
			FUNC_REF = 1,
			FUNC_RMASK = 0xff,
			OP_FAIL_S = "REPLACE",
			OP_FAIL_Z = "REPLACE",
			OP_PASS_Z = "REPLACE",
		},
	},
	StencilReflection_DrawReflected = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			BLEND_FUNC = "aA",	-- BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA
			DEPTH_TEST = "LESS",
			CULL = "CW",
			MSAA = true,
		},	-- reflection matrix has inverted normals. using CCW instead of CW.
		fstencil = bgfx.make_stencil {
			TEST = "EQUAL",
			FUNC_REF = 1,
			FUNC_RMASK = 1,
			OP_FAIL_S = "KEEP",
			OP_FAIL_Z = "KEEP",
			OP_PASS_Z = "KEEP",
		},
	},
	StencilReflection_BlendPlane = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBZ",
			BLEND_FUNC = "1s",	-- BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_SRC_COLOR
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
	},
	StencilReflection_DrawScene = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
	},
	ProjectionShadows_DrawAmbient = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBZ",  -- write depth !
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
	},
	ProjectionShadows_CraftStencil = {
		state = bgfx.make_state {
			DEPTH_TEST = "LESS",
			MSAA = true,
		},
		fstencil = bgfx.make_stencil {
			TEST = "ALWAYS",
			FUNC_REF = 1,
			FUNC_RMASK = 0xff,
			OP_FAIL_S = "KEEP",
			OP_FAIL_Z = "KEEP",
			OP_PASS_Z = "REPLACE", -- store the value
		},
	},
	ProjectionShadows_DrawDiffuse = {
		state = bgfx.make_state {
			WRITE_MASK = "RGB",
			BLEND_FUNC = "11",  --BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE
			DEPTH_TEST = "EQUAL",
			CULL = "CCW",
			MSAA = true,
		},
		fstencil = bgfx.make_stencil {
			TEST = "NOTEQUAL",
			FUNC_REF = 1,
			FUNC_RMASK = 1,
			OP_FAIL_S = "KEEP",
			OP_FAIL_Z = "KEEP",
			OP_PASS_Z = "KEEP",
		},
	},
	Custom_BlendLightTexture = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBZ",
			DEPTH_TEST = "LESS",
			BLEND_FUNC = "sS", -- BGFX_STATE_BLEND_SRC_COLOR, BGFX_STATE_BLEND_INV_SRC_COLOR
			CULL = "CCW",
			MSAA = true,
		},
	},
	Custom_DrawPlaneBottom = {
		state = bgfx.make_state {
			WRITE_MASK = "RGB",
			CULL = "CW",
			MSAA = true,
		},
	},
}

local function set_state(s)
	bgfx.set_state(s.state)
	bgfx.set_stencil(s.fstencil)
end

local function mtxBillboard(result,  view, pos, s0, s1, s2)
	local v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15 = view:unpack()
	local p0,p1,p2 = pos:unpack()
	result:pack(
		v0 * s0,
		v4 * s0,
		v8 * s0,
		0,
		v1 * s1,
		v5 * s1,
		v9 * s1,
		0,
		v2 * s2,
		v6 * s2,
		v10 * s2,
		0,
		p0,
		p1,
		p2,
		1
	)

	return result
end

local function mtxShadow(result , ground, light)
	local g0,g1,g2,g3 = ground:unpack()
	local l0,l1,l2,l3 = light:unpack()
	local dot = g0 * l0 + g1 * l1 + g2 * l2 + g3 * l3

	result:pack(
		dot - l0 * g0,
		    - l1 * g0,
		    - l2 * g0,
		    - l3 * g0,

		    - l0 * g1,
		dot - l1 * g1,
		    - l2 * g1,
		    - l3 * g1,

		    - l0 * g2,
		    - l1 * g2,
		dot - l2 * g2,
		    - l3 * g2,

		    - l0 * g3,
		    - l1 * g3,
		    - l2 * g3,
		dot - l3 * g3
	)

	return result
end

local draw_views = {
	StencilReflectionScene = { 0, RENDER_VIEWID_RANGE1_PASS_0 , RENDER_VIEWID_RANGE1_PASS_1, RENDER_VIEWID_RANGE1_PASS_2, RENDER_VIEWID_RANGE1_PASS_3, RENDER_VIEWID_RANGE1_PASS_7 },
	ProjectionShadowsScene = {
		0, RENDER_VIEWID_RANGE1_PASS_0, RENDER_VIEWID_RANGE1_PASS_7,
	}
}

-- todo: destroy Uniforms
local time = 0
local deltaTime = 0.01
local function mainloop()
	local view = math3d.matrix "view"
	local proj = math3d.matrix "proj"
	math3d.reset()
	bgfx.touch(0)
	time = time + deltaTime

	submitConstUniforms()

	-- Update settings.
	local numLights = settings.lights

	Uniforms.params:pack(1,1,numLights,0)
	Uniforms.color:pack(nil,nil,nil, settings.reflection)

	if settings.updateLights then
		ctx.lightTimeAccumulator = ctx.lightTimeAccumulator + deltaTime
	end

	if settings.updateScene then
		ctx.sceneTimeAccumulator = ctx.sceneTimeAccumulator + deltaTime
	end

	local radius = (settings.scene == "StencilReflectionScene") and 15 or 25
	local pihalf = math.pi / 2
	for i = 1, numLights do
		math3d.vector(i, Uniforms.lightPosRadius):pack(
			math.sin(ctx.lightTimeAccumulator * 1.1 + i * 0.03 + i * pihalf* 1.07) * 20,
			8 + (1 - math.cos(ctx.lightTimeAccumulator * 1.5 + i * 0.29 + pihalf * 1.49)) * 4,
			math.cos(ctx.lightTimeAccumulator * 1.3 + i * 0.13 + i * pihalf * 1.79) * 20,
			radius
		)
	end

	-- Floor position.
	local floorMtx = math3d.matrix():srt(20,20,20,0,0,0,0,0,0)

	-- Bunny position.
	local bunnyMtx = math3d.matrix():srt(5,5,5,0,1.56 - ctx.sceneTimeAccumulator, 0, 0,2,0)

	-- Columns position.

	local columnMtx = {}
	local dist = 14
	columnMtx[1] = math3d.matrix():srt(1,1,1,0,0,0,
		dist, 0, dist)
	columnMtx[2] = math3d.matrix():srt(1,1,1,0,0,0,
		-dist, 0, dist)
	columnMtx[3] = math3d.matrix():srt(1,1,1,0,0,0,
		dist, 0, -dist)
	columnMtx[4] = math3d.matrix():srt(1,1,1,0,0,0,
		-dist, 0, -dist)

	bgfx.set_view_clear(0, "CDS", 0x303030ff, 1, 0)

	-- Bunny and columns color.
	Uniforms.color:pack(0.7, 0.65, 0.6)

	if settings.scene == "StencilReflectionScene" then
		-- First pass - Draw plane.

		-- Setup params for this scene.
		Uniforms.params:pack(1, 1)

		-- Floor.
		set_state(s_renderStates.StencilReflection_CraftStencil)
		bgfx.set_transform(floorMtx)
		submitPerDrawUniforms()
		util.meshSubmit(ctx.m_hplaneMesh, RENDER_VIEWID_RANGE1_PASS_0, ctx.m_programColorBlack)

		-- Second pass - Draw reflected objects.
		-- Clear depth from previous pass.
		bgfx.set_view_clear(RENDER_VIEWID_RANGE1_PASS_1, "D", 0x303030ff, 1, 0)

		local reflectMtx = math3d.matrix "reflectMtx"

		-- Reflect lights.
		local reflectedLights = Uniforms.tmpLights
		for ii = 1, numLights do
			local light = math3d.vector(ii, Uniforms.lightPosRadius)
			local v = math3d.vector(ii, reflectedLights):copy(light)
			light:mul(reflectMtx)
		end

		-- Reflect and submit bunny.

		local mtxReflectedBunny = math3d.matrix():mul(bunnyMtx, reflectMtx)
		set_state(s_renderStates.StencilReflection_DrawReflected)
		bgfx.set_transform(mtxReflectedBunny)
		submitPerDrawUniforms()
		util.meshSubmit(ctx.m_bunnyMesh, RENDER_VIEWID_RANGE1_PASS_1, ctx.m_programColorLighting)

		-- Reflect and submit columns.

		local mtxReflectedColumn = math3d.matrix()
		for ii = 1, 4 do
			mtxReflectedColumn:mul(columnMtx[ii], reflectMtx)
			set_state(s_renderStates.StencilReflection_DrawReflected)
			bgfx.set_transform(mtxReflectedColumn)
			submitPerDrawUniforms()
			util.meshSubmit(ctx.m_columnMesh, RENDER_VIEWID_RANGE1_PASS_1, ctx.m_programColorLighting)
		end

		-- Set lights back.
		Uniforms.tmpLights , Uniforms.lightPosRadius = Uniforms.lightPosRadius, Uniforms.tmpLights

		-- Third pass - Blend plane.

		-- Floor.
		set_state(s_renderStates.StencilReflection_BlendPlane)
		bgfx.set_transform(floorMtx)
		submitPerDrawUniforms()
		bgfx.set_texture(0, ctx.s_texColor, ctx.m_fieldstoneTex)
		util.meshSubmit(ctx.m_hplaneMesh, RENDER_VIEWID_RANGE1_PASS_2, ctx.m_programTextureLighting)

		-- Fourth pass - Draw everything else but the plane.

		-- Bunny.
		set_state(s_renderStates.StencilReflection_DrawScene)
		bgfx.set_transform(bunnyMtx)
		submitPerDrawUniforms()
		util.meshSubmit(ctx.m_bunnyMesh, RENDER_VIEWID_RANGE1_PASS_3, ctx.m_programColorLighting)

		-- Columns.
		for i=1,4 do
			set_state(s_renderStates.StencilReflection_DrawScene)
			bgfx.set_transform(columnMtx[i])
			submitPerDrawUniforms()
			util.meshSubmit(ctx.m_columnMesh, RENDER_VIEWID_RANGE1_PASS_3, ctx.m_programColorLighting)
		end

	else
		-- "ProjectionShadowsScene"
		local numCubes = 9
		local cubeMtx = ctx.cubeMtx

		for i=1,numCubes do
			math3d.matrix(i, cubeMtx):srt(1,1,1,0,0,0,
				math.sin(i*2 + 11 - ctx.sceneTimeAccumulator) * 13,
				4,
				math.cos(i*2 + 11 - ctx.sceneTimeAccumulator) * 13)
		end

		-- First pass - Draw entire scene. (ambient only).
		Uniforms.params:pack(1, 1)

		-- Bunny.
		set_state(s_renderStates.ProjectionShadows_DrawAmbient)
		bgfx.set_transform(bunnyMtx)
		submitPerDrawUniforms()
		util.meshSubmit(ctx.m_bunnyMesh, RENDER_VIEWID_RANGE1_PASS_0, ctx.m_programColorLighting)

		-- Floor.
		set_state(s_renderStates.ProjectionShadows_DrawAmbient)
		bgfx.set_transform(floorMtx)
		bgfx.set_texture(0, ctx.s_texColor, ctx.m_fieldstoneTex)
		submitPerDrawUniforms()
		util.meshSubmit(ctx.m_hplaneMesh, RENDER_VIEWID_RANGE1_PASS_0, ctx.m_programTextureLighting)

		-- Cubes.
		for i = 1, numCubes do
			set_state(s_renderStates.ProjectionShadows_DrawAmbient)
			bgfx.set_transform(cubeMtx[i])
			submitPerDrawUniforms()
			bgfx.set_texture(0, ctx.s_texColor, ctx.m_figureTex)
			util.meshSubmit(ctx.m_cubeMesh, RENDER_VIEWID_RANGE1_PASS_0, ctx.m_programTextureLighting)
		end

		-- Ground plane.
		local plane_pos = math3d.vector():pack(0,0,0)
		local normal = math3d.vector():pack(0,1,0)
		local ground = math3d.vector():copy(normal)
		ground:pack(nil, nil, nil, - plane_pos:dot(normal) - 0.01)	-- - 0.01 against z-fighting

		local pos = math3d.vector()
		for i=1, numLights do
			local viewId = RENDER_VIEWID_RANGE5_PASS_6 + i - 1
			-- Clear stencil for this light source.
			bgfx.set_view_clear(viewId, "S", 0x303030ff, 1, 0)

			-- Draw shadow projection of scene objects.

			-- Get homogeneous light pos.
			pos:copy(math3d.vector(i, Uniforms.lightPosRadius)):pack(nil, nil, nil, 1)

			-- Calculate shadow mtx for current light.
			local shadowMtx = math3d.matrix()
			mtxShadow(shadowMtx, ground, pos)

			-- Submit bunny's shadow.
			local mtxShadowedBunny = math3d.matrix():mul(bunnyMtx, shadowMtx)
			set_state(s_renderStates.ProjectionShadows_CraftStencil)
			bgfx.set_transform(mtxShadowedBunny)
			submitPerDrawUniforms()
			util.meshSubmit(ctx.m_bunnyMesh, viewId, ctx.m_programColorBlack)

			-- Submit cube shadows.
			local mtxShadowedCube = math3d.matrix()
			for j = 1, numCubes do
				mtxShadowedCube:mul(cubeMtx[j], shadowMtx)

				set_state(s_renderStates.ProjectionShadows_CraftStencil)
				bgfx.set_transform(mtxShadowedCube)
				submitPerDrawUniforms()
				util.meshSubmit(ctx.m_cubeMesh, viewId, ctx.m_programColorBlack)
			end

			-- Draw entire scene. (lighting pass only. blending is on)
			Uniforms.params:pack(0,1,1, i - 1)

			-- Bunny.
			set_state(s_renderStates.ProjectionShadows_DrawDiffuse)
			bgfx.set_transform(bunnyMtx)
			submitPerDrawUniforms()
			util.meshSubmit(ctx.m_bunnyMesh, viewId, ctx.m_programColorLighting)

			-- Floor.
			set_state(s_renderStates.ProjectionShadows_DrawDiffuse)
			bgfx.set_transform(floorMtx)
			bgfx.set_texture(0, ctx.s_texColor, ctx.m_figureTex)
			submitPerDrawUniforms()
			util.meshSubmit(ctx.m_hplaneMesh, viewId, ctx.m_programColorLighting)

			-- Cubes.
			for j = 1, numCubes do
				set_state(s_renderStates.ProjectionShadows_DrawDiffuse)
				bgfx.set_transform(cubeMtx[j])
				bgfx.set_texture(0, ctx.s_texColor, ctx.m_figureTex)
				submitPerDrawUniforms()
				util.meshSubmit(ctx.m_cubeMesh, viewId, ctx.m_programColorLighting)
			end

			bgfx.set_view_rect(viewId, 0, 0, ctx.width, ctx.height)
			bgfx.set_view_transform(viewId, view, proj)
		end

		-- Reset these to default..
		Uniforms.params:pack(1,1)
	end

	-- lights
	local lightMtx = math3d.matrix()
	for ii = 1, numLights do
		local c = math3d.vector("color", Uniforms):copy(math3d.vector(ii, Uniforms.lightRgbInnerR))
		mtxBillboard(lightMtx, view, math3d.vector(ii, Uniforms.lightPosRadius), 1.5, 1.5, 1.5)
		set_state(s_renderStates.Custom_BlendLightTexture)
		bgfx.set_transform(lightMtx)
		submitPerDrawUniforms()
		bgfx.set_texture(0, ctx.s_texColor, ctx.m_flareTex)
		util.meshSubmit(ctx.m_vplaneMesh, RENDER_VIEWID_RANGE1_PASS_7, ctx.m_programColorTexture)
	end

	-- Draw floor bottom.
	set_state(s_renderStates.Custom_DrawPlaneBottom)
	bgfx.set_transform(math3d.matrix "floor")
	submitPerDrawUniforms()
	bgfx.set_texture(0, ctx.s_texColor, ctx.m_flareTex)
	util.meshSubmit(ctx.m_hplaneMesh, RENDER_VIEWID_RANGE1_PASS_7, ctx.m_programTexture)

	for _,viewid in ipairs(draw_views[settings.scene]) do
		bgfx.set_view_rect(viewid, 0, 0, ctx.width, ctx.height)
		bgfx.set_view_transform(viewid, view, proj)
	end

	bgfx.frame()

	--reset clear values on used views
	--clearViewMask(s_clearMask, BGFX_CLEAR_NONE, m_clearValues);
	if settings.scene == "StencilReflectionScene" then
		bgfx.set_view_clear(RENDER_VIEWID_RANGE1_PASS_1, "", 0x303030ff, 1, 0)
	else
		local viewId = RENDER_VIEWID_RANGE5_PASS_6
		for i=0, numLights-1 do
			bgfx.set_view_clear(viewId + i, "", 0x303030ff, 1, 0)
		end
	end
end

local function mtxReflected(result , p , n)
	local dot = p:dot(n)
	local x,y,z = n:unpack()
	result:pack(
		 1 - 2 * x* x,  --  1-2Nx^2
		-2 * x * y,		--  -2*Nx*Ny
		-2 * x * z,		--  -2*NxNz
		0,				--  0

		-2 * x * y,		--  -2*NxNy
		 1 - 2 * y * y,	--  1-2*Ny^2
		 -2 * y * z,	--  -2*NyNz
		 0,				--  0

		 -2 * x * z,	--  -2*NxNz
		 -2 * y * z,	--  -2NyNz
		 1 - 2 * z * z,	--  1-2*Nz^2
		 0,				--  0

		 2 * dot * x,	--  2*dot*Nx
		 2 * dot * y,	--  2*dot*Ny
		 2 * dot * z,	--  2*dot*Nz
		 1				--  1
	)
	return result
end

local function mesh(vb, ib)
	local g = {}
	g.vb = bgfx.create_vertex_buffer(vb, ctx.vdecl)
	g.ib = bgfx.create_index_buffer(ib)

	return { group = { g } }
end

local function init(canvas)

	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION",  3, "FLOAT" },
		{ "NORMAL",    4, "UINT8", true, true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}

	init_Uniforms()
	ctx.s_texColor = bgfx.create_uniform("s_texColor", "i1")

	ctx.m_programTextureLighting = util.programLoad("vs_stencil_texture_lighting", "fs_stencil_texture_lighting")
	ctx.m_programColorLighting   = util.programLoad("vs_stencil_color_lighting",   "fs_stencil_color_lighting"  )
	ctx.m_programColorTexture    = util.programLoad("vs_stencil_color_texture",    "fs_stencil_color_texture"   )
	ctx.m_programColorBlack      = util.programLoad("vs_stencil_color",            "fs_stencil_color_black"     )
	ctx.m_programTexture         = util.programLoad("vs_stencil_texture",          "fs_stencil_texture"         )

	ctx.m_bunnyMesh = util.meshLoad "meshes/bunny.bin"
	ctx.m_columnMesh = util.meshLoad "meshes/column.bin"

	local encodeNormalRgba8 = bgfxu.encodeNormalRgba8

	local s_cubeVertices = {
	 "fffdff",
	 -1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 1.0, 1.0 ,
	  1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0.0, 1.0 ,
	 -1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 1.0, 0.0 ,
	  1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0.0, 0.0 ,
	 -1.0, -1.0,  1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 1.0, 1.0 ,
	  1.0, -1.0,  1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0.0, 1.0 ,
	 -1.0, -1.0, -1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 1.0, 0.0 ,
	  1.0, -1.0, -1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0.0, 0.0 ,
	  1.0, -1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0.0, 0.0 ,
	  1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0.0, 1.0 ,
	 -1.0, -1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 1.0, 0.0 ,
	 -1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 1.0, 1.0 ,
	  1.0, -1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0.0, 0.0 ,
	  1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0.0, 1.0 ,
	 -1.0, -1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 1.0, 0.0 ,
	 -1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 1.0, 1.0 ,
	  1.0,  1.0, -1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 1.0, 1.0 ,
	  1.0,  1.0,  1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0.0, 1.0 ,
	  1.0, -1.0, -1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 1.0, 0.0 ,
	  1.0, -1.0,  1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0.0, 0.0 ,
	 -1.0,  1.0, -1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 1.0, 1.0 ,
	 -1.0,  1.0,  1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0.0, 1.0 ,
	 -1.0, -1.0, -1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 1.0, 0.0 ,
	 -1.0, -1.0,  1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0.0, 0.0 ,
	}

	local s_cubeIndices = {
	0,  1,  2,
	1,  3,  2,
	4,  6,  5,
	5,  6,  7,

	8,  9, 10,
	9, 11, 10,
	12, 14, 13,
	13, 14, 15,

	16, 17, 18,
	17, 19, 18,
	20, 22, 21,
	21, 22, 23,
	}

	ctx.m_cubeMesh = mesh(s_cubeVertices,s_cubeIndices)

	local s_texcoord = 5.0
	local s_hplaneVertices = {
	"fffdff",
	 -1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0), s_texcoord, s_texcoord ,
	  1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0), s_texcoord, 0.0       ,
	 -1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0), 0.0,       s_texcoord ,
	  1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0), 0.0,       0.0       ,
	}

	local s_planeIndices = {
	0, 1, 2,
	1, 3, 2,
	}

	local s_vplaneVertices = {
	 "fffdff",
	 -1.0,  1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 1.0, 1.0 ,
	  1.0,  1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 1.0, 0.0 ,
	 -1.0, -1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 0.0, 1.0 ,
	  1.0, -1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 0.0, 0.0 ,
	}

	ctx.m_hplaneMesh = mesh(s_hplaneVertices, s_planeIndices)
	ctx.m_vplaneMesh = mesh(s_vplaneVertices, s_planeIndices)

	ctx.m_figureTex     = util.textureLoad "textures/figure-rgba.dds"
	ctx.m_flareTex      = util.textureLoad "textures/flare.dds"
	ctx.m_fieldstoneTex = util.textureLoad "textures/fieldstone-rgba.dds"

	local rgbInnerR = {
		{ 1.0, 0.7, 0.2, 0.0 }, --yellow
		{ 0.7, 0.2, 1.0, 0.0 }, --purple
		{ 0.2, 1.0, 0.7, 0.0 }, --cyan
		{ 1.0, 0.4, 0.2, 0.0 }, --orange
		{ 0.7, 0.7, 0.7, 0.0 }, --white
	}

	for i = 1, MAX_LIGHTS do
		local index = i % #rgbInnerR + 1
		math3d.vector(i, Uniforms.lightRgbInnerR):pack(table.unpack(rgbInnerR[index]))
	end

	ctx.lightTimeAccumulator = 0
	ctx.sceneTimeAccumulator = 0


	local plane_pos = math3d.vector():pack(0,0.01,0)
	local normal = math3d.vector():pack(0,1,0)

	mtxReflected( math3d.matrix("reflectMtx"), plane_pos, normal)

	math3d.matrix ("floor"):srt( 20,20,20,0,0,0,0,-0.1, 0)

	ctx.cubeMtx = {}

	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "v")

	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp( 0, 18, -40, 0,0,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 2000)
end

function canvas:action(x,y)
	mainloop()
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
  -- todo: destory resources
  ant.shutdown()
end
