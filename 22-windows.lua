package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local MAX_WINDOWS = 8

local ctx = {
	canvas = iup.canvas {},
}

local button = iup.button {
	title = "New Window",
}

local dlg = iup.dialog {
	iup.vbox {
		button,
		ctx.canvas,
	},
	title = "22-windows",
	size = "HALFxHALF",
}

local ms = util.mathstack

local windows = {}
local time = 0
local function mainloop()
	math3d.reset(ms)
	bgfx.touch(0)
	time = time + 0.001

	local views = {}
	for _, wnd in pairs(windows) do
		local viewid = wnd.viewid
		if viewid then
			bgfx.touch(viewid)
			table.insert(views, viewid)
		end
	end

	local n = #views

	local count = 0
	for yy = 0, 10 do
		for xx = 0, 10 do
			local mat = ms:srtmat(nil, {time + xx*0.21, time + yy*0.37,0} , {-15.0 + xx * 3, -15.0 + yy * 3, 0})
			bgfx.set_transform(mat)
			bgfx.set_vertex_buffer(ctx.vb)
			bgfx.set_index_buffer(ctx.ib)
			bgfx.set_state(ctx.state)
			local m = count % (n+1)
			if m > 0 then
				m = views[m]
			end
			bgfx.submit(m, ctx.prog)
			count = count + 1
		end
	end

	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.prog = util.programLoad("vs_cubes", "fs_cubes")

	ctx.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
	ctx.vdecl = bgfx.vertex_decl {
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
		ctx.vdecl)
	ctx.ib = bgfx.create_index_buffer{
		0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
	}
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
	bgfx.reset(ctx.width,ctx.height, "v")
	local viewmat = ms( { 0,0,-35 } , {0,0,0}, "lP" )
	local projmat = ms:matrix { type = "mat", fov = 60, aspect = w/h, n = 0.1, f = 100 }
	bgfx.set_view_transform(0, viewmat, projmat)
end

local last_x, last_y
local num_window = 0

function dlg.close_cb()
	for _,wnd in pairs(windows) do
		wnd.dlg:destroy()
	end
end

local function new_window()
	local canvas = iup.canvas{}
	local wnd = { canvas = canvas }
	windows[canvas]  = wnd
	local dlg = iup.dialog {
		canvas,
		size = "QUARTERxHALF",
		title = "windows - " .. tostring(canvas),
	}
	wnd.dlg = dlg

	function dlg:close_cb()
		num_window = num_window - 1
		local wnd = windows[canvas]
		windows[canvas] = nil
		if wnd.viewid then
			bgfx.set_view_frame_buffer(wnd.viewid)
		end
		bgfx.destroy(wnd.fbh)
	end

	function canvas:resize_cb(w,h)
		if wnd.viewid == nil then
			-- find new id
			local viewid
			for i = 1, MAX_WINDOWS do
				viewid = i
				for _, w in pairs(windows) do
					if w.viewid == viewid then
						viewid = nil
						break
					end
				end
				if viewid then
					break
				end
			end
			wnd.viewid = assert(viewid)
		end
		if wnd.fbh then
			bgfx.destroy(wnd.fbh)
		end
		local handle = iup.GetAttributeData(canvas,"HWND")
		wnd.fbh = bgfx.create_frame_buffer(handle,w,h)
		bgfx.set_view_clear(wnd.viewid, "CD", 0x303030ff, 1, 0)
		bgfx.set_view_rect(wnd.viewid, 0, 0, w, h)
		bgfx.set_view_frame_buffer(wnd.viewid, wnd.fbh)

		local viewmat = ms( { 0,0,-35 }, { 0,0,0 }, "lP")
		local projmat = ms:matrix { type = "mat", fov = 60, aspect = w/h, n = 0.1, f = 100 }
		bgfx.set_view_transform(wnd.viewid, viewmat, projmat)
	end

	if last_x then
		dlg:showxy(last_x + 10, last_y + 10)
	else
		dlg:showxy(iup.LEFT, iup.TOP)
	end
	local x,y = dlg.SCREENPOSITION:match("(%d+),(%d+)")
	last_x = tonumber(x)
	last_y = tonumber(y)
end

function button:action()
	if num_window >= MAX_WINDOWS then
		iup.Popup(iup.messagedlg{
			buttondefault = "1",
			value = "Can't create more window",
		})
	elseif util.caps.supported.SWAP_CHAIN then
		num_window = num_window + 1
		new_window()
	else
		iup.Popup(iup.messagedlg{
			buttondefault = "1",
			value = "Swap Chain not supported",
		})
	end
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)
