local ant = require "ant"
local util = require "ant.util"
local math3d = require "ant.math"
local bgfx = require "bgfx"

canvas = iup.canvas{}

dlg = iup.dialog {
  canvas,
  title = "02-metaballs",
  size = "HALFxHALF",
}

local s_edges = {
	0x000, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
	0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
	0x190, 0x099, 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
	0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
	0x230, 0x339, 0x033, 0x13a, 0x636, 0x73f, 0x435, 0x53c,
	0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
	0x3a0, 0x2a9, 0x1a3, 0x0aa, 0x7a6, 0x6af, 0x5a5, 0x4ac,
	0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
	0x460, 0x569, 0x663, 0x76a, 0x66 , 0x16f, 0x265, 0x36c,
	0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
	0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0x0ff, 0x3f5, 0x2fc,
	0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
	0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x055, 0x15c,
	0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
	0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0x0cc,
	0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
	0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
	0x0cc, 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
	0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
	0x15c, 0x55 , 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
	0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
	0x2fc, 0x3f5, 0x0ff, 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
	0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
	0x36c, 0x265, 0x16f, 0x066, 0x76a, 0x663, 0x569, 0x460,
	0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
	0x4ac, 0x5a5, 0x6af, 0x7a6, 0x0aa, 0x1a3, 0x2a9, 0x3a0,
	0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
	0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x033, 0x339, 0x230,
	0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
	0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x099, 0x190,
	0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
	0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x000,
}

