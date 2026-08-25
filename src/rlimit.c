/**
 *  Copyright (C) 2026 Masatoshi Fukunaga
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

// depend
#include "lua_errno.h"
// lua
#include <lauxlib.h>
// system
#include <errno.h>
#include <stdio.h>
#include <sys/resource.h>
#include <unistd.h>

static const char *const RESOURCE_NAMES[] = {
    "as",      "core",     "cpu",        "data",   "fsize", "locks",
    "memlock", "msgqueue", "nice",       "nofile", "nproc", "rss",
    "rtprio",  "rttime",   "sigpending", "stack",  NULL,
};

// returns the RLIMIT_* constant for the resource name at index 1, or -1 with
// errno set to ENOSYS when the platform does not support the resource.
static int check_rtype(lua_State *L, const char **name)
{
    int opt      = luaL_checkoption(L, 1, NULL, RESOURCE_NAMES);
    int resource = -1;

    *name = RESOURCE_NAMES[opt];
    switch (opt) {
    case 0: // as
#ifdef RLIMIT_AS
        resource = RLIMIT_AS;
#endif
        break;
    case 1: // core
#ifdef RLIMIT_CORE
        resource = RLIMIT_CORE;
#endif
        break;
    case 2: // cpu
#ifdef RLIMIT_CPU
        resource = RLIMIT_CPU;
#endif
        break;
    case 3: // data
#ifdef RLIMIT_DATA
        resource = RLIMIT_DATA;
#endif
        break;
    case 4: // fsize
#ifdef RLIMIT_FSIZE
        resource = RLIMIT_FSIZE;
#endif
        break;
    case 5: // locks
#ifdef RLIMIT_LOCKS
        resource = RLIMIT_LOCKS;
#endif
        break;
    case 6: // memlock
#ifdef RLIMIT_MEMLOCK
        resource = RLIMIT_MEMLOCK;
#endif
        break;
    case 7: // msgqueue
#ifdef RLIMIT_MSGQUEUE
        resource = RLIMIT_MSGQUEUE;
#endif
        break;
    case 8: // nice
#ifdef RLIMIT_NICE
        resource = RLIMIT_NICE;
#endif
        break;
    case 9: // nofile
#ifdef RLIMIT_NOFILE
        resource = RLIMIT_NOFILE;
#endif
        break;
    case 10: // nproc
#ifdef RLIMIT_NPROC
        resource = RLIMIT_NPROC;
#endif
        break;
    case 11: // rss
#ifdef RLIMIT_RSS
        resource = RLIMIT_RSS;
#endif
        break;
    case 12: // rtprio
#ifdef RLIMIT_RTPRIO
        resource = RLIMIT_RTPRIO;
#endif
        break;
    case 13: // rttime
#ifdef RLIMIT_RTTIME
        resource = RLIMIT_RTTIME;
#endif
        break;
    case 14: // sigpending
#ifdef RLIMIT_SIGPENDING
        resource = RLIMIT_SIGPENDING;
#endif
        break;
    case 15: // stack
#ifdef RLIMIT_STACK
        resource = RLIMIT_STACK;
#endif
        break;
    }

    if (resource == -1) {
        errno = ENOSYS;
    }
    return resource;
}

static int getlimit(lua_State *L, int resource, const char *resname,
                    struct rlimit *rl)
{
    if (getrlimit(resource, rl) != 0) {
        char msg[256] = {0};
        snprintf(msg, sizeof(msg), "failed to getrlimit for resource '%s'",
                 resname);

        lua_pushnil(L);
        lua_errno_new_with_message(L, errno, "getrlimit", msg);
        return 2;
    }
    return 0;
}

// accepts -1 (RLIM_INFINITY) or a non-negative integer; any other negative
// value raises an argument error.
static int check_limit(lua_State *L, int idx, const char *resname,
                       const char *field, rlim_t *limit)
{
    lua_Integer v = 0;

    if (lua_isnoneornil(L, idx)) {
        // if the argument is omitted or nil, leave the limit unchanged
        return 0;
    }

    v = luaL_checkinteger(L, idx);
    if (v < -1) {
        // note: luaL_error format strings only accept lua_pushvfstring
        // conversions, which reject the "%lld" conversion on lua 5.3+ and
        // luaJIT; format the value with snprintf instead.
        char msg[128] = {0};
        snprintf(msg, sizeof(msg),
                 "invalid %s for resource '%s': expected -1 (infinity) or a "
                 "non-negative integer, got %lld",
                 field, resname, (long long)v);
        return luaL_argerror(L, idx, msg);
    } else if (v == -1) {
        *limit = RLIM_INFINITY;
    } else {
        *limit = (rlim_t)v;
    }
    return 1;
}

static int setlimit(lua_State *L, int resource, const char *resname,
                    struct rlimit *rl)
{
    // if cur or max is specified, set the corresponding value in the
    // rlimit struct and call setrlimit. omitted or nil means unchanged.
    struct rlimit newrl = *rl;
    int nspecified      = check_limit(L, 2, resname, "cur", &newrl.rlim_cur) +
                          check_limit(L, 3, resname, "max", &newrl.rlim_max);
    int rv              = 0;

    if (!nspecified) {
        // if neither cur nor max is specified, raise an error
        return luaL_error(L, "either cur or max must be specified");
    }

    // if the new rlimit values are different from the current values,
    // call setrlimit
    if ((newrl.rlim_cur != rl->rlim_cur || newrl.rlim_max != rl->rlim_max) &&
        setrlimit(resource, &newrl) != 0) {
        char msg[256] = {0};
        snprintf(msg, sizeof(msg), "failed to setrlimit for resource '%s'",
                 resname);
        lua_pushnil(L);
        lua_errno_new_with_message(L, errno, "setrlimit", msg);
        return 2;
    }

    // re-read the actual limits: the kernel may clamp the requested
    // values (e.g. RLIMIT_NOFILE on darwin).
    rv = getlimit(L, resource, resname, rl);
    if (rv) {
        return rv;
    }

    return 0;
}

static int rlimit_lua(lua_State *L)
{
    const char *resname = NULL;
    int resource        = check_rtype(L, &resname);
    struct rlimit rl    = {0};
    int rv              = 0;

    if (resource == -1) {
        char msg[256] = {0};
        snprintf(msg, sizeof(msg),
                 "resource '%s' is not supported on this platform", resname);
        lua_pushnil(L);
        lua_errno_new_with_message(L, ENOSYS, "getrlimit", msg);
        return 2;
    }

    rv = getlimit(L, resource, resname, &rl);
    if (rv) {
        // early return if getlimit failed
        return rv;
    }

    // if cur or max is specified, call setlimit to update the limits
    if (lua_gettop(L) > 1 && (rv = setlimit(L, resource, resname, &rl))) {
        // early return if setlimit failed
        return rv;
    }

    // RLIM_INFINITY is reported as -1
    lua_createtable(L, 0, 3);
    lua_pushstring(L, resname);
    lua_setfield(L, -2, "resource");
    lua_pushinteger(L, rl.rlim_cur == RLIM_INFINITY ? -1 :
                                                      (lua_Integer)rl.rlim_cur);
    lua_setfield(L, -2, "cur");
    lua_pushinteger(L, rl.rlim_max == RLIM_INFINITY ? -1 :
                                                      (lua_Integer)rl.rlim_max);
    lua_setfield(L, -2, "max");
    return 1;
}

LUALIB_API int luaopen_testcase_rlimit(lua_State *L)
{
    lua_errno_loadlib(L);
    lua_pushcfunction(L, rlimit_lua);
    return 1;
}
