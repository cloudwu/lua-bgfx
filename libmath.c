#include "math3d.h"
#include <lua.h>
#include <lauxlib.h>

static void *
check_userdata(lua_State *L, int idx) {
	void * ret = lua_touserdata(L, idx);
	luaL_argcheck(L, ret != NULL, idx, "Userdata should not be NULL");
	return ret;
}

static int
lnewvec3(lua_State *L) {
	struct vector3 tmp;
	if (lua_isuserdata(L, 1)) {
		struct vector3 *copy = check_userdata(L,1);
		tmp = *copy;
	} else {
		tmp.x = luaL_optnumber(L, 1, 0);
		tmp.y = luaL_optnumber(L, 2, 0);
		tmp.z = luaL_optnumber(L, 3, 0);
	}
	struct vector3 *vec3 = lua_newuserdata(L, sizeof(*vec3));
	*vec3 = tmp;
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

static int
lvec3_pack(lua_State *L) {
	struct vector3 *vec3 = check_userdata(L, 1);
	if (!lua_isnoneornil(L, 2)) {
		vec3->x = luaL_checknumber(L, 2);
	}
	if (!lua_isnoneornil(L, 3)) {
		vec3->y = luaL_checknumber(L, 3);
	}
	if (!lua_isnoneornil(L, 4)) {
		vec3->z = luaL_checknumber(L, 4);
	}
	lua_settop(L,1);
	return 1;
}

static int
lvec3_unpack(lua_State *L) {
	struct vector3 *vec3 = check_userdata(L, 1);
	lua_pushnumber(L, vec3->x);
	lua_pushnumber(L, vec3->y);
	lua_pushnumber(L, vec3->z);
	return 3;
}

static int
lvec3_dot(lua_State *L) {
	struct vector3 *a = check_userdata(L, 1);
	struct vector3 *b = check_userdata(L, 2);
	float v = vector3_dot(a,b);
	lua_pushnumber(L, v);
	return 1;
}

static int
lvec3_cross(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	struct vector3 *a = check_userdata(L, 2);
	struct vector3 *b = check_userdata(L, 3);
	vector3_cross(v,a,b);
	lua_settop(L, 1);
	return 1;
}

static int
lvec3_vector(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	struct vector3 *a = check_userdata(L, 2);
	struct vector3 *b = check_userdata(L, 3);
	vector3_vector(v,a,b);
	lua_settop(L, 1);
	return 1;
}

static int
lvec3_length(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	float len = vector3_length(v);
	lua_pushnumber(L, len);
	return 1;
}

static int
lvec3_normalize(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	vector3_normalize(v);
	lua_settop(L,1);
	return 1;
}

static int
lvec3_copy(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	struct vector3 *from = check_userdata(L, 2);
	*v = *from;
	lua_settop(L, 1);
	return 1;
}

static int
lvec3_tostring(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	lua_pushfstring(L, "[%f, %f, %f]", v->x, v->y, v->z);

	return 1;
}

static int
lvec3_rotation(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	struct vector3 *from = check_userdata(L, 2);
	vector3_to_rotation(v, from);
	lua_settop(L, 1);
	return 1;
}

static int
lvec3_lerp(lua_State *L) {
	struct vector3 *v = check_userdata(L, 1);
	struct vector3 *a = check_userdata(L, 2);
	struct vector3 *b = check_userdata(L, 3);
	float f = luaL_checknumber(L,4);
	vector3_lerp(v, a,b,f);
	lua_settop(L,1);
	return 1;
}

static void
create_meta(lua_State *L, luaL_Reg *l, const char *name, lua_CFunction tostring) {
	int n = 0;
	while(l[n].name)
		++n;
	lua_newtable(L);
	lua_createtable(L, 0, n);
	int i;
	for (i=0;i<n;i++) {
		lua_pushcfunction(L, l[i].func);
		lua_setfield(L, -2, l[i].name);
	}
	lua_setfield(L, -2, "__index");
	lua_pushstring(L, name);
	lua_setfield(L, -2, "__metatable");
	lua_pushcfunction(L, tostring);
	lua_setfield(L, -2, "__tostring");
}

static int
lvec3_transmat(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	matrix44_transmat(m,v->x,v->y,v->z);
	lua_settop(L,2);
	return 1;
}

static int
lvec3_scalemat(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	matrix44_scalemat(m,v->x,v->y,v->z);
	lua_settop(L,2);
	return 1;
}

static int
lvec3_rotmat(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	matrix44_rotmat(m,v->x,v->y,v->z);
	lua_settop(L,2);
	return 1;
}

static int
lvec3_rotaxis(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	float angle = luaL_checknumber(L,3);
	matrix44_rot_axis(m,v,angle);
	lua_settop(L,2);
	return 1;
}

static int
lvec3_mul(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	vector3_mul(v,m);
	lua_settop(L,1);
	return 1;
}

static int
lvec3_mul33(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	vector3_mul33(v,m);
	lua_settop(L,1);
	return 1;
}

static int
lvec3_distAABB(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	struct vector3 *mins = check_userdata(L,2);
	struct vector3 *maxs = check_userdata(L,3);
	float d = vector3_distAABB(v, mins, maxs);
	lua_pushnumber(L,d);
	return 1;
}

static int
lvec3_plane(lua_State *L) {
	struct vector3 *v = check_userdata(L,1);
	struct plane *p = check_userdata(L,2);
	float d = luaL_optnumber(L,3,0);
	plane_init(p, v, d);
	lua_settop(L,2);
	return 1;
}

static void
vector3(lua_State *L) {
	luaL_Reg l[] = {
		{ "pack", lvec3_pack },
		{ "unpack", lvec3_unpack },
		{ "dot", lvec3_dot },
		{ "cross", lvec3_cross },
		{ "vector", lvec3_vector },
		{ "length", lvec3_length },
		{ "normalize", lvec3_normalize },
		{ "copy", lvec3_copy },
		{ "rotation", lvec3_rotation },
		{ "lerp", lvec3_lerp },
		{ "transmat", lvec3_transmat },
		{ "scalemat", lvec3_scalemat },
		{ "rotmat", lvec3_rotmat },
		{ "rotaxis", lvec3_rotaxis },
		{ "mul", lvec3_mul },
		{ "mul33", lvec3_mul33 },
		{ "plane", lvec3_plane },
		{ "distAABB", lvec3_distAABB },
		{ NULL, NULL },
	};
	create_meta(L, l, "vector3", lvec3_tostring);
	lua_pushcclosure(L, lnewvec3, 1);
}

static int
lnewquat(lua_State *L) {
	if (lua_isuserdata(L, 1)) {
		struct quaternion *tmp = check_userdata(L,1);
		struct quaternion *q = lua_newuserdata(L, sizeof(*q));
		*q = *tmp;
	} else if lua_isnoneornil(L, 1) {
		struct quaternion *q = lua_newuserdata(L, sizeof(*q));
		q->x = 0;
		q->y = 0;
		q->z = 0;
		q->w = 1.0f;
	} else {
		float x = luaL_checknumber(L, 1);
		float y = luaL_checknumber(L, 2);
		float z = luaL_checknumber(L, 3);
		struct quaternion *q = lua_newuserdata(L, sizeof(*q));
		quaternion_init(q, x, y, z);
	}
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);

	return 1;
}