local s_indices = {
	{},
	{   0,  8,  3,  },
	{   0,  1,  9,  },
	{   1,  8,  3,  9,  8,  1,  },
	{   1,  2, 10 },
	{   0,  8,  3,  1,  2, 10 },
	{   9,  2, 10,  0,  2,  9 },
	{   2,  8,  3,  2, 10,  8, 10,  9,  8 },
	{   3, 11,  2 },
	{   0, 11,  2,  8, 11,  0 },
	{   1,  9,  0,  2,  3, 11 },
	{   1, 11,  2,  1,  9, 11,  9,  8, 11 },
	{   3, 10,  1, 11, 10,  3 },
	{   0, 10,  1,  0,  8, 10,  8, 11, 10 },
	{   3,  9,  0,  3, 11,  9, 11, 10,  9 },
	{   9,  8, 10, 10,  8, 11 },
	{   4,  7,  8 },
	{   4,  3,  0,  7,  3,  4 },
	{   0,  1,  9,  8,  4,  7 },
	{   4,  1,  9,  4,  7,  1,  7,  3,  1 },
	{   1,  2, 10,  8,  4,  7 },
	{   3,  4,  7,  3,  0,  4,  1,  2, 10 },
	{   9,  2, 10,  9,  0,  2,  8,  4,  7 },
	{   2, 10,  9,  2,  9,  7,  2,  7,  3,  7,  9,  4 },
	{   8,  4,  7,  3, 11,  2 },
	{  11,  4,  7, 11,  2,  4,  2,  0,  4 },
	{   9,  0,  1,  8,  4,  7,  2,  3, 11 },
	{   4,  7, 11,  9,  4, 11,  9, 11,  2,  9,  2,  1 },
	{   3, 10,  1,  3, 11, 10,  7,  8,  4 },
	{   1, 11, 10,  1,  4, 11,  1,  0,  4,  7, 11,  4 },
	{   4,  7,  8,  9,  0, 11,  9, 11, 10, 11,  0,  3 },
	{   4,  7, 11,  4, 11,  9,  9, 11, 10 },
	{   9,  5,  4 },
	{   9,  5,  4,  0,  8,  3 },
	{   0,  5,  4,  1,  5,  0 },
	{   8,  5,  4,  8,  3,  5,  3,  1,  5 },
	{   1,  2, 10,  9,  5,  4 },
	{   3,  0,  8,  1,  2, 10,  4,  9,  5 },
	{   5,  2, 10,  5,  4,  2,  4,  0,  2 },
	{   2, 10,  5,  3,  2,  5,  3,  5,  4,  3,  4,  8 },
	{   9,  5,  4,  2,  3, 11 },
	{   0, 11,  2,  0,  8, 11,  4,  9,  5 },
	{   0,  5,  4,  0,  1,  5,  2,  3, 11 },
	{   2,  1,  5,  2,  5,  8,  2,  8, 11,  4,  8,  5 },
	{  10,  3, 11, 10,  1,  3,  9,  5,  4 },
	{   4,  9,  5,  0,  8,  1,  8, 10,  1,  8, 11, 10 },
	{   5,  4,  0,  5,  0, 11,  5, 11, 10, 11,  0,  3 },
	{   5,  4,  8,  5,  8, 10, 10,  8, 11 },
	{   9,  7,  8,  5,  7,  9 },
	{   9,  3,  0,  9,  5,  3,  5,  7,  3 },
	{   0,  7,  8,  0,  1,  7,  1,  5,  7 },
	{   1,  5,  3,  3,  5,  7 },
	{   9,  7,  8,  9,  5,  7, 10,  1,  2 },
	{  10,  1,  2,  9,  5,  0,  5,  3,  0,  5,  7,  3 },
	{   8,  0,  2,  8,  2,  5,  8,  5,  7, 10,  5,  2 },
	{   2, 10,  5,  2,  5,  3,  3,  5,  7 },
	{   7,  9,  5,  7,  8,  9,  3, 11,  2 },
	{   9,  5,  7,  9,  7,  2,  9,  2,  0,  2,  7, 11 },
	{   2,  3, 11,  0,  1,  8,  1,  7,  8,  1,  5,  7 },
	{  11,  2,  1, 11,  1,  7,  7,  1,  5 },
	{   9,  5,  8,  8,  5,  7, 10,  1,  3, 10,  3, 11 },
	{   5,  7,  0,  5,  0,  9,  7, 11,  0,  1,  0, 10, 11, 10,  0 },
	{  11, 10,  0, 11,  0,  3, 10,  5,  0,  8,  0,  7,  5,  7,  0 },
	{  11, 10,  5,  7, 11,  5 },
	{  10,  6,  5 },
	{   0,  8,  3,  5, 10,  6 },
	{   9,  0,  1,  5, 10,  6 },
	{   1,  8,  3,  1,  9,  8,  5, 10,  6 },
	{   1,  6,  5,  2,  6,  1 },
	{   1,  6,  5,  1,  2,  6,  3,  0,  8 },
	{   9,  6,  5,  9,  0,  6,  0,  2,  6 },
	{   5,  9,  8,  5,  8,  2,  5,  2,  6,  3,  2,  8 },
	{   2,  3, 11, 10,  6,  5 },
	{  11,  0,  8, 11,  2,  0, 10,  6,  5 },
	{   0,  1,  9,  2,  3, 11,  5, 10,  6 },
	{   5, 10,  6,  1,  9,  2,  9, 11,  2,  9,  8, 11 },
	{   6,  3, 11,  6,  5,  3,  5,  1,  3 },
	{   0,  8, 11,  0, 11,  5,  0,  5,  1,  5, 11,  6 },
	{   3, 11,  6,  0,  3,  6,  0,  6,  5,  0,  5,  9 },
	{   6,  5,  9,  6,  9, 11, 11,  9,  8 },
	{   5, 10,  6,  4,  7,  8 },
	{   4,  3,  0,  4,  7,  3,  6,  5, 10 },
	{   1,  9,  0,  5, 10,  6,  8,  4,  7 },
	{  10,  6,  5,  1,  9,  7,  1,  7,  3,  7,  9,  4 },
	{   6,  1,  2,  6,  5,  1,  4,  7,  8 },
	{   1,  2,  5,  5,  2,  6,  3,  0,  4,  3,  4,  7 },
	{   8,  4,  7,  9,  0,  5,  0,  6,  5,  0,  2,  6 },
	{   7,  3,  9,  7,  9,  4,  3,  2,  9,  5,  9,  6,  2,  6,  9 },
	{   3, 11,  2,  7,  8,  4, 10,  6,  5 },
	{   5, 10,  6,  4,  7,  2,  4,  2,  0,  2,  7, 11 },
	{   0,  1,  9,  4,  7,  8,  2,  3, 11,  5, 10,  6 },
	{   9,  2,  1,  9, 11,  2,  9,  4, 11,  7, 11,  4,  5, 10,  6 },
	{   8,  4,  7,  3, 11,  5,  3,  5,  1,  5, 11,  6 },
	{   5,  1, 11,  5, 11,  6,  1,  0, 11,  7, 11,  4,  0,  4, 11 },
	{   0,  5,  9,  0,  6,  5,  0,  3,  6, 11,  6,  3,  8,  4,  7 },
	{   6,  5,  9,  6,  9, 11,  4,  7,  9,  7, 11,  9 },
	{  10,  4,  9,  6,  4, 10 },
	{   4, 10,  6,  4,  9, 10,  0,  8,  3 },
	{  10,  0,  1, 10,  6,  0,  6,  4,  0 },
	{   8,  3,  1,  8,  1,  6,  8,  6,  4,  6,  1, 10 },
	{   1,  4,  9,  1,  2,  4,  2,  6,  4 },
	{   3,  0,  8,  1,  2,  9,  2,  4,  9,  2,  6,  4 },
	{   0,  2,  4,  4,  2,  6 },
	{   8,  3,  2,  8,  2,  4,  4,  2,  6 },
	{  10,  4,  9, 10,  6,  4, 11,  2,  3 },
	{   0,  8,  2,  2,  8, 11,  4,  9, 10,  4, 10,  6 },
	{   3, 11,  2,  0,  1,  6,  0,  6,  4,  6,  1, 10 },
	{   6,  4,  1,  6,  1, 10,  4,  8,  1,  2,  1, 11,  8, 11,  1 },
	{   9,  6,  4,  9,  3,  6,  9,  1,  3, 11,  6,  3 },
	{   8, 11,  1,  8,  1,  0, 11,  6,  1,  9,  1,  4,  6,  4,  1 },
	{   3, 11,  6,  3,  6,  0,  0,  6,  4 },
	{   6,  4,  8, 11,  6,  8 },
	{   7, 10,  6,  7,  8, 10,  8,  9, 10 },
	{   0,  7,  3,  0, 10,  7,  0,  9, 10,  6,  7, 10 },
	{  10,  6,  7,  1, 10,  7,  1,  7,  8,  1,  8,  0 },
	{  10,  6,  7, 10,  7,  1,  1,  7,  3 },
	{   1,  2,  6,  1,  6,  8,  1,  8,  9,  8,  6,  7 },
	{   2,  6,  9,  2,  9,  1,  6,  7,  9,  0,  9,  3,  7,  3,  9 },
	{   7,  8,  0,  7,  0,  6,  6,  0,  2 },
	{   7,  3,  2,  6,  7,  2 },
	{   2,  3, 11, 10,  6,  8, 10,  8,  9,  8,  6,  7 },
	{   2,  0,  7,  2,  7, 11,  0,  9,  7,  6,  7, 10,  9, 10,  7 },
	{   1,  8,  0,  1,  7,  8,  1, 10,  7,  6,  7, 10,  2,  3, 11 },
	{  11,  2,  1, 11,  1,  7, 10,  6,  1,  6,  7,  1 },
	{   8,  9,  6,  8,  6,  7,  9,  1,  6, 11,  6,  3,  1,  3,  6 },
	{   0,  9,  1, 11,  6,  7 },
	{   7,  8,  0,  7,  0,  6,  3, 11,  0, 11,  6,  0 },
	{   7, 11,  6 },
	{   7,  6, 11 },
	{   3,  0,  8, 11,  7,  6 },
	{   0,  1,  9, 11,  7,  6 },
	{   8,  1,  9,  8,  3,  1, 11,  7,  6 },
	{  10,  1,  2,  6, 11,  7 },
	{   1,  2, 10,  3,  0,  8,  6, 11,  7 },
	{   2,  9,  0,  2, 10,  9,  6, 11,  7 },
	{   6, 11,  7,  2, 10,  3, 10,  8,  3, 10,  9,  8 },
	{   7,  2,  3,  6,  2,  7 },
	{   7,  0,  8,  7,  6,  0,  6,  2,  0 },
	{   2,  7,  6,  2,  3,  7,  0,  1,  9 },
	{   1,  6,  2,  1,  8,  6,  1,  9,  8,  8,  7,  6 },
	{  10,  7,  6, 10,  1,  7,  1,  3,  7 },
	{  10,  7,  6,  1,  7, 10,  1,  8,  7,  1,  0,  8 },
	{   0,  3,  7,  0,  7, 10,  0, 10,  9,  6, 10,  7 },
	{   7,  6, 10,  7, 10,  8,  8, 10,  9 },
	{   6,  8,  4, 11,  8,  6 },
	{   3,  6, 11,  3,  0,  6,  0,  4,  6 },
	{   8,  6, 11,  8,  4,  6,  9,  0,  1 },
	{   9,  4,  6,  9,  6,  3,  9,  3,  1, 11,  3,  6 },
	{   6,  8,  4,  6, 11,  8,  2, 10,  1 },
	{   1,  2, 10,  3,  0, 11,  0,  6, 11,  0,  4,  6 },
	{   4, 11,  8,  4,  6, 11,  0,  2,  9,  2, 10,  9 },
	{  10,  9,  3, 10,  3,  2,  9,  4,  3, 11,  3,  6,  4,  6,  3 },
	{   8,  2,  3,  8,  4,  2,  4,  6,  2 },
	{   0,  4,  2,  4,  6,  2 },
	{   1,  9,  0,  2,  3,  4,  2,  4,  6,  4,  3,  8 },
	{   1,  9,  4,  1,  4,  2,  2,  4,  6 },
	{   8,  1,  3,  8,  6,  1,  8,  4,  6,  6, 10,  1 },
	{  10,  1,  0, 10,  0,  6,  6,  0,  4 },
	{   4,  6,  3,  4,  3,  8,  6, 10,  3,  0,  3,  9, 10,  9,  3 },
	{  10,  9,  4,  6, 10,  4 },
	{   4,  9,  5,  7,  6, 11 },
	{   0,  8,  3,  4,  9,  5, 11,  7,  6 },
	{   5,  0,  1,  5,  4,  0,  7,  6, 11 },
	{  11,  7,  6,  8,  3,  4,  3,  5,  4,  3,  1,  5 },
	{   9,  5,  4, 10,  1,  2,  7,  6, 11 },
	{   6, 11,  7,  1,  2, 10,  0,  8,  3,  4,  9,  5 },
	{   7,  6, 11,  5,  4, 10,  4,  2, 10,  4,  0,  2 },
	{   3,  4,  8,  3,  5,  4,  3,  2,  5, 10,  5,  2, 11,  7,  6 },
	{   7,  2,  3,  7,  6,  2,  5,  4,  9 },
	{   9,  5,  4,  0,  8,  6,  0,  6,  2,  6,  8,  7 },
	{   3,  6,  2,  3,  7,  6,  1,  5,  0,  5,  4,  0 },
	{   6,  2,  8,  6,  8,  7,  2,  1,  8,  4,  8,  5,  1,  5,  8 },
	{   9,  5,  4, 10,  1,  6,  1,  7,  6,  1,  3,  7 },
	{   1,  6, 10,  1,  7,  6,  1,  0,  7,  8,  7,  0,  9,  5,  4 },
	{   4,  0, 10,  4, 10,  5,  0,  3, 10,  6, 10,  7,  3,  7, 10 },
	{   7,  6, 10,  7, 10,  8,  5,  4, 10,  4,  8, 10 },
	{   6,  9,  5,  6, 11,  9, 11,  8,  9 },
	{   3,  6, 11,  0,  6,  3,  0,  5,  6,  0,  9,  5 },
	{   0, 11,  8,  0,  5, 11,  0,  1,  5,  5,  6, 11 },
	{   6, 11,  3,  6,  3,  5,  5,  3,  1 },
	{   1,  2, 10,  9,  5, 11,  9, 11,  8, 11,  5,  6 },
	{   0, 11,  3,  0,  6, 11,  0,  9,  6,  5,  6,  9,  1,  2, 10 },
	{  11,  8,  5, 11,  5,  6,  8,  0,  5, 10,  5,  2,  0,  2,  5 },
	{   6, 11,  3,  6,  3,  5,  2, 10,  3, 10,  5,  3 },
	{   5,  8,  9,  5,  2,  8,  5,  6,  2,  3,  8,  2 },
	{   9,  5,  6,  9,  6,  0,  0,  6,  2 },
	{   1,  5,  8,  1,  8,  0,  5,  6,  8,  3,  8,  2,  6,  2,  8 },
	{   1,  5,  6,  2,  1,  6 },
	{   1,  3,  6,  1,  6, 10,  3,  8,  6,  5,  6,  9,  8,  9,  6 },
	{  10,  1,  0, 10,  0,  6,  9,  5,  0,  5,  6,  0 },
	{   0,  3,  8,  5,  6, 10 },
	{  10,  5,  6 },
	{  11,  5, 10,  7,  5, 11 },
	{  11,  5, 10, 11,  7,  5,  8,  3,  0 },
	{   5, 11,  7,  5, 10, 11,  1,  9,  0 },
	{  10,  7,  5, 10, 11,  7,  9,  8,  1,  8,  3,  1 },
	{  11,  1,  2, 11,  7,  1,  7,  5,  1 },
	{   0,  8,  3,  1,  2,  7,  1,  7,  5,  7,  2, 11 },
	{   9,  7,  5,  9,  2,  7,  9,  0,  2,  2, 11,  7 },
	{   7,  5,  2,  7,  2, 11,  5,  9,  2,  3,  2,  8,  9,  8,  2 },
	{   2,  5, 10,  2,  3,  5,  3,  7,  5 },
	{   8,  2,  0,  8,  5,  2,  8,  7,  5, 10,  2,  5 },
	{   9,  0,  1,  5, 10,  3,  5,  3,  7,  3, 10,  2 },
	{   9,  8,  2,  9,  2,  1,  8,  7,  2, 10,  2,  5,  7,  5,  2 },
	{   1,  3,  5,  3,  7,  5 },
	{   0,  8,  7,  0,  7,  1,  1,  7,  5 },
	{   9,  0,  3,  9,  3,  5,  5,  3,  7 },
	{   9,  8,  7,  5,  9,  7 },
	{   5,  8,  4,  5, 10,  8, 10, 11,  8 },
	{   5,  0,  4,  5, 11,  0,  5, 10, 11, 11,  3,  0 },
	{   0,  1,  9,  8,  4, 10,  8, 10, 11, 10,  4,  5 },
	{  10, 11,  4, 10,  4,  5, 11,  3,  4,  9,  4,  1,  3,  1,  4 },
	{   2,  5,  1,  2,  8,  5,  2, 11,  8,  4,  5,  8 },
	{   0,  4, 11,  0, 11,  3,  4,  5, 11,  2, 11,  1,  5,  1, 11 },
	{   0,  2,  5,  0,  5,  9,  2, 11,  5,  4,  5,  8, 11,  8,  5 },
	{   9,  4,  5,  2, 11,  3 },
	{   2,  5, 10,  3,  5,  2,  3,  4,  5,  3,  8,  4 },
	{   5, 10,  2,  5,  2,  4,  4,  2,  0 },
	{   3, 10,  2,  3,  5, 10,  3,  8,  5,  4,  5,  8,  0,  1,  9 },
	{   5, 10,  2,  5,  2,  4,  1,  9,  2,  9,  4,  2 },
	{   8,  4,  5,  8,  5,  3,  3,  5,  1 },
	{   0,  4,  5,  1,  0,  5 },
	{   8,  4,  5,  8,  5,  3,  9,  0,  5,  0,  3,  5 },
	{   9,  4,  5 },
	{   4, 11,  7,  4,  9, 11,  9, 10, 11 },
	{   0,  8,  3,  4,  9,  7,  9, 11,  7,  9, 10, 11 },
	{   1, 10, 11,  1, 11,  4,  1,  4,  0,  7,  4, 11 },
	{   3,  1,  4,  3,  4,  8,  1, 10,  4,  7,  4, 11, 10, 11,  4 },
	{   4, 11,  7,  9, 11,  4,  9,  2, 11,  9,  1,  2 },
	{   9,  7,  4,  9, 11,  7,  9,  1, 11,  2, 11,  1,  0,  8,  3 },
	{  11,  7,  4, 11,  4,  2,  2,  4,  0 },
	{  11,  7,  4, 11,  4,  2,  8,  3,  4,  3,  2,  4 },
	{   2,  9, 10,  2,  7,  9,  2,  3,  7,  7,  4,  9 },
	{   9, 10,  7,  9,  7,  4, 10,  2,  7,  8,  7,  0,  2,  0,  7 },
	{   3,  7, 10,  3, 10,  2,  7,  4, 10,  1, 10,  0,  4,  0, 10 },
	{   1, 10,  2,  8,  7,  4 },
	{   4,  9,  1,  4,  1,  7,  7,  1,  3 },
	{   4,  9,  1,  4,  1,  7,  0,  8,  1,  8,  7,  1 },
	{   4,  0,  3,  7,  4,  3 },
	{   4,  8,  7 },
	{   9, 10,  8, 10, 11,  8 },
	{   3,  0,  9,  3,  9, 11, 11,  9, 10 },
	{   0,  1, 10,  0, 10,  8,  8, 10, 11 },
	{   3,  1, 10, 11,  3, 10 },
	{   1,  2, 11,  1, 11,  9,  9, 11,  8 },
	{   3,  0,  9,  3,  9, 11,  1,  2,  9,  2, 11,  9 },
	{   0,  2, 11,  8,  0, 11 },
	{   3,  2, 11 },
	{   2,  3,  8,  2,  8, 10, 10,  8,  9 },
	{   9, 10,  2,  0,  9,  2 },
	{   2,  3,  8,  2,  8, 10,  0,  1,  8,  1, 10,  8 },
	{   1, 10,  2 },
	{   1,  3,  8,  9,  1,  8 },
	{   0,  9,  1 },
	{   0,  3,  8 },
	{  -1 },
}

