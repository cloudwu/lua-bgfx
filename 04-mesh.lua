local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

canvas = iup.canvas {}

dlg = iup.dialog {
  canvas,
  title = "04-mesh",
  size = "HALFxHALF",
}

local ctx = {}

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.01
	local timev = math3d.vector():pack(time)
	bgfx.set_uniform(ctx.u_time, timev)
	local mtx = math3d.matrix():rotmat(0, time)
	bgfx.set_transform(mtx)
	bgfx.set_state(ctx.state)
	util.meshSubmit(ctx.mesh, 0, ctx.prog)
	bgfx.frame()
end

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.prog = util.programLoad("vs_mesh", "fs_mesh")
	ctx.mesh = util.meshLoad "meshes/bunny.bin"
	ctx.u_time = bgfx.create_uniform("u_time", "v4")
	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		CULL = "CCW",
		MSAA = true,
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
	bgfx.reset(w,h, "v")

	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp( 0,1,-2.5, 0,1,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
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
  bgfx.destroy(ctx.u_time)
  bgfx.destroy(ctx.prog)
  util.meshUnload(ctx.mesh)
  ant.shutdown()
end
