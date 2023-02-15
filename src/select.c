/**
 * Copyright (C) 2021 Masatoshi Fukunaga
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int len_lua(lua_State *L)
{
    lua_pushinteger(L, lua_gettop(L));
    return 1;
}

static int head_lua(lua_State *L)
{
    int narg        = lua_gettop(L) - 1;
    lua_Integer idx = luaL_checkinteger(L, 1);

    lua_remove(L, 1);
    if (idx > narg) {
        return narg;
    } else if (idx <= 0) {
        return 0;
    }

    lua_settop(L, idx);
    return idx;
}

static int tail_lua(lua_State *L)
{
    int narg        = lua_gettop(L) - 1;
    lua_Integer idx = luaL_checkinteger(L, 1);

    if (idx > narg) {
        return 0;
    } else if (idx <= 1) {
        return narg;
    }

    return narg - idx + 1;
}

LUALIB_API int luaopen_testcase_select(lua_State *L)
{
    struct luaL_Reg funcs[] = {
        {"len",  len_lua },
        {"head", head_lua},
        {"tail", tail_lua},
        {NULL,   NULL    }
    };
    struct luaL_Reg *ptr = funcs;

    // create module table
    lua_newtable(L);
    do {
        lua_pushstring(L, ptr->name);
        lua_pushcfunction(L, ptr->func);
        lua_rawset(L, -3);
        ptr++;
    } while (ptr->name);

    return 1;
}
