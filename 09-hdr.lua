local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local settings = {
	speed = 0.37,
	middleGray = 0.18,
	white = 1.1,
	threshold = 1.5,
}

local function slider(name, title, min, max)
	local value = assert(settings[name])
	local label = iup.label { title = tostring(value) }
	local function update_value(self)
		local v = tonumber(self.value)
		settings[name] = v
		label.title = string.format("%.2f",v)
	end
	local s = iup.frame {
		iup.hbox {
			iup.val {
				"HORIZONTAL";
				min = min,
				max = max,
				value = value,
				valuechanged_cb = update_value,
			},
			label
		},
		title = title,
	}
	return s
end

local canvas = iup.canvas {}
local lumAvgLabel = iup.label { SIZE = "100x" } -- { expand="HORIZONTAL" }

local function update_lumarg()
	local v0,v1,v2,v3 = string.unpack("BBBB", settings.lumAvg)
	local exponent = v3 - 128
	local lumAvg = v2/255 * 2 ^ exponent

	lumAvgLabel.title = string.format("lum Avg : %.2f", lumAvg)
end

local ctrl = iup.frame {
	iup.vbox {
		slider("speed", "Speed", 0, 1),
		slider("middleGray", "Middle gray", 0.1, 1),
		slider("white", "White point", 0.1, 2),
		slider("threshold", "Threshold", 0.1, 2),
		lumAvgLabel,
	},
	title = "Settings",
--	margin  = "10x10",
	size = "60",
}

dlg = iup.dialog {
	iup.hbox {
		iup.vbox {
			ctrl,
			margin = "10x10",
		},
		canvas,
	},
  title = "09-hdr",
  size = "HALFxHALF",
}

local ctx = {}
local view_order = { 0,1,2,3,4,5,6,7,8,9 }

local function shuffle()
	for i=1,9 do
		local a = math.random(i, 10)
		local b = math.random(i, 10)
		view_order[a] , view_order[b] = view_order[b], view_order[a]
	end
end

local function screenSpaceQuad(textureWidth, textureHeight, originBottomLeft)
	local width = 1
	local height = 1
	ctx.tvb:alloc(3, ctx.vdecl)

	local zz = 0
	local minx = -width
	local maxx = width
	local miny = 0
	local maxy = height*2
	local texelHalfW = ctx.s_texelHalf/textureWidth
	local texelHalfH = ctx.s_texelHalf/textureHeight
	local minu = -1 + texelHalfW
	local maxu = 1 + texelHalfW
	local minv = texelHalfH
	local maxv = 2 + texelHalfH

	if originBottomLeft then
		minv,maxv = maxv, minv
		minv = minv - 1
		maxv = maxv - 1
	end

	ctx.tvb(0, minx, miny, zz, 0xffffffff, minu, minv)
	ctx.tvb(1, maxx, miny, zz, 0xffffffff, maxu, minv)
	ctx.tvb(2, maxx, maxy, zz, 0xffffffff, maxu, maxv)

	ctx.tvb:set()
end

local offsets = {}
local function setOffsets2x2Lum(handle, width, height)
	local du = 1/width
	local dv = 1/height
	local num = 0
	local h = ctx.s_texelHalf
	for yy = 0, 2 do
		for xx = 0, 2 do
			num = num + 1
			local v = math3d.vector(num,offsets):pack((xx - h) * du,(yy - h) * dv)
		end
	end

	bgfx.set_uniform(handle, table.unpack(offsets))
end

local function setOffsets4x4Lum(handle, width, height)
	local du = 1/width
	local dv = 1/height
	local num = 0
	local h = ctx.s_texelHalf
	for yy = 0, 3 do
		for xx = 0, 3 do
			num = num + 1
			local v = math3d.vector(num,offsets):pack((xx - 1 - h) * du,(yy - 1 - h) * dv)
		end
	end

	bgfx.set_uniform(handle, table.unpack(offsets))
