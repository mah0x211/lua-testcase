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
#include <errno.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#if defined(__APPLE__)
# include <mach/mach.h>
# include <mach/mach_time.h>

static inline int getnsec_ex(struct timespec *ts)
{
    static mach_timebase_info_data_t tbinfo = {0};
    uint64_t ns                             = 0;

    if (tbinfo.denom == 0) {
        (void)mach_timebase_info(&tbinfo);
    }

    ns          = mach_absolute_time() * tbinfo.numer / tbinfo.denom;
    ts->tv_sec  = ns / 1000000000;
    ts->tv_nsec = ns - (ts->tv_sec * 1000000000);
    return 0;
}

#else

static inline int getnsec_ex(struct timespec *ts)
{
    return clock_gettime(CLOCK_MONOTONIC, ts);
}

#endif

static inline int getnsec(uint64_t *ns)
{
    struct timespec ts = {0};

    if (getnsec_ex(&ts) == -1) {
        return -1;
    }

    *ns = (uint64_t)ts.tv_sec * 1000000000 + (uint64_t)ts.tv_nsec;
    return 0;
}

#define TESTCASE_TIMER_MT "testcase.timer"

typedef struct {
    uint64_t total;
    uint64_t start;
} testcase_timer_t;

static int nsec2utime(lua_State *L, uint64_t ns)
{
    static const long double us  = 1000;
    static const long double ms  = us * 1000;
    static const long double sec = ms * 1000;
    static const long double min = sec * 60;

    if (ns >= min) {
        // min
        lua_pushnumber(L, (long double)ns / min);
        lua_pushliteral(L, "%.3f m");
        lua_pushliteral(L, "m");
    } else if (ns >= sec) {
        // second
        lua_pushnumber(L, (long double)ns / sec);
        lua_pushliteral(L, "%.3f s");
        lua_pushliteral(L, "s");
    } else if (ns >= ms) {
        // millisecond
        lua_pushnumber(L, (long double)ns / ms);
        lua_pushliteral(L, "%.3f ms");
        lua_pushliteral(L, "ms");
    } else if (ns >= us) {
        // microsecond
        lua_pushnumber(L, (long double)ns / us);
        lua_pushliteral(L, "%.3f us");
        lua_pushliteral(L, "us");
    } else {
        // nanosecond
        lua_pushnumber(L, (long double)ns);
        lua_pushliteral(L, "%d ns");
        lua_pushliteral(L, "ns");
    }
    return 3;
}

static int elapsed_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)luaL_checkudata(L, 1, TESTCASE_TIMER_MT);
    uint64_t ns = 0;

    if (getnsec(&ns) == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    return nsec2utime(L, ns - t->start);
}

static int stop_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)luaL_checkudata(L, 1, TESTCASE_TIMER_MT);
    uint64_t ns      = 0;
    uint64_t elapsed = 0;

    if (getnsec(&ns) == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }

    elapsed = ns - t->start;
    t->total += elapsed;
    t->start = ns;

    return nsec2utime(L, elapsed);
}

static int start_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)luaL_checkudata(L, 1, TESTCASE_TIMER_MT);
    uint64_t ns = 0;

    if (getnsec(&ns) == -1) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    t->start = ns;
    lua_pushboolean(L, 1);

    return 1;
}

static int total_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)luaL_checkudata(L, 1, TESTCASE_TIMER_MT);
    return nsec2utime(L, t->total);
}

static int reset_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)luaL_checkudata(L, 1, TESTCASE_TIMER_MT);
    t->total = t->start = 0;
    return 0;
}

static int tostring_lua(lua_State *L)
{
    lua_pushfstring(L, TESTCASE_TIMER_MT ": %p", lua_touserdata(L, 1));
    return 1;
}

static int new_lua(lua_State *L)
{
    testcase_timer_t *t =
        (testcase_timer_t *)lua_newuserdata(L, sizeof(testcase_timer_t));
    *t = (testcase_timer_t){.total = 0, .start = 0};
    luaL_getmetatable(L, TESTCASE_TIMER_MT);
    lua_setmetatable(L, -2);
    return 1;
}

static int usleep_lua(lua_State *L)
{
    useconds_t usec = luaL_checkinteger(L, 1);
    usleep(usec);
    return 0;
}

static int nanotime_lua(lua_State *L)
{
    struct timespec ts = {0};

    if (getnsec_ex(&ts) == -1) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    lua_pushnumber(L, (double)ts.tv_sec + ((double)ts.tv_nsec / 1000000000));

    return 1;
}

LUALIB_API int luaopen_testcase_timer(lua_State *L)
{
    // create metatable
    if (luaL_newmetatable(L, TESTCASE_TIMER_MT)) {
        struct luaL_Reg mmethod[] = {
            {"__tostring", tostring_lua},
            {NULL,         NULL        }
        };
        struct luaL_Reg method[] = {
            {"reset",   reset_lua  },
            {"total",   total_lua  },
            {"start",   start_lua  },
            {"stop",    stop_lua   },
            {"elapsed", elapsed_lua},
            {NULL,      NULL       }
        };
        struct luaL_Reg *ptr = mmethod;

        // metamethods
        do {
            lua_pushstring(L, ptr->name);
            lua_pushcfunction(L, ptr->func);
            lua_rawset(L, -3);
            ptr++;
        } while (ptr->name);

        // methods
        lua_pushstring(L, "__index");
        lua_newtable(L);
        ptr = method;
        do {
            lua_pushstring(L, ptr->name);
            lua_pushcfunction(L, ptr->func);
            lua_rawset(L, -3);
            ptr++;
        } while (ptr->name);
        lua_rawset(L, -3);
    }
    lua_settop(L, 0);

    // create module table
    lua_newtable(L);
    lua_pushstring(L, "new");
    lua_pushcfunction(L, new_lua);
    lua_rawset(L, -3);
    lua_pushstring(L, "usleep");
    lua_pushcfunction(L, usleep_lua);
    lua_rawset(L, -3);
    lua_pushstring(L, "nanotime");
    lua_pushcfunction(L, nanotime_lua);
    lua_rawset(L, -3);

    return 1;
}
