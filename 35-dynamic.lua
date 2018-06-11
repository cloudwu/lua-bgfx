local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local kDimWidth  = 11
local kDimHeight = 11

local s_cubeVertices = {
	"fffd",
	-1.0,  1.0,  1.0, 0xff000000 ,
	 1.0,  1.0,  1.0, 0xff0000ff ,
	-1.0, -1.0,  1.0, 0xff00ff00 ,
	 1.0, -1.0,  1.0, 0xff00ffff ,
	-1.0,  1.0, -1.0, 0xffff0000 ,
	 1.0,  1.0, -1.0, 0xffff00ff ,
	-1.0, -1.0, -1.0, 0xffffff00 ,
	 1.0, -1.0, -1.0, 0xffffffff ,
}

canvas = iup.canvas{}

dlg = iup.dialog {
  canvas,
  title = "35-dynamic",
  size = "HALFxHALF",
}

local tmp = { "fffd" }
local ctx = {}
local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	local mat = math3d.matrix()
	time = time + 0.01


	local mtx = math3d.matrix()
	do
		local angle math.random()
		mtx:rotmat(0,0,angle)
		local vec = math3d.vector()
		for i = 2, 33, 4 do
			vec:pack(s_cubeVertices[i], s_cubeVertices[i+1], s_cubeVertices[i+2])
			vec:mul(mtx)
			tmp[i], tmp[i+1], tmp[i+2] = vec:unpack()
			local r = math.random(0,0xff)
			local g = math.random(0,0xff)
			local b = math.random(0,0xff)
			local a = math.random(0,0xff)
			tmp[i+3] = r << 24 | g << 16 | b << 8 | a
		end

		local idx = math.random(1, kDimWidth*kDimHeight)
		bgfx.update(ctx.m_vbh[idx], 0, tmp)
	end

	-- Submit 11x11 cubes.

	for yy = 0, kDimHeight do
		for xx = 0, kDimWidth do
			mtx:rotmat(time + xx*0.21, time + yy * 0.37):trans(-15.0 + xx * 3, -15.0 + yy * 3, 0)
			-- Set model matrix for rendering.
			bgfx.set_transform(mtx)
			-- Set vertex and index buffer.
			bgfx.set_vertex_buffer(ctx.m_vbh[yy*kDimWidth+xx+1])
			bgfx.set_index_buffer(ctx.m_ibh)
			-- Set render states.
			bgfx.set_state(ctx.state)
			-- Submit primitive for rendering to view 0.
			bgfx.submit(0, ctx.prog)
		end
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}
	-- Create static vertex buffer.
	ctx.m_vbh = {}

	for yy = 0 , kDimHeight do
		for xx = 0, kDimWidth do
			ctx.m_vbh[yy*kDimWidth+xx+1] = bgfx.create_dynamic_vertex_buffer(
						s_cubeVertices, ctx.vdecl)
		end
	end

	-- Create static index buffer.
	ctx.m_ibh = bgfx.create_dynamic_index_buffer {
	0, 1, 2,
	3,
	7,
	1,
	5,
	0,
	4,
	2,
	6,
	7,
	4,
	5,
	}

	ctx.prog = util.programLoad("vs_cubes", "fs_cubes")

	ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- base on BGFX_STATE_DEFAULT

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
  ant.shutdown()
end