static int
lquat_tostring(lua_State *L) {
	struct quaternion *q = check_userdata(L, 1);
	lua_pushfstring(L, "[%f, %f, %f, %f]", q->x, q->y, q->z, q->w);

	return 1;
}

static int
lquat_mul(lua_State *L) {
	struct quaternion *q = check_userdata(L, 1);
	struct quaternion *a = check_userdata(L, 2);
	struct quaternion *b = check_userdata(L, 3);
	quaternion_mul(q,a,b);
	lua_settop(L,1);
	return 1;
}

static int
lquat_copy(lua_State *L) {
	struct quaternion *a = check_userdata(L, 1);
	struct quaternion *b = check_userdata(L, 2);
	*a = *b;
	lua_settop(L,1);
	return 1;
}

static int
lquat_slerp(lua_State *L) {
	struct quaternion *q = check_userdata(L, 1);
	struct quaternion *a = check_userdata(L, 2);
	struct quaternion *b = check_userdata(L, 3);
	float t = luaL_checknumber(L, 4);
	quaternion_slerp(q,a,b,t);
	lua_settop(L,1);
	return 1;
}

static int
lquat_nslerp(lua_State *L) {
	struct quaternion *q = check_userdata(L, 1);
	struct quaternion *a = check_userdata(L, 2);
	struct quaternion *b = check_userdata(L, 3);
	float t = luaL_checknumber(L, 4);
	quaternion_nslerp(q,a,b,t);
	lua_settop(L,1);
	return 1;
}

