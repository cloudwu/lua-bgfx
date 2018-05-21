local ant = require "ant"
local util = require "ant.util"
local common = require "ant.common"
local math3d = require "ant.math"
local bgfx = require "bgfx"

canvas = iup.canvas{
--	rastersize = "1024x768",
--	rastersize = "400x300",
}

canvas.keypress_cb = common.keypress_cb

dlg = iup.dialog {
  canvas,
  title = "01-cubes",
  size = "HALFxHALF",
}

local ctx = {}
local time = 0
local function mainloop()
	common.save_screenshot "screenshot.ppm"
	math3d.reset()
	bgfx.touch(0)
	local mat = math3d.matrix()
	time = time + 0.001
	for yy = 0, 10 do
		for xx = 0, 10 do
			mat:rotmat(time + xx*0.21, time + yy*0.37):trans(-15.0 + xx * 3, -15.0 + yy * 3, 0)
			bgfx.set_transform(mat)
			bgfx.set_vertex_buffer(ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_state(ctx.state)
			bgfx.submit(0, ctx.prog)
		end
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
--		renderer = "DIRECT3D9",
		renderer = "OPENGL",
	}
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.prog = util.programLoad("vs_cubes", "fs_cubes")

	ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}
	ctx.vb = bgfx.create_vertex_buffer({
			"fffd",
			-1.0,  1.0,  1.0, 0xff000000,
			 1.0,  1.0,  1.0, 0xff0000ff,
			-1.0, -1.0,  1.0, 0xff00ff00,
			 1.0, -1.0,  1.0, 0xff00ffff,
			-1.0,  1.0, -1.0, 0xffff0000,
			 1.0,  1.0, -1.0, 0xffff00ff,
			-1.0, -1.0, -1.0, 0xffffff00,
			 1.0, -1.0, -1.0, 0xffffffff,
		},
		ctx.vdecl)
	ctx.ib = bgfx.create_index_buffer{
		0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
	}
	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
	bgfx.reset(ctx.width,ctx.height, "vmx")
	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp(0,0,-35, 0,0,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)
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
  bgfx.destroy(ctx.vb)
  bgfx.destroy(ctx.ib)
  bgfx.destroy(ctx.prog)
  ant.shutdown()
end