local s_cube = {
	{ 0.0, 1.0, 1.0 },
	{ 1.0, 1.0, 1.0 },
	{ 1.0, 1.0, 0.0 },
	{ 0.0, 1.0, 0.0 },
	{ 0.0, 0.0, 1.0 },
	{ 1.0, 0.0, 1.0 },
	{ 1.0, 0.0, 0.0 },
	{ 0.0, 0.0, 0.0 },
}

local idx1_table = { 1,2,3,0,5,6,7,4,4,5,6,7}

local verts = {}
for i=1,16 do
	verts[i] = {}
end

local function vertLerp(result, iso, idx0, v0, idx1, v1)
	local edge0 = s_cube[idx0]
	local edge1 = s_cube[idx1]

	if math.abs(iso-v1) < 0.00001 then
		result[1] = edge1[1];
		result[2] = edge1[2];
		result[3] = edge1[3];
		return 1.0
	end

	if math.abs(iso-v0) < 0.00001
		or math.abs(v0-v1) < 0.00001 then
		result[1] = edge0[1]
		result[2] = edge0[2]
		result[3] = edge0[3]
		return 0.0
	end

	local lerp = (iso - v0) / (v1 - v0)
	result[1] = edge0[1] + lerp * (edge1[1] - edge0[1])
	result[2] = edge0[2] + lerp * (edge1[2] - edge0[2])
	result[3] = edge0[3] + lerp * (edge1[3] - edge0[3])

	return lerp
