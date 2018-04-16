local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"
local bgfxu = require "bgfx.util"

local settings = {
	sizePwrTwo = 10,
	coverageSpotL = 90.0,
	spotOuterAngle  = 45.0,
	spotInnerAngle  = 30.0,
	stencilPack = true,
	fovXAdjust = 0.0,
	fovYAdjust = 0.0,
	stabilize = true,
	numSplits = 4,
	splitDistribution = 0.6,
	updateLights = true,
	updateScene = true,
	lightType = "SpotLight",
	depthImpl = "InvZ",
	drawDepthBuffer = false,
	depthValuePow = 1.0,
	smImpl = "Hard",
	bias = 0.0,
	normalOffset = 0.0,
	near = 1.0,
	far = 200.0,
	xOffset = 1.0,
	yOffset = 1.0,
	doBlur = true,
	customParam0 = 0.5,
	customParam1 = 500,
	showSmCoverage = false,
}

local RENDERVIEW_SHADOWMAP_0_ID =1
local RENDERVIEW_SHADOWMAP_1_ID =2
local RENDERVIEW_SHADOWMAP_2_ID =3
local RENDERVIEW_SHADOWMAP_3_ID =4
local RENDERVIEW_SHADOWMAP_4_ID =5
local RENDERVIEW_VBLUR_0_ID     =6
local RENDERVIEW_HBLUR_0_ID     =7
local RENDERVIEW_VBLUR_1_ID     =8
local RENDERVIEW_HBLUR_1_ID     =9
local RENDERVIEW_VBLUR_2_ID     =10
local RENDERVIEW_HBLUR_2_ID     =11
local RENDERVIEW_VBLUR_3_ID     =12
local RENDERVIEW_HBLUR_3_ID     =13
local RENDERVIEW_DRAWSCENE_0_ID =14
local RENDERVIEW_DRAWSCENE_1_ID =15
local RENDERVIEW_DRAWDEPTH_0_ID =16
local RENDERVIEW_DRAWDEPTH_1_ID =17
local RENDERVIEW_DRAWDEPTH_2_ID =18
local RENDERVIEW_DRAWDEPTH_3_ID =19

local GREEN = 1
local YELLOW =2
local BLUE =3
local RED =4

do

canvas = iup.canvas {}

local radios = {}
local function radio(name)
	local def = assert(settings[name])
	return function(init)
		local map = assert(radios[name])
		local ret = iup.radio(init)
		local p = assert(map[def])
		ret.value = p.ctrl
		return ret
	end
end

local sliders = {}

local function slider(key, title, min, max, fmt)
	local value = assert(settings[key])
	local integer = math.type(value) == "integer"
	local tv = value
	if fmt then
		if fmt == "%p" then
			tv = string.format("%d",2^value)
		else
			tv = string.format(fmt, value)
		end
	end
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
				if fmt == "%p" then
					label.title = string.format("%d",2^v)
				else
					label.title = string.format("%d",v)
				end
			else
				settings[key] = v
				label.title = string.format(fmt or "%.2f",v)
			end
		end,
	}

	sliders[key] = val

	return iup.hbox {
		iup.label { title = title .. " : " },
		val,
		label,
	}
end

local settings_default = {
	SpotLight_InvZ_Hard = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.0035, 0, 0.01 },
		normalOffset = { 0.0012, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 500, 1, 1000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Single_InvZ_Hard",
	},
	SpotLight_InvZ_PCF = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,99 },
		far = { 250, 100, 2000 },
		bias = { 0.007, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 500, 1, 1000 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Single_InvZ_PCF",
	},
	SpotLight_InvZ_VSM = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.0045, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.02, 0, 0.04 },
		customParam1 = { 450, 1, 1000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_VSM",
		progDraw = "colorLighting_Single_InvZ_VSM",
	},
	SpotLight_InvZ_ESM = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 3,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.02, 0, 0.3 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 9000, 1, 15000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Single_InvZ_ESM",
	},
	SpotLight_Linear_Hard = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.0025, 0, 0.01 },
		normalOffset = { 0.0012, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 500, 1, 1000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Single_Linear_Hard",
	},
	SpotLight_Linear_PCF = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,99 },
		far = { 250, 100, 2000 },
		bias = { 0.0025, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 2000, 1, 2000 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Single_Linear_PCF",
	},
	SpotLight_Linear_VSM = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.006, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.02, 0, 1 },
		customParam1 = { 300, 1, 1500 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_VSM",
		progDraw = "colorLighting_Single_Linear_VSM",
	},
	SpotLight_Linear_ESM = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.0055, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 2500, 1, 5000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Single_Linear_ESM",
	},

	PointLight_InvZ_Hard = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.006, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 50, 1, 300 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Omni_InvZ_Hard",
	},
	PointLight_InvZ_PCF = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,99 },
		far = { 250, 100, 2000 },
		bias = { 0.004, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 50, 1, 300 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Omni_InvZ_PCF",
	},
	PointLight_InvZ_VSM = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 8,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.001, 0, 0.05 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.02, 0, 0.04 },
		customParam1 = { 450, 1, 900 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_InvZ_VSM",
		progDraw = "colorLighting_Omni_InvZ_VSM",
	},
	PointLight_InvZ_ESM = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 3,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.035, 0, 0.1 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 9000, 1, 15000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Omni_InvZ_ESM",
	},
	PointLight_Linear_Hard = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.003, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 120, 1, 300 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Omni_Linear_Hard",
	},
	PointLight_Linear_PCF = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,99 },
		far = { 250, 100, 2000 },
		bias = { 0.0035, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 120, 1, 300 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Omni_Linear_PCF",
	},
	PointLight_Linear_VSM = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.006, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.02, 0, 1 },
		customParam1 = { 400, 1, 900 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_Linear_VSM",
		progDraw = "colorLighting_Omni_Linear_VSM",
	},
	PointLight_Linear_ESM = {
		sizePwrTwo = { 12, 9, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 250, 100, 2000 },
		bias = { 0.007, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 8000, 1, 15000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.25, 0, 2 },
		yOffset = { 0.25, 0, 2 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Omni_Linear_ESM",
	},

	DirectionalLight_InvZ_Hard = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 10, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.0012, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.05 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 200, 1, 400 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 1 },
		yOffset = { 0.2, 0, 1 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Cascade_InvZ_Hard",
	},
	DirectionalLight_InvZ_PCF = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,99 },
		far = { 550, 100, 2000 },
		bias = { 0.0012, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 200, 1, 400 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Cascade_InvZ_PCF",
	},
	DirectionalLight_InvZ_VSM = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.004, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.02, 0, 0.04 },
		customParam1 = { 2500, 1, 5000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 2 },
		yOffset = { 0.2, 0, 2 },
		progPack = "packDepth_InvZ_VSM",
		progDraw = "colorLighting_Cascade_InvZ_VSM",
	},
	DirectionalLight_InvZ_ESM = {
		sizePwrTwo = { 10, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.004, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 9500, 1, 15000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 1 },
		yOffset = { 0.2, 0, 1 },
		progPack = "packDepth_InvZ_RGBA",
		progDraw = "colorLighting_Cascade_InvZ_ESM",
	},
	DirectionalLight_Linear_Hard = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.0012, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 500, 1, 1000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 1 },
		yOffset = { 0.2, 0, 1 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Cascade_Linear_Hard",
	},
	DirectionalLight_Linear_PCF = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,99 },
		far = { 550, 100, 2000 },
		bias = { 0.0012, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 200, 1, 400 },
		xNum = { 2, 0, 8 },
		yNum = { 2, 0, 8 },
		xOffset = { 1, 0, 3 },
		yOffset = { 1, 0, 3 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Cascade_Linear_PCF",
	},
	DirectionalLight_Linear_VSM = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.004, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.02, 0, 0.04 },
		customParam1 = { 2500, 1, 5000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 1 },
		yOffset = { 0.2, 0, 1 },
		progPack = "packDepth_Linear_VSM",
		progDraw = "colorLighting_Cascade_Linear_VSM",
	},
	DirectionalLight_Linear_ESM = {
		sizePwrTwo = { 11, 7, 12, "%p"},
		depthValuePow = { 1, 1, 20 },
		near = { 1,1,10 },
		far = { 550, 100, 2000 },
		bias = { 0.004, 0, 0.01 },
		normalOffset = { 0.001, 0, 0.04 },
		customParam0 = { 0.7, 0, 1 },
		customParam1 = { 9500, 1, 15000 },
		xNum = { 2, 0, 4 },
		yNum = { 2, 0, 4 },
		xOffset = { 0.2, 0, 1 },
		yOffset = { 0.2, 0, 1 },
		progPack = "packDepth_Linear_RGBA",
		progDraw = "colorLighting_Cascade_Linear_ESM",
	},
}

-- export
function update_default_settings()
	local key = string.format("%s_%s_%s", settings.lightType , settings.depthImpl, settings.smImpl)
	local s = assert(settings_default[key])
	for key, values in pairs(s) do
		local ctrl = sliders[key]
		if ctrl then
			local v, min, max , fmt = table.unpack(values)
			local value = v
			if fmt then
				if fmt == "%p" then
					value = string.format("%d", 2^v)
				else
					value = string.format(fmt, v)
				end
			end
			ctrl.min = min
			ctrl.max = max
			ctrl.value = value
			settings[key] = v
		else
			if type(values) == "table" then
				settings[key] = values[1]
			else
				settings[key] = values
			end
		end
	end
end

