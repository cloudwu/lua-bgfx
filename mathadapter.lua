local bgfx = require "bgfx"
local math3d = require "math3d"
local adapter = require "math3d.adapter"

bgfx.alloc_transform = adapter.matrix(bgfx.alloc_transform, 1, 0)
bgfx.set_transform = adapter.matrix(bgfx.set_transform, 1, 0)
bgfx.set_view_transform = adapter.matrix(bgfx.set_view_transform, 2, 2)
bgfx.set_uniform = adapter.variant(bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
bgfx.set_uniform_command = adapter.variant(bgfx.set_uniform_matrix_command, bgfx.set_uniform_vector_command, 2)
local idb = bgfx.instance_buffer_metatable()
idb.pack = adapter.format(idb.pack, idb.format, 3)
idb.__call = idb.pack