end

local function triangulate(tvb, offset, rgb, xyz, val, iso)
	local cubeindex = 0
	if val[1].val < iso then cubeindex = cubeindex | 0x01 end
	if val[2].val < iso then cubeindex = cubeindex | 0x02 end
	if val[3].val < iso then cubeindex = cubeindex | 0x04 end
	if val[4].val < iso then cubeindex = cubeindex | 0x08 end
	if val[5].val < iso then cubeindex = cubeindex | 0x10 end
	if val[6].val < iso then cubeindex = cubeindex | 0x20 end
	if val[7].val < iso then cubeindex = cubeindex | 0x40 end
	if val[8].val < iso then cubeindex = cubeindex | 0x80 end

	cubeindex = cubeindex + 1
	if 0 == s_edges[cubeindex] then
		return 0
	end

	local flags = s_edges[cubeindex]

	for ii = 0, 11 do
		if (flags & (1<<ii)) ~= 0 then
			local idx0 = (ii&7) + 1
			local idx1 = (idx1_table[ii+1])+1
			local vertex = verts[ii+1]
			local lerp = vertLerp(vertex, iso, idx0, val[idx0].val, idx1, val[idx1].val)

			local na = val[idx0]
			local nb = val[idx1]
			vertex[4] = na[1] + lerp * (nb[1] - na[1])
			vertex[5] = na[2] + lerp * (nb[2] - na[2])
			vertex[6] = na[3] + lerp * (nb[3] - na[3])
		end
	end

	local dr = rgb[4] - rgb[1]
	local dg = rgb[5] - rgb[2]
	local db = rgb[6] - rgb[3]

	local num = 0
	local indices = s_indices[cubeindex]

	for ii , v in ipairs(indices) do
		local vertex = verts[indices[ii] + 1]
		local xyz1 = xyz[1] + vertex[1];
		local xyz2 = xyz[2] + vertex[2];
		local xyz3 = xyz[3] + vertex[3];

		local rr = math.floor((rgb[1] + vertex[1]*dr)*255)
		local gg = math.floor((rgb[2] + vertex[2]*dg)*255)
		local bb = math.floor((rgb[3] + vertex[3]*db)*255)

		local abgr = 0xff000000 | (bb << 16) | (gg << 8) | rr

		tvb:packV(offset, xyz1, xyz2, xyz3, vertex[4], vertex[5], vertex[6], abgr)

		offset = offset + 1
		num = num + 1
	end

	return num
