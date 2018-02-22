local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"
local bgfxu = require "bgfx.util"

canvas = iup.canvas {}

dlg = iup.dialog {
  canvas,
  title = "15-shadowmaps_simple",
  size = "HALFxHALF",
}

local RENDER_SHADOW_PASS_ID = 0
local RENDER_SCENE_PASS_ID = 1

local ctx = {}
local time = 0
local function mainloop()
	math3d.reset()
	time = time + 0.01
	bgfx.touch(0)

--	Setup lights.
	local lightPos = math3d.vector():pack(
		-math.cos(time),
		-1,
		-math.sin(time),
		0)
	bgfx.set_uniform(ctx.u_lightPos, lightPos)

--	Setup instance matrices.
	local mtxFloor = math3d.matrix():srt(
		30.0, 30.0, 30.0
		,0.0, 0.0, 0.0
		,0.0, 0.0, 0.0
	)

	local mtxBunny = math3d.matrix():srt(
		5,5,5
		,0,math.pi - time, 0
		,15,5,0
	)

	local mtxHollowcube = math3d.matrix():srt(
		2.5, 2.5, 2.5
		, 0.0, 1.56 - time, 0.0
		, 0.0, 10.0, 0.0
	)

	local mtxCube = math3d.matrix():srt(
		2.5, 2.5, 2.5
		, 0.0, 1.56 - time, 0.0
		, -15.0, 5.0, 0.0
	)

--	Define matrices.
	local ex,ey,ez = lightPos:unpack()
	local lightView = math3d.matrix():lookatp(-ex, -ey, -ez, 0,0,0)
	local area = 30.0
	local lightProj = math3d.matrix():orthomat(-area, area, -area, area, -100.0, 100.0)

	bgfx.set_view_rect(RENDER_SHADOW_PASS_ID, 0, 0, ctx.m_shadowMapSize, ctx.m_shadowMapSize)
	bgfx.set_view_frame_buffer(RENDER_SHADOW_PASS_ID, ctx.m_shadowMapFB)
	bgfx.set_view_transform(RENDER_SHADOW_PASS_ID, lightView, lightProj)

	bgfx.set_view_rect(RENDER_SCENE_PASS_ID, 0, 0, ctx.width, ctx.height)
	bgfx.set_view_transform(RENDER_SCENE_PASS_ID, math3d.matrix "view", math3d.matrix "proj")

--	Clear backbuffer and shadowmap framebuffer at beginning.
	bgfx.set_view_clear(RENDER_SHADOW_PASS_ID, "CD",0x303030ff, 1.0, 0)
	bgfx.set_view_clear(RENDER_SCENE_PASS_ID, "CD",0x303030ff, 1.0, 0)

	local mtxTmp = math3d.matrix():mul(lightProj, math3d.matrix "mtxCrop")
	local mtxShadow = math3d.matrix():mul(lightView, mtxTmp)

--	Floor.
	local lightMtx = math3d.matrix():mul(mtxFloor, mtxShadow)
	local cached = bgfx.set_transform(mtxFloor)

	for pass =1, 2 do
		local st = ctx.m_state[pass]
		bgfx.set_transform(cached)
		for _,texture in ipairs(st.textures) do
			bgfx.set_texture(texture.stage, texture.sampler, texture.texture, texture.flags)
		end
		bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
		bgfx.set_index_buffer(ctx.m_ibh)
		bgfx.set_vertex_buffer(ctx.m_vbh)
		bgfx.set_state(st.state)
		bgfx.submit(st.viewId, st.program)
	end

--	Bunny.
	lightMtx:mul(mtxBunny, mtxShadow)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_bunny, ctx.m_state[1], mtxBunny)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_bunny, ctx.m_state[2], mtxBunny)

--	Hollow cube.
	lightMtx:mul(mtxHollowcube, mtxShadow)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_hollowcube, ctx.m_state[1], mtxHollowcube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_hollowcube, ctx.m_state[2], mtxHollowcube)

--	Cube.
	lightMtx:mul(mtxCube, mtxShadow)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_cube, ctx.m_state[1], mtxCube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_cube, ctx.m_state[2], mtxCube)

	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
--		renderer = "OPENGL",
	}
--	bgfx.set_debug "ST"

	-- Uniforms.
	ctx.s_shadowMap = bgfx.create_uniform("s_shadowMap", "i1")
	ctx.u_lightPos  = bgfx.create_uniform("u_lightPos",  "v4")
	ctx.u_lightMtx  = bgfx.create_uniform("u_lightMtx",  "m4")