local function radio_choice(title, key, type, sub, func)
	local map = radios[key]
	if not map then
		map = {}
		radios[key] = map
	end
	if func then
		func(settings[key] == type)
	end
	local c = iup.toggle {
		title = title,
		action = function(self, v)
			if v == 1 then
				if map.__pannel then
					map.__pannel.value = sub
				end
				settings[key] = type
			end
			if func then
				func(v==1)
			end
			update_default_settings()
		end
	}
	map[type] = { ctrl = c, pannel = sub }
	return c
end

local function checkbox(key, title, func)
	local value = settings[key]
	assert(type(value) == "boolean")
	if func then
		func(value)
	end
	return iup.toggle {
		title = title,
		value = value and "ON" or "OFF",
		action = function (_, v)
			settings[key] = (v == 1)
			if func then
				func(v==1)
			end
		end
	}
end

local spot_sub = iup.vbox {
	slider("coverageSpotL", "Shadow map area", 45, 120),
	slider("spotOuterAngle", "Spot outer cone", 0, 91),
	slider("spotInnerAngle", "Spot inner cone", 0, 90),
}

local point_sub = iup.vbox {
	checkbox("stencilPack", "Stencil pack"),
	slider("fovXAdjust", "Fov X adjust", -20.0, 20.0),
	slider("fovYAdjust", "Fov Y adjust", -20.0, 20.0),
}

local directional_sub = iup.vbox {
	checkbox("stabilize", "Stabilize cascades"),
	slider("numSplits", "Cascade splits", 1, 4),
	slider("splitDistribution", "Cascade distribution", 0, 1),
}

local function sub_pannel(key)
	local def = assert(settings[key])
	return function(init)
		local map = assert(radios[key])
		local c = iup.zbox(init)
		map.__pannel = c
		c.value = map[def].pannel
		return c
	end
end

local light = iup.frame {
	title = "Light",
	iup.vbox {
		radio "lightType" {
			iup.hbox {
				radio_choice("Spot light", "lightType", "SpotLight", spot_sub),
				radio_choice("Point light", "lightType", "PointLight", point_sub),
				radio_choice("Directional light", "lightType", "DirectionalLight", directional_sub),
			},
		},
		sub_pannel "lightType" {
			spot_sub,
			point_sub,
			directional_sub,
		},
		checkbox("showSmCoverage", "Show shadow map coverage"),
		slider("sizePwrTwo", "Shadow map resolution", 7, 12, "%p"),
		NORMALIZESIZE = "HORIZONTAL",
	},
}

local dvp = slider("depthValuePow", "Depth value pow", 1, 20)

local hard_sub = iup.vbox {}

local pcf_sub = iup.vbox {
	slider("xOffset", "X Offset", 0, 3),
	slider("yOffset", "Y Offset", 0, 3),
}

local vsm_sub = iup.vbox {
	slider("customParam0", "Min variance", 0, 1 ),
	slider("customParam1", "Depth multiplier", 1, 1000 ),
	checkbox("doBlur", "Blur shadow map"),
	slider("xOffset", "X Offset", 0, 3),
	slider("yOffset", "Y Offset", 0, 3),
}

local esm_sub = iup.vbox {
	slider("customParam0", "ESM Hardness", 0, 1 ),
	slider("customParam1", "Depth multiplier", 1, 1000 ),
	checkbox("doBlur", "Blur shadow map"),
	slider("xOffset", "X Offset", 0, 3),
	slider("yOffset", "Y Offset", 0, 3),
}

local settings = iup.frame {
	title = "Settings",
	iup.vbox {
		iup.hbox {
			checkbox("updateLights", "Update lights"),
			checkbox("updateScene", "Update scene"),
			checkbox("drawDepthBuffer", "Draw depth", function (v) dvp.visible = v and "yes" or "no" end),
		},
		dvp,
		radio "lightType" {
			iup.hbox {
				iup.label { title = "Shadow map depth:" },
				radio_choice("InvZ", "depthImpl", "InvZ"),
				radio_choice("Linear", "depthImpl", "Linear"),
			},
		},
		radio "smImpl" {
			iup.hbox {
				iup.label { title = "Shadow Map imp" },
				radio_choice("Hard", "smImpl", "Hard", hard_sub),
				radio_choice("PCF", "smImpl", "PCF", pcf_sub),
				radio_choice("VSM", "smImpl", "VSM", vsm_sub),
				radio_choice("ESM", "smImpl", "ESM", esm_sub),
			},
		},
		slider("bias", "Bias", 0, 0.01, "%.4f"),
		slider("normalOffset","Normal offset", 0, 0.05,"%.3f"),
		slider("near", "Near plane", 1, 10),
		slider("far", "Far plane", 200, 2000, "%.0f"),
		sub_pannel "smImpl" {
			hard_sub,
			pcf_sub,
			vsm_sub,
			esm_sub,
		},
	},
}

local leftpannel =  iup.hbox {
	iup.vbox {
		light,
		settings,
		iup.hbox { size = "100" },	-- for min hsize
		NORMALIZESIZE = "HORIZONTAL",
	},
}

dlg = iup.dialog {
	iup.hbox {
		leftpannel,
		canvas,
		margin = "2x2",
	},
  title = "16-shadowmaps",
  size = "HALF",
}

end

-----------------------------------------------

local Uniforms = {}

local function init_Uniforms()

	local function univ(name, ...)
		math3d.vector(name, Uniforms):pack(...)
	end

	Uniforms.ambientPass = 1
	Uniforms.lightingPass = 1
	-- m_ambientPass m_lightingPass;
	univ("params0", 1,1)

	-- m_shadowMapBias m_shadowMapOffset m_shadowMapParam0 m_shadowMapParam1
	Uniforms.shadowMapBias = 0.003
	Uniforms.shadowMapOffset = 0
	Uniforms.shadowMapParam0 = 0.5
	Uniforms.shadowMapParam1 = 1
	univ("params1", 0.003, 0, 0.5, 1)

	Uniforms.depthValuePow = 1
	Uniforms.showSmCoverage = 1
	Uniforms.shadowMapTexelSize = 1/512
	univ("params2", 1,1, 1/512)

	univ("csmFarDistances", 30, 90, 180, 1000)
	univ("tetraNormalGreen", 0, -0.57735026, 0.81649661)
	univ("tetraNormalYellow", 0, -0.57735026, -0.81649661)
	univ("tetraNormalBlue", -0.81649661, 0.57735026, 0)
	univ("tetraNormalRed", 0.81649661, 0.57735026, 0)


	Uniforms.XNum = 2
	Uniforms.YNum = 2
	Uniforms.XOffset = 10.0/512
	Uniforms.YOffset = 10.0/512

	-- m_XNum m_YNum m_XOffset m_YOffset
	univ("paramsBlur", 2,2, 10/512, 10/512)

	local function uni(name, t)
		Uniforms[name] = bgfx.create_uniform(name, t or "v4")
	end

	uni "u_params0"
	uni "u_params1"
	uni "u_params2"
	uni "u_color"
	uni "u_smSamplingParams"
	uni "u_csmFarDistances"
	uni("u_lightMtx", "m4")

	uni "u_tetraNormalGreen"
	uni "u_tetraNormalYellow"
	uni "u_tetraNormalBlue"
	uni "u_tetraNormalRed"

	uni("u_shadowMapMtx0", "m4")
	uni("u_shadowMapMtx1", "m4")
	uni("u_shadowMapMtx2", "m4")
	uni("u_shadowMapMtx3", "m4")

	uni "u_lightPosition"
	uni "u_lightAmbientPower"
	uni "u_lightDiffusePower"
	uni "u_lightSpecularPower"
	uni "u_lightSpotDirectionInner"
	uni "u_lightAttenuationSpotOuter"

	uni "u_materialKa"
	uni "u_materialKd"
	uni "u_materialKs"


	Uniforms.materialPtr = false	-- reserved
	Uniforms.lightPtr = false
	Uniforms.colorPtr = false
	Uniforms.lightMtxPtr = false
	Uniforms.shadowMapMtx0 = false
	Uniforms.shadowMapMtx1 = false
	Uniforms.shadowMapMtx2 = false
	Uniforms.shadowMapMtx3 = false

	setmetatable(Uniforms, { __newindex = function(t,k,v) error(k) end })	-- readonly
end

-- Call this once at initialization.
local function submitConstUniforms()
	bgfx.set_uniform(Uniforms.u_tetraNormalGreen,  Uniforms.tetraNormalGreen)
	bgfx.set_uniform(Uniforms.u_tetraNormalYellow,  Uniforms.tetraNormalYellow)
	bgfx.set_uniform(Uniforms.u_tetraNormalBlue,  Uniforms.tetraNormalBlue)
	bgfx.set_uniform(Uniforms.u_tetraNormalRed,  Uniforms.tetraNormalRed)
end

