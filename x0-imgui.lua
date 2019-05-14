package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local imgui = require "imgui"
local bimgui = require "bgfx.imgui"
local widget = bimgui.widget
local flags = bimgui.flags
local windows = bimgui.windows
local utils = bimgui.util

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

local checkbox = {}

local combobox = { "B" }

local lines = { 1,2,3,2,1 }

local test_window = {
	id = "Test",
	open = true,
	flags = flags.Window { "MenuBar" },	-- "NoClosed"
}

local function run_window(wnd)
	if not wnd.open then
		return
	end
	local touch, open = windows.Begin(wnd.id, wnd.flags)
	if touch then
		wnd:update()
		windows.End()
		wnd.open = open
	end
end

local lists = { "Alice", "Bob" }

local tab_noclosed = flags.TabBar { "NoClosed" }

function test_window:update()
	self:menu()
	if windows.BeginTabBar "tab_bar" then
		if windows.BeginTabItem ("Tab1",tab_noclosed) then
			self:tab_update()
			windows.EndTabItem()
		end
		if windows.BeginTabItem ("Tab2",tab_noclosed) then
			if widget.Button "Save Ini" then
				print(utils.SaveIniSettings())
			end
			windows.EndTabItem()
		end
		windows.EndTabBar()
	end
end

function test_window:menu()
	if widget.BeginMenuBar() then
		widget.MenuItem("M1")
		widget.MenuItem("M2")
		widget.EndMenuBar()
	end
end

function test_window:tab_update()
	widget.Button "Test"
	widget.SmallButton "Small"
	if widget.Checkbox("Checkbox", checkbox) then
		print("Click Checkbox", checkbox[1])
	end
	widget.Text("Hello World", 1,0,0)
	if widget.BeginCombo( "Combo", combobox ) then
		widget.Selectable("A", combobox)
		widget.Selectable("B", combobox)
		widget.Selectable("C", combobox)
		widget.EndCombo()
	end
	if widget.TreeNode "TreeNodeA" then
		widget.TreePop()
	end
	if widget.TreeNode "TreeNodeB" then
		widget.TreePop()
	end
	if widget.TreeNode "TreeNodeC" then
		widget.TreePop()
	end

	widget.PlotLines("lines", lines)
	widget.PlotHistogram("histogram", lines)

	if widget.ListBox("##list",lists) then
		print(lists.current)
	end
end

local function update_ui()
	windows.SetNextWindowSizeConstraints(300, 300, 500, 500)
	run_window(test_window)
end


local function mainloop()
	bgfx.touch(0)

	bgfx.frame()
end

--print(enum.ColorEditFlags { "NoAlpha", "HDR" } )

imgui.init(ctx)
util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(imgui.updatefunc(update_ui,mainloop))