end

local DIMS = 32

local ctx = {}

local ypitch = DIMS
local zpitch = DIMS*DIMS
local invdim = 1/(DIMS-1)

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.01
	local numVertices = 0
	local maxVertices = (32<<10)
	ctx.tvb:alloc(maxVertices, ctx.vdecl)

	local numSpheres = 16
	local sphere = {}
	for i=1,numSpheres do
		table.insert(sphere, {
			math.sin(time*i*0.21+i*0.37) * (DIMS * 0.5 - 8),
			math.sin(time*i*0.37+i*0.67) * (DIMS * 0.5 - 8),
			math.cos(time*i*0.11+i*0.13) * (DIMS * 0.5 - 8),
			1/(2 + (math.sin(time*(i*0.13)) * 0.5 + 0.5) * 2)
		})
	end

	local grid = ctx.grid

	for zz = 0 , DIMS-1 do
		for yy = 0, DIMS-1 do
			local offset = (zz*DIMS+yy)*DIMS
			for xx = 0 , DIMS-1 do
				local xoffset = offset + xx
				local dist = 0.0
				local prod = 1.0
				for ii = 1, numSpheres do
					local pos = sphere[ii]

					local dx = pos[1] - (-DIMS*0.5 + xx )
					local dy = pos[2] - (-DIMS*0.5 + yy )
					local dz = pos[3] - (-DIMS*0.5 + zz )
					local invr = pos[4]
					local dot = dx*dx + dy*dy + dz*dz
					dot = dot * invr * invr
					dist = dist * dot + prod
					prod = prod *dot
				end
				grid[xoffset+1].val = dist / prod - 1;
			end
		end
	end

	for zz = 1, DIMS-2 do
		for yy = 1, DIMS-2 do
			local offset = (zz*DIMS+yy)*DIMS
			for xx = 1, DIMS-2 do
				local xoffset = offset + xx + 1
				local v1 = grid[xoffset-1     ].val - grid[xoffset+1     ].val
				local v2 = grid[xoffset-ypitch].val - grid[xoffset+ypitch].val
				local v3 = grid[xoffset-zpitch].val - grid[xoffset+zpitch].val
				local l = (v1^2 + v2^2 + v3^2) ^ 0.5
				local r =grid[xoffset]
				r[1] = v1 * l
				r[2] = v2 * l
				r[3] = v3 * l
			end
		end
	end

	local rgb = {}
	local pos = {}
	local val = {}
	for zz = 0, DIMS-2 do
		if numVertices+12 >= maxVertices then break	end
		rgb[3] = zz*invdim
		rgb[6] = (zz+1)*invdim

		for yy = 0, DIMS-2 do
			if numVertices+12 >= maxVertices then break end
			local offset = (zz*DIMS+yy)*DIMS
			rgb[2] = yy*invdim
			rgb[5] = (yy+1)*invdim
			for xx = 0, DIMS-2 do
				if numVertices+12 >= maxVertices then break end
				local xoffset = offset + xx
				rgb[1] = xx*invdim
				rgb[4] = (xx+1)*invdim

				pos[1] = -DIMS*0.5 + xx
				pos[2] = -DIMS*0.5 + yy
				pos[3] = -DIMS*0.5 + zz

				val[1] = grid[xoffset+zpitch+ypitch+1]
				val[2] = grid[xoffset+zpitch+ypitch+2]
				val[3] = grid[xoffset+ypitch+2       ]
				val[4] = grid[xoffset+ypitch+1       ]
				val[5] = grid[xoffset+zpitch+1       ]
				val[6] = grid[xoffset+zpitch+2       ]
				val[7] = grid[xoffset+2              ]
				val[8] = grid[xoffset+1              ]

				local num = triangulate( ctx.tvb ,  numVertices , rgb, pos, val, 0.5)
				numVertices = numVertices + num
			end
		end
	end

	local mat = math3d.matrix()
	mat:rotmat(time*0.67, time)
	bgfx.set_transform(mat)
	ctx.tvb:setV(0, 0, numVertices)
	bgfx.set_state()	-- default state
	-- { WRITE_MASK = "RGBAZ", DEPTH_TEST = "LESS", CULL = "CW", MSAA = true }
	bgfx.submit(0, ctx.prog)
	bgfx.frame()
end

local function init(canvas)
	ant.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
--	bgfx.set_debug "ST"

	ctx.prog = util.programLoad("vs_metaballs", "fs_metaballs")
	ctx.vdecl = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "NORMAL", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}
	ctx.tvb = bgfx.transient_buffer "ffffffd"
	local grid = {}
	ctx.grid = grid
	for i = 1, DIMS^3 do
		grid[i] = { 0, 0, 0}
	end
	ant.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w,h, "vmx")
	local viewmat = math3d.matrix "view"
	local projmat = math3d.matrix "proj"
	viewmat:lookatp(0,0,-50, 0,0,0)
	projmat:projmat(60, w/h, 0.1, 100)
	bgfx.set_view_transform(0, viewmat, projmat)
end

function canvas:action(x,y)
	mainloop()
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
  bgfx.destroy(ctx.prog)
  ant.shutdown()
end