-- Call this once per frame.
local function submitPerFrameUniforms()
	Uniforms.params1:pack(Uniforms.shadowMapBias,
		Uniforms.shadowMapOffset,
		Uniforms.shadowMapParam0,
		Uniforms.shadowMapParam1)
	bgfx.set_uniform(Uniforms.u_params1, Uniforms.params1)
	Uniforms.params2:pack(
		Uniforms.depthValuePow,
		Uniforms.showSmCoverage,
		Uniforms.shadowMapTexelSize)
	bgfx.set_uniform(Uniforms.u_params2, Uniforms.params2)

	Uniforms.paramsBlur:pack(
		Uniforms.XNum,
		Uniforms.YNum,
		Uniforms.XOffset,
		Uniforms.YOffset)
	bgfx.set_uniform(Uniforms.u_smSamplingParams, Uniforms.paramsBlur)

	bgfx.set_uniform(Uniforms.u_csmFarDistances, Uniforms.csmFarDistances)

	bgfx.set_uniform(Uniforms.u_materialKa, Uniforms.materialPtr.ambient)
	bgfx.set_uniform(Uniforms.u_materialKd, Uniforms.materialPtr.diffuse)
	bgfx.set_uniform(Uniforms.u_materialKs, Uniforms.materialPtr.specular)

	bgfx.set_uniform(Uniforms.u_lightPosition,             Uniforms.lightPtr.position_viewSpace)
	bgfx.set_uniform(Uniforms.u_lightAmbientPower,         Uniforms.lightPtr.ambient)
	bgfx.set_uniform(Uniforms.u_lightDiffusePower,         Uniforms.lightPtr.diffuse)
	bgfx.set_uniform(Uniforms.u_lightSpecularPower,        Uniforms.lightPtr.specular)
	bgfx.set_uniform(Uniforms.u_lightSpotDirectionInner,   Uniforms.lightPtr.spotdirection_viewSpace)
	bgfx.set_uniform(Uniforms.u_lightAttenuationSpotOuter, Uniforms.lightPtr.attenuation)
end

-- Call this before each draw call.
local function submitPerDrawUniforms()
	bgfx.set_uniform(Uniforms.u_shadowMapMtx0, Uniforms.shadowMapMtx0)
	bgfx.set_uniform(Uniforms.u_shadowMapMtx1, Uniforms.shadowMapMtx1)
	bgfx.set_uniform(Uniforms.u_shadowMapMtx2, Uniforms.shadowMapMtx2)
	bgfx.set_uniform(Uniforms.u_shadowMapMtx3, Uniforms.shadowMapMtx3)

	Uniforms.params0:pack(Uniforms.ambientPass, Uniforms.lightingPass)
	bgfx.set_uniform(Uniforms.u_params0,  Uniforms.params0)

	bgfx.set_uniform(Uniforms.u_lightMtx, Uniforms.lightMtxPtr)
	bgfx.set_uniform(Uniforms.u_color,    Uniforms.colorPtr)
end

-- render state
local s_renderState = {
	Default = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
--			BLEND_FACTOR = 0xffffffff,
		},
	},
	ShadowMap_PackDepth = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
	},
	ShadowMap_PackDepthHoriz = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
		fstencil = bgfx.make_stencil {
			TEST = "EQUAL",
			FUNC_REF = 1,
			FUNC_RMASK = 0xff,
			OP_FAIL_S = "KEEP",
			OP_FAIL_Z = "KEEP",
			OP_PASS_Z = "KEEP",
		},
	},
	ShadowMap_PackDepthVert = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			CULL = "CCW",
			MSAA = true,
		},
		fstencil = bgfx.make_stencil {
			TEST = "EQUAL",
			FUNC_REF = 0,
			FUNC_RMASK = 0xff,
			OP_FAIL_S = "KEEP",
			OP_FAIL_Z = "KEEP",
			OP_PASS_Z = "KEEP",
		},
	},
	Custom_BlendLightTexture = {
		state = bgfx.make_state {
			WRITE_MASK = "RGBAZ",
			DEPTH_TEST = "LESS",
			BLEND_FUNC = "sS", -- BGFX_STATE_BLEND_SRC_COLOR, BGFX_STATE_BLEND_INV_SRC_COLOR
			CULL = "CCW",
			MSAA = true,
		},
	},
	Custom_DrawPlaneBottom = {
		state = bgfx.make_state {
			WRITE_MASK = "RGB",
			CULL = "CW",
			MSAA = true,
		},
	},
}

local Programs = {}
local function init_Programs()
	local function prog(name, vs, fs)
		fs = fs or vs
		vs = "vs_shadowmaps_" .. vs
		fs = "fs_shadowmaps_" .. fs
		Programs[name] = util.programLoad(vs, fs)
	end

	--misc
	prog("black", "color", "color_black")
	prog("texture", "texture")
	prog("colorTexture", "color_texture")

	--blur
	prog("vblur_RGBA", "vblur")
	prog("hblur_RGBA", "hblur")
	prog("vblur_VSM", "vblur", "vblur_vsm")
	prog("hblur_VSM", "hblur", "hblur_vsm")

	--draw depth
	prog("drawDepth_RGBA", "unpackdepth")
	prog("drawDepth_VSM", "unpackdepth", "unpackdepth_vsm")

	-- Pack depth.
	prog("packDepth_InvZ_RGBA", "packdepth")
	prog("packDepth_InvZ_VSM", "packdepth", "packdepth_vsm")
	prog("packDepth_Linear_RGBA", "packdepth_linear")
	prog("packDepth_Linear_VSM", "packdepth_linear", "packdepth_vsm_linear")

	-- Color lighting.
	prog("colorLighting_Single_InvZ_Hard", "color_lighting", "color_lighting_hard")
	prog("colorLighting_Single_InvZ_PCF", "color_lighting", "color_lighting_pcf")
	prog("colorLighting_Single_InvZ_VSM", "color_lighting", "color_lighting_vsm")
	prog("colorLighting_Single_InvZ_ESM", "color_lighting", "color_lighting_esm")

	prog("colorLighting_Single_Linear_Hard", "color_lighting_linear", "color_lighting_hard_linear")
	prog("colorLighting_Single_Linear_PCF", "color_lighting_linear", "color_lighting_pcf_linear")
	prog("colorLighting_Single_Linear_VSM", "color_lighting_linear", "color_lighting_vsm_linear")
	prog("colorLighting_Single_Linear_ESM", "color_lighting_linear", "color_lighting_esm_linear")

	prog("colorLighting_Omni_InvZ_Hard", "color_lighting_omni", "color_lighting_hard_omni")
	prog("colorLighting_Omni_InvZ_PCF", "color_lighting_omni", "color_lighting_pcf_omni")
	prog("colorLighting_Omni_InvZ_VSM", "color_lighting_omni", "color_lighting_vsm_omni")
	prog("colorLighting_Omni_InvZ_ESM", "color_lighting_omni", "color_lighting_esm_omni")

	prog("colorLighting_Omni_Linear_Hard", "color_lighting_linear_omni", "color_lighting_hard_linear_omni")
	prog("colorLighting_Omni_Linear_PCF", "color_lighting_linear_omni", "color_lighting_pcf_linear_omni")
	prog("colorLighting_Omni_Linear_VSM", "color_lighting_linear_omni", "color_lighting_vsm_linear_omni")
	prog("colorLighting_Omni_Linear_ESM", "color_lighting_linear_omni", "color_lighting_esm_linear_omni")

	prog("colorLighting_Cascade_InvZ_Hard", "color_lighting_csm", "color_lighting_hard_csm")
	prog("colorLighting_Cascade_InvZ_PCF", "color_lighting_csm", "color_lighting_pcf_csm")
	prog("colorLighting_Cascade_InvZ_VSM", "color_lighting_csm", "color_lighting_vsm_csm")
	prog("colorLighting_Cascade_InvZ_ESM", "color_lighting_csm", "color_lighting_esm_csm")

	prog("colorLighting_Cascade_Linear_Hard", "color_lighting_linear_csm", "color_lighting_hard_linear_csm")
	prog("colorLighting_Cascade_Linear_PCF", "color_lighting_linear_csm", "color_lighting_pcf_linear_csm")
	prog("colorLighting_Cascade_Linear_VSM", "color_lighting_linear_csm", "color_lighting_vsm_linear_csm")
	prog("colorLighting_Cascade_Linear_ESM", "color_lighting_linear_csm", "color_lighting_esm_linear_csm")
end

local ctx = {}

local function screenSpaceQuad(textureWidth, textureHeight, originBottomLeft)
	local width = 1
	local height = 1

	ctx.color_tb:alloc(3, ctx.PosColorTexCoord0Vertex)

	local zz = 0
	local minx = -width
	local maxx = width
	local miny = 0
	local maxy = height * 2

	local texelHalfW = ctx.s_texelHalf / textureWidth
	local texelHalfH = ctx.s_texelHalf / textureHeight
	local minu = -1 + texelHalfW
	local maxu = 1 + texelHalfW

	local minv = texelHalfH
	local maxv = 2 + texelHalfH

	if originBottomLeft then
		minv, maxv = maxv, minv
		minv = minv - 1
		maxv = maxv - 1
	end

	ctx.color_tb:packV(0, minx, miny, zz, 0xffffffff, minu, minv)
	ctx.color_tb:packV(1, maxx, miny, zz, 0xffffffff, maxu, minv)
	ctx.color_tb:packV(2, maxx, maxy, zz, 0xffffffff, maxu, maxv)

	ctx.color_tb:set()
end

local corners = {}
local function worldSpaceFrustumCorners(out,near, far, projWidth, projHeight, invViewMtx)
	-- Define frustum corners in view space.
	local nw = near * projWidth
	local nh = near * projHeight
	local fw = far * projWidth
	local fh = far * projHeight

	local numCorners = 8
	math3d.vector(1,corners):pack(-nw,  nh, _near)
	math3d.vector(2,corners):pack( nw,  nh, _near)
	math3d.vector(3,corners):pack( nw, -nh, _near)
	math3d.vector(4,corners):pack(-nw, -nh, _near)
	math3d.vector(5,corners):pack(-fw,  fh, _far )
	math3d.vector(6,corners):pack( fw,  fh, _far )
	math3d.vector(7,corners):pack( fw, -fh, _far )
	math3d.vector(8,corners):pack(-fw, -fh, _far )

	-- Convert them to world space.
	for i = 1, numCorners do
		local v = math3d.vector(i, out)
		v:mul(corners[i], invViewMtx)
	end
