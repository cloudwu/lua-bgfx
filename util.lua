-- A util library for bgfx examples

local util = {}

local bgfx = require "bgfx"
local math3d = require "math3d"
local adapter = require "mathadapter"

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

local function save_screenshot(filename)
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

local shader_path

local function init_shader_path(caps)
	local path = {
		NOOP       = "dx9",
		DIRECT3D9  = "dx9",
		DIRECT3D11 = "dx11",
		DIRECT3D12 = "dx11",
		GNM        = "pssl",
		METAL      = "metal",
		OPENGL     = "glsl",
		OPENGLES   = "essl",
		VULKAN     = "spirv",
	}
	shader_path = "shaders/".. (assert(path[caps.rendererType])) .."/"
end

do
	local function load_shader(name)
		local filename = shader_path .. name .. ".bin"
		local f = assert(io.open(filename, "rb"))
		local data = f:read "a"
		f:close()
		local h = bgfx.create_shader(data)
		bgfx.set_name(h, filename)
		return h
	end

	local function load_shader_uniforms(name)
		local h = load_shader(name)
		local uniforms = bgfx.get_shader_uniforms(h)
		return h, uniforms
	end

	local function uniform_info(uniforms, handles)
		for _, h in ipairs(handles) do
			local name, type, num = bgfx.get_uniform_info(h)
			if uniforms[name] == nil then
				uniforms[name] = { handle = h, name = name, type = type, num = num }
			end
		end
	end

	local function programLoadEx(vs,fs, uniform)
		local vsid, u1 = load_shader_uniforms(vs)
		local fsid, u2
		if fs then
			fsid, u2 = load_shader_uniforms(fs)
		end
		uniform_info(uniform, u1)
		if u2 then
			uniform_info(uniform, u2)
		end
		return bgfx.create_program(vsid, fsid, true), uniform
	end

	function util.programLoad(vs,fs, uniform)
		if uniform then
			return programLoadEx(vs,fs, uniform)
		else
			local vsid = load_shader(vs)
			local fsid = fs and load_shader(fs)
			return bgfx.create_program(vsid, fsid, true)
		end
	end

	function util.computeLoad(cs)
		local csid = load_shader(cs)
		return bgfx.create_program(csid, true)
	end

	function util.shaderLoad(s)
		return load_shader(s)
	end
end

do
	local mesh_decode = {}
	local vb_header = "<" .. string.rep("f", 4+6+16)
--	local vb_data = { "!", "", nil, nil }
--	local ib_data = { "", nil, nil }

	local function read_mesh_header(group, data, offset)
		local tmp = { string.unpack(vb_header, data, offset) }
		group.sphere = { table.unpack(tmp,1,4) }
		group.aabb = { table.unpack(tmp,5,10) }
		group.obb = { table.unpack(tmp,11,26) }
		return tmp[27]
	end

	mesh_decode["VB \1"] = function(mesh, group, data, offset)
		offset = read_mesh_header(mesh, data, offset)
		local stride, numVertices
		mesh.vdecl, stride, offset = bgfx.vertex_layout(data, offset)
		numVertices, offset = string.unpack("<I2", data, offset)
		local size = stride * numVertices
		local vb_data = bgfx.memory_buffer(data, offset, size)
		group.vb = bgfx.create_vertex_buffer(vb_data, mesh.vdecl)
		return offset + size
	end

	mesh_decode["IB \0"] = function(mesh, group, data, offset)
		local numIndices
		numIndices, offset = string.unpack("<I4", data, offset)
		local size = numIndices * 2
		local ib_data = bgfx.memory_buffer(data, offset, size)
		group.ib = bgfx.create_index_buffer(ib_data)
		return offset + size
	end

	mesh_decode["IBC\0"] = function(mesh, group, data, offset)
		error "Unsupport Compressed IB"
	end

	mesh_decode["PRI\0"] = function(mesh, group, data, offset)
		local material, num
		material, num, offset = string.unpack("<s2I2", data, offset)	-- no used
		group.prim = {}
		for i=1,num do
			local p = {}
			p.name, p.startIndex, p.numIndices, p.startVertex, p.numVertices, offset = string.unpack("<s2I4I4I4I4", data, offset)
			offset = read_mesh_header(p, data, offset)
			table.insert(group.prim, p)
		end
		local tmp = {}
		for k,v in pairs(group) do
			group[k] = nil
			tmp[k] = v
		end
		table.insert(mesh.group, tmp)
		return offset
	end

	function util.meshLoad(filename)
		local f = assert(io.open(filename,"rb"))
		local data = f:read "a"
		f:close()
		local mesh = { group = {} }
		local offset = 1
		local group = {}
		while true do
			local tag = data:sub(offset, offset+3)
			if tag == "" then
				break
			end
			local decoder = mesh_decode[tag]
			if not decoder then
				error ("Invalid tag " .. tag)
			end
			offset = decoder(mesh, group, data, offset + 4)
		end

		return mesh
	end
end