static int
lquat_inverted(lua_State *L) {
	struct quaternion *q = check_userdata(L, 1);
	quaternion_inverted(q);
	lua_settop(L,1);
	return 1;
}

static int
lquat_matrix(lua_State *L) {
	struct quaternion *q = check_userdata(L,1);
	union matrix44 *mat = check_userdata(L,2);
	matrix44_from_quaternion(mat, q);
	lua_settop(L,2);
	return 1;
}

static int
lquat_pack(lua_State *L) {
	struct quaternion *q = check_userdata(L,1);
	if (!lua_isnoneornil(L, 2)) {
		q->x = luaL_checknumber(L, 2);
	}
	if (!lua_isnoneornil(L, 3)) {
		q->y = luaL_checknumber(L, 3);
	}
	if (!lua_isnoneornil(L, 4)) {
		q->z = luaL_checknumber(L, 4);
	}
	if (!lua_isnoneornil(L, 5)) {
		q->w = luaL_checknumber(L, 5);
	}
	lua_settop(L,1);
	return 1;
}

static int
lquat_unpack(lua_State *L) {
	struct quaternion *q = check_userdata(L,1);
	lua_pushnumber(L, q->x);
	lua_pushnumber(L, q->y);
	lua_pushnumber(L, q->z);
	lua_pushnumber(L, q->w);
	return 4;
}

static void
quaternion(lua_State *L) {
	luaL_Reg l[] = {
		{ "mul", lquat_mul },
		{ "copy", lquat_copy },
		{ "pack", lquat_pack },
		{ "unpack", lquat_unpack },
		{ "slerp", lquat_slerp },
		{ "nslerp", lquat_nslerp },
		{ "inverted", lquat_inverted },
		{ "matrix", lquat_matrix },
		{ NULL, NULL },
	};
	create_meta(L, l, "quateraion", lquat_tostring);
	lua_pushcclosure(L, lnewquat, 1);
}

static int
lnewmat(lua_State *L) {
	if (lua_isuserdata(L, 1)) {
		union matrix44 *tmp = check_userdata(L,1);
		union matrix44 *mat = lua_newuserdata(L, sizeof(*mat));
		*mat = *tmp;
	} else if lua_isnoneornil(L, 1) {
		union matrix44 *mat = lua_newuserdata(L, sizeof(*mat));
		matrix44_identity(mat);
	} else {
		float x = luaL_checknumber(L, 1);
		float y = luaL_checknumber(L, 2);
		float z = luaL_checknumber(L, 3);
		union matrix44 *mat = lua_newuserdata(L, sizeof(*mat));
		matrix44_rot(mat, x, y, z);
	}
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);

	return 1;
}

static int
lmat_tostring(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	lua_pushfstring(L, "[(%f, %f, %f, %f) (%f, %f, %f, %f) (%f, %f, %f, %f) (%f, %f, %f, %f)]",
		m->c[0][0],m->c[0][1],m->c[0][2],m->c[0][3],
		m->c[1][0],m->c[1][1],m->c[1][2],m->c[1][3],
		m->c[2][0],m->c[2][1],m->c[2][2],m->c[2][3],
		m->c[3][0],m->c[3][1],m->c[3][2],m->c[3][3]);
	return 1;
}

