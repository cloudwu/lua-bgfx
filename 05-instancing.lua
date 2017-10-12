local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

canvas = iup.canvas {}

dlg = iup.dialog {
  canvas,
  title = "05-instancing",
  size = "HALFxHALF",
}

local ctx = {}

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.01
	ctx.idb:alloc(121)
	local mtx = math3d.matrix()
	local color = math3d.vector()

	local i = 0
	for yy=0,10 do
		for xx=0,10 do
			mtx:rotmat(time + xx* 0.21 , time + yy * 0.37)
			mtx:packline(4, -15.0 + xx*3.0, -15.0 + yy*3.0, 0.0)
			color:pack(
				math.sin(time+xx/11)*0.5+0.5,
				math.cos(time+yy/11)*0.5+0.5,
				math.sin(time*3.0)*0.5+0.5
			)
			ctx.idb(i, mtx, color)
			i = i + 1
		end
	end

	ctx.idb:set()
	bgfx.set_vertex_buffer(0, ctx.vb)
	bgfx.set_index_buffer(ctx.ib)
	bgfx.set_state(ctx.state)
	bgfx.submit(0, ctx.prog)
	bgfx.frame()
end

local function notsupported()
	bgfx.touch(0)
	bgfx.dbg_text_print(0, 0, 0x01, " Instancing is not supported by GPU. ")
	bgfx.frame()
end

local init

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.prog = util.load_program("vs_instancing", "fs_instancing")
	ctx.state = bgfx.make_state {}
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "NORMAL", 4, "UINT8", true, true },
		{ "TANGENT", 4, "UINT8", true, true },
		{ "TEXCOORD0", 2, "UINT16", true, true },
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
	ctx.idb = bgfx.instance_buffer "mv"	-- 64 bytes for 4x4 matrix + 16 bytes for RGBA color

	if ant.caps.supported.INSTANCING then
		ant.mainloop(mainloop)
	else
		bgfx.set_debug "T"
		ant.mainloop(notsupported)
	end
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "vmx")

	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp( 0.0, 0.0, -35.0, 0,0,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
end

function canvas:action(x,y)
	if ant.caps.supported.INSTANCING then
		mainloop()
	else
		notsupported()
	end
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
  bgfx.destroy(ctx.prog)
  bgfx.destroy(ctx.ib)
  bgfx.destroy(ctx.vb)
  ant.shutdown()
end
