#define LUA_LIB

extern "C" {
	#include <lua.h>
	#include <lauxlib.h>
}

#include "imgui/imgui.h"

static int
lcreate(lua_State *L) {
	float fontSize = luaL_checknumber(L, 1);
	imguiCreate(fontSize);
	return 0;
}

static int
ldestroy(lua_State *L) {
	imguiDestroy();
	return 0;
}

static int
lbeginFrame(lua_State *L) {
	int32_t mx = luaL_checkinteger(L, 1);
	int32_t my = luaL_checkinteger(L, 2);
	int button1 = lua_toboolean(L, 3);
	int button2 = lua_toboolean(L, 4);
	int button3 = lua_toboolean(L, 5);
	int32_t scroll = luaL_checkinteger(L, 6);
	uint16_t width = luaL_checkinteger(L, 7);
	uint16_t height = luaL_checkinteger(L, 8);
	int inputChar = luaL_checkinteger(L, 9);
	bgfx::ViewId view = luaL_checkinteger(L, 10);
	uint8_t button = 
		(button1 ? IMGUI_MBUT_LEFT : 0) |
		(button2 ? IMGUI_MBUT_RIGHT : 0) |
		(button3 ? IMGUI_MBUT_MIDDLE : 0);
	imguiBeginFrame(mx, my, button, scroll, width, height, inputChar, view);
	return 0;
}

static int
lendFrame(lua_State *L) {
	imguiEndFrame();
	return 0;
}

// We need a ImGui API bindings, This is only for test
static int
ltest(lua_State *L) {
	// Create a window called "My First Tool", with a menu bar.
	ImGui::Begin("ImGUI Demo", NULL, 0);
	ImGui::Text("Hello, world %d", 123);
	if (ImGui::Button("Button")) {
		// do stuff
	}
	ImGui::End();
	return 0;
}

extern "C" LUAMOD_API int
luaopen_bgfx_imgui(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreate },
		{ "destroy", ldestroy },
		{ "begin_frame", lbeginFrame },
		{ "end_frame", lendFrame },
		{ "test", ltest },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}

