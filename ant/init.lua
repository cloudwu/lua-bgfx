local bgfx = require "bgfx"
local framework = require "ant.framework"

local ant = {}

local init_flag

function ant.init(args)
	assert(init_flag == nil)
	bgfx.init {
		renderer = args.renderer,
		format = args.format,
		width = args.width,
		height = args.height,
		reset = args.reset,
		debug = args.debug,
		profile = args.profile,
		getlog = args.getlog,
		numBackBuffers = args.numBackBuffers,
		maxFrameLatency = args.maxFrameLatency,

		-- platform data
		ndt = args.ndt,
		nwh = args.nwh,
		context = args.context,
		backBuffer = args.backBuffer,
		backBufferDS = args.backBufferDS,
	}
	ant.caps = bgfx.get_caps()
	init_flag = true
	framework.init_all()
end

function ant.shutdown()
	if init_flag then
		bgfx.shutdown()
	end
end

function ant.mainloop(f)
	iup.SetIdle(function ()
		local ok , err = xpcall(f, debug.traceback)
		if not ok then
			print(err)
			iup.SetIdle()
		end
		return iup.DEFAULT
	end)
end

return ant
