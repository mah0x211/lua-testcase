/**
 * Copyright (C) 2023 Masatoshi Fukunaga
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

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
// lualib
#include <lauxlib.h>
#include <lualib.h>

#define MODULE_MT "testcase.socketpair"

static int write_lua(lua_State *L)
{
    int *sock       = luaL_checkudata(L, 1, MODULE_MT);
    size_t len      = 0;
    const char *msg = luaL_checklstring(L, 2, &len);
    ssize_t n       = write(*sock, msg, len);

    if (len == -1) {
        lua_pushnil(L);
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    lua_pushinteger(L, n);
    return 1;
}

static int read_lua(lua_State *L)
{
    int *sock      = luaL_checkudata(L, 1, MODULE_MT);
    char buf[4096] = {0};
    ssize_t n      = read(*sock, buf, sizeof(buf));

    if (n == -1) {
        lua_pushnil(L);
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        lua_pushstring(L, strerror(errno));
        return 2;
    } else if (n == 0) {
        lua_pushnil(L);
    } else {
        lua_pushlstring(L, buf, n);
    }

    return 1;
}

static int close_lua(lua_State *L)
{
    int *sock = luaL_checkudata(L, 1, MODULE_MT);

    if (*sock != -1) {
        close(*sock);
        *sock = -1;
    }
    return 0;
}

static int nonblock_lua(lua_State *L)
{
    int *sock         = luaL_checkudata(L, 1, MODULE_MT);
    int should_change = lua_gettop(L) > 1;
    int enabled       = 0;

    if (should_change) {
        luaL_checktype(L, 2, LUA_TBOOLEAN);
        enabled = lua_toboolean(L, 2);
    }

    // get O_NONBLOCK flag from socket
    int flags = fcntl(*sock, F_GETFL, 0);
    if (flags == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    // set current O_NONBLOCK flag
    if (flags & O_NONBLOCK) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }

    // change O_NONBLOCK flag
    if (should_change) {
        if (enabled) {
            flags |= O_NONBLOCK;
        } else {
            flags &= ~O_NONBLOCK;
        }

        if (fcntl(*sock, F_SETFL, flags) == -1) {
            lua_pushnil(L);
            lua_pushstring(L, strerror(errno));
            return 2;
        }
    }

    return 1;
}

static int fd_lua(lua_State *L)
{
    int *sock = luaL_checkudata(L, 1, MODULE_MT);

    lua_pushinteger(L, *sock);
    return 1;
}

static int tostring_lua(lua_State *L)
{
    lua_pushfstring(L, MODULE_MT ": %p", lua_touserdata(L, 1));
    return 1;
}

static int gc_lua(lua_State *L)
{
    int *sock = lua_touserdata(L, 1);

    if (*sock != -1) {
        close(*sock);
    }
    return 0;
}

static int new_lua(lua_State *L)
{
    int nonblock = 0;

    // check boolean arguments
    if (lua_gettop(L) > 0) {
        luaL_checktype(L, 1, LUA_TBOOLEAN);
        nonblock = lua_toboolean(L, 1);
    }

    int *sock1  = lua_newuserdata(L, sizeof(int));
    int *sock2  = lua_newuserdata(L, sizeof(int));
    int pair[2] = {0};
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    if (nonblock) {
        fcntl(pair[0], F_SETFL, O_NONBLOCK);
        fcntl(pair[1], F_SETFL, O_NONBLOCK);
    }

    *sock2 = pair[1];
    luaL_getmetatable(L, MODULE_MT);
    lua_setmetatable(L, -2);

    *sock1 = pair[0];
    lua_pushvalue(L, -2);
    luaL_getmetatable(L, MODULE_MT);
    lua_setmetatable(L, -2);

    return 2;
}

LUALIB_API int luaopen_testcase_socketpair(lua_State *L)
{
    // create metatable
    if (luaL_newmetatable(L, MODULE_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__gc",       gc_lua      },
            {"__tostring", tostring_lua},
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"fd",       fd_lua      },
            {"nonblock", nonblock_lua},
            {"close",    close_lua   },
            {"read",     read_lua    },
            {"write",    write_lua   },
            {NULL,       NULL        }
        };

        // metamethods
        for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        // methods
        lua_newtable(L);
        for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
            lua_pushcfunction(L, ptr->func);
            lua_setfield(L, -2, ptr->name);
        }
        lua_setfield(L, -2, "__index");
    }
    lua_settop(L, 0);

    lua_pushcfunction(L, new_lua);
    return 1;
}
