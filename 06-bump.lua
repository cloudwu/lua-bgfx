package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local bgfxu = require "bgfx.util"
local util = require "util"
local math3d = require "math3d"

local ctx = {
	canvas = iup.canvas {},
}

local ms = util.mathstack

local dlg = iup.dialog {
	ctx.canvas,
	title = "06-bump",
	size = "HALFxHALF",
}

local time = 0

local function setlight()
	local light = {}
	for i=1,ctx.numLights do
		light[i] = ms:vector ( math.sin(time*(0.1+i*0.17) + i * math.pi * 1.37) * 3,
			math.cos(time*(0.2+i*0.29) + i * math.pi * 1.49) * 3,
			-2.5, 3 )
	end

	bgfx.set_uniform(ctx.u_lightPosRadius, table.unpack(light))
	bgfx.set_uniform(ctx.u_lightRgbInnerR, table.unpack(ctx.lightRgbInnerR))
end

local function mainloop()
	math3d.reset(ms)
	bgfx.touch(0)
	time = time + 0.01

	setlight()

	for yy=0,2 do
		for xx=0,2 do
			bgfx.set_transform(ms:srtmat(nil, { time*0.023 + xx*0.21, time*0.03 + yy*0.37, 0 }, { -3+xx*3, -3+yy*3, 0 } ))
			bgfx.set_vertex_buffer(ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_texture(0, ctx.s_texColor, ctx.textureColor)
			bgfx.set_texture(1, ctx.s_texNormal, ctx.textureNormal)
			bgfx.set_state(ctx.state)
			bgfx.submit(0, ctx.prog)
		end
	end
	bgfx.frame()
end

local function mainloop_instancing()
	math3d.reset(ms)
	bgfx.touch(0)
	time = time + 0.01

	setlight()

	ctx.idb:alloc(9)
	for yy= 0,2 do
		for xx=0,2 do
			ctx.idb(yy*3+xx, ms:srtmat(nil, { time*0.023 + xx*0.21, time*0.03 + yy*0.37, 0 },{ -3+xx*3, -3+yy*3, 0 } ) )
		end
	end
	ctx.idb:set()
	bgfx.set_vertex_buffer(ctx.vb)
	bgfx.set_index_buffer(ctx.ib)
	bgfx.set_texture(0, ctx.s_texColor, ctx.textureColor)
	bgfx.set_texture(1, ctx.s_texNormal, ctx.textureNormal)
	bgfx.set_state(ctx.state)
	bgfx.submit(0, ctx.prog)

	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "NORMAL", 4, "UINT8", true, true },
		{ "TANGENT", 4, "UINT8", true, true },
		{ "TEXCOORD0", 2, "INT16", true, true },
	}

	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		MSAA = true,
	}

	local s_cubeIndices =  {
	 0,  2,  1,
	 1,  2,  3,
	 4,  5,  6,
	 5,  7,  6,

	 8, 10,  9,
	 9, 10, 11,
	12, 13, 14,
	13, 15, 14,

	16, 18, 17,
	17, 18, 19,
	20, 21, 22,
	21, 23, 22,
	}

	local encodeNormalRgba8 = bgfxu.encodeNormalRgba8

	ctx.vb = bgfx.create_vertex_buffer({
			"fffddss",
			-1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0,      0,      0 ,
			 1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0, 0x7fff,      0 ,
			-1.0, -1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0,      0, 0x7fff ,
			 1.0, -1.0,  1.0, encodeNormalRgba8( 0.0,  0.0,  1.0), 0, 0x7fff, 0x7fff ,
			-1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0,      0,      0 ,
			 1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0, 0x7fff,      0 ,
			-1.0, -1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0,      0, 0x7fff ,
			 1.0, -1.0, -1.0, encodeNormalRgba8( 0.0,  0.0, -1.0), 0, 0x7fff, 0x7fff ,
			-1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0,      0,      0 ,
			 1.0,  1.0,  1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0, 0x7fff,      0 ,
			-1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0,      0, 0x7fff ,
			 1.0,  1.0, -1.0, encodeNormalRgba8( 0.0,  1.0,  0.0), 0, 0x7fff, 0x7fff ,
			-1.0, -1.0,  1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0,      0,      0 ,
			 1.0, -1.0,  1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0, 0x7fff,      0 ,
			-1.0, -1.0, -1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0,      0, 0x7fff ,
			 1.0, -1.0, -1.0, encodeNormalRgba8( 0.0, -1.0,  0.0), 0, 0x7fff, 0x7fff ,
			 1.0, -1.0,  1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0,      0,      0 ,
			 1.0,  1.0,  1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0, 0x7fff,      0 ,
			 1.0, -1.0, -1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0,      0, 0x7fff ,
			 1.0,  1.0, -1.0, encodeNormalRgba8( 1.0,  0.0,  0.0), 0, 0x7fff, 0x7fff ,
			-1.0, -1.0,  1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0,      0,      0 ,
			-1.0,  1.0,  1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0, 0x7fff,      0 ,
			-1.0, -1.0, -1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0,      0, 0x7fff ,
			-1.0,  1.0, -1.0, encodeNormalRgba8(-1.0,  0.0,  0.0), 0, 0x7fff, 0x7fff ,
		},
		ctx.vdecl , "t" , s_cubeIndices)
	ctx.ib = bgfx.create_index_buffer(s_cubeIndices)
	ctx.s_texColor  = bgfx.create_uniform("s_texColor", "s")
	ctx.s_texNormal = bgfx.create_uniform("s_texNormal", "s")
	ctx.numLights = 4
	ctx.u_lightPosRadius = bgfx.create_uniform("u_lightPosRadius", "v4", ctx.numLights)
	ctx.u_lightRgbInnerR = bgfx.create_uniform("u_lightRgbInnerR", "v4", ctx.numLights)
	ctx.textureColor = util.textureLoad "textures/fieldstone-rgba.dds"
	ctx.textureNormal = util.textureLoad "textures/fieldstone-n.dds"

	ctx.lightRgbInnerR = {
		ms:ref "vector" { 1.0, 0.7, 0.2, 0.8 },
		ms:ref "vector" { 0.7, 0.2, 1.0, 0.8 },
		ms:ref "vector" { 0.2, 1.0, 0.7, 0.8 },
		ms:ref "vector" { 1.0, 0.4, 0.2, 0.8 },
	}

	if util.caps.supported.INSTANCING then
		ctx.prog = util.programLoad("vs_bump_instanced", "fs_bump")
		ctx.idb = bgfx.instance_buffer "m"
		mainloop = mainloop_instancing
	else
		ctx.prog = util.programLoad("vs_bump", "fs_bump")
	end
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "vmx")

	local viewmat = ms( { 0.0, 0.0, -7.0 }, {  0,0,0 }, "lP")
	local projmat = ms( { type = "mat", fov = 60, aspect = w/h , n = 0.1, f = 100 }, "P")

	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)

-- bgfx.destroy(ctx.prog)
-- bgfx.destroy(ctx.ib)
-- bgfx.destroy(ctx.vb)
-- bgfx.destroy(ctx.s_texColor)
-- bgfx.destroy(ctx.s_texNormal)
-- bgfx.destroy(ctx.u_lightPosRadius)
-- bgfx.destroy(ctx.u_lightRgbInnerR)
-- bgfx.destroy(ctx.textureColor)
-- bgfx.destroy(ctx.textureNormal)
