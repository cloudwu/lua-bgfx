local bgfx = require "bgfx"

local common = {}

local debug

function common:keypress_cb(key, press)
	if press == 0 then
		return
	end
	if key ==  iup.K_F1 then
		debug = not debug
		bgfx.set_debug(debug and "S" or "")
	elseif key == iup.K_F12 then
		bgfx.request_screenshot()
	end
end

local function save_ppm(filename, data, width, height, pitch)
	local f = assert(io.open(filename, "wb"))
	f:write(string.format("P3\n%d %d\n255\n",width, height))
	local line = 0
	for i = 0, height-1 do
		for j = 0, width-1 do
			local r,g,b,a = string.unpack("BBBB",data,i*pitch+j*4+1)
			f:write(r," ",g," ",b," ")
			line = line + 1
			if line > 8 then
				f:write "\n"
				line = 0
			end
		end
	end
	f:close()
end

function common.save_screenshot(filename)
	local name , width, height, pitch, data = bgfx.get_screenshot()
	if name then
		local size = #data
		if size < width * height * 4 then
			-- not RGBA
			return
		end
		print("Save screenshot to ", filename)
		save_ppm(filename, data, width, height, pitch)
	end
end

return common
