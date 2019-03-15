package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local RENDER_PASS_SHADING = 0  -- Default forward rendered geo with simple shading
local RENDER_PASS_ID = 1 -- ID buffer for picking
local RENDER_PASS_BLIT = 2  -- Blit GPU render target to CPU texture

local ID_DIM = 8  -- Size of the ID buffer

local ctx = {
	canvas = iup.canvas {},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "30-picking",
	size = "HALFxHALF",
}

local ms = util.mathstack
local canvas = ctx.canvas

function canvas:motion_cb(x,y)
	ctx.mouse_x = x
	ctx.mouse_y = y
end

function canvas:button_cb(button, pressed, x,y, status)
	if button == iup.BUTTON1 and pressed == 1 then
		ctx.mouse_click = true
	end
end

local time = 0
local function mainloop()
	math3d.reset(ms)
	time = time + 0.01

	bgfx.set_view_frame_buffer(RENDER_PASS_ID, ctx.m_pickingFB)

	-- Set up picking pass
	local invViewProj = ms(ctx.proj, ctx.view, "*iP")

	-- Mouse coord in NDC
	local mouseXNDC = ( ctx.mouse_x / ctx.width ) * 2 - 1
	local mouseYNDC = ( ctx.height - ctx.mouse_y) / ctx.height * 2 - 1

	local mousePosNDC = ms:vector(mouseXNDC, mouseYNDC, 0.0, 1)
	local pickEye = ms( mousePosNDC, invViewProj, "%P")

	local mousePosNDCEnd = ms:vector ( mouseXNDC, mouseYNDC, 1, 1 )
	local pickAt = ms ( mousePosNDCEnd, invViewProj, "%P")

	-- Look at our unprojected point
	local pickView = ms ( pickEye, pickAt, "lP" )

	-- Tight FOV is best for picking
	local pickProj = ms:matrix { type = "mat", fov = ctx.m_fov , aspect = 1, n = 0.1, f = 100.0 }

	-- View rect and transforms for picking pass
	bgfx.set_view_rect(RENDER_PASS_ID, 0, 0, ID_DIM, ID_DIM)
	bgfx.set_view_transform(RENDER_PASS_ID, pickView, pickProj)

	-- Now that our passes are set up, we can finally draw each mesh

	-- Picking highlights a mesh so we'll set up this tint color
	for mesh = 1,12 do
		local scale = ctx.m_meshScale[mesh]
		-- Set up transform matrix for each mesh
		local mtx = ms:srtmat(
			{scale,scale,scale} ,
			{ 0.0, time*0.37*((mesh -1 ) % 2 * 2 - 1), 0.0 },
			{ ((mesh-1) % 4) - 1.5, ((mesh-1) // 4) - 1.25, 0.0 }
		)

		-- Submit mesh to both of our render passes
		-- Set uniform based on if this is the highlighted mesh
		bgfx.set_uniform(ctx.u_tint, ctx[( mesh == ctx.m_highlighted and "tintHighlighted" or "tintBasic")])
		bgfx.set_transform(mtx)
		bgfx.set_state(ctx.state)
		util.meshSubmit(ctx.m_meshes[mesh], RENDER_PASS_SHADING, ctx.m_shadingProgram)

		-- Submit ID pass based on mesh ID
		bgfx.set_uniform(ctx.u_id, ctx.m_idsF[mesh])
		bgfx.set_transform(mtx)
		bgfx.set_state(ctx.state)
		util.meshSubmit(ctx.m_meshes[mesh], RENDER_PASS_ID,ctx.m_idProgram)
	end

	-- If the user previously clicked, and we're done reading data from GPU, look at ID buffer on CPU
	-- Whatever mesh has the most pixels in the ID buffer is the one the user clicked on.
	if ctx.m_reading == ctx.m_currFrame then
		ctx.m_reading = nil

		local tmp = {}
		local maxread = 0
		local ids, idc
		idc = 0
		for x = 1, ID_DIM * ID_DIM do
			local rgba = ctx.m_blitData[x]
			-- todo : Direct3D9 is BGRA
			if rgba ~= 0 then
				local num = (tmp[rgba] or 0) + 1
				tmp[rgba] = num
				if num > maxread then
					maxread = num
					ids = ctx.m_idsU[rgba]
					idc = rgba
				end
			end
		end
		ctx.m_highlighted = ids
	end

	-- Start a new readback?
	if ctx.m_reading == nil and ctx.mouse_click then
		ctx.mouse_click = nil
		-- Blit and read
		bgfx.blit(RENDER_PASS_BLIT, ctx.m_blitTex, 0, 0, ctx.m_pickingRT)
		ctx.m_reading = bgfx.read_texture(ctx.m_blitTex, ctx.m_blitData)
	end

	ctx.m_currFrame = bgfx.frame()
end

function ctx.init()
	-- Set up screen clears
	bgfx.set_view_clear(RENDER_PASS_SHADING, "CD", 0x303030ff, 1, 0)
	-- ID buffer clears to black, which represnts clicking on nothing (background)
	bgfx.set_view_clear(RENDER_PASS_ID, "CD", 0x000000ff, 1, 0)
--	bgfx.set_debug "ST"
	ctx.u_tint = bgfx.create_uniform("u_tint", "v4")	-- Tint for when you click on items
	ctx.u_id = bgfx.create_uniform("u_id", "v4")	-- ID for drawing into ID buffer

	-- Create program from shaders.
	ctx.m_shadingProgram = util.programLoad("vs_picking_shaded", "fs_picking_shaded")  -- Blinn shading
	ctx.m_idProgram      = util.programLoad("vs_picking_shaded", "fs_picking_id")	-- Shader for drawing into ID buffer

	local meshPaths = {
		"meshes/orb.bin",
		"meshes/column.bin",
		"meshes/bunny.bin",
		"meshes/cube.bin",
		"meshes/tree.bin",
		"meshes/hollowcube.bin",
	}

	local meshScale = {
		0.5,
		0.05,
		0.5,
		0.25,
		0.05,
		0.05,
	}

	ctx.m_highlighted = nil
	ctx.m_reading = nil
	ctx.m_fov = 3.0
	ctx.m_cameraSpin = false
	ctx.m_meshes = {}
	ctx.m_meshScale = {}
	ctx.m_idsF = {}
	ctx.m_idsU = {}

	for ii = 1, 12 do
		ctx.m_meshes[ii] = util.meshLoad(meshPaths[ii % #meshPaths + 1])
		ctx.m_meshScale[ii] = meshScale[ii % #meshScale + 1]
		-- For the sake of this example, we'll give each mesh a random color,  so the debug output looks colorful.
		-- In an actual app, you'd probably just want to count starting from 1
		local rr = math.random(1, 255)
		local gg = math.random(1, 255)
		local bb = math.random(1, 255)
--		local rr = ii
--		local gg = 0
--		local bb = 0
		ctx.m_idsF[ii] = ms:ref "vector" (rr / 255,gg / 255,bb / 255,1)
		ctx.m_idsU[rr + (gg << 8) + (bb << 16) + (255 << 24)] = ii	-- map id
	end

	-- Set up ID buffer, which has a color target and depth buffer
	ctx.m_pickingRT = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "RGBA8", "rtapac")	-- -p:BGFX_TEXTURE_MIN_POINT
	ctx.m_pickingRTDepth = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "D24S8", "rtapac")

	-- CPU texture for blitting to and reading ID buffer so we can see what was clicked on.
	-- Impossible to read directly from a render target, you *must* blit to a CPU texture
	-- first. Algorithm Overview: Render on GPU -> Blit to CPU texture -> Read from CPU
	-- texture.

	ctx.m_blitTex = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "RGBA8", "bwbrapac")	-- bw:BGFX_TEXTURE_BLIT_DST br:BGFX_TEXTURE_READ_BACK

	ctx.m_pickingFB = bgfx.create_frame_buffer({ctx.m_pickingRT,ctx.m_pickingRTDepth}, true)

	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		CULL = "CCW",
		MSAA = true,
	}

	ctx.tintBasic = ms:ref "vector" (1,1,1,1)
	ctx.tintHighlighted = ms:ref "vector" (0.3,0.3,2,1)

	ctx.mouse_x = 0
	ctx.mouse_y = 0

	ctx.m_blitData = bgfx.memory_texture(ID_DIM*ID_DIM * 4)

	assert(util.caps.supported.TEXTURE_BLIT)
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "v")

	ctx.view = ms:ref "matrix" (ms( { 0,0,-2.5 }, { 0,0,0 }, "lP"))
	ctx.proj = ms:ref "matrix" { type = "mat", fov = 60, aspect = w/h, n = 0.1, f = 100 }

	-- Set up view rect and transform for the shaded pass
	bgfx.set_view_transform(RENDER_PASS_SHADING, ctx.view, ctx.proj)
	bgfx.set_view_rect(RENDER_PASS_SHADING, 0, 0, ctx.width, ctx.height)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)
