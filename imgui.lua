local bimgui = require "bgfx.imgui"
local iup = require "iuplua"

local imgui = {}

local attribs = {}

function imgui.init(args)
	local function resize(w,h)
		attribs.width = w
		attribs.height = h
	end
	if args.resize then
		local old_resize = args.resize
		function args.resize(w,h)
			resize(w,h)
			old_resize(w,h)
		end
	else
		args.resize = resize
	end

	attribs.font_size = args.imgui_font or 18
	attribs.mx = 0
	attribs.my = 0
	attribs.button1 = false
	attribs.button2 = false
	attribs.button3 = false
	attribs.scroll = 0
	attribs.width = args.width
	attribs.height = args.height
	attribs.input_char = 0
	attribs.viewid = args.imgui_view or 255

	local canvas = assert(args.canvas)

	local function init()
		bimgui.create(attribs.font_size)
	end
	if args.init then
		local old_init = args.init
		function args.init(...)
			old_init(...)
			init()
		end
	else
		args.init = init
	end

	function canvas:button_cb(button, pressed, x, y, status)
		if button == iup.BUTTON1 then
			attribs.button1 = pressed ~= 0
		elseif button == iup.BUTTON2 then
			attribs.button2 = pressed ~= 0
		elseif button == iup.BUTTON3 then
			attribs.button3 = pressed ~= 0
		end
		attribs.mx = x
		attribs.my = y
	end

	function canvas:motion_cb(x, y, status)
		attribs.mx = x
		attribs.my = y
	end

	function canvas:wheel_cb(delta, x, y, status)
		attribs.scroll = delta
		attribs.mx = x
		attribs.my = y
	end
end

function imgui.updatefunc(f, mainloop)
	return function()
		bimgui.begin_frame(
			attribs.mx,
			attribs.my,
			attribs.button1,
			attribs.button2,
			attribs.button3,
			attribs.scroll,
			attribs.width,
			attribs.height,
			attribs.input_char,
			attribs.viewid
		)
		local ok , err = xpcall(f, debug.traceback)
		if not ok then
			print(err)
		end
		bimgui.end_frame()
		mainloop()
	end
end

return imgui
