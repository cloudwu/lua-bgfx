package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local kThreadGroupUpdateSize = 512
local kMaxParticleCount      = 32 * 1024

local useIndirect = true
local RESET = true
local settings_all ={}

settings_all[1] = {	-- point
	timeStep          = 0.0067,
	dispatchSize      = 32,
	gravity           = 0.069,
	damping           = 0.0,
	particleIntensity = 0.35,
	particleSize      = 0.925,
	baseSeed          = 0,
	particlePower     = 5.0,
	initialSpeed      = 122.6,
	initialShape      = 0,
	maxAccel          = 30.0,
}

local settings = settings_all[1]

settings_all[2] = {	-- sphere
	timeStep          = 0.0157,
	dispatchSize      = 32,
	gravity           = 0.109,
	damping           = 0.25,
	particleIntensity = 0.64,
	particleSize      = 0.279,
	baseSeed          = 57,
	particlePower     = 3.5,
	initialSpeed      = 3.2,
	initialShape      = 1,
	maxAccel          = 100.0,
}

settings_all[3] = {	-- box
	timeStep          = 0.02,
	dispatchSize      = 32,
	gravity           = 0.24,
	damping           = 0.12,
	particleIntensity = 1.0,
	particleSize      = 1.0,
	baseSeed          = 23,
	particlePower     = 4.0,
	initialSpeed      = 31.1,
	initialShape      = 2,
	maxAccel          = 39.29,
}

settings_all[4] = { -- donut
	timeStep          = 0.0118,
	dispatchSize      = 32,
	gravity           = 0.141,
	damping           = 1.0,
	particleIntensity = 0.64,
	particleSize      = 0.28,
	baseSeed          = 60,
	particlePower     = 1.97,
	initialSpeed      = 69.7,
	initialShape      = 3,
	maxAccel          = 3.21,
}

local ctrls = {}

local function update_ctrls()
	for k,v in pairs(ctrls) do
		ctrls[k]()
	end
end

local function slider(key, title, min, max)
	local value = assert(settings[key])
	local integer = math.type(value) == "integer"
	local tv = value
	local label = iup.label { title = tv , size = "30" }
	local val = iup.val {
		min = min,
		max = max,
		value = value,
		valuechanged_cb = function (self)
			local v = tonumber(self.value)
			if integer then
				v = math.floor(v)
				settings[key] = v
				label.title = string.format("%d",v)
			else
				settings[key] = v
				label.title = string.format("%.3f",v)
			end
		end,
	}

	ctrls[key] = function()
		local v = settings[key]
		if integer then
			v = math.floor(v)
			label.title = string.format("%d",v)
		else
			label.title = string.format("%.3f",v)
		end
		val.value = v
	end

	return iup.hbox {
		iup.label { title = title .. " : " },
		val,
		label,
	}
end

local shape = iup.list {
	"Point",
	"Sphere",
	"Box",
	"Donut",
	value = 1,
	dropdown = "YES",
	valuechanged_cb = function (self)
		local v = tonumber(self.value)
		settings = assert(settings_all[v])
		update_ctrls()
		RESET = true
	end
}

local useIndirect_ctrl = iup.toggle {
	title = "Use draw/dispatch indirect",
	value = "ON",
	action = function (_, v)
		useIndirect = (v == 1)
	end
}

local ctx = {
	canvas = iup.canvas {},
}

local ctrl = iup.frame {
	iup.vbox {
		iup.hbox {
			iup.button {
				title = "Reset",
				action = function()
					RESET = true	-- reset
				end,
			},
			shape,
		},
		slider("baseSeed", "Random seed", 0, 100),
		slider("dispatchSize", "Particle count (x512)", 1, 64),
		slider("gravity", "Gravity", 0, 0.3),
		slider("damping", "Damping", 0, 1),
		slider("maxAccel", "Max acceleration", 0, 100),
		slider("timeStep", "Time step", 0, 0.02),
		slider("particleIntensity", "Particle intensity", 0, 1),
		slider("particleSize", "Particle size", 0, 1),
		slider("particlePower", "Particle power", 0.001, 16),
		useIndirect_ctrl,
	},
	title = "Settings",
	size = "60",
}

local dlg = iup.dialog {
	iup.hbox {
		iup.vbox {
			ctrl,
			margin = "2x2",
		},
		ctx.canvas,
	},
	title = "24-nbody",
	size = "HALFxHALF",
}

local function packParams()
	ctx.m_paramsData[1].v = math3d.pack("fdff",
		settings.timeStep,
		settings.dispatchSize,
		settings.gravity,
		settings.damping)
	ctx.m_paramsData[2].v = math3d.pack("ffdf",
		settings.particleIntensity,
		settings.particleSize,
		settings.baseSeed,
		settings.particlePower)
	ctx.m_paramsData[3].v = math3d.pack("fdfd",
		settings.initialSpeed,
		settings.initialShape,
		settings.maxAccel,
		0)

	return ctx.m_paramsData
end

local function mainloop()
	math3d.reset()

	local params = packParams()
	if RESET then
		RESET = false
