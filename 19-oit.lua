local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local settings = {
	frontToBack = true,
	fadeInOut = false,
	mode = 1,
}

local canvas = iup.canvas {}

local function checkbox(key, title)
	local value = settings[key]
	assert(type(value) == "boolean")
	return iup.toggle {
		title = title,
		value = value and "ON" or "OFF",
		action = function (_, v)
			settings[key] = (v == 1)
		end
	}
end

local radios = {}
local function radio(name)
	local def = assert(settings[name])
	return function(init)
		local map = assert(radios[name])
		local ret = iup.radio(init)
		local p = assert(map[def])
		ret.value = p
		return ret
	end
end

local function radio_choice(title, key, type)
	local map = radios[key]
	if not map then
		map = {}
		radios[key] = map
	end
	local c = iup.toggle {
		title = title,
		action = function(self, v)
			if v == 1 then
				settings[key] = type
			end
		end
	}
	map[type] = c
	return c
end

local ctrl = iup.frame {
	iup.vbox {
		radio "mode" {
			iup.vbox {
				radio_choice("None", "mode", 0),
				radio_choice("Separate", "mode", 1),
				radio_choice("MRT Independent", "mode", 2),
			},
		},
		checkbox("frontToBack", "Front to back"),
		checkbox("fadeInOut", "Fade in/out"),
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
  title = "19-oit",
  size = "HALFxHALF",
}

local ctx = {}

local function screenSpaceQuad(textureWidth, textureHeight, originBottomLeft)
	local width = 1
	local height = 1
	ctx.tvb:alloc(3, ctx.PosColorTexCoord0Vertex)

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

local time = 0
local function mainloop()
	math3d.reset()
	time = time + 0.01
	-- Set palette color for index 0
	bgfx.set_palette_color(0, 0, 0, 0, 0)

	-- Set palette color for index 1
	bgfx.set_palette_color(1, 1,1,1,1)

	bgfx.set_view_clear_mrt(0, "CD"
					, 1 -- Depth
					, 0 -- Stencil
					, 0 -- FB texture 0, color palette 0
					, 1 == settings.mode and  1 or 0 -- FB texture 1, color palette 1
					)
	bgfx.set_view_clear_mrt(1, "CD"
					, 1 -- Depth
					, 0 -- Stencil
					, 0 --Color palette 0
					)

	if settings.mode == 0 then
		bgfx.set_view_frame_buffer(0, nil)
	else
		bgfx.set_view_frame_buffer(0,ctx.m_fbh)
	end

	local color = math3d.vector()
	local mtx = math3d.matrix()
	for depth = 0, 2 do
		local zz = settings.frontToBack and 2-depth or depth

		for yy = 0, 2 do
			for xx = 0, 2 do
				color:pack(xx/3, zz/3, yy/3, 0.5)

				if settings.fadeInOut and zz == 1 then
					color:pack(nil,nil,nil, math.sin(time*3.0)*0.49+0.5)
				end

				bgfx.set_uniform(ctx.u_color, color)

				mtx:rotmat(time*0.023 + xx*0.21, time*0.03 + yy*0.37)
				mtx:packline(4, -2.5+xx*2.5, -2.5+yy*2.5, -2.5+zz*2.5)

				-- Set transform for draw call.
				bgfx.set_transform(mtx)

				-- Set vertex and index buffer.
				bgfx.set_vertex_buffer(ctx.vb)
				bgfx.set_index_buffer(ctx.ib)

				local program
				if settings.mode == 0 then
					-- Set vertex and fragment shaders.
					program = ctx.m_blend
					-- Set render states.
					bgfx.set_state(ctx.state0)
				elseif settings.mode == 1 then
					-- Set vertex and fragment shaders.
					program = ctx.m_wbSeparatePass
					-- Set render states.
					bgfx.set_state(ctx.state1)
				else
					program = ctx.m_wbPass

					-- Set render states.
					bgfx.set_state(ctx.state2)
				end

				-- Submit primitive for rendering to view 0.
				bgfx.submit(0, program)
			end
		end
	end

	if settings.mode ~= 0  then
		bgfx.set_texture(0, ctx.s_texColor0, ctx.m_fbtextures[1])
		bgfx.set_texture(1, ctx.s_texColor1, ctx.m_fbtextures[2])
		bgfx.set_state(ctx.state_screen)
		screenSpaceQuad(ctx.width, ctx.height, ant.caps.originBottomLeft)
		bgfx.submit(1, 1 == settings.mode and ctx.m_wbSeparateBlit or ctx.m_wbBlit)
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
	ctx.PosColorVertex = bgfx.vertex_decl {
		{ "POSITION",  3, "FLOAT" },
		{ "COLOR0",    4, "UINT8", true },
	}

	ctx.PosColorTexCoord0Vertex = bgfx.vertex_decl {
		{ "POSITION",  3, "FLOAT" },
		{ "COLOR0",    4, "UINT8", true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}
	ctx.tvb = bgfx.transient_buffer "fffdff"

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
		ctx.PosColorVertex)
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

	-- Create texture sampler uniforms.
	ctx.s_texColor0 = bgfx.create_uniform("s_texColor0", "i1")
	ctx.s_texColor1 = bgfx.create_uniform("s_texColor1", "i1")
	ctx.u_color     = bgfx.create_uniform("u_color", "v4")

	ctx.m_blend          = util.programLoad("vs_oit",      "fs_oit"                  )
	ctx.m_wbSeparatePass = util.programLoad("vs_oit",      "fs_oit_wb_separate"      )
	ctx.m_wbSeparateBlit = util.programLoad("vs_oit_blit", "fs_oit_wb_separate_blit" )
	ctx.m_wbPass         = util.programLoad("vs_oit",      "fs_oit_wb"               )
	ctx.m_wbBlit         = util.programLoad("vs_oit_blit", "fs_oit_wb_blit"          )

	assert(ant.caps.limits.maxFBAttachments >= 2)
	assert(bgfx.is_texture_valid(0, false, 1, "RGBA16F", "rt"))
	assert(bgfx.is_texture_valid(0, false, 1, "R16F", "rt"))

	ctx.state0 = bgfx.make_state {
		CULL = "CW",
		WRITE_MASK = "RGBA",
		DEPTH_TEST = "LESS",
		MSAA = true,
		BLEND = "ALPHA",
	}
	ctx.state1 = bgfx.make_state {
		CULL = "CW",
		WRITE_MASK = "RGBA",
		DEPTH_TEST = "ALWAYS",
		MSAA = true,
		BLEND_FUNC = "110A",	-- BGFX_STATE_BLEND_FUNC_SEPARATE(BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_INV_SRC_ALPHA)
	}
	ctx.state2 = bgfx.make_state {
		CULL = "CW",
		WRITE_MASK = "RGBA",
		DEPTH_TEST = "ALWAYS",
		MSAA = true,
		BLEND_FUNC = "11", -- BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE)
		BLEND_ENABLE = "i",	-- BGFX_STATE_BLEND_INDEPENDENT
		BLEND_FUNC_RT = "10s",	-- BGFX_STATE_BLEND_FUNC_RT_1(BGFX_STATE_BLEND_ZERO, BGFX_STATE_BLEND_SRC_COLOR)
	}
	ctx.state_screen = bgfx.make_state {
		WRITE_MASK = "RGB",
		BLEND_FUNC = "Aa",	-- BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_INV_SRC_ALPHA, BGFX_STATE_BLEND_SRC_ALPHA)
	}

	ctx.m_fbtextures = {}
	ctx.s_texelHalf = ant.caps.rendererType == "DIRECT3D9" and 0.5 or 0

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
	ctx.m_fbtextures[1] = bgfx.create_texture2d(w,h,false,1,"RGBA16F","rt")
	ctx.m_fbtextures[2] = bgfx.create_texture2d(w,h,false,1,"R16F","rt")
	ctx.m_fbh = bgfx.create_frame_buffer( ctx.m_fbtextures , true)

	-- Set view 0 default viewport.
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.set_view_rect(1, 0, 0, w, h)

	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp(0,0,-7, 0,0,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)


	-- Set view and projection matrix for view 1.
	local viewmat1 = math3d.matrix "view1"
	viewmat1:identity()
	local projmat1 = math3d.matrix "proj1"
	projmat1:orthomat(0,1,1,0,0,100)
	bgfx.set_view_transform(1, viewmat1, projmat1)
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
