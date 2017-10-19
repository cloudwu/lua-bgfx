local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

canvas = iup.canvas {}

dlg = iup.dialog {
  canvas,
  title = "03-raymarch",
  size = "HALFxHALF",
}

local ctx = {}

local index = { 0,2,1,0,3,2 }

local function renderScreenSpaceQuad(minx, miny, width, height)
	ctx.tb:alloc(4, 6, ctx.vdecl)
	local zz = 0
	local maxx = minx + width
	local maxy = miny + height
	local minu = -1.0
	local minv = -1.0
	local maxu = 1
	local maxv = 1

	ctx.tb:packV(0, minx, miny, zz, 0xff0000ff, minu, minv)
	ctx.tb:packV(1, maxx, miny, zz, 0xff00ff00, maxu, minv)
	ctx.tb:packV(2, maxx, maxy, zz, 0xffff0000, maxu, maxv)
	ctx.tb:packV(3, minx, maxy, zz, 0xffffffff, minu, maxv)

	ctx.tb:packI(index)
	bgfx.set_state()	-- default
	ctx.tb:set()
	bgfx.submit(1, ctx.prog)
end

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.01
	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	local vp = math3d.matrix():mul(viewmat, projmat)
	local mtx = math3d.matrix():rotmat(time, time * 0.37)
	local mtxInv = math3d.matrix():inverted(mtx)
	local lightDirTime = math3d.vector():pack(-0.4, -0.5, -1.0, 0):normalize():vec4mul(mtxInv):pack(nil,nil,nil,time)

	bgfx.set_uniform(ctx.u_lightDirTime, lightDirTime)
	local invMvp = math3d.matrix():mul(mtx,vp):inverted()
	bgfx.set_uniform(ctx.u_mtx, invMvp)

	renderScreenSpaceQuad(0.0, 0.0, 1280.0, 720.0)

	bgfx.frame()
end

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.prog = util.programLoad("vs_raymarching", "fs_raymarching")
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}
	ctx.u_mtx = bgfx.create_uniform("u_mtx", "m4")
	ctx.u_lightDirTime = bgfx.create_uniform("u_lightDirTime", "v4")
	ctx.tb = bgfx.transient_buffer "fffdff"

	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.set_view_rect(1, 0, 0, w, h)
	bgfx.reset(w,h, "v")

	local viewmat = math3d.matrix("view"):lookatp( 0,0,-15, 0,0,0)
	local projmat = math3d.matrix("proj"):projmat(60, ctx.width/ctx.height, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)
	local orthomat = math3d.matrix("ortho"):orthomat(0.0, 1280.0, 720.0, 0.0, 0.0, 100.0)
	bgfx.set_view_transform(1, nil, orthomat)
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
  bgfx.destroy(ctx.prog)
  bgfx.destroy(ctx.u_mtx)
  bgfx.destroy(ctx.u_lightDirTime)
  ant.shutdown()
end