function util.meshUnload(mesh)
	for _,group in ipairs(mesh.group) do
		bgfx.destroy(group.ib)
		bgfx.destroy(group.vb)
	end
end

function util.meshSubmit(mesh, id, prog)
	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(id, prog, 0, i ~= n and "" or "ivs")
	end
end

function util.meshSubmitState(mesh, state, mtx)
	bgfx.set_transform(mtx)
	bgfx.set_state(state.state)

	for _, texture in ipairs(state.textures) do
		bgfx.set_texture(texture.stage,texture.sampler,texture.texture,texture.flags)
	end

	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(state.viewId, state.program, 0, i ~= n and "" or "ivs")
	end
end

function util.textureLoad(filename, info)
	local f = assert(io.open(filename, "rb"))
	local imgdata = f:read "a"
	f:close()
	local h = bgfx.create_texture(imgdata, info)
	bgfx.set_name(h, filename)
	return h
end

local function use_iup()
	local init_flag

	local iup = require "iuplua"

	function util.init(args)
		local canvas = assert(args.canvas)
		local function init()
			bgfx.init {
				renderer = args.renderer,
				format = args.format,
				width = args.width,
				height = args.height,
				reset = args.reset,
				debug = args.debug,
				profile = args.profile,
				pushlog = args.pushlog,
				pushlog_context = args.pushlog_context,
				loglevel = args.loglevel,
				numBackBuffers = args.numBackBuffers,
				maxFrameLatency = args.maxFrameLatency,
				debugTextScale = args.debugTextScale,

				-- platform data
				ndt = args.ndt,
				nwh = iup.GetAttributeData(canvas,"HWND"),
				context = args.context,
				backBuffer = args.backBuffer,
				backBufferDS = args.backBufferDS,
			}
			util.caps = bgfx.get_caps()
			math3d.set_homogeneous_depth(util.caps.homogeneousDepth)
			init_shader_path(util.caps)
			init_flag = true
			bgfx.set_debug "T"
		end

		function canvas:resize_cb(w,h)
			if init_flag == nil then
				init()
				if args.init then
					args.init(w,h)
				end
				init_flag = true
			end
			if args.resize then
				args.resize(w,h)
			end
		end

		local debug

		function canvas:keypress_cb(key, press)
			if press == 0 then
				return
			end
			if key ==  iup.K_F1 then
				debug = not debug
				bgfx.set_debug(debug and "ST" or "T")
			elseif key == iup.K_F12 then
				bgfx.request_screenshot()
			end
		end
	end

	function util.run(f)
		iup.SetIdle(function ()
			assert(init_flag)
			save_screenshot "screenshot.ppm"
			local ok , err = xpcall(f, debug.traceback)
			if not ok then
				print(err)
				iup.SetIdle()
			end
			return iup.DEFAULT
		end)

		iup.MainLoop()
		iup.Close()
		if init_flag then
			bgfx.shutdown()
		end
	end
end

local function use_sdl()
	local init_flag

	local sdl = require "sdlwnd"

	local EVENT = {}

	function util.init(args)
		sdl.init(args)

		local function init()
			-- prevent creation of a renderer thread
			bgfx.set_platform_data {
				nwh = sdl.handle()
			}
			bgfx.render_frame()
			bgfx.init {
				renderer = args.renderer,
				format = args.format,
				width = args.width,
				height = args.height,
				reset = args.reset,
				debug = args.debug,
				profile = args.profile,
				pushlog = args.pushlog,
				pushlog_context = args.pushlog_context,
				loglevel = args.loglevel,
				numBackBuffers = args.numBackBuffers,
				maxFrameLatency = args.maxFrameLatency,

				-- platform data
				ndt = args.ndt,
				nwh = sdl.handle(),
				context = args.context,
				backBuffer = args.backBuffer,
				backBufferDS = args.backBufferDS,
			}
			util.caps = bgfx.get_caps()
			math3d.set_homogeneous_depth(util.caps.homogeneousDepth)
			init_shader_path(util.caps)
			init_flag = true
			bgfx.set_debug "T"
		end

		init()
		if args.init then
			args.init()
		end
		EVENT.RESIZE = args.resize
	end

	function EVENT.QUIT()
		return true
	end

	do
		local debug

		function EVENT.KEY(key, press)
			if not press then
				return
			end
			if key == "F1" then
				debug = not debug
				bgfx.set_debug(debug and "ST" or "T")
			elseif key == "F12" then
				bgfx.request_screenshot()
			end
		end
	end

	function EVENT.MOTION(x, y)
	end

	function EVENT.BUTTON(x, y, button, pressed, click)
	end

	local function dispatch(name, ...)
		if name then
			return not EVENT[name](...)
		else
			return true
		end
	end

	function util.run(f)
		while dispatch(sdl.event()) do
			save_screenshot "screenshot.ppm"
			local ok , err = xpcall(f, debug.traceback)
			if not ok then
				print(err)
				break
			end
			sdl.frame()
		end
		bgfx.shutdown()
	end
end

if SDL then
	use_sdl()
else
	use_iup()
end

return util
