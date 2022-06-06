/**
 * Copyright (C) 2022 Masatoshi Fukunaga
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
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
// lua
#include <lauxlib.h>
#include <lualib.h>

#define PROC_MT "testcase.process"

static int wait_lua(lua_State *L)
{
    pid_t *p    = luaL_checkudata(L, 1, PROC_MT);
    pid_t pid   = *p;
    int wstatus = 0;

    if (pid == 0) {
        return luaL_error(L, "cannot wait for self-process to terminate");
    } else if (pid < 1) {
        // already exit
        errno = ECHILD;
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        lua_pushinteger(L, errno);
        return 3;
    } else if (waitpid(pid, &wstatus, WUNTRACED | WCONTINUED) == -1) {
        // got error
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        lua_pushinteger(L, errno);
        return 3;
    }

    // push result
    lua_createtable(L, 0, 5);
    lua_pushinteger(L, pid);
    lua_setfield(L, -2, "pid");
    if (WIFEXITED(wstatus)) {
        *p = -pid;
        // exit status
        lua_pushinteger(L, WEXITSTATUS(wstatus));
        lua_setfield(L, -2, "exit");
    } else if (WIFSIGNALED(wstatus)) {
        *p = -pid;
        // exit by signal
        lua_pushinteger(L, WTERMSIG(wstatus));
        lua_setfield(L, -2, "sigterm");
#ifdef WCOREDUMP
        if (WCOREDUMP(wstatus)) {
            lua_pushboolean(L, 1);
            lua_setfield(L, -2, "coredump");
        }
#endif
    } else if (WIFSTOPPED(wstatus)) {
        // stopped by signal
        lua_pushinteger(L, WSTOPSIG(wstatus));
        lua_setfield(L, -2, "sigstop");
    } else if (WIFCONTINUED(wstatus)) {
        // continued by signal
        lua_pushboolean(L, 1);
        lua_setfield(L, -2, "sigcont");
    }

    return 1;
}

static int is_child_lua(lua_State *L)
{
    pid_t *p = luaL_checkudata(L, 1, PROC_MT);
    lua_pushboolean(L, *p == 0);
    return 1;
}

static int pid_lua(lua_State *L)
{
    pid_t *p = luaL_checkudata(L, 1, PROC_MT);
    lua_pushinteger(L, *p);
    return 1;
}

static int gc_lua(lua_State *L)
{
    pid_t *p  = luaL_checkudata(L, 1, PROC_MT);
    pid_t pid = *p;

    if (pid == 0) {
        printf("exit child\n");
        exit(EXIT_SUCCESS);
    } else if (pid > 1) {
        // kill process
        if (waitpid(pid, NULL, WNOHANG) == 0 && kill(pid, SIGKILL) == 0) {
            waitpid(pid, NULL, 0);
        }
    }

    return 0;
}

static int tostring_lua(lua_State *L)
{
    pid_t *p = luaL_checkudata(L, 1, PROC_MT);
    lua_pushfstring(L, PROC_MT ": %p", p);
    return 1;
}

static int fork_lua(lua_State *L)
{
    pid_t *p  = lua_newuserdata(L, sizeof(pid_t));
    pid_t pid = fork();

    if (pid == -1) {
        // got error
        lua_pushnil(L);
        if (errno == EAGAIN) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
        } else {
            lua_pushstring(L, strerror(errno));
            lua_pushinteger(L, errno);
        }
        return 3;
    }

    *p = pid;
    luaL_getmetatable(L, PROC_MT);
    lua_setmetatable(L, -2);

    return 1;
}

LUALIB_API int luaopen_testcase_fork(lua_State *L)
{
    struct luaL_Reg mmethod[] = {
        {"__gc", gc_lua},
        {NULL,   NULL  }
    };
    struct luaL_Reg method[] = {
        {"pid",      pid_lua     },
        {"is_child", is_child_lua},
        {"wait",     wait_lua    },
        {NULL,       NULL        }
    };

    // create metatable
    luaL_newmetatable(L, PROC_MT);
    // metamethods
    for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
        lua_pushstring(L, ptr->name);
        lua_pushcfunction(L, ptr->func);
        lua_rawset(L, -3);
    }
    // methods
    lua_pushstring(L, "__index");
    lua_newtable(L);
    for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
        lua_pushstring(L, ptr->name);
        lua_pushcfunction(L, ptr->func);
        lua_rawset(L, -3);
    }
    lua_rawset(L, -3);
    lua_pop(L, 1);

    lua_pushcfunction(L, fork_lua);
    return 1;
}
