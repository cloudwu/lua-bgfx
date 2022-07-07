package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local ctx = {
--	renderer = "OPENGL",
	canvas = iup.canvas{
	--	rastersize = "1024x768",
	--	rastersize = "400x300",
	},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "01-cubes",
	size = "HALFxHALF",
}

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.001
	local transform = {}
	local n = 1
	for yy = 0, 9 do
		for xx = 0, 9 do
			transform[n] = { r = { time + xx*0.21, time + yy*0.37, 0 }, t = { -15.0 + xx * 3, -15.0 + yy * 3, 0 } }
			n = n + 1
		end
	end
	local tid = bgfx.alloc_transform(table.unpack(transform))
	bgfx.set_vertex_buffer(ctx.vb)
	bgfx.set_index_buffer(ctx.ib)
	bgfx.set_state(ctx.state)
	bgfx.multi_submit(0, ctx.prog, tid, 100)

--	for yy = 0, 10 do
--		for xx = 0, 10 do
--			bgfx.set_transform { r = { time + xx*0.21, time + yy*0.37, 0 }, t = { -15.0 + xx * 3, -15.0 + yy * 3, 0 } }
--			bgfx.set_vertex_buffer(ctx.vb)
--			bgfx.set_index_buffer(ctx.ib)
--			bgfx.set_state(ctx.state)
--			bgfx.submit(0, ctx.prog)
--		end
--	end

	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.prog = util.programLoad("vs_cubes", "fs_cubes")

	ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
	ctx.vdecl = bgfx.vertex_layout {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}
	local buf = bgfx.memory_buffer( 16 * 8)
	buf[1]    = string.pack("fffL", -1.0,  1.0,  1.0, 0xff000000)
	buf[16+1] = string.pack("fffL", 1.0,  1.0,  1.0, 0xff0000ff)
	buf[32+1] = string.pack("fffL", -1.0, -1.0,  1.0, 0xff00ff00)
	buf[48+1] = string.pack("fffL", 1.0, -1.0,  1.0, 0xff00ffff)
	buf[64+1] = string.pack("fffL", -1.0,  1.0, -1.0, 0xffff0000)
	buf[80+1] = string.pack("fffL", 1.0,  1.0, -1.0, 0xffff00ff)
	buf[96+1] = string.pack("fffL", -1.0, -1.0, -1.0, 0xffffff00)
	buf[112+1] = string.pack("fffL", 1.0, -1.0, -1.0, 0xffffffff)
--[[
	local buf = bgfx.memory_buffer("fffd", {
			-1.0,  1.0,  1.0, 0xff000000,
			 1.0,  1.0,  1.0, 0xff0000ff,
			-1.0, -1.0,  1.0, 0xff00ff00,
			 1.0, -1.0,  1.0, 0xff00ffff,
			-1.0,  1.0, -1.0, 0xffff0000,
			 1.0,  1.0, -1.0, 0xffff00ff,
			-1.0, -1.0, -1.0, 0xffffff00,
			 1.0, -1.0, -1.0, 0xffffffff,
		})
	]]
	ctx.vb = bgfx.create_vertex_buffer(buf, ctx.vdecl)
	ctx.ib = bgfx.create_index_buffer{
		0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
	}
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
	bgfx.reset(ctx.width,ctx.height, "vmx")
	-- calc lookat matrix, return matrix pointer, and remove top

	local eyepos, at = math3d.vector(0,0,-35), math3d.vector(0, 0, 0)
	local viewmat = math3d.lookat(eyepos, at)
	local projmat = math3d.projmat { fov = 60, aspect = w/h , n = 0.1, f = 100 }
	bgfx.set_view_transform(0, viewmat, projmat)
end


util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)

-- util.run will call bgfx.shutdown to destroy everything, so don't call these:
--bgfx.destroy(ctx.vb)
--bgfx.destroy(ctx.ib)
--bgfx.destroy(ctx.prog)
