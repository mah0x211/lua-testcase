/**
 * Copyright (C) 2024 Masatoshi Fukunaga
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

// lua
#include <lua.h>
// system
#include <errno.h>
#include <signal.h>
#include <string.h>

// Pure C no-op handler: async-signal-safe, never calls into Lua.
// sa_flags=0 (no SA_RESTART) means blocked syscalls like poll() return EINTR
// when SIGCHLD is delivered.
static void noop_handler(int sig)
{
    (void)sig;
}

typedef struct {
    struct sigaction noop;
    struct sigaction saved;
    int enabled;
} nosigchld_t;

// nosigchld(enabled) -> true | false, errmsg
// enabled=true:  installs the noop SIGCHLD handler without SA_RESTART.
// enabled=false: restores the previously saved SIGCHLD disposition.
static int nosigchld_lua(lua_State *L)
{
#ifdef SIGCHLD
    nosigchld_t *s = (nosigchld_t *)lua_touserdata(L, lua_upvalueindex(1));
    int enabled    = lua_toboolean(L, 1);

    // Only change the handler if the requested state is different from the
    // current state.
    if (s->enabled != enabled) {
        if (enabled) {
            // Install the no-op handler and save the previous handler in
            // s->saved.
            s->enabled = sigaction(SIGCHLD, &s->noop, &s->saved) == 0;
        } else if (sigaction(SIGCHLD, &s->saved, NULL) == 0) {
            // Restore the previous handler from s->saved.
            s->enabled = 0;
        }
    }

    if (s->enabled == enabled) {
        // Successfully changed the handler or the handler was already in the
        // requested state.
        lua_pushboolean(L, 1);
        return 1;
    }
    // sigaction() failed, e.g. if SIGCHLD is not supported on this platform.
    lua_pushboolean(L, 0);
    lua_pushstring(L, strerror(errno));
    return 2;

#else
    (void)L;
    lua_pushboolean(L, 1);
    return 1;
#endif
}

LUALIB_API int luaopen_testcase_nosigchld(lua_State *L)
{
#ifdef SIGCHLD
    nosigchld_t *s = (nosigchld_t *)lua_newuserdata(L, sizeof(nosigchld_t));
    memset(s, 0, sizeof(*s));
    s->noop.sa_handler = noop_handler;
    sigemptyset(&s->noop.sa_mask);
    // no SA_RESTART so that poll()/select() return EINTR
    s->noop.sa_flags = 0;
    lua_pushcclosure(L, nosigchld_lua, 1);
#else
    lua_pushcfunction(L, nosigchld_lua);
#endif
    return 1;
}