static int
lmat_pack(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	int i;
	for (i=0;i<16;i++) {
		m->x[i] = luaL_checknumber(L, 2+i);
	}
	lua_settop(L,1);
	return 1;
}

static int
lmat_packline(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	int l = luaL_checkinteger(L, 2);
	if (l < 1 || l > 4) {
		return luaL_error(L, "out of range (%d) of matrix line", l);
	}
	float * line = m->c[l-1];
	int i;
	for (i=0;i<4;i++) {
		int idx = 3+i;
		if (!lua_isnoneornil(L, idx)) {
			line[i] = luaL_checknumber(L, idx);
		}
	}
	lua_settop(L, 1);
	return 1;
}

static int
lmat_unpack(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	int i;
	for (i=0;i<16;i++) {
		lua_pushnumber(L, m->x[i]);
	}
	return 16;
}

static int
lmat_copy(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	union matrix44 *from = check_userdata(L, 2);
	*m=*from;
	lua_settop(L,1);
	return 1;
}

static int
lmat_identity(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	matrix44_identity(m);
	lua_settop(L,1);
	return 1;
}

static int
lmat_perspective(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	float l = luaL_checknumber(L, 2);
	float r = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	float t = luaL_checknumber(L, 5);
	float n = luaL_checknumber(L, 6);
	float f = luaL_checknumber(L, 7);
	int homogeneousDepth = lua_toboolean(L, 8);
	matrix44_perspective(m,l,r,b,t,n,f,homogeneousDepth);

	lua_settop(L,1);
	return 1;
}

static int
lmat_ortho(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	float l = luaL_checknumber(L, 2);
	float r = luaL_checknumber(L, 3);
	float b = luaL_checknumber(L, 4);
	float t = luaL_checknumber(L, 5);
	float n = luaL_checknumber(L, 6);
	float f = luaL_checknumber(L, 7);
	int homogeneousDepth = lua_toboolean(L, 8);
	matrix44_ortho(m,l,r,b,t,n,f,homogeneousDepth);

	lua_settop(L,1);
	return 1;
}

static int
lmat_mul(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	union matrix44 *a = check_userdata(L, 2);
	union matrix44 *b = check_userdata(L, 3);
	if (b == NULL) {
		b = a;
		a = m;
	}
	matrix44_mul(m,a,b);
	lua_settop(L,1);
	return 1;
}

static int
lmat_fastmul43(lua_State *L) {
	union matrix44 *m = check_userdata(L, 1);
	union matrix44 *a = check_userdata(L, 2);
	union matrix44 *b = check_userdata(L, 3);
	matrix44_fastmul43(m,a,b);
	lua_settop(L,1);
	return 1;
}

static int
lmat_transposed(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	matrix44_transposed(m);
	lua_settop(L,1);
	return 1;
}

static int
lmat_determinant(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	float v = matrix44_determinant(m);
	lua_pushnumber(L,v);
	return 1;
}

static int
lmat_inverted(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	if (lua_isnoneornil(L, 2)) {
		union matrix44 tmp = *m;
		matrix44_inverted(m, &tmp);
	} else {
		union matrix44 *from = check_userdata(L,2);
		matrix44_inverted(m, from);
	}
	lua_settop(L,1);
	return 1;
}

static int
lmat_gettrans(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	struct vector3 *v = check_userdata(L,2);
	matrix44_gettrans(m,v);
	lua_settop(L,2);
	return 1;
}

static int
lmat_getscale(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	struct vector3 *v = check_userdata(L,2);
	matrix44_getscale(m,v);
	lua_settop(L,2);
	return 1;
}

static int
lmat_decompose(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	struct vector3 *trans = check_userdata(L,2);
	struct vector3 *rot = check_userdata(L,3);
	struct vector3 *scale = check_userdata(L,4);
	matrix44_decompose(m, trans, rot, scale);
	lua_settop(L, 4);
	return 3;
}