--	When using GL clip space depth range [-1, 1] and packing depth into color buffer, we need to
--	adjust the depth range to be [0, 1] for writing to the color buffer
	ctx.u_depthScaleOffset = bgfx.create_uniform("u_depthScaleOffset", "v4")

	local depthScaleOffset = math3d.vector()

	if ant.caps.homogeneousDepth then
		bgfx.set_uniform(ctx.u_depthScaleOffset, depthScaleOffset:pack(1, 0, 0, 0))
	else
		bgfx.set_uniform(ctx.u_depthScaleOffset, depthScaleOffset:pack(0.5, 0.5, 0, 0))
	end

--	Create vertex stream declaration.
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "NORMAL", 4, "UINT8", true, true },
	}

--	Meshes.
	ctx.m_bunny      = util.meshLoad "meshes/bunny.bin"
	ctx.m_cube       = util.meshLoad "meshes/cube.bin"
	ctx.m_hollowcube = util.meshLoad "meshes/hollowcube.bin"

	local encodeNormalRgba8 = bgfxu.encodeNormalRgba8

	ctx.m_vbh = bgfx.create_vertex_buffer(
		{ "fffd",
		 -1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0),
		  1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0),
		 -1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0),
		  1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0),
		}
		, ctx.vdecl)

	ctx.m_ibh = bgfx.create_index_buffer {
		0, 1, 2,
		1, 3, 2,
	}

--	Render targets.
	ctx.m_shadowMapSize = 512

--	Shadow samplers are supported at least partially supported if texture
--	compare less equal feature is supported.
	ctx.m_shadowSamplerSupported = ant.caps.supported.TEXTURE_COMPARE_LEQUAL

	local shadowMapTexture
	if ctx.m_shadowSamplerSupported then
		-- Depth textures and shadow samplers are supported.
		ctx.m_progShadow = util.programLoad("vs_sms_shadow", "fs_sms_shadow")
		ctx.m_progMesh   = util.programLoad("vs_sms_mesh",   "fs_sms_mesh")

		shadowMapTexture = bgfx.create_texture2d(
			ctx.m_shadowMapSize
			, ctx.m_shadowMapSize
			, false
			, 1
			, "D16"
			, "rtc["	-- BGFX_TEXTURE_RT | BGFX_TEXTURE_COMPARE_LEQUAL
		)
		ctx.m_shadowMapFB = bgfx.create_frame_buffer({shadowMapTexture}, true)
	else
		-- Depth textures and shadow samplers are not supported. Use float
		-- depth packing into color buffer instead.
		ctx.m_progShadow = util.programLoad("vs_sms_shadow_pd", "fs_sms_shadow_pd")
		ctx.m_progMesh   = util.programLoad("vs_sms_mesh",      "fs_sms_mesh_pd")

		shadowMapTexture = bgfx.create_texture2d(
			ctx.m_shadowMapSize
			, ctx.m_shadowMapSize
			, false
			, 1
			, "BGRA8"
			, "rt"	-- BGFX_TEXTURE_RT
		)
		local fbtextures = {
			shadowMapTexture,
			bgfx.create_texture2d(
				ctx.m_shadowMapSize
				, ctx.m_shadowMapSize
				, false
				, 1
				, "D16"
				, "rw"	-- BGFX_TEXTURE_RT_WRITE_ONLY
			)
		}
		ctx.m_shadowMapFB = bgfx.create_frame_buffer(fbtextures, true)
	end

	ctx.m_state = {}
	ctx.m_state[1] = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
		program = ctx.m_progShadow,
		viewId = RENDER_SHADOW_PASS_ID,
		textures = {}
	}
	ctx.m_state[2] = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
		program = ctx.m_progMesh,
		viewId = RENDER_SCENE_PASS_ID,
		textures = {{
			flags = nil,
			stage = 0,
			sampler = ctx.s_shadowMap,
			texture = shadowMapTexture
		}},
	}

	local sy = ant.caps.originBottomLeft and 0.5 or -0.5
	local sz = ant.caps.homogeneousDepth and 0.5 or 1
	local tz = ant.caps.homogeneousDepth and 0.5 or 0

	local mtxCrop = math3d.matrix "mtxCrop"
	mtxCrop:pack(
		0.5, 0.0, 0.0, 0.0,
		0.0,   sy, 0.0, 0.0,
		0.0, 0.0, sz,   0.0,
		0.5, 0.5, tz,   1.0
	)

	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.reset(ctx.width,ctx.height, "vmx")
	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp(0,30,-60, 0,5,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)
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
  -- todo: destroy resources
  ant.shutdown()
end
