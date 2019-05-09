package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local imgui = require "imgui"
local ig = require "bgfx.imgui"

local ctx = {
	canvas = iup.canvas{},
	stats = {},
	imgui_view = 255,
	imgui_font = 18,
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "X0-imgui",
	size = "HALFxHALF",
}

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
end

function ctx.resize(w,h)
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w,h, "")
	ctx.width = w
	ctx.height = h
end

local function gui()
	ig.test()
end

local function mainloop()
	bgfx.touch(0)

	bgfx.frame()
end

imgui.init(ctx)
util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(imgui.updatefunc(gui,mainloop))