static int
lmat_trans(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float z = luaL_checknumber(L, 4);
	matrix44_trans(m,x,y,z);
	lua_settop(L,1);
	return 1;
}

static int
lmat_scale(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float z = luaL_checknumber(L, 4);
	matrix44_scale(m,x,y,z);
	lua_settop(L,1);
	return 1;
}

static int
lmat_rot(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	float z = luaL_checknumber(L, 4);
	matrix44_rot(m,x,y,z);
	lua_settop(L,1);
	return 1;
}

static int
lmat_lookat(lua_State *L) {
	union matrix44 *m = check_userdata(L,1);
	struct vector3 *eye = check_userdata(L, 2);
	struct vector3 *at = check_userdata(L, 3);
	struct vector3 *up = lua_touserdata(L, 4);
	matrix44_lookat(m, eye, at, up);
	lua_settop(L, 1);
	return 1;
}

static void
matrix(lua_State *L) {
	luaL_Reg l[] = {
		{ "pack", lmat_pack },
		{ "packline", lmat_packline },
		{ "unpack", lmat_unpack },
		{ "copy", lmat_copy },
		{ "identity", lmat_identity },
		{ "perspective", lmat_perspective },
		{ "ortho", lmat_ortho },
		{ "mul", lmat_mul },
		{ "fastmul43", lmat_fastmul43 },
		{ "transposed", lmat_transposed },
		{ "determinant", lmat_determinant },
		{ "inverted", lmat_inverted },
		{ "gettrans", lmat_gettrans },
		{ "getscale", lmat_getscale },
		{ "decompose", lmat_decompose },
		{ "trans", lmat_trans },
		{ "scale", lmat_scale },
		{ "rot", lmat_rot },
		{ "lookat", lmat_lookat },
		{ NULL, NULL },
	};
	create_meta(L, l, "matrix", lmat_tostring);
	lua_pushcclosure(L, lnewmat, 1);
}

