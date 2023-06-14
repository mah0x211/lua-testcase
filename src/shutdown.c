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
#include <errno.h>
#include <sys/socket.h>
// lua
#include <lua_errno.h>

static int shutdown_lua(lua_State *L)
{
    static const char *const options[] = {
        "rd",
        "wr",
        "rdwr",
        NULL,
    };
    int fd  = -1;
    int how = SHUT_RDWR;

    if (lua_isnumber(L, 1)) {
        fd = luaL_checkinteger(L, 1);
    } else {
        FILE **fp = lauxh_checkfilep(L, 1);
        if (*fp) {
            fd = fileno(*fp);
        }
    }

    switch (luaL_checkoption(L, 2, "rdwr", options)) {
    case 0:
        how = SHUT_RD;
        break;
    case 1:
        how = SHUT_WR;
        break;
    }

    if (shutdown(fd, how) == 0) {
        lua_pushboolean(L, 1);
        return 1;
    }
    lua_pushboolean(L, 0);
    lua_errno_new(L, errno, "shutdown");
    return 2;
}

LUALIB_API int luaopen_testcase_shutdown(lua_State *L)
{
    lua_errno_loadlib(L);
    lua_pushcfunction(L, shutdown_lua);
    return 1;
}