--		bgfx.set_buffer(0, ctx.m_prevPositionBuffer0, "w")
--		bgfx.set_buffer(1, ctx.m_currPositionBuffer0, "w")
--		bgfx.set_uniform(ctx.u_params, table.unpack(params))
		local command = bgfx.set_buffer_command(0, ctx.m_prevPositionBuffer0, "w")
		command = command .. bgfx.set_buffer_command(1, ctx.m_currPositionBuffer0, "w")
		command = command .. bgfx.set_uniform_command(ctx.u_params, table.unpack(params))
		bgfx.execute_setter(command)
		bgfx.dispatch(0, ctx.m_initInstancesProgram, kMaxParticleCount // kThreadGroupUpdateSize, 1, 1)
	end

	if useIndirect then
		bgfx.set_uniform(ctx.u_params, table.unpack(params))
		bgfx.set_buffer(0, ctx.m_indirectBuffer, "w")
		bgfx.dispatch(0, ctx.m_indirectProgram)
	end

	bgfx.set_buffer(0, ctx.m_prevPositionBuffer0, "r")
	bgfx.set_buffer(1, ctx.m_currPositionBuffer0, "r")
	bgfx.set_buffer(2, ctx.m_prevPositionBuffer1, "w")
	bgfx.set_buffer(3, ctx.m_currPositionBuffer1, "w")
	bgfx.set_uniform(ctx.u_params, table.unpack(params))

	if useIndirect then
		bgfx.dispatch_indirect(0, ctx.m_updateInstancesProgram, ctx.m_indirectBuffer, 1)
	else
		bgfx.dispatch(0, ctx.m_updateInstancesProgram, settings.dispatchSize, 1, 1)
	end

	ctx.m_currPositionBuffer0, ctx.m_currPositionBuffer1 = ctx.m_currPositionBuffer1, ctx.m_currPositionBuffer0
	ctx.m_prevPositionBuffer0, ctx.m_prevPositionBuffer1 = ctx.m_prevPositionBuffer1, ctx.m_prevPositionBuffer0

	-- Set vertex and index buffer.
	bgfx.set_vertex_buffer(ctx.m_vbh)
	bgfx.set_index_buffer(ctx.m_ibh)
	bgfx.set_instance_data_buffer(ctx.m_currPositionBuffer0, 0, settings.dispatchSize * kThreadGroupUpdateSize)

	bgfx.set_state(ctx.state)

	-- Submit primitive for rendering to view 0.
	if useIndirect then
		bgfx.submit_indirect(0, ctx.m_particleProgram, ctx.m_indirectBuffer, 0)
	else
		bgfx.submit(0, ctx.m_particleProgram)
	end

	bgfx.dbg_text_print(0,0, 0xf, useIndirect and "Use Indirect         " or "Not use Indirect")

	bgfx.frame()
end


function ctx.init()
	assert(util.caps.supported.COMPUTE)
	if not util.caps.supported.DRAW_INDIRECT then
		useIndirect = false
		useIndirect_ctrl.visible = "NO"
	end
	bgfx.set_debug "T"

	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGB",
		BLEND = "ADD",
		DEPTH_TEST = "ALWAYS",
	}
	-- Set view 0 clear state.
	bgfx.set_view_clear(0, "CD", 0x303030ff , 1.0 , 0)

	local quadVertexDecl = bgfx.vertex_layout {
		{ "POSITION", 2, "FLOAT" },
	}

	-- Create static vertex buffer.
	ctx.m_vbh = bgfx.create_vertex_buffer(bgfx.memory_buffer("ff", {
		 1.0,  1.0,
		-1.0,  1.0,
		-1.0, -1.0,
		 1.0, -1.0,
	}) , quadVertexDecl)

	-- Create static index buffer.
	ctx.m_ibh = bgfx.create_index_buffer { 0, 1, 2, 2, 3, 0, }

	-- Create particle program from shaders.
	ctx.m_particleProgram = util.programLoad("vs_particle", "fs_particle")

	-- Setup compute buffers
	local computeVertexDecl = bgfx.vertex_layout {
		{ "TEXCOORD0", 4, "FLOAT" },
	}

	ctx.m_currPositionBuffer0 = bgfx.create_dynamic_vertex_buffer(1 << 15, computeVertexDecl, "rw")
	ctx.m_currPositionBuffer1 = bgfx.create_dynamic_vertex_buffer(1 << 15, computeVertexDecl, "rw")
	ctx.m_prevPositionBuffer0 = bgfx.create_dynamic_vertex_buffer(1 << 15, computeVertexDecl, "rw")
	ctx.m_prevPositionBuffer1 = bgfx.create_dynamic_vertex_buffer(1 << 15, computeVertexDecl, "rw")

	ctx.u_params = bgfx.create_uniform("u_params", "v4", 3)

	ctx.m_initInstancesProgram   = util.computeLoad "cs_init_instances"
	ctx.m_updateInstancesProgram = util.computeLoad "cs_update_instances"

	ctx.m_indirectProgram = nil
	ctx.m_indirectBuffer  = nil

	if util.caps.supported.DRAW_INDIRECT then
		ctx.m_indirectProgram = util.computeLoad "cs_indirect"
		ctx.m_indirectBuffer  = bgfx.create_indirect_buffer(2)
	end

	ctx.m_paramsData = {}
	for i=1,3 do
		ctx.m_paramsData[i] = math3d.ref(math3d.vector())
	end

	bgfx.set_uniform(ctx.u_params, table.unpack(packParams()))

	bgfx.set_buffer(0, ctx.m_prevPositionBuffer0, "w")
	bgfx.set_buffer(1, ctx.m_currPositionBuffer0, "w")
	bgfx.dispatch(0, ctx.m_initInstancesProgram, kMaxParticleCount // kThreadGroupUpdateSize, 1, 1)

end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "v")
	bgfx.set_view_rect(0, 0, 0, w , h)

	local viewmat = math3d.lookat( { 0,0, -45 }, { 0,0,0 })
	local projmat = math3d.projmat { fov = 90, aspect = w/h, n = 0.1, f = 100000 }
	bgfx.set_view_transform(0, viewmat, projmat)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)