end

local function computeViewSpaceComponents(light, mtx)
	light.position_viewSpace:vec4mul(light.position, mtx)
	local v1,v2,v3,v4 = light.spotdirection:unpack()
	local tmp = math3d.vector():pack(v1,v2,v3,0)
	light.spotdirection_viewSpace:vec4mul(tmp, mtx):pack(nil,nil,nil,v4)
end

local function mtxBillboard(result, view, pos, s0,s1,s2)
	local p0,p1,p2 = pos:unpack()
	local v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15 = view:unpack()
	return result:pack(
		v0 * s0,
		v4 * s0,
		v8 * s0,
		0,
		v1 * s1,
		v5 * s1,
		v9 * s1,
		0,
		v2 * s2,
		v6 * s2,
		v10 * s2,
		0,
		p0,
		p1,
		p2,
		1)
end

local function mtxYawPitchRoll(vec)
	local yaw = vec[1]
	local pitch = vec[2]
	local roll = vec[3]

	local sroll = math.sin(roll)
	local croll = math.cos(roll)
	local spitch = math.sin(pitch)
	local cpitch = math.cos(pitch)
	local syaw = math.sin(yaw)
	local cyaw = math.cos(yaw)

	return sroll * spitch * syaw + croll * cyaw,
	 sroll * cpitch,
	 sroll * spitch * cyaw - croll * syaw,
	 0.0,
	 croll * spitch * syaw - sroll * cyaw,
	 croll * cpitch,
	 croll * spitch * cyaw + sroll * syaw,
	 0.0,
	 cpitch * syaw,
	 -spitch,
	 cpitch * cyaw,
	 0.0,
	 0.0,
	 0.0,
	 0.0,
	 1.0
end


-- _splits = { near0, far0, near1, far1... nearN, farN }
-- N = _numSplits

local function splitFrustum(numSlices, near, far, l)
	local splits = {}
--	const float l = _splitWeight;
	local ratio = far/near
	numSlices = numSlices * 2

	-- First slice.
	splits[1] = near

	local ff = 1
	for nn = 3, numSlices, 2 do
		local si = ff / numSlices
		local nearp = l * near * ratio ^ si + (1-l) * (near + (far-near) * si)
		splits[nn] = nearp	-- near
		splits[ff+1] = nearp * 1.005	-- far from previous split
		ff = ff + 2
	end
	splits[numSlices] = far;
	return splits
end

local function submitShadowMesh(mesh, viewId, mtx, program, renderState, texture, submitShadowMaps)
	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)

		-- set uniforms.
		submitPerDrawUniforms()

		-- Set model matrix for rendering.
		bgfx.set_transform(mtx)
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)

		-- set textures
		if texture then
			bgfx.set_texture(0, ctx.s_texColor, texture)
		end
		if submitShadowMaps then
			for i=1,4 do
				bgfx.set_texture(3+i, ctx.s_shadowMap[i], bgfx.get_texture(ctx.s_rtShadowMap[i]))
			end
		end
		-- Apply render state.
		bgfx.set_stencil(renderState.fstencil, renderState.bstencil)
		bgfx.set_state(renderState.state)

		-- Submit.
		bgfx.submit(viewId, program)
	end
end

local function init_mat4(array)
	for i =1,4 do
		math3d.matrix(i,array)
	end
	return array
end

local mtxTrees = {}
local lightView = init_mat4 {}
local lightProj = init_mat4 {}
local mtxYpr = {}
local frustumCorners = {}
local mtxCropBias = {}

