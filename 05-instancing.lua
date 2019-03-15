package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local ctx = {
	canvas = iup.canvas {},
}

local ms = util.mathstack

local dlg = iup.dialog {
	ctx.canvas,
	title = "05-instancing",
	size = "HALFxHALF",
}

local time = 0
local function mainloop()
	math3d.reset(ms)
	bgfx.touch(0)
	time = time + 0.01
	ctx.idb:alloc(121)

	local i = 0
	for yy=0,10 do
		for xx=0,10 do
			local mtx = ms( { type = "srt",
				r = { time + xx* 0.21 , time + yy * 0.37, 0 },
				t = { -15.0 + xx*3.0, -15.0 + yy*3.0, 0.0 },
			} , "P")
			local color = ms( {
				math.sin(time+xx/11)*0.5+0.5,
				math.cos(time+yy/11)*0.5+0.5,
				math.sin(time*3.0)*0.5+0.5
				}, "P")
			ctx.idb(i, mtx, color)
			i = i + 1
		end
	end

	ctx.idb:set()
	bgfx.set_vertex_buffer(ctx.vb)
	bgfx.set_index_buffer(ctx.ib)
	bgfx.set_state()
	bgfx.submit(0, ctx.prog)
	bgfx.frame()
end

local function notsupported()
	bgfx.touch(0)
	bgfx.dbg_text_print(0, 0, 0x01, " Instancing is not supported by GPU. ")
	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.prog = util.programLoad("vs_instancing", "fs_instancing")
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

	if not util.caps.supported.INSTANCING then
		bgfx.set_debug "T"
		mainloop = notsupported
	end
end


function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "vmx")

	local viewmat = ms( { 0.0, 0.0, -35.0 }, {  0,0,0 }, "lP")
	local projmat = ms( { type = "mat", fov = 60, aspect = w/h , n = 0.1, f = 100 }, "P")
	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)

--  bgfx.destroy(ctx.prog)
--  bgfx.destroy(ctx.ib)
--  bgfx.destroy(ctx.vb)