static int
lnewvec4(lua_State *L) {
	struct vector4 tmp;
	if (lua_isuserdata(L, 1)) {
		struct vector4 *copy = check_userdata(L,1);
		tmp = *copy;
	} else {
		tmp.x = luaL_optnumber(L, 1, 0);
		tmp.y = luaL_optnumber(L, 2, 0);
		tmp.z = luaL_optnumber(L, 3, 0);
		tmp.w = luaL_optnumber(L, 4, 1.0);
	}
	struct vector4 *vec4 = lua_newuserdata(L, sizeof(*vec4));
	*vec4 = tmp;
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

#define lvec4_tostring lquat_tostring
#define lvec4_copy lquat_copy
#define lvec4_pack lquat_pack
#define lvec4_unpack lquat_unpack

static int
lvec4_mul(lua_State *L) {
	struct vector4 *v = check_userdata(L,1);
	union matrix44 *m = check_userdata(L,2);
	vector4_mul(v,m);
	lua_settop(L,1);
	return 1;
}

static void
vector4(lua_State *L) {
	luaL_Reg l[] = {
		{ "copy", lvec4_copy },
		{ "pack", lvec4_pack },
		{ "unpack", lvec4_unpack },
		{ "mul", lvec4_mul },
		{ NULL, NULL },
	};
	create_meta(L, l, "vector4", lvec4_tostring);
	lua_pushcclosure(L, lnewvec4, 1);
}

static int
lnewplane(lua_State *L) {
	int top = lua_gettop(L);
	if (top == 0) {
		struct plane *p = lua_newuserdata(L, sizeof(*p));
		p->normal.x = 0;
		p->normal.y = 0;
		p->normal.z = 1;
		p->dist = 0;	// XY plane
	} else if (top == 1) {
		struct plane *copy = check_userdata(L,1);
		struct plane *p = lua_newuserdata(L, sizeof(*p));
		*p = *copy;
	} else if (top == 3) {
		struct vector3 *a = check_userdata(L,1);
		struct vector3 *b = check_userdata(L,2);
		struct vector3 *c = check_userdata(L,3);
		struct plane *p = lua_newuserdata(L, sizeof(*p));
		plane_init_dot3(p, a,b,c);
	} else {
		return luaL_error(L, "Invalid new plane");
	}
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

static int
lplane_tostring(lua_State *L) {
	struct plane *p = check_userdata(L, 1);
	lua_pushfstring(L, "[%f, %f, %f : %f]", p->normal.x, p->normal.x, p->normal.z, p->dist);
	return 1;
}

static int
lplane_dist(lua_State *L) {
	struct plane *p = check_userdata(L, 1);
	struct vector3 *v = check_userdata(L, 2);
	float d = plane_dist(p,v);
	lua_pushnumber(L, d);
	return 1;
}

static int
lplane_copy(lua_State *L) {
	struct plane *p = check_userdata(L, 1);
	struct plane *from = check_userdata(L, 2);
	*p = *from;
	lua_settop(L,1);
	return 1;
}

static int
lplane_dot3(lua_State *L) {
	struct plane *p = check_userdata(L, 1);
	struct vector3 *a = check_userdata(L,2);
	struct vector3 *b = check_userdata(L,3);
	struct vector3 *c = check_userdata(L,4);
	plane_init_dot3(p, a,b,c);
	lua_settop(L,1);
	return 1;
}

static int
lplane_normal(lua_State *L) {
	struct plane *p = check_userdata(L, 1);
	lua_pushnumber(L, p->normal.x);
	lua_pushnumber(L, p->normal.y);
	lua_pushnumber(L, p->normal.z);

	return 3;
}

static void
plane(lua_State *L) {
	luaL_Reg l[] = {
		{ "copy", lplane_copy },
		{ "dist", lplane_dist },
		{ "dot3", lplane_dot3 },
		{ "normal", lplane_normal },
		{ NULL, NULL },
	};
	create_meta(L, l, "plane", lplane_tostring);
	lua_pushcclosure(L, lnewplane, 1);
}

static int
lraytriangle(lua_State *L) {
	int top = lua_gettop(L);
	if (top != 6) {
		return luaL_error(L, "intersection.raytriangle(rayOrig,rayDir,p0,p1,p2,ret)");
	}
	struct vector3 *ro = check_userdata(L,1);
	struct vector3 *rd = check_userdata(L,2);
	struct vector3 *p0 = check_userdata(L,3);
	struct vector3 *p1 = check_userdata(L,4);
	struct vector3 *p2 = check_userdata(L,5);
	struct vector3 *inst = check_userdata(L,6);
	if (intersection_raytriangle(ro,rd,p0,p1,p2,inst) == NULL) {
		return 0;
	}
	return 1;
}

static int
lrayAABB(lua_State *L) {
	int top = lua_gettop(L);
	if (top != 4) {
		return luaL_error(L, "intersection.rayAABB(rayOrig,rayDir,mins,maxs)");
	}
	struct vector3 *ro = check_userdata(L,1);
	struct vector3 *rd = check_userdata(L,2);
	struct vector3 *mins = check_userdata(L,3);
	struct vector3 *maxs = check_userdata(L,4);
	int r = intersection_rayAABB(ro,rd,mins,maxs);
	lua_pushboolean(L,r);
	return 1;
}

int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);
	lua_newtable(L);
	vector3(L);
	lua_setfield(L, -2, "vector3");
	quaternion(L);
	lua_setfield(L, -2, "quaternion");
	matrix(L);
	lua_setfield(L, -2, "matrix");
	vector4(L);
	lua_setfield(L, -2, "vector4");
	plane(L);
	lua_setfield(L, -2, "plane");
	luaL_Reg l[] = {
		{ "raytriangle", lraytriangle },
		{ "rayAABB", lrayAABB },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);
	lua_setfield(L, -2, "intersection");
	return 1;
}