local function mainloop()
	local view = math3d.matrix "view"
	local proj = math3d.matrix "proj"
	math3d.reset()

	Uniforms.shadowMapTexelSize = 1 / ctx.m_currentShadowMapSize
	submitConstUniforms()

	Uniforms.shadowMapBias   = settings.bias
	Uniforms.shadowMapOffset = settings.normalOffset
	Uniforms.shadowMapParam0 = settings.customParam0
	Uniforms.shadowMapParam1 = settings.customParam1
	Uniforms.depthValuePow   = settings.depthValuePow
	Uniforms.XNum            = settings.xNum
	Uniforms.YNum            = settings.yNum
	Uniforms.XOffset         = settings.xOffset
	Uniforms.YOffset         = settings.yOffset
	Uniforms.showSmCoverage  = settings.showSmCoverage and 1 or 0
	Uniforms.lightPtr = settings.lightType == "DirectionalLight" and ctx.m_directionalLight or ctx.m_pointLight

		-- attenuationSpotOuter
		--	float m_attnConst;
		--	float m_attnLinear;
		--	float m_attnQuadrantic;
		--	float m_outer;

		-- spotDirectionInner
		--	float m_x;
		--	float m_y;
		--	float m_z;
		--	float m_inner;
	if settings.lightType == "SpotLight" then
		math3d.vector("attenuation",ctx.m_pointLight):pack(nil, nil, nil, settings.spotOuterAngle)
		math3d.vector("spotdirection",ctx.m_pointLight):pack(nil, nil, nil, settings.spotInnerAngle)
	else
		math3d.vector("attenuation",ctx.m_pointLight):pack(nil, nil, nil, 91) --above 90.0f means point light
	end

	submitPerFrameUniforms()
	-- update time
	local deltaTime = 0.01

	-- Update lights.
	computeViewSpaceComponents(ctx.m_pointLight, view)
	computeViewSpaceComponents(ctx.m_directionalLight, view)

	if settings.updateLights then
		ctx.m_timeAccumulatorLight = ctx.m_timeAccumulatorLight + deltaTime
	end
	if settings.updateScene then
		ctx.m_timeAccumulatorScene = ctx.m_timeAccumulatorScene + deltaTime
	end

	-- Setup lights.
	local x = math.cos(ctx.m_timeAccumulatorLight) * 20
	local y = 26
	local z = math.sin(ctx.m_timeAccumulatorLight) * 20
	ctx.m_pointLight.position:pack(x,y,z)
	ctx.m_pointLight.spotdirection:pack(-x,-y,-z)

	ctx.m_directionalLight.position:pack(
		-math.cos(ctx.m_timeAccumulatorLight),
		-1,
		-math.sin(ctx.m_timeAccumulatorLight))

	-- Setup instance matrices.
	local floorScale = 550.0
	local mtxFloor = math3d.matrix():scalemat(floorScale,floorScale,floorScale)
	local mtxBunny = math3d.matrix():srt(
					   5.0
					   , 5.0
					   , 5.0
					   , 0.0
					   , 1.56 - ctx.m_timeAccumulatorScene
					   , 0.0
					   , 15.0
					   , 5.0
					   , 0.0
					   )

	local mtxHollowcube = math3d.matrix():srt(
					   2.5
					   , 2.5
					   , 2.5
					   , 0.0
					   , 1.56 - ctx.m_timeAccumulatorScene
					   , 0.0
					   , 0.0
					   , 10.0
					   , 0.0
					   )

	local mtxCube = math3d.matrix():srt(
					   2.5
					   , 2.5
					   , 2.5
					   , 0.0
					   , 1.56 - ctx.m_timeAccumulatorScene
					   , 0.0
					   , -15.0
					   , 5.0
					   , 0.0
					   )

	local numTrees = 10
	for i = 1, 	numTrees do
		math3d.matrix(i, mtxTrees):srt(2,2,2
						   , 0 , i-1 , 0
						   , math.sin((i-1)*2*math.pi/numTrees ) * 60
						   , 0.0
						   , math.cos((i-1)*2*math.pi/numTrees ) * 60
						   )
	end

	-- Compute transform matrices.
	local shadowMapPasses = 4

	local screenProj = math3d.matrix():orthomat(0,1,1,0,0,100)
	local screenView = math3d.matrix():identity()

	local function matrix_far(mtx)
		local m = { mtx:unpack() }
		m[11] = m[11] / settings.far
		m[15] = m[15] / settings.far
		mtx:pack(table.unpack(m))
	end

	if settings.lightType == "SpotLight" then
		local fovy = settings.coverageSpotL
		local aspect = 1
		-- Horizontal == 1

		local mtx = lightProj[1]:projmat(fovy, aspect, settings.near, settings.far, false)
		-- For linear depth, prevent depth division by variable w-component in shaders and divide here by far plane
		if settings.depthImpl == "Linear" then
			matrix_far(mtx)
		end
		local at = math3d.vector()
		local v1,v2,v3 = ctx.m_pointLight.position:unpack()
		local v4,v5,v6 = ctx.m_pointLight.spotdirection:unpack()
		at:pack(v1+v4,v2+v5,v3+v6)
		-- Green == 1
		-- Yellow 2
		-- Blue 3
		-- Red 4
		lightView[1]:lookat(ctx.m_pointLight.position, at)
	elseif settings.lightType == "PointLight" then
		local rad = math.rad
		local ypr =	{
			{ rad(  0.0), rad( 27.36780516), rad(0.0) },
			{ rad(180.0), rad( 27.36780516), rad(0.0) },
			{ rad(-90.0), rad(-27.36780516), rad(0.0) },
			{ rad( 90.0), rad(-27.36780516), rad(0.0) },
		}

		if settings.stencilPack then
			local fovx = 143.98570868 + 3.51 + settings.fovXAdjust
			local fovy = 125.26438968 + 9.85 + settings.fovYAdjust
			local aspect = math.tan(rad(fovx*0.5) )/math.tan(rad(fovy*0.5) )

			-- Vertical == 2
			local mtx = lightProj[2]:projmat(fovx , aspect, settings.near, settings.far, false)

			--For linear depth, prevent depth division by variable w-component in shaders and divide here by far plane
			if settings.depthImpl == "Linear" then
				matrix_far(mtx)
			end

			ypr[GREEN][3] = rad(180.0)
			ypr[YELLOW][3] = rad(  0.0)
			ypr[BLUE][3] = rad( 90.0)
			ypr[RED][3] = rad(-90.0)
		end

		local fovx = 143.98570868 + 7.8 + settings.fovXAdjust
		local fovy = 125.26438968 + 3.0 + settings.fovYAdjust
		local aspect = math.tan(rad(fovx*0.5) )/math.tan(rad(fovy*0.5) )

		local mtx = lightProj[1]:projmat(fovy, aspect, settings.near, settings.far)

		-- For linear depth, prevent depth division by variable w component in shaders and divide here by far plane

		if settings.depthImpl == "Linear" then
			matrix_far(mtx)
		end

		local tmpv = math3d.vector()
		for i = 1, 4 do
			local mtxTmp = math3d.matrix(i, mtxYpr)
			local m0,m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15 = mtxYawPitchRoll(ypr[i])
			mtxTmp:pack(m0,m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15)

			local pv = ctx.m_pointLight.position
			local tmp_x = - pv:dot(tmpv:pack(m0,m1,m2))
			local tmp_y = - pv:dot(tmpv:pack(m4,m5,m6))
			local tmp_z = - pv:dot(tmpv:pack(m8,m9,m10))

			mtxTmp:transposed()
			lightView[i]:copy(mtxTmp)
			lightView[i]:packline(4, tmp_x, tmp_y, tmp_z, 1)
		end
	else -- "DirectionalLight"
		-- Setup light view mtx.
		local px,py,pz = ctx.m_directionalLight.position:unpack()
		lightView[1]:lookatp(-px,-py,-pz,0,0,0)

		-- Compute camera inverse view mtx.
		local mtxViewInv = math3d:matrix():inverted(view)

		-- Compute split distances.
		local maxNumSplits = 4

		local splitSlices = splitFrustum(settings.numSplits,
			settings.near,
			settings.far,
			settings.splitDistribution)

		-- Update uniforms.

		-- This lags for 1 frame, but it's not a problem.
		Uniforms.csmFarDistances:pack(splitSlices[2], splitSlices[4], splitSlices[6], splitSlices[8])

		local mtxProj = math3d.matrix():orthomat(1,-1,1,-1,-settings.far,settings.far)

		local numCorners = 8
		local nn = -1
		local ff = 0
		for i = 1, settings.numSplits do
			nn = nn + 2
			ff = ff + 2
			-- Compute frustum corners for one split in world space.

			local fc = frustumCorners[i]
			if not fc then
				fc = {}
				frustumCorners[i] = fc
			end
			worldSpaceFrustumCorners(fc, splitSlices[nn], splitSlices[ff], ctx.projWidth, ctx.projHeight, mtxViewInv)

			local min = { 9000, 9000, 9000 }
			local max = { -9000, -9000, -9000 }

			for j = 1, numCorners do
				-- Transform to light space.
				local lightSpaceFrustumCorner = math3d.vector():mul(fc[j], lightView[1])

				-- Update bounding box.
				local v1,v2,v3 = lightSpaceFrustumCorner:unpack()
				min[1] = math.min(min[1], v1)
				max[1] = math.max(max[1], v1)
				min[2] = math.min(min[2], v2)
				max[2] = math.max(max[2], v2)
				min[3] = math.min(min[3], v3)
				max[3] = math.max(max[3], v3)
			end

			local minproj = math3d.vector():pack(table.unpack(min))
			local maxproj = math3d.vector():pack(table.unpack(max))

			minproj:mulH(mtxProj)
			maxproj:mulH(mtxProj)

			local max_x, max_y = maxproj:unpack()
			local min_x, min_y = minproj:unpack()

			local scalex = 2 / (max_x - min_x)
			local scaley = 2 / (max_y - min_y)

			if settings.stabilize then
				local quantizer = 64
				scalex = quantizer / math.ceil(quantizer / scalex)
				scaley = quantizer / math.ceil(quantizer / scaley)
			end

			local offsetx = 0.5 * (max_x + min_x) * scalex
			local offsety = 0.5 * (max_y + min_y) * scaley

			if settings.stabilize then
				local halfSize = ctx.m_currentShadowMapSize * 0.5
				offsetx = math.ceil(offsetx * halfSize) / halfSize
				offsety = math.ceil(offsety * halfSize) / halfSize
			end

			local mtxCrop = lightProj[i]:identity()
			mtxCrop:packline(1, scalex)
			mtxCrop:packline(2, nil, scaley)
			mtxCrop:packline(4, offsetx, offsety)
			lightProj[i]:mul(mtxCrop,mtxProj)
		end
	end

	-- Reset render targets.
	for i =0, RENDERVIEW_DRAWDEPTH_3_ID do
		bgfx.set_view_frame_buffer(i)	-- reset
	end

	-- Determine on-screen rectangle size where depth buffer will be drawn.
	local depthRectHeight = math.floor(ctx.height / 2.5)
	local depthRectWidth  = depthRectHeight
	local depthRectX = 0
	local depthRectY = ctx.height - depthRectHeight

	-- Setup views and render targets.
	local setViewRect = bgfx.set_view_rect
	local setViewTransform = bgfx.set_view_transform
	local setViewFrameBuffer = bgfx.set_view_frame_buffer
	local m_currentShadowMapSize = ctx.m_currentShadowMapSize
	setViewRect(0, 0, 0, ctx.width, ctx.height)
	setViewTransform(0, view, proj)

	if settings.lightType == "SpotLight" then
		--		 * RENDERVIEW_SHADOWMAP_0_ID - Clear shadow map. (used as convenience, otherwise render_pass_1 could be cleared)
		--		 * RENDERVIEW_SHADOWMAP_1_ID - Craft shadow map.
		--		 * RENDERVIEW_VBLUR_0_ID - Vertical blur.
		--		 * RENDERVIEW_HBLUR_0_ID - Horizontal blur.
		--		 * RENDERVIEW_DRAWSCENE_0_ID - Draw scene.
		--		 * RENDERVIEW_DRAWSCENE_1_ID - Draw floor bottom.
		--		 * RENDERVIEW_DRAWDEPTH_0_ID - Draw depth buffer.

		setViewRect(RENDERVIEW_SHADOWMAP_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_SHADOWMAP_1_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_VBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_DRAWSCENE_0_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWSCENE_1_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWDEPTH_0_ID, depthRectX, depthRectY, depthRectWidth, depthRectHeight)

		setViewTransform(RENDERVIEW_SHADOWMAP_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_SHADOWMAP_1_ID, lightView[1], lightProj[1])
		setViewTransform(RENDERVIEW_VBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWSCENE_0_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWSCENE_1_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_0_ID, screenView, screenProj)

		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_0_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_1_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_VBLUR_0_ID, ctx.s_rtBlur)
		setViewFrameBuffer(RENDERVIEW_HBLUR_0_ID, ctx.s_rtShadowMap[1])
	elseif settings.lightType == "PointLight" then
		--		 * RENDERVIEW_SHADOWMAP_0_ID - Clear entire shadow map.
		--		 * RENDERVIEW_SHADOWMAP_1_ID - Craft green tetrahedron shadow face.
		--		 * RENDERVIEW_SHADOWMAP_2_ID - Craft yellow tetrahedron shadow face.
		--		 * RENDERVIEW_SHADOWMAP_3_ID - Craft blue tetrahedron shadow face.
		--		 * RENDERVIEW_SHADOWMAP_4_ID - Craft red tetrahedron shadow face.
		--		 * RENDERVIEW_VBLUR_0_ID - Vertical blur.
		--		 * RENDERVIEW_HBLUR_0_ID - Horizontal blur.
		--		 * RENDERVIEW_DRAWSCENE_0_ID - Draw scene.
		--		 * RENDERVIEW_DRAWSCENE_1_ID - Draw floor bottom.
		--		 * RENDERVIEW_DRAWDEPTH_0_ID - Draw depth buffer.

		setViewRect(RENDERVIEW_SHADOWMAP_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		if settings.stencilPack then
			local f = m_currentShadowMapSize --full size
			local h = m_currentShadowMapSize//2 --half size
			setViewRect(RENDERVIEW_SHADOWMAP_1_ID, 0, 0, f, h)
			setViewRect(RENDERVIEW_SHADOWMAP_2_ID, 0, h, f, h)
			setViewRect(RENDERVIEW_SHADOWMAP_3_ID, 0, 0, h, f)
			setViewRect(RENDERVIEW_SHADOWMAP_4_ID, h, 0, h, f)
		else
			local h = m_currentShadowMapSize//2 --half size
			setViewRect(RENDERVIEW_SHADOWMAP_1_ID, 0, 0, h, h)
			setViewRect(RENDERVIEW_SHADOWMAP_2_ID, h, 0, h, h)
			setViewRect(RENDERVIEW_SHADOWMAP_3_ID, 0, h, h, h)
			setViewRect(RENDERVIEW_SHADOWMAP_4_ID, h, h, h, h)
		end
		setViewRect(RENDERVIEW_VBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_DRAWSCENE_0_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWSCENE_1_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWDEPTH_0_ID, depthRectX, depthRectY, depthRectWidth, depthRectHeight)

		setViewTransform(RENDERVIEW_SHADOWMAP_0_ID, screenView, screenProj);
		setViewTransform(RENDERVIEW_SHADOWMAP_1_ID, lightView[GREEN],  lightProj[1])
		setViewTransform(RENDERVIEW_SHADOWMAP_2_ID, lightView[YELLOW], lightProj[1])

		if settings.stencilPack then
			setViewTransform(RENDERVIEW_SHADOWMAP_3_ID, lightView[BLUE], lightProj[2])
			setViewTransform(RENDERVIEW_SHADOWMAP_4_ID, lightView[RED], lightProj[2])
		else
			setViewTransform(RENDERVIEW_SHADOWMAP_3_ID, lightView[BLUE], lightProj[1])
			setViewTransform(RENDERVIEW_SHADOWMAP_4_ID, lightView[RED], lightProj[1])
		end

		setViewTransform(RENDERVIEW_VBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWSCENE_0_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWSCENE_1_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_0_ID, screenView, screenProj)

		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_0_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_1_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_2_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_3_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_4_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_VBLUR_0_ID, ctx.s_rtBlur)
		setViewFrameBuffer(RENDERVIEW_HBLUR_0_ID, ctx.s_rtShadowMap[1])
	else	-- LightType::DirectionalLight == settings.m_lightType
		--		 * RENDERVIEW_SHADOWMAP_1_ID - Craft shadow map for first  split.
		--		 * RENDERVIEW_SHADOWMAP_2_ID - Craft shadow map for second split.
		--		 * RENDERVIEW_SHADOWMAP_3_ID - Craft shadow map for third  split.
		--		 * RENDERVIEW_SHADOWMAP_4_ID - Craft shadow map for fourth split.
		--		 * RENDERVIEW_VBLUR_0_ID - Vertical   blur for first  split.
		--		 * RENDERVIEW_HBLUR_0_ID - Horizontal blur for first  split.
		--		 * RENDERVIEW_VBLUR_1_ID - Vertical   blur for second split.
		--		 * RENDERVIEW_HBLUR_1_ID - Horizontal blur for second split.
		--		 * RENDERVIEW_VBLUR_2_ID - Vertical   blur for third  split.
		--		 * RENDERVIEW_HBLUR_2_ID - Horizontal blur for third  split.
		--		 * RENDERVIEW_VBLUR_3_ID - Vertical   blur for fourth split.
		--		 * RENDERVIEW_HBLUR_3_ID - Horizontal blur for fourth split.
		--		 * RENDERVIEW_DRAWSCENE_0_ID - Draw scene.
		--		 * RENDERVIEW_DRAWSCENE_1_ID - Draw floor bottom.
		--		 * RENDERVIEW_DRAWDEPTH_0_ID - Draw depth buffer for first  split.
		--		 * RENDERVIEW_DRAWDEPTH_1_ID - Draw depth buffer for second split.
		--		 * RENDERVIEW_DRAWDEPTH_2_ID - Draw depth buffer for third  split.
		--		 * RENDERVIEW_DRAWDEPTH_3_ID - Draw depth buffer for fourth split.

		depthRectHeight = math.floor(ctx.height / 3)
		depthRectWidth  = depthRectHeight
		depthRectX = 0
		depthRectY = ctx.height - depthRectHeight

		setViewRect(RENDERVIEW_SHADOWMAP_1_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_SHADOWMAP_2_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_SHADOWMAP_3_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_SHADOWMAP_4_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_VBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_0_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_VBLUR_1_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_1_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_VBLUR_2_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_2_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_VBLUR_3_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_HBLUR_3_ID, 0, 0, m_currentShadowMapSize, m_currentShadowMapSize)
		setViewRect(RENDERVIEW_DRAWSCENE_0_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWSCENE_1_ID, 0, 0, ctx.width, ctx.height)
		setViewRect(RENDERVIEW_DRAWDEPTH_0_ID, depthRectX+(0*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
		setViewRect(RENDERVIEW_DRAWDEPTH_1_ID, depthRectX+(1*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
		setViewRect(RENDERVIEW_DRAWDEPTH_2_ID, depthRectX+(2*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)
		setViewRect(RENDERVIEW_DRAWDEPTH_3_ID, depthRectX+(3*depthRectWidth), depthRectY, depthRectWidth, depthRectHeight)

		setViewTransform(RENDERVIEW_SHADOWMAP_1_ID, lightView[1], lightProj[1])
		setViewTransform(RENDERVIEW_SHADOWMAP_2_ID, lightView[1], lightProj[2])
		setViewTransform(RENDERVIEW_SHADOWMAP_3_ID, lightView[1], lightProj[3])
		setViewTransform(RENDERVIEW_SHADOWMAP_4_ID, lightView[1], lightProj[4])
		setViewTransform(RENDERVIEW_VBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_VBLUR_1_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_1_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_VBLUR_2_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_2_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_VBLUR_3_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_HBLUR_3_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWSCENE_0_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWSCENE_1_ID, view, proj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_0_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_1_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_2_ID, screenView, screenProj)
		setViewTransform(RENDERVIEW_DRAWDEPTH_3_ID, screenView, screenProj)

		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_1_ID, ctx.s_rtShadowMap[1])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_2_ID, ctx.s_rtShadowMap[2])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_3_ID, ctx.s_rtShadowMap[3])
		setViewFrameBuffer(RENDERVIEW_SHADOWMAP_4_ID, ctx.s_rtShadowMap[4])
		setViewFrameBuffer(RENDERVIEW_VBLUR_0_ID, ctx.s_rtBlur)         --vblur
		setViewFrameBuffer(RENDERVIEW_HBLUR_0_ID, ctx.s_rtShadowMap[1]) --hblur
		setViewFrameBuffer(RENDERVIEW_VBLUR_1_ID, ctx.s_rtBlur)         --vblur
		setViewFrameBuffer(RENDERVIEW_HBLUR_1_ID, ctx.s_rtShadowMap[2]) --hblur
		setViewFrameBuffer(RENDERVIEW_VBLUR_2_ID, ctx.s_rtBlur)         --vblur
		setViewFrameBuffer(RENDERVIEW_HBLUR_2_ID, ctx.s_rtShadowMap[3]) --hblur
		setViewFrameBuffer(RENDERVIEW_VBLUR_3_ID, ctx.s_rtBlur)         --vblur
		setViewFrameBuffer(RENDERVIEW_HBLUR_3_ID, ctx.s_rtShadowMap[4]) --hblur
	end

	-- Clear backbuffer at beginning.
	bgfx.set_view_clear(0, "CD", 0, 1, 0)
	bgfx.touch(0)

	-- Clear shadowmap rendertarget at beginning.
	local flags0 = settings.lightType == "DirectionalLight" and "" or "CDS"

	bgfx.set_view_clear(RENDERVIEW_SHADOWMAP_0_ID, flags0
								, 0xfefefefe --blur fails on completely white regions
							   , 1
							   , 0
							   )
	bgfx.touch(RENDERVIEW_SHADOWMAP_0_ID)

	local flags1 = settings.lightType == "DirectionalLight" and "CD" or ""

	for i = 0 , 3 do
		bgfx.set_view_clear(RENDERVIEW_SHADOWMAP_1_ID+i , flags1
								   , 0xfefefefe -- blur fails on completely white regions
								   , 1
								   , 0
								   )
		bgfx.touch(RENDERVIEW_SHADOWMAP_1_ID+i)
	end

	local progDraw_id = assert(Programs[settings.progDraw], settings.progDraw)
	local progPack_id = assert(Programs[settings.progPack], settings.progPack)
	-- Render.
	-- Craft shadow map.
	do
		-- Craft stencil mask for point light shadow map packing.
		if settings.lightType == "PointLight" and settings.stencilPack then
			ctx.postb:alloc(6, ctx.posDecl)
			local min = 0.0
			local max = 1
			local center = 0.5
			local zz = 0

			ctx.postb:packV(0, min, min, zz)
			ctx.postb:packV(1, max, min, zz)
			ctx.postb:packV(2, center, center, zz)
			ctx.postb:packV(3, center, center, zz)
			ctx.postb:packV(4, max, max, zz)
			ctx.postb:packV(5, min, max, zz)

			bgfx.set_state(ctx.black_state)
			bgfx.set_stencil(ctx.black_stencil)

			ctx.postb:set()
			bgfx.submit(RENDERVIEW_SHADOWMAP_0_ID, Programs.black)
		end

		-- Draw scene into shadowmap.
		local drawNum

		if settings.lightType == "SpotLight" then
			drawNum = 1
		elseif settings.lightType == "PointLight" then
			drawNum = 4
		else -- LightType::DirectionalLight == settings.m_lightType)
			drawNum = settings.numSplits
		end

		for i = 1, drawNum do
			local viewId = RENDERVIEW_SHADOWMAP_1_ID + i - 1

			local renderStateIndex = "ShadowMap_PackDepth"
			if settings.lightType == "PointLight" and settings.stencilPack then
				renderStateIndex = i <=2 and "ShadowMap_PackDepthHoriz" or "ShadowMap_PackDepthVert"
			end

			-- Floor.
			submitShadowMesh(ctx.m_hplaneMesh, viewId, mtxFloor, progPack_id, s_renderState[renderStateIndex])

			-- Bunny.
			submitShadowMesh(ctx.m_bunnyMesh, viewId, mtxBunny, progPack_id, s_renderState[renderStateIndex])

			-- Hollow cube.
			submitShadowMesh(ctx.m_hollowcubeMesh, viewId, mtxHollowcube, progPack_id, s_renderState[renderStateIndex])

			-- Cube.
			submitShadowMesh(ctx.m_cubeMesh, viewId, mtxCube, progPack_id, s_renderState[renderStateIndex])

			-- Trees.
			for j = 1, numTrees do
				submitShadowMesh(ctx.m_treeMesh, viewId, mtxTrees[j], progPack_id, s_renderState[renderStateIndex])
			end
		end

		local depthType = settings.smImpl == "VSM" and "VSM" or "RGBA"
		local bVsmOrEsm = settings.smImpl == "VSM" or settings.smImpl == "ESM"

		-- Blur shadow map.
		if bVsmOrEsm and settings.doBlur then
			bgfx.set_texture(4, ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtShadowMap[1]))
			bgfx.set_state(ctx.state_rgba)
			screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
			bgfx.submit(RENDERVIEW_VBLUR_0_ID, Programs["vblur_" .. depthType])

			bgfx.set_texture(4,ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtBlur) )
			bgfx.set_state(ctx.state_rgba)
			screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
			bgfx.submit(RENDERVIEW_HBLUR_0_ID, Programs["hblur_" .. depthType])

			if settings.lightType == "DirectionalLight" then
				local j = 0
				for i = 2, settings.numSplits do
					j = j + 2
					local viewId = RENDERVIEW_VBLUR_0_ID + j

					bgfx.set_texture(4, ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtShadowMap[i]) )
					bgfx.set_state(ctx.state_rgba)
					screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
					bgfx.submit(viewId, Programs["vblur_" .. depthType])

					bgfx.set_texture(4,ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtBlur) )
					bgfx.set_state(ctx.state_rgba)
					screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
					bgfx.submit(viewId+1, Programs["hblur_" .. depthType])
				end
			end
		end

		-- Draw scene.

		local mtxShadow = math3d.matrix()
		local ymul = ctx.s_flipV and 0.5 or -0.5
		local zadd = settings.depthImpl == "Linear" and 0 or 0.5
		local mtxBias = math3d.matrix():pack(
					0.5, 0.0, 0.0, 0.0,
					0.0, ymul, 0.0, 0.0,
					0.0, 0.0, 0.5, 0.0,
					0.5, 0.5, zadd, 1.0
				)
		if settings.lightType == "SpotLight" then
			local mtxTmp = math3d.matrix():mul(lightProj[1], mtxBias)
			mtxShadow:mul(lightView[1], mtxTmp) -- lightViewProjBias
		elseif settings.lightType == "PointLight" then
			local s = ymul * 2 -- (s_flipV) ? 1.0f : -1.0f; //sign
			--		zadd = (DepthImpl::Linear == m_settings.m_depthImpl) ? 0.0f : 0.5f;
			if not settings.stencilPack then
				-- D3D: Green, OGL: Blue
				math3d.matrix(1,mtxCropBias):pack(
					0.25,    0.0, 0.0, 0.0,
				 0.0, s*0.25, 0.0, 0.0,
				 0.0,    0.0, 0.5, 0.0,
					0.25,   0.25, zadd, 1.0
				)
				-- D3D: Yellow, OGL: Red
				math3d.matrix(2,mtxCropBias):pack(
					0.25,    0.0, 0.0, 0.0,
				 0.0, s*0.25, 0.0, 0.0,
				 0.0,    0.0, 0.5, 0.0,
					0.75,   0.25, zadd, 1.0
				)
				-- D3D: Blue, OGL: Green
				math3d.matrix(3,mtxCropBias):pack(
						0.25,    0.0, 0.0, 0.0,
					 0.0, s*0.25, 0.0, 0.0,
					 0.0,    0.0, 0.5, 0.0,
						0.25,   0.75, zadd, 1.0
				)
				-- D3D: Red, OGL: Yellow
				math3d.matrix(4,mtxCropBias):pack(
						0.25,    0.0, 0.0, 0.0,
					 0.0, s*0.25, 0.0, 0.0,
					 0.0,    0.0, 0.5, 0.0,
						0.75,   0.75, zadd, 1.0
				)
			else
				-- D3D: Red, OGL: Blue
				math3d.matrix(1,mtxCropBias):pack(
						0.25,   0.0, 0.0, 0.0,
					 0.0, s*0.5, 0.0, 0.0,
					 0.0,   0.0, 0.5, 0.0,
						0.25,   0.5, zadd, 1.0
					)
				-- D3D: Blue, OGL: Red
				math3d.matrix(2,mtxCropBias):pack(
						0.25,   0.0, 0.0, 0.0,
					 0.0, s*0.5, 0.0, 0.0,
					 0.0,   0.0, 0.5, 0.0,
						0.75,   0.5, zadd, 1.0
					)
				-- D3D: Green, OGL: Green
				math3d.matrix(3,mtxCropBias):pack(
					0.5,    0.0, 0.0, 0.0,
					0.0, s*0.25, 0.0, 0.0,
					0.0,    0.0, 0.5, 0.0,
					0.5,   0.75, zadd, 1.0
					)
				-- D3D: Yellow, OGL: Yellow
				math3d.matrix(4,mtxCropBias):pack(
					0.5,    0.0, 0.0, 0.0,
					0.0, s*0.25, 0.0, 0.0,
					0.0,    0.0, 0.5, 0.0,
					0.5,   0.25, zadd, 1.0
					)
			end

			for i = 1, 4 do
				local projType
				if settings.stencilPack and i>2 then
					projType = 2
				else
					projType = 1 -- ProjType::Horizontal
				end
				local biasIndex = ctx.cropBiasIndices[settings.stencilPack][ctx.s_flipV][i]
				local mtxTmp = math3d.matrix():mul(mtxYpr[i], lightProj[projType])
				ctx.m_shadowMapMtx[i]:mul(mtxTmp, mtxCropBias[biasIndex])	-- mtxYprProjBias
			end

			-- lightInvTranslate
			local vx,vy,vz = ctx.m_pointLight.position:unpack()
			mtxShadow:transmat(-vx,-vy,-vz)
		else -- //LightType::DirectionalLight == settings.m_lightType
			for i = 1, settings.numSplits do
				local mtxTmp = math3d.matrix()
				mtxTmp:mul(lightProj[i], mtxBias)
				ctx.m_shadowMapMtx[i]:mul(lightView[1], mtxTmp)
			end
		end

		-- Floor.
		local m_lightMtx = math3d.matrix "m_lightMtx"
		local notdirectional = settings.lightType ~= "DirectionalLight"
		if notdirectional then
			m_lightMtx:mul(mtxFloor, mtxShadow) -- not needed for directional light
		end

		submitShadowMesh(ctx.m_hplaneMesh, RENDERVIEW_DRAWSCENE_0_ID, mtxFloor, progDraw_id, s_renderState.Default, nil, true)

		-- Bunny.
		if notdirectional then
			m_lightMtx:mul(mtxBunny, mtxShadow)
		end

		submitShadowMesh(ctx.m_bunnyMesh, RENDERVIEW_DRAWSCENE_0_ID, mtxBunny, progDraw_id, s_renderState.Default, nil, true)

		-- Hollow cube.
		if notdirectional then
			m_lightMtx:mul(mtxHollowcube, mtxShadow)
		end

		submitShadowMesh(ctx.m_hollowcubeMesh, RENDERVIEW_DRAWSCENE_0_ID, mtxHollowcube, progDraw_id, s_renderState.Default, nil, true)

		-- Cube.
		if notdirectional then
			m_lightMtx:mul(mtxCube, mtxShadow)
		end

		submitShadowMesh(ctx.m_cubeMesh, RENDERVIEW_DRAWSCENE_0_ID, mtxCube, progDraw_id, s_renderState.Default, nil, true)

		-- Trees.
		for i = 1, numTrees do
			if notdirectional then
				m_lightMtx:mul(mtxTrees[i], mtxShadow)
			end

			submitShadowMesh(ctx.m_treeMesh, RENDERVIEW_DRAWSCENE_0_ID, mtxTrees[i], progDraw_id, s_renderState.Default, nil, true)
		end

		-- Lights.
		if settings.lightType == "SpotLight" or settings.lightType == "PointLight" then
			--	const float lightScale[3] = { 1.5f, 1.5f, 1.5f };
			local mtx = math3d.matrix()
			mtxBillboard(mtx, view, ctx.m_pointLight.position , 1.5,1.5,1.5)
			submitShadowMesh(ctx.m_vplaneMesh, RENDERVIEW_DRAWSCENE_0_ID,
				mtx,
				Programs.colorTexture,
				s_renderState.Custom_BlendLightTexture,
				ctx.m_texFlare
			)
		end

		-- Draw floor bottom.
		local floorBottomMtx = math3d.matrix():srt(
			floorScale, floorScale, floorScale,	--scale
			0,0,0,
			0,-0.1,0)

		submitShadowMesh(ctx.m_hplaneMesh, RENDERVIEW_DRAWSCENE_1_ID
			, floorBottomMtx
			, Programs.texture
			, s_renderState.Custom_DrawPlaneBottom
			, ctx.m_texFigure
		)

		-- Draw depth rect.
		if settings.drawDepthBuffer then
			bgfx.set_texture(4, ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtShadowMap[1]) )
			bgfx.set_state(ctx.state_rgba)
			screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
			bgfx.submit(RENDERVIEW_DRAWDEPTH_0_ID, Programs["drawDepth_" .. depthType])

			if settings.lightType == "DirectionalLight" then
				for i = 2, settings.numSplits do
					bgfx.set_texture(4, ctx.s_shadowMap[1], bgfx.get_texture(ctx.s_rtShadowMap[i]) )
					bgfx.set_state(ctx.state_rgba)
					screenSpaceQuad(m_currentShadowMapSize, m_currentShadowMapSize, ctx.s_flipV)
					bgfx.submit(RENDERVIEW_DRAWDEPTH_0_ID+i-1, Programs["drawDepth_" ..depthType])
				end
			end
		end

		-- Update render target size.
		local bLtChanged = ctx.lightType ~= settings.lightType
		ctx.lightType = settings.lightType
		local shadowMapSize = 1 << settings.sizePwrTwo

		if bLtChanged or m_currentShadowMapSize ~= shadowMapSize then
			ctx.m_currentShadowMapSize = shadowMapSize
			local fbtextures = {}
			do
				bgfx.destroy(ctx.s_rtShadowMap[1])

				fbtextures[1] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "BGRA8", "rt")
				fbtextures[2] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "D24S8", "rt")
				ctx.s_rtShadowMap[1] = bgfx.create_frame_buffer(fbtextures, true)
			end

			if settings.lightType == "DirectionalLight" then
				for i = 2, 4 do
					bgfx.destroy(ctx.s_rtShadowMap[i])
					fbtextures[1] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "BGRA8", "rt")
					fbtextures[2] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "D24S8", "rt")
					ctx.s_rtShadowMap[i] = bgfx.create_frame_buffer(fbtextures, true)
				end
			end

			bgfx.destroy(ctx.s_rtBlur)
			ctx.s_rtBlur = bgfx.create_frame_buffer(shadowMapSize, shadowMapSize, "BGRA8")
		end
	end

	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}
