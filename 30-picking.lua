local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local RENDER_PASS_SHADING = 0  -- Default forward rendered geo with simple shading
local RENDER_PASS_ID = 1 -- ID buffer for picking
local RENDER_PASS_BLIT = 2  -- Blit GPU render target to CPU texture

local ID_DIM = 8  -- Size of the ID buffer

canvas = iup.canvas {}

dlg = iup.dialog {
  canvas,
  title = "30-picking",
  size = "HALFxHALF",
}

local ctx = {}

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
	math3d.reset()
	time = time + 0.01

	bgfx.set_view_frame_buffer(RENDER_PASS_ID, ctx.m_pickingFB)

	-- Set up picking pass
	local viewProj = math3d.matrix():mul(math3d.matrix "view", math3d.matrix "proj")
	local invViewProj = math3d.matrix():inverted(viewProj)

	-- Mouse coord in NDC
	local mouseXNDC = ( ctx.mouse_x / ctx.width ) * 2 - 1
	local mouseYNDC = ( ctx.height - ctx.mouse_y) / ctx.height * 2 - 1

	local pickEye = math3d.vector()
	local mousePosNDC = math3d.vector():pack( mouseXNDC, mouseYNDC, 0.0 )

	pickEye:mulH(mousePosNDC, invViewProj)

	local pickAt = math3d.vector()
	local mousePosNDCEnd = math3d.vector():pack( mouseXNDC, mouseYNDC, 1 )
	pickAt:mulH(mousePosNDCEnd, invViewProj)

	-- Look at our unprojected point
	local pickView = math3d.matrix()
	pickView:lookat(pickEye, pickAt)

	-- Tight FOV is best for picking
	local pickProj = math3d.matrix()
	pickProj:projmat(ctx.m_fov, 1, 0.1, 100.0)

	-- View rect and transforms for picking pass
	bgfx.set_view_rect(RENDER_PASS_ID, 0, 0, ID_DIM, ID_DIM)
	bgfx.set_view_transform(RENDER_PASS_ID, pickView, pickProj)

	-- Now that our passes are set up, we can finally draw each mesh

	-- Picking highlights a mesh so we'll set up this tint color
	local mtx = math3d.matrix()
	for mesh = 1,12 do
		local scale = ctx.m_meshScale[mesh]
		-- Set up transform matrix for each mesh
		mtx:srt(scale, scale, scale
			, 0.0
			, time*0.37*((mesh -1 ) % 2 * 2 - 1)
			, 0.0
			, ((mesh-1) % 4) - 1.5
			, ((mesh-1) // 4) - 1.25
			, 0.0
		)

		-- Submit mesh to both of our render passes
		-- Set uniform based on if this is the highlighted mesh
		bgfx.set_uniform(ctx.u_tint, math3d.vector( mesh == ctx.m_highlighted and "tintHighlighted" or "tintBasic"))
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

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
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
		math3d.vector(ii, ctx.m_idsF):pack(rr / 255,gg / 255,bb / 255,1)
		ctx.m_idsU[rr + (gg << 8) + (bb << 16) + (255 << 24)] = ii	-- map id
	end

	-- Set up ID buffer, which has a color target and depth buffer
	ctx.m_pickingRT = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "RGBA8", "rt-p+p*pucvc")	-- -p:BGFX_TEXTURE_MIN_POINT
	ctx.m_pickingRTDepth = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "D24S8", "rt-p+p*pucvc")

	-- CPU texture for blitting to and reading ID buffer so we can see what was clicked on.
	-- Impossible to read directly from a render target, you *must* blit to a CPU texture
	-- first. Algorithm Overview: Render on GPU -> Blit to CPU texture -> Read from CPU
	-- texture.

	ctx.m_blitTex = bgfx.create_texture2d(ID_DIM, ID_DIM, false, 1, "RGBA8", "bwbr-p+p*pucvc")	-- bw:BGFX_TEXTURE_BLIT_DST br:BGFX_TEXTURE_READ_BACK

	ctx.m_pickingFB = bgfx.create_frame_buffer({ctx.m_pickingRT,ctx.m_pickingRTDepth}, true)

	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		CULL = "CCW",
		MSAA = true,
	}

	math3d.vector("tintBasic"):pack(1,1,1,1)
	math3d.vector("tintHighlighted"):pack(0.3,0.3,2,1)

	ctx.mouse_x = 0
	ctx.mouse_y = 0

	ctx.m_blitData = bgfx.memory_texture(ID_DIM*ID_DIM * 4)

	assert(ant.caps.supported.TEXTURE_BLIT)

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
	viewmat:lookatp( 0,0,-2.5, 0,0,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)

	-- Set up view rect and transform for the shaded pass
	bgfx.set_view_transform(RENDER_PASS_SHADING, viewmat, projmat)
	bgfx.set_view_rect(RENDER_PASS_SHADING, 0, 0, ctx.width, ctx.height)
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
  ant.shutdown()
end
