#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

#include "SDL.h"
#include "SDL_syswm.h"

#define FRAMESEC 1000

struct context {
	SDL_Window *window;
	uint64_t tick;
	int frame;
	int fps;
	int w;
	int h;
};

static struct context *
getCtx(lua_State *L) {
	struct context * ctx = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	return ctx;
}

static int
get_int(lua_State *L, int idx, const char * name) {
	if (lua_getfield(L, idx, name) != LUA_TNUMBER) {
		luaL_error(L, "Can't get %s as number", name);
	}
	int isnum;
	int r = lua_tointegerx(L, -1, &isnum);
	if (!isnum)
		luaL_error(L, "Can't get %s as integer", name);
	lua_pop(L, 1);
	return r;
}

static uint32_t
is_enable(lua_State *L, int idx, const char * name) {
	lua_getfield(L, idx, name);
	int enable = lua_toboolean(L, -1);
	lua_pop(L, 1);
	return enable ? 0xffffffff : 0;
}

static int
linit(lua_State *L) {
	struct context * ctx = getCtx(L);
	if (ctx->window != NULL)
		return luaL_error(L, "Already init");
	if (SDL_Init(SDL_INIT_VIDEO) < 0)
		return luaL_error(L, "Couldn't initialize SDL: %s\n", SDL_GetError());

	luaL_checktype(L, 1, LUA_TTABLE);

	ctx->w = get_int(L, 1, "width");
	ctx->h = get_int(L, 1, "height");

	uint32_t flags = 0;

	flags |= is_enable(L, 1, "borderless") & SDL_WINDOW_BORDERLESS;
	flags |= is_enable(L, 1, "resizeable") & SDL_WINDOW_RESIZABLE;
	flags |= is_enable(L, 1, "fullscreen") & SDL_WINDOW_FULLSCREEN;

	const char * title = "";
	if (lua_getfield(L, 1, "title") == LUA_TSTRING) {
		title = lua_tostring(L, -1);
		lua_pop(L, 1);
	}

	SDL_Window *wnd = SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, ctx->w, ctx->h, flags);
	if (wnd == NULL) {
        return luaL_error(L, "Couldn't create window : %s", SDL_GetError());
	}

	ctx->window = wnd;
	ctx->tick = SDL_GetTicks64();
	ctx->frame = 0;
	ctx->fps = get_int(L, 1, "fps");

	return 0;
}

static int
lframe(lua_State *L) {
	struct context * ctx = getCtx(L);
	uint64_t c = SDL_GetTicks64();
	int lastframe = ctx->frame;
	int frame = lastframe + 1;
	if (frame > ctx->fps) {
		lastframe = 0;
		frame = 1;
	}
	int delta = FRAMESEC * frame / ctx->fps - FRAMESEC * lastframe / ctx->fps;
	ctx->frame = frame;
	ctx->tick += delta;
	if (c < ctx->tick)
		SDL_Delay(ctx->tick - c);
	if (c - ctx->tick > FRAMESEC) {
		// reset frame count if the error is too large
		ctx->tick = c;
		ctx->frame = 0;
	}

	return 0;
}

static int
winevent(lua_State *L, SDL_Event *ev) {
	switch (ev->window.event) {
		case SDL_WINDOWEVENT_SIZE_CHANGED :
			lua_pushstring(L, "RESIZE");
			lua_pushinteger(L, ev->window.data1);
			lua_pushinteger(L, ev->window.data2);
			return 3;
	}
	return 0;
}

static int
keyevent(lua_State *L, SDL_Event *ev) {
//	if (ev->key.repeat)
//		return 0;
	lua_pushstring(L, "KEY");
	lua_pushstring(L, SDL_GetKeyName(ev->key.keysym.sym));
	lua_pushboolean(L, ev->key.type == SDL_KEYDOWN);
	return 3;
}

static int
motionevent(lua_State *L, SDL_Event *ev) {
	int x = ev->motion.x;
	int y = ev->motion.y;
	lua_pushstring(L, "MOTION");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	return 3;
}

static int
buttonevent(lua_State *L, SDL_Event *ev) {
	int x = ev->motion.x;
	int y = ev->motion.y;
	lua_pushstring(L, "BUTTON");
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	lua_pushinteger(L, ev->button.button);
	lua_pushboolean(L, ev->button.state == SDL_PRESSED);
	lua_pushinteger(L, ev->button.clicks);
	return 6;
}

static int
levent(lua_State *L) {
	SDL_Event event;

	int r;

	while (SDL_PollEvent(&event)) {
		switch (event.type)	{
			case SDL_QUIT:
				lua_pushstring(L, "QUIT");
				return 1;
			case SDL_WINDOWEVENT:
				if ((r = winevent(L, &event)) > 0)
					return r;
				break;
			case SDL_KEYDOWN:
			case SDL_KEYUP:
				if ((r = keyevent(L, &event)) > 0)
					return r;
				break;
			case SDL_TEXTEDITING:
				SDL_StopTextInput();
				break;
			case SDL_MOUSEMOTION:
				if ((r = motionevent(L, &event)) > 0)
					return r;
				break;
			case SDL_MOUSEBUTTONDOWN:
			case SDL_MOUSEBUTTONUP:
				return buttonevent(L, &event);
			default:
				break;
		}
	}
	return 0;
}

static int
lhandle(lua_State *L) {
	// todo : support other platforms, it's windows only now
	struct context * ctx = getCtx(L);
	if (ctx->window == NULL)
		return luaL_error(L, "Init first");
	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);

	if (!SDL_GetWindowWMInfo(ctx->window, &wmInfo)) {
		return luaL_error(L, "SDL_GetWindowWMInfo error : %s", SDL_GetError());
	}

	lua_pushlightuserdata(L, (void *)wmInfo.info.win.window);
	return 1;
}

LUAMOD_API int
luaopen_sdlwnd(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "frame", lframe },
		{ "event", levent },
		{ "handle", lhandle },
		{ NULL, NULL },
	};
	luaL_newlibtable(L, l);
	struct context *ctx = (struct context *)lua_newuserdatauv(L, sizeof(struct context), 1);
	memset(ctx, 0, sizeof(*ctx));
	luaL_setfuncs(L,l,1);
	return 1;
}
