package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local bgfxu = require "bgfx.util"
local util = require "util"
local math3d = require "math3d"

local ctx = {
	canvas = iup.canvas {},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "15-shadowmaps_simple",
	size = "HALFxHALF",
}

local RENDER_SHADOW_PASS_ID = 0
local RENDER_SCENE_PASS_ID = 1

local vec0 = math3d.vector()
local time = 0
local function mainloop()
	math3d.reset()
	time = time + 0.01
	bgfx.touch(0)

--	Setup lights.
	local lightPos = math3d.vector (
		-math.cos(time),
		-1,
		-math.sin(time),
		0)
	bgfx.set_uniform(ctx.u_lightPos, lightPos)

--	Setup instance matrices.
	local mtxFloor = math3d.matrix { s = 30 }

	local mtxBunny = math3d.matrix { s = 5, r = { 0, math.pi - time, 0}, t={15,5,0} }

	local mtxHollowcube = math3d.matrix { s = 2.5, r = { 0.0, 1.56 - time, 0.0 }, t = { 0.0, 10.0, 0.0 } }

	local mtxCube = math3d.matrix { s = 2.5 , r = { 0.0, 1.56 - time, 0.0 }, t = { -15.0, 5.0, 0.0 } }

--	Define matrices.
	local lightView = math3d.lookat ( math3d.sub( vec0, lightPos ) , vec0)

	local area = 30.0
	local lightProj = math3d.projmat { ortho = true, l = -area, r = area, b = -area, t = area, n = -100, f = 100 }

	bgfx.set_view_rect(RENDER_SHADOW_PASS_ID, 0, 0, ctx.m_shadowMapSize, ctx.m_shadowMapSize)
	bgfx.set_view_frame_buffer(RENDER_SHADOW_PASS_ID, ctx.m_shadowMapFB)
	bgfx.set_view_transform(RENDER_SHADOW_PASS_ID, lightView, lightProj)

	bgfx.set_view_rect(RENDER_SCENE_PASS_ID, 0, 0, ctx.width, ctx.height)
	bgfx.set_view_transform(RENDER_SCENE_PASS_ID, ctx.view, ctx.proj)

--	Clear backbuffer and shadowmap framebuffer at beginning.
	bgfx.set_view_clear(RENDER_SHADOW_PASS_ID, "CD",0x303030ff, 1.0, 0)
	bgfx.set_view_clear(RENDER_SCENE_PASS_ID, "CD",0x303030ff, 1.0, 0)

	local mtxTmp =math3d.mul(ctx.mtxCrop, lightProj)
	local mtxShadow = math3d.mul(mtxTmp, lightView)
	local lightMtx = math3d.mul(mtxShadow, mtxFloor)

--	Floor.
	local cached =  bgfx.set_transform(mtxFloor)
	for pass =1, 2 do
		local st = ctx.m_state[pass]
		bgfx.set_transform_cached(cached)
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
	lightMtx = math3d.mul(mtxShadow , mtxBunny)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_bunny, ctx.m_state[1], mtxBunny)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_bunny, ctx.m_state[2], mtxBunny)

--	Hollow cube.
	lightMtx = math3d.mul(mtxShadow, mtxHollowcube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_hollowcube, ctx.m_state[1], mtxHollowcube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_hollowcube, ctx.m_state[2], mtxHollowcube)

--	Cube.
	lightMtx = math3d.mul(mtxShadow, mtxCube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_cube, ctx.m_state[1], mtxCube)
	bgfx.set_uniform(ctx.u_lightMtx, lightMtx)
	util.meshSubmitState(ctx.m_cube, ctx.m_state[2], mtxCube)

	bgfx.frame()
end

function ctx.init()
	-- Uniforms.
	ctx.s_shadowMap = bgfx.create_uniform("s_shadowMap", "s")
	ctx.u_lightPos  = bgfx.create_uniform("u_lightPos",  "v4")
	ctx.u_lightMtx  = bgfx.create_uniform("u_lightMtx",  "m4")

--	When using GL clip space depth range [-1, 1] and packing depth into color buffer, we need to
--	adjust the depth range to be [0, 1] for writing to the color buffer
	ctx.u_depthScaleOffset = bgfx.create_uniform("u_depthScaleOffset", "v4")

	if util.caps.homogeneousDepth then
		bgfx.set_uniform(ctx.u_depthScaleOffset, math3d.vector(1, 0, 0, 0))
	else
		bgfx.set_uniform(ctx.u_depthScaleOffset, math3d.vector(0.5, 0.5, 0, 0))
	end

--	Create vertex stream declaration.
	ctx.vdecl = bgfx.vertex_layout {
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
	ctx.m_shadowSamplerSupported = util.caps.supported.TEXTURE_COMPARE_LEQUAL

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

	local sy = util.caps.originBottomLeft and 0.5 or -0.5
	local sz = util.caps.homogeneousDepth and 0.5 or 1
	local tz = util.caps.homogeneousDepth and 0.5 or 0

	ctx.mtxCrop = math3d.ref(math3d.matrix (
		0.5, 0.0, 0.0, 0.0,
		0.0,  sy, 0.0, 0.0,
		0.0, 0.0,  sz, 0.0,
		0.5, 0.5,  tz, 1.0
	))
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(ctx.width,ctx.height, "vmx")
	ctx.view = math3d.ref(math3d.lookat( { 0,30,-60 }, { 0,5,0 }))
	ctx.proj = math3d.ref(math3d.projmat { fov = 60, aspect = w/h, n = 0.1, f = 100 })
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)
