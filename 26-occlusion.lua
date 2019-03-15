package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local CUBES_DIM = 10

local ctx = {
	canvas = iup.canvas {},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "26-occlusion",
	size = "HALFxHALF",
}

local ms = util.mathstack
local time = 0

local function mainloop()
	math3d.reset(ms)
	bgfx.touch(0)
	bgfx.touch(2)
	time = time + 0.001

	local img = {}
	local offset = -(CUBES_DIM-1) * 3.0 / 2.0
	for yy = 0, CUBES_DIM-1 do
		for xx = 0, CUBES_DIM-1 do
			local mtx = ms:srtmat ( nil, { time + xx*0.21 , time + yy*0.37, 0 }, {offset + xx*3, 0, offset + yy*3} )
			local occlusionQuery = ctx.m_occlusionQueries[yy*CUBES_DIM+xx+1]

			bgfx.set_transform(mtx)
			bgfx.set_vertex_buffer(0,ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_condition(occlusionQuery, true)
			bgfx.set_state()	-- default
			bgfx.submit(0, ctx.m_program)


			bgfx.set_transform(mtx)
			bgfx.set_vertex_buffer(0,ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_state(ctx.test_state)
			bgfx.submit_occlusion_query(1, ctx.m_program, occlusionQuery)

			bgfx.set_transform(mtx)
			bgfx.set_vertex_buffer(0,ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_condition(occlusionQuery, true)
			bgfx.set_state()	-- default
			bgfx.submit(2, ctx.m_program)

			local r = bgfx.get_result(occlusionQuery)
			if r then
				table.insert(img, "\xfe\x0f")
			elseif r == false then
				table.insert(img, " \x0f")
			else
				table.insert(img, "x\x0f")
			end
		end
	end

	bgfx.dbg_text_clear()

	bgfx.dbg_text_image(5,5,CUBES_DIM,CUBES_DIM,table.concat(img))

	local _, num = bgfx.get_result(ctx.m_occlusionQueries[1])
	bgfx.dbg_text_print(5, 5 + CUBES_DIM + 1, 0xf, tostring(num))

	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.set_view_clear(2, "CD", 0x202020ff, 1, 0)

	bgfx.set_debug "T"

	ctx.m_program = util.programLoad("vs_cubes", "fs_cubes")

	ctx.VertexDecl = bgfx.vertex_decl {
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
		ctx.VertexDecl)

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

	assert(util.caps.supported.OCCLUSION_QUERY)

	ctx.m_occlusionQueries = {}

	for i = 1, CUBES_DIM*CUBES_DIM do
		ctx.m_occlusionQueries[i] = bgfx.create_occlusion_query()
	end

	ctx.test_state = bgfx.make_state {
		DEPTH_TEST = "LEQUAL",
		CULL = "CW",
	}
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(ctx.width,ctx.height, "v")
	local viewmat = ms( { 0,0,-35} , { 0,0,0 }, "lP")
	local projmat = ms:matrix { type = "mat", fov = 90, aspect = w/h, n = 0.1, f = 10000 }
	local view2 = ms( { 17.5, 10, -17.5 }, { 0,0,0 }, "lP")

	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(1, 0, 0, ctx.width, ctx.height)
	bgfx.set_view_transform(1, viewmat, projmat)

	bgfx.set_view_transform(2, view2, projmat)
	bgfx.set_view_rect(2, 10, (h * 3//4 - 10), w//4, h//4)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)
