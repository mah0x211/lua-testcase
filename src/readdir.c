/**
 *  Copyright (C) 2023 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#include <dirent.h>
#include <errno.h>
#include <sys/types.h>
// lua
#include <lauxlib.h>
#include <lualib.h>
// lua module
#include <lua_errno.h>

static int readdir_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    DIR *dir         = NULL;

    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);
    dir = opendir(path);
    if (!dir) {
        lua_errno_new(L, errno, "readdir");
        return 1;
    }

    errno = 0;
    for (struct dirent *entry = readdir(dir); entry; entry = readdir(dir)) {
        lua_pushvalue(L, 2);
        lua_pushstring(L, entry->d_name);
        if (lua_pcall(L, 1, 1, 0) != 0) {
            printf("call failed\n");
            closedir(dir);
            lua_error_new(L, -1);
            return 1;
        } else if (lua_gettop(L) > 2 && lua_type(L, -1) != LUA_TNIL) {
            closedir(dir);
            return 1;
        }

        errno = 0;
    }
    closedir(dir);
    if (errno) {
        // got error
        lua_errno_new(L, errno, "readdir");
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

LUALIB_API int luaopen_testcase_readdir(lua_State *L)
{
    lua_errno_loadlib(L);
    lua_pushcfunction(L, readdir_lua);
    return 1;
}
