local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

local settings = {
	distance = 2.0,
	transitions = true,
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

local ctrl = iup.frame {
	iup.vbox {
		slider("distance", "Distance", 2, 6),
		iup.toggle {
			title = "transitions",
			value = "ON",
			action = function(self, v)
				settings.transitions = (v == 1)
			end,
		},
	},
	title = "Settings",
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
  title = "12-lod",
  size = "HALFxHALF",
}

local ctx = {}

local function mainloop()
	math3d.reset()
	bgfx.touch(0)

	local view = math3d.matrix():lookatp(0,2, - settings.distance, 0,1,0)
	local proj = math3d.matrix "proj"
	bgfx.set_view_transform(0, view, proj)
	local mtx = math3d.matrix():scalemat(0.1, 0.1, 0.1)

	local currentLODframe = settings.transitions and (32- ctx.m_transitionFrame) or 32
	local mainLOD = settings.transitions and ctx.m_currLod or ctx.m_targetLod

	local stipple = math3d.vector():pack( 0, -1, currentLODframe * 4 / 255 - 1/255 )
	local stippleInv = math3d.vector():pack( 31 * 4 /255, 1, ctx.m_transitionFrame * 4/255 - 1/255)

	bgfx.set_texture(0, ctx.s_texColor, ctx.m_textureBark)
	bgfx.set_texture(1, ctx.s_texStipple, ctx.m_textureStipple)
	bgfx.set_uniform(ctx.u_stipple, stipple)
	bgfx.set_state(ctx.stateOpaque)
	bgfx.set_transform(mtx)
	util.meshSubmit(ctx.m_meshTrunk[mainLOD], 0, ctx.m_program)

	bgfx.set_texture(0, ctx.s_texColor, ctx.m_textureLeafs)
	bgfx.set_texture(1, ctx.s_texStipple, ctx.m_textureStipple)
	bgfx.set_uniform(ctx.u_stipple, stipple)
	bgfx.set_state(ctx.stateTransparent)
	bgfx.set_transform(mtx)
	util.meshSubmit(ctx.m_meshTop[mainLOD], 0, ctx.m_program)

	if settings.transitions and m_transitionFrame ~= 0 then
		bgfx.set_texture(0, ctx.s_texColor, ctx.m_textureBark)
		bgfx.set_texture(1, ctx.s_texStipple, ctx.m_textureStipple)
		bgfx.set_uniform(ctx.u_stipple, stippleInv)
		bgfx.set_state(ctx.stateOpaque)
		bgfx.set_transform(mtx)
		util.meshSubmit(ctx.m_meshTrunk[ctx.m_targetLod], 0, ctx.m_program)

		bgfx.set_texture(0, ctx.s_texColor, ctx.m_textureLeafs)
		bgfx.set_texture(1, ctx.s_texStipple, ctx.m_textureStipple)
		bgfx.set_uniform(ctx.u_stipple, stippleInv)
		bgfx.set_state(ctx.stateTransparent)
		bgfx.set_transform(mtx)
		util.meshSubmit(ctx.m_meshTop[ctx.m_targetLod], 0, ctx.m_program)
	end

	local lod = 1
	if settings.distance > 2.5 then
		lod = 2
	end
	if settings.distance > 5 then
		lod = 3
	end

	if ctx.m_targetLod ~= lod then
		if ctx.m_targetLod == ctx.m_currLod then
			ctx.m_targetLod = lod
		end
	end

	if ctx.m_currLod ~= ctx.m_targetLod then
		ctx.m_transitionFrame = ctx.m_transitionFrame + 1
	end

	if ctx.m_transitionFrame > 32 then
		ctx.m_currLod = ctx.m_targetLod
		ctx.m_transitionFrame = 0
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init { nwh = iup.GetAttributeData(canvas,"HWND") }
--	bgfx.set_debug "ST"
	ctx.stateOpaque = nil -- default
	ctx.stateTransparent = bgfx.make_state {
		WRITE_MASK = "RGBA",
		DEPTH_TEST = "LESS",
		MSAA = true,
		CULL = "CCW",
		BLEND = "ALPHA",
	}

	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	ctx.s_texColor   = bgfx.create_uniform("s_texColor",   "i1")
	ctx.s_texStipple = bgfx.create_uniform("s_texStipple", "i1")
	ctx.u_stipple    = bgfx.create_uniform("u_stipple",    "v4")
	ctx.m_program = util.programLoad("vs_tree", "fs_tree")
	ctx.m_textureLeafs = util.textureLoad "textures/leafs1.dds"
	ctx.m_textureBark  = util.textureLoad "textures/bark1.dds"

	local knightTour = {
		{0,0}, {1,2}, {3,3}, {4,1}, {5,3}, {7,2}, {6,0}, {5,2},
		{7,3}, {6,1}, {4,0}, {3,2}, {2,0}, {0,1}, {1,3}, {2,1},
		{0,2}, {1,0}, {2,2}, {0,3}, {1,1}, {3,0}, {4,2}, {5,0},
		{7,1}, {6,3}, {5,1}, {7,0}, {6,2}, {4,3}, {3,1}, {2,3},
	}
	local tmp = {}
	for ii=1,32 do
		local p = knightTour[ii]
		tmp[p[2] * 8 + p[1]+1] = ii*4-4
	end
	ctx.m_textureStipple = bgfx.create_texture2d(8,4,false,1,"R8","+p-p",string.char(table.unpack(tmp)))

	ctx.m_meshTop = {
		util.meshLoad "meshes/tree1b_lod0_1.bin",
		util.meshLoad "meshes/tree1b_lod1_1.bin",
		util.meshLoad "meshes/tree1b_lod2_1.bin",
	}

	ctx.m_meshTrunk = {
		util.meshLoad "meshes/tree1b_lod0_2.bin",
		util.meshLoad "meshes/tree1b_lod1_2.bin",
		util.meshLoad "meshes/tree1b_lod2_2.bin",
	}

	ctx.m_scrollArea  = 0
	ctx.m_transitionFrame = 0
	ctx.m_currLod         = 1
	ctx.m_targetLod       = 1

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
	bgfx.set_view_rect(0, 0, 0, w, h)
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