end

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.02 * settings.speed
	shuffle()
	local hdrSkybox, hdrMesh, hdrLuminance, hdrLumScale0, hdrLumScale1,
		hdrLumScale2, hdrLumScale3, hdrBrightness, hdrVBlur, hdrHBlurTonemap = table.unpack(view_order)
	bgfx.set_view_name(hdrSkybox, "Skybox")
	bgfx.set_view_clear(hdrSkybox, "CD", 0x303030ff, 1.0, 0)
	bgfx.set_view_rect(hdrSkybox, 0, 0)
	bgfx.set_view_frame_buffer(hdrSkybox, ctx.m_fbh)

	bgfx.set_view_name(hdrMesh, "Mesh")
	bgfx.set_view_clear(hdrMesh, "ds")
	bgfx.set_view_rect(hdrMesh, 0, 0)
	bgfx.set_view_frame_buffer(hdrMesh, ctx.m_fbh)

	bgfx.set_view_name(hdrLuminance, "Luminance")
	bgfx.set_view_rect(hdrLuminance, 0, 0, 128, 128)
	bgfx.set_view_frame_buffer(hdrLuminance, ctx.m_lum[1])

	bgfx.set_view_name(hdrLumScale0, "Downscale luminance 0")
	bgfx.set_view_rect(hdrLumScale0, 0, 0, 64, 64)
	bgfx.set_view_frame_buffer(hdrLumScale0, ctx.m_lum[2])

	bgfx.set_view_name(hdrLumScale1, "Downscale luminance 1")
	bgfx.set_view_rect(hdrLumScale1, 0, 0, 16, 16)
	bgfx.set_view_frame_buffer(hdrLumScale1, ctx.m_lum[3])

	bgfx.set_view_name(hdrLumScale2, "Downscale luminance 2")
	bgfx.set_view_rect(hdrLumScale2, 0, 0, 4, 4)
	bgfx.set_view_frame_buffer(hdrLumScale2, ctx.m_lum[4])

	bgfx.set_view_name(hdrLumScale3, "Downscale luminance 3")
	bgfx.set_view_rect(hdrLumScale3, 0, 0, 1, 1)
	bgfx.set_view_frame_buffer(hdrLumScale3, ctx.m_lum[5])

	bgfx.set_view_name(hdrBrightness, "Brightness")
	bgfx.set_view_rect(hdrBrightness, 0, 0, "1/2")
	bgfx.set_view_frame_buffer(hdrBrightness, ctx.m_bright)

	bgfx.set_view_name(hdrVBlur, "Blur vertical")
	bgfx.set_view_rect(hdrVBlur, 0, 0, "1/8")
	bgfx.set_view_frame_buffer(hdrVBlur, ctx.m_blur)

	bgfx.set_view_name(hdrHBlurTonemap, "Blur horizontal + tonemap")
	bgfx.set_view_rect(hdrHBlurTonemap, 0, 0)
	bgfx.set_view_frame_buffer(hdrHBlurTonemap)	-- bgfx::setViewFrameBuffer(hdrHBlurTonemap, BGFX_INVALID_HANDLE)

	bgfx.set_view_order(view_order)

	for i=0,#view_order-1 do
		bgfx.set_view_transform(i, nil, ctx.ortho)
	end

	local mtx = math3d.matrix():rotmat(0, time)
	local eye = math3d.vector():pack(0,1,-2.5):mul(mtx)
	local at = math3d.vector():pack(0,1,0)
	local view = math3d.matrix():lookat(eye, at)

	bgfx.set_view_transform(hdrMesh, view, ctx.proj)

	-- Render skybox into view hdrSkybox.
	bgfx.set_texture(0, ctx.s_texCube, ctx.m_uffizi)
	bgfx.set_state(ctx.state)
	bgfx.set_uniform(ctx.u_mtx, mtx)
	screenSpaceQuad( ctx.width, ctx.height, true)
	bgfx.submit(hdrSkybox, ctx.m_skyProgram)

	local tonemap = math3d.vector():pack(
		settings.middleGray,
		settings.white ^ 2,
		settings.threshold,
		time
	)
	local originBottomLeft = ant.caps.originBottomLeft

	-- Render m_mesh into view hdrMesh.
	bgfx.set_texture(0, ctx.s_texCube, ctx.m_uffizi)
	bgfx.set_uniform(ctx.u_tonemap, tonemap)
	bgfx.set_state(ctx.mesh_state)
	util.meshSubmit(ctx.m_mesh, hdrMesh, ctx.m_meshProgram)

	-- Calculate luminance.
	setOffsets2x2Lum(ctx.u_offset, 128, 128)
	bgfx.set_texture(0, ctx.s_texColor, ctx.m_fbtextures[1])
	bgfx.set_state(ctx.state)
	screenSpaceQuad(128.0, 128.0, originBottomLeft)
	bgfx.submit(hdrLuminance, ctx.m_lumProgram)

	-- Downscale luminance 0.
	setOffsets4x4Lum(ctx.u_offset, 128, 128)
	bgfx.set_texture(0, ctx.s_texColor, bgfx.get_texture(ctx.m_lum[1]))
	bgfx.set_state(ctx.state)
	screenSpaceQuad(64.0, 64.0, originBottomLeft)
	bgfx.submit(hdrLumScale0, ctx.m_lumAvgProgram)

	-- Downscale luminance 1.
	setOffsets4x4Lum(ctx.u_offset, 64, 64)
	bgfx.set_texture(0, ctx.s_texColor, bgfx.get_texture(ctx.m_lum[2]))
	bgfx.set_state(ctx.state)
	screenSpaceQuad(16, 16, originBottomLeft)
	bgfx.submit(hdrLumScale1, ctx.m_lumAvgProgram)

	-- Downscale luminance 2.
	setOffsets4x4Lum(ctx.u_offset, 16, 16)
	bgfx.set_texture(0, ctx.s_texColor, bgfx.get_texture(ctx.m_lum[3]))
	bgfx.set_state(ctx.state)
	screenSpaceQuad(4, 4, originBottomLeft)
	bgfx.submit(hdrLumScale2, ctx.m_lumAvgProgram)

	-- Downscale luminance 3.
	setOffsets4x4Lum(ctx.u_offset, 4, 4)
	bgfx.set_texture(0, ctx.s_texColor, bgfx.get_texture(ctx.m_lum[4]))
	bgfx.set_state(ctx.state)
	screenSpaceQuad(1, 1, originBottomLeft)
	bgfx.submit(hdrLumScale3, ctx.m_lumAvgProgram)

	-- m_bright pass m_threshold is tonemap[3].
	setOffsets4x4Lum(ctx.u_offset, ctx.width/2, ctx.height/2)
	bgfx.set_texture(0, ctx.s_texColor, ctx.m_fbtextures[1])
	bgfx.set_texture(1, ctx.s_texLum, bgfx.get_texture(ctx.m_lum[5]))
	bgfx.set_state(ctx.state)
	bgfx.set_uniform(ctx.u_tonemap, tonemap)
	screenSpaceQuad( ctx.width/2, ctx.height/2, originBottomLeft)
	bgfx.submit(hdrBrightness, ctx.m_brightProgram)

	-- m_blur m_bright pass vertically.
	bgfx.set_texture(0, ctx.s_texColor, bgfx.get_texture(ctx.m_bright))
	bgfx.set_state(ctx.state)
	bgfx.set_uniform(ctx.u_tonemap, tonemap)
	screenSpaceQuad(ctx.width/8, ctx.height/8, originBottomLeft)
	bgfx.submit(hdrVBlur, ctx.m_blurProgram)

	-- m_blur m_bright pass horizontally, do tonemaping and combine.
	bgfx.set_texture(0, ctx.s_texColor, ctx.m_fbtextures[1])
	bgfx.set_texture(1, ctx.s_texLum, bgfx.get_texture(ctx.m_lum[5]) )
	bgfx.set_texture(2, ctx.s_texBlur, bgfx.get_texture(ctx.m_blur) )
	bgfx.set_state(ctx.state)
	screenSpaceQuad( ctx.width, ctx.height, originBottomLeft)
	bgfx.submit(hdrHBlurTonemap, ctx.m_tonemapProgram)

	if ctx.m_rb then
		bgfx.blit(hdrHBlurTonemap, ctx.m_rb, 0, 0, bgfx.get_texture(ctx.m_lum[5]) )
		bgfx.read_texture(ctx.m_rb, ctx.lumAvg_data)
		settings.lumAvg = tostring(ctx.lumAvg_data)
		update_lumarg()
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
--	bgfx.set_debug "ST"
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION",  3, "FLOAT" },
		{ "COLOR0",    4, "UINT8", true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}
	ctx.tvb = bgfx.transient_buffer "fffdff"
	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBA",
		MSAA = false,
	}
	ctx.mesh_state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		CULL = "CCW",
		MSAA = true,
	}

	ctx.m_uffizi = util.textureLoad("textures/uffizi.dds", 0, "ucvcwc")	-- BGFX_TEXTURE_U_CLAMP | BGFX_TEXTURE_V_CLAMP | BGFX_TEXTURE_W_CLAMP
	ctx.m_skyProgram     = util.programLoad("vs_hdr_skybox",  "fs_hdr_skybox")
	ctx.m_lumProgram     = util.programLoad("vs_hdr_lum",     "fs_hdr_lum")
	ctx.m_lumAvgProgram  = util.programLoad("vs_hdr_lumavg",  "fs_hdr_lumavg")
	ctx.m_blurProgram    = util.programLoad("vs_hdr_blur",    "fs_hdr_blur")
	ctx.m_brightProgram  = util.programLoad("vs_hdr_bright",  "fs_hdr_bright")
	ctx.m_meshProgram    = util.programLoad("vs_hdr_mesh",    "fs_hdr_mesh")
	ctx.m_tonemapProgram = util.programLoad("vs_hdr_tonemap", "fs_hdr_tonemap")

	ctx.s_texCube   = bgfx.create_uniform("s_texCube",  "i1")
	ctx.s_texColor  = bgfx.create_uniform("s_texColor", "i1")
	ctx.s_texLum    = bgfx.create_uniform("s_texLum",   "i1")
	ctx.s_texBlur   = bgfx.create_uniform("s_texBlur",  "i1")
	ctx.u_mtx       = bgfx.create_uniform("u_mtx",      "m4")
	ctx.u_tonemap   = bgfx.create_uniform("u_tonemap",  "v4")
	ctx.u_offset    = bgfx.create_uniform("u_offset",   "v4", 16)

	ctx.m_mesh = util.meshLoad "meshes/bunny.bin"
	ctx.m_fbh = nil -- frame buffer

	ctx.s_texelHalf = ant.caps.rendererType == "DIRECT3D9" and 0.5 or 0

	ctx.m_lum = {
		bgfx.create_frame_buffer(128, 128, "BGRA8"),
		bgfx.create_frame_buffer(64, 64, "BGRA8"),
		bgfx.create_frame_buffer(16, 16, "BGRA8"),
		bgfx.create_frame_buffer(4, 4, "BGRA8"),
		bgfx.create_frame_buffer(1, 1, "BGRA8"),
	}

	ctx.m_bright = bgfx.create_frame_buffer("1/2", "BGRA8")
	ctx.m_blur   = bgfx.create_frame_buffer("1/8", "BGRA8")

	if ant.caps.supported.TEXTURE_BLIT and ant.caps.supported.TEXTURE_READ_BACK then
		ctx.m_rb = bgfx.create_texture2d(1, 1, false, 1, "BGRA8", "br") -- BGFX_TEXTURE_READ_BACK
	end

	ctx.ortho = math3d.matrix("ortho"):orthomat(0,1,1,0,0,100,0)
	ctx.m_fbtextures = {}

	ctx.lumAvg_data = bgfx.memory_texture(4)

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
	bgfx.destroy(ctx.m_fbh)
	local fbtextures = ctx.m_fbtextures
	fbtextures[1] = bgfx.create_texture2d(ctx.width, ctx.height,false, 1, "BGRA8", "rtucvc")	-- BGFX_TEXTURE_RT | BGFX_TEXTURE_U_CLAMP | BGFX_TEXTURE_V_CLAMP
	local textureFlags = "rwrt"

	local depthFormat = bgfx.is_texture_valid(0, false, 1, "D16", textureFlags) and "D16" or
		(bgfx.is_texture_valid(0, false, 1, "D24S8", textureFlags) and "D24S8" or "D32")

	fbtextures[2] = bgfx.create_texture2d(ctx.width, ctx.height, false, 1, depthFormat, textureFlags)

	ctx.m_fbh = bgfx.create_frame_buffer(fbtextures, true)
	ctx.proj = math3d.matrix("proj"):projmat(60, ctx.width/ctx.height, 0.1, 100)
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
  -- todo: destory resources
  ant.shutdown()
end