--	bgfx.set_debug "ST"

	local renderer = ant.caps.rendererType
	if renderer == "DIRECT3D9" then
		ctx.s_texelHalf = 0.5
	else
		ctx.s_texelHalf = 0
	end
	ctx.s_flipV = (renderer == "OPENGL" or renderer == "OPENGLES")

	init_Uniforms()

	ctx.s_texColor = bgfx.create_uniform("s_texColor",  "i1")
	ctx.s_shadowMap = {
		bgfx.create_uniform("s_shadowMap0", "i1"),
		bgfx.create_uniform("s_shadowMap1", "i1"),
		bgfx.create_uniform("s_shadowMap2", "i1"),
		bgfx.create_uniform("s_shadowMap3", "i1"),
	}

	init_Programs()

	ctx.PosNormalTexcoordDecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "NORMAL", 4, "UINT8", true, true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}

	ctx.PosColorTexCoord0Vertex = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
		{ "TEXCOORD0", 2, "FLOAT" },
	}

	ctx.color_tb = bgfx.transient_buffer "fffdff"

	ctx.posDecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
	}

	ctx.postb = bgfx.transient_buffer "fff"
	ctx.black_state = bgfx.make_state {}
	ctx.black_stencil = bgfx.make_stencil {
				TEST = "ALWAYS",
				FUNC_REF = 1,
				FUNC_RMASK = 0xff,
				OP_FAIL_S = "REPLACE",
				OP_FAIL_Z = "REPLACE",
				OP_PASS_Z = "REPLACE",
			}

	-- Textures.
	ctx.m_texFigure = util.textureLoad "textures/figure-rgba.dds"
	ctx.m_texFlare = util.textureLoad "textures/flare.dds"
	ctx.m_texFieldstone = util.textureLoad "textures/fieldstone-rgba.dds"

	-- Meshes.
	ctx.m_bunnyMesh = util.meshLoad "meshes/bunny.bin"
	ctx.m_treeMesh = util.meshLoad "meshes/tree.bin"
	ctx.m_cubeMesh = util.meshLoad "meshes/cube.bin"
	ctx.m_hollowcubeMesh = util.meshLoad "meshes/hollowcube.bin"

	local function mesh(vb, ib)
		local g = {}
		g.vb = bgfx.create_vertex_buffer(vb, ctx.PosNormalTexcoordDecl)
		g.ib = bgfx.create_index_buffer(ib)

		return { group = { g } }
	end

	local encodeNormalRgba8 = bgfxu.encodeNormalRgba8

	local s_texcoord = 5.0

	local s_hplaneVertices = {
		"fffdff",
		-1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0), s_texcoord, s_texcoord,
		 1.0, 0.0,  1.0, encodeNormalRgba8(0.0, 1.0, 0.0), s_texcoord, 0.0      ,
		-1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0), 0.0,       s_texcoord,
		 1.0, 0.0, -1.0, encodeNormalRgba8(0.0, 1.0, 0.0), 0.0,       0.0      ,
	}
	local s_vplaneVertices = {
		"fffdff",
	 -1.0,  1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 1.0, 1.0 ,
	  1.0,  1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 1.0, 0.0 ,
	 -1.0, -1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 0.0, 1.0 ,
	  1.0, -1.0, 0.0, encodeNormalRgba8(0.0, 0.0, -1.0), 0.0, 0.0 ,
	}
	local s_planeIndices = {
		0, 1, 2,
		1, 3, 2,
	}
	ctx.m_hplaneMesh = mesh(s_hplaneVertices, s_planeIndices)
	ctx.m_vplaneMesh = mesh(s_vplaneVertices, s_planeIndices)

	-- Materials.

	ctx.m_defaultMaterial = {}
	math3d.vector("ambient", ctx.m_defaultMaterial):pack(1,1,1,0)
	math3d.vector("diffuse", ctx.m_defaultMaterial):pack(1,1,1,0)
	math3d.vector("specular", ctx.m_defaultMaterial):pack(1,1,1,0)

	-- Lights.
	ctx.m_pointLight = {}
	math3d.vector("position", ctx.m_pointLight):pack(0,0,0,1)
	math3d.vector("position_viewSpace", ctx.m_pointLight):pack(0,0,0,0)
	math3d.vector("ambient", ctx.m_pointLight):pack(1,1,1,0)
	math3d.vector("diffuse", ctx.m_pointLight):pack(1,1,1,850)
	math3d.vector("specular", ctx.m_pointLight):pack(1,1,1,0)
	math3d.vector("spotdirection", ctx.m_pointLight):pack(0,-0.4,-0.6,1)
	math3d.vector("spotdirection_viewSpace", ctx.m_pointLight):pack(0,0,0,0)
	math3d.vector("attenuation", ctx.m_pointLight):pack(1,1,1,91)


	ctx.m_directionalLight = {}
	math3d.vector("position", ctx.m_directionalLight):pack(0.5,-1,0.1,0)
	math3d.vector("position_viewSpace", ctx.m_directionalLight):pack(0,0,0,0)
	math3d.vector("ambient", ctx.m_directionalLight):pack(1,1,1,0.02)
	math3d.vector("diffuse", ctx.m_directionalLight):pack(1,1,1,0.4)
	math3d.vector("specular", ctx.m_directionalLight):pack(1,1,1,0)
	math3d.vector("spotdirection", ctx.m_directionalLight):pack(0,0,0,1)
	math3d.vector("spotdirection_viewSpace", ctx.m_directionalLight):pack(0,0,0,0)
	math3d.vector("attenuation", ctx.m_directionalLight):pack(0,0,0,1)

	local c = math3d.vector("m_color"):pack(1,1,1,1)

	ctx.m_shadowMapMtx = {}

	Uniforms.materialPtr = ctx.m_defaultMaterial
	Uniforms.lightPtr = ctx.m_pointLight
	Uniforms.colorPtr = c
	Uniforms.lightMtxPtr = math3d.matrix "m_lightMtx"
	Uniforms.shadowMapMtx0 = math3d.matrix(1, ctx.m_shadowMapMtx)
	Uniforms.shadowMapMtx1 = math3d.matrix(2, ctx.m_shadowMapMtx)
	Uniforms.shadowMapMtx2 = math3d.matrix(3, ctx.m_shadowMapMtx)
	Uniforms.shadowMapMtx3 = math3d.matrix(4, ctx.m_shadowMapMtx)

	submitConstUniforms()

	-- Render targets.
	local shadowMapSize = 1 << settings.sizePwrTwo
	ctx.m_currentShadowMapSize = shadowMapSize
	Uniforms.shadowMapTexelSize = 1 / shadowMapSize

	ctx.s_rtShadowMap = {}

	local fbtextures = {}
	for i=1,4 do
		fbtextures[1] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "BGRA8", "rt")
		fbtextures[2] = bgfx.create_texture2d(shadowMapSize, shadowMapSize, false, 1, "D24S8", "rt")
		ctx.s_rtShadowMap[i] = bgfx.create_frame_buffer(fbtextures, true)
	end
	ctx.s_rtBlur = bgfx.create_frame_buffer(shadowMapSize, shadowMapSize, "BGRA8")

	ctx.m_timeAccumulatorLight = 0
	ctx.m_timeAccumulatorScene = 0

	ctx.cropBiasIndices = {}
	ctx.cropBiasIndices[false] = { -- settings.m_stencilPack == false
		[false] = { 1, 2, 3, 4 },	-- flipV == false
		[true] = { 3, 4, 1, 2 },
	}
	ctx.cropBiasIndices[true] = {
		[false] = { 4, 3, 1, 2 },
		[true] = { 3, 4, 1, 2 },
	}

	ctx.state_rgba = bgfx.make_state {
		WRITE_MASK = "RGBA",
	}

	update_default_settings()

	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	ctx.width = w
	ctx.height = h
	bgfx.reset(ctx.width,ctx.height, "v")
	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp(0,30,-60, 0,5,0)
	projmat:projmat(60, ctx.width/ctx.height, 0.1, 2000)

	ctx.projHeight = math.tan(math.rad(60)*0.5)
	ctx.projWidth = ctx.projHeight * (ctx.width/ctx.height)
end

function canvas:action(x,y)
	mainloop()
end

-----------------------------------------------

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
  -- todo: destory resources
  ant.shutdown()
end
