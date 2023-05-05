/**
 * Copyright (C) 2023 Masatoshi Fukunaga
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
// lua
#include <lauxlib.h>
#include <lua.h>

static int xpcall_lua(lua_State *L)
{
    int top = lua_gettop(L);
    int rc  = 0;
    int ref = LUA_NOREF;

    luaL_checktype(L, 1, LUA_TFUNCTION);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);

    lua_pushvalue(L, 1);
    lua_remove(L, 1);
    switch (lua_pcall(L, 0, 0, 1)) {
    case 0:
        lua_pushboolean(L, 1);
        return 1;

    // case LUA_ERRRUN:
    // case LUA_ERRSYNTAX:
    // case LUA_ERRMEM:
    // case LUA_ERRERR:
    default:
        lua_pushboolean(L, 0);
        lua_insert(L, 1);
        lua_call(L, 1, 1);
        return 2;
    }
}

LUALIB_API int luaopen_testcase_xpcall(lua_State *L)
{
    lua_pushcfunction(L, xpcall_lua);
    return 1;
}
