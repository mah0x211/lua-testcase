/**
 * Copyright (C) 2026 Masatoshi Fukunaga
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
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <unistd.h>
// lua
#include <lauxlib.h>
#include <lua.h>

typedef struct {
    const char *name;
    int num;
} signal_entry_t;

// Canonical signals must come before their aliases so that tosigname() returns
// the primary name (e.g., "SIGABRT" not "SIGIOT", "SIGPOLL" not "SIGIO").
static const signal_entry_t SIGNALS[] = {
// --- POSIX.1-1990 ---
// macOS: 1  Linux: 1
#ifdef SIGHUP
    {"SIGHUP",    SIGHUP   }, // terminal line hangup
#endif
// macOS: 2  Linux: 2
#ifdef SIGINT
    {"SIGINT",    SIGINT   }, // interrupt from keyboard
#endif
// macOS: 3  Linux: 3
#ifdef SIGQUIT
    {"SIGQUIT",   SIGQUIT  }, // quit from keyboard (core)
#endif
// macOS: 4  Linux: 4
#ifdef SIGILL
    {"SIGILL",    SIGILL   }, // illegal instruction (core)
#endif
// macOS: 5  Linux: 5
#ifdef SIGTRAP
    {"SIGTRAP",   SIGTRAP  }, // trace/breakpoint trap (core)
#endif
// macOS: 6  Linux: 6
#ifdef SIGABRT
    {"SIGABRT",   SIGABRT  }, // process abort (core)
#endif
// macOS: 8  Linux: 8
#ifdef SIGFPE
    {"SIGFPE",    SIGFPE   }, // erroneous arithmetic operation (core)
#endif
// macOS: 9  Linux: 9
#ifdef SIGKILL
    {"SIGKILL",   SIGKILL  }, // kill (cannot be caught or ignored)
#endif
// macOS: 11  Linux: 11
#ifdef SIGSEGV
    {"SIGSEGV",   SIGSEGV  }, // invalid memory reference (core)
#endif
// macOS: 13  Linux: 13
#ifdef SIGPIPE
    {"SIGPIPE",   SIGPIPE  }, // broken pipe: write to pipe with no readers
#endif
// macOS: 14  Linux: 14
#ifdef SIGALRM
    {"SIGALRM",   SIGALRM  }, // alarm clock
#endif
// macOS: 15  Linux: 15
#ifdef SIGTERM
    {"SIGTERM",   SIGTERM  }, // termination signal
#endif
// macOS: 30  Linux: 10
#ifdef SIGUSR1
    {"SIGUSR1",   SIGUSR1  }, // user-defined signal 1
#endif
// macOS: 31  Linux: 12
#ifdef SIGUSR2
    {"SIGUSR2",   SIGUSR2  }, // user-defined signal 2
#endif
// macOS: 20  Linux: 17
#ifdef SIGCHLD
    {"SIGCHLD",   SIGCHLD  }, // child stopped or terminated
#endif
// macOS: 19  Linux: 18
#ifdef SIGCONT
    {"SIGCONT",   SIGCONT  }, // continue if stopped
#endif
// macOS: 17  Linux: 19
#ifdef SIGSTOP
    {"SIGSTOP",   SIGSTOP  }, // stop process (cannot be caught or ignored)
#endif
// macOS: 18  Linux: 20
#ifdef SIGTSTP
    {"SIGTSTP",   SIGTSTP  }, // stop typed at terminal
#endif
// macOS: 21  Linux: 21
#ifdef SIGTTIN
    {"SIGTTIN",   SIGTTIN  }, // background read from control terminal
#endif
// macOS: 22  Linux: 22
#ifdef SIGTTOU
    {"SIGTTOU",   SIGTTOU  }, // background write to control terminal
#endif

// --- POSIX.1-2001 ---
// macOS: 10  Linux: 7
#ifdef SIGBUS
    {"SIGBUS",    SIGBUS   }, // bus error: bad memory access (core)
#endif
// macOS: 27  Linux: 27
#ifdef SIGPROF
    {"SIGPROF",   SIGPROF  }, // profiling timer expired
#endif
// macOS: 12  Linux: 31
#ifdef SIGSYS
    {"SIGSYS",    SIGSYS   }, // bad system call argument (core)
#endif
// macOS: 16  Linux: 23
#ifdef SIGURG
    {"SIGURG",    SIGURG   }, // urgent condition on socket
#endif
// macOS: 26  Linux: 26
#ifdef SIGVTALRM
    {"SIGVTALRM", SIGVTALRM}, // virtual timer expired
#endif
// macOS: 24  Linux: 24
#ifdef SIGXCPU
    {"SIGXCPU",   SIGXCPU  }, // CPU time limit exceeded (core)
#endif
// macOS: 25  Linux: 25
#ifdef SIGXFSZ
    {"SIGXFSZ",   SIGXFSZ  }, // file size limit exceeded (core)
#endif

// --- XSI (POSIX.1-2001) / SysV ---
// macOS: 7 (=SIGEMT, not really supported)  Linux: 29
#ifdef SIGPOLL
    {"SIGPOLL",   SIGPOLL  }, // pollable event (SysV); listed before SIGIO
#endif
// macOS: 28  Linux: 28
#ifdef SIGWINCH
    {"SIGWINCH",  SIGWINCH }, // window size change (4.3BSD/SVr4)
#endif

// --- Platform-specific (non-alias) ---
// macOS: 7  Linux: (undefined)
#ifdef SIGEMT
    {"SIGEMT",    SIGEMT   }, // EMT instruction (macOS/BSD; core)
#endif
// macOS: 29  Linux: (undefined)
#ifdef SIGINFO
    {"SIGINFO",   SIGINFO  }, // information request (macOS/BSD)
#endif
// macOS: (undefined)  Linux: 30
#ifdef SIGPWR
    {"SIGPWR",    SIGPWR   }, // power failure (Linux/SVr4)
#endif
// macOS: (undefined)  Linux: 16
#ifdef SIGSTKFLT
    {"SIGSTKFLT", SIGSTKFLT}, // stack fault on coprocessor (Linux, obsolete)
#endif

// --- Aliases (after canonical names so tosigname returns the primary) ---
// = SIGABRT (macOS: 6  Linux: 6)
#ifdef SIGIOT
    {"SIGIOT",    SIGIOT   }, // alias for SIGABRT (compat)
#endif
// = SIGCHLD (Linux: 17)
#ifdef SIGCLD
    {"SIGCLD",    SIGCLD   }, // alias for SIGCHLD (Linux/SVr4 compat)
#endif
// macOS: 23 (independent)  Linux: 29 (=SIGPOLL)
#ifdef SIGIO
    {"SIGIO",     SIGIO    }, // I/O now possible; alias for SIGPOLL on Linux
#endif

    {NULL,        0        },
};

/**
 * @brief Look up a signal entry by name (case-insensitive).
 * @return pointer to the entry, or NULL if not found.
 */
static const signal_entry_t *lookup_by_name(const char *name)
{
    for (const signal_entry_t *e = SIGNALS; e->name; e++) {
        if (strcasecmp(e->name, name) == 0) {
            return e;
        }
    }
    return NULL;
}

/**
 * @brief Look up a signal entry by number.
 * @return pointer to the first matching entry, or NULL if not found.
 */
static const signal_entry_t *lookup_by_num(int num)
{
    for (const signal_entry_t *e = SIGNALS; e->name; e++) {
        if (e->num == num) {
            return e;
        }
    }
    return NULL;
}

/**
 * @brief Resolve a signal from stack position idx.
 *        Accepts an integer (signal number) or a string (signal name,
 *        case-insensitive, "SIGTERM" form).
 * @return signal number, or raises a Lua argument error.
 */
static int get_signal(lua_State *L, int idx)
{
    if (lua_type(L, idx) == LUA_TNUMBER) {
        return (int)lua_tointeger(L, idx);
    }
    const char *name        = luaL_checkstring(L, idx);
    const signal_entry_t *e = lookup_by_name(name);
    if (!e) {
        return luaL_argerror(L, idx, "invalid signal name");
    }
    return e->num;
}

// ok, err = kill(signame|signum, pid)
// Sends signal sig to process pid.
// sig may be a signal name string (case-insensitive, e.g. "SIGTERM") or a
// signal number. Returns true on success, or false and an error message on
// failure.
static int kill_lua(lua_State *L)
{
    int sig   = get_signal(L, 1);
    pid_t pid = (pid_t)luaL_checkinteger(L, 2);

    if (kill(pid, sig) == -1) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

// ok, err = raise(signame|signum)
// Sends signal sig to the calling process.
// sig may be a signal name string (case-insensitive) or a signal number.
// Returns true on success, or false and an error message on failure.
static int raise_lua(lua_State *L)
{
    int sig = get_signal(L, 1);

    if (raise(sig) != 0) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

// name? = tosigname(signum)
// Returns the canonical signal name string for signum (e.g. 15 -> "SIGTERM"),
// or nil if signum is not a known signal number.
static int tosigname_lua(lua_State *L)
{
    int num                 = (int)luaL_checkinteger(L, 1);
    const signal_entry_t *e = lookup_by_num(num);

    if (!e) {
        lua_pushnil(L);
        return 1;
    }
    lua_pushstring(L, e->name);
    return 1;
}

// num? = tosignum(signame)
// Returns the signal number for the given signal name string (case-insensitive,
// e.g. "SIGTERM" or "sigterm"), or nil if signame is not a known signal name.
static int tosignum_lua(lua_State *L)
{
    const char *name        = luaL_checkstring(L, 1);
    const signal_entry_t *e = lookup_by_name(name);

    if (!e) {
        lua_pushnil(L);
        return 1;
    }
    lua_pushinteger(L, e->num);
    return 1;
}

// ok, err = sigignore(signame|signum)
// Sets the disposition of signal sig to SIG_IGN so the signal is silently
// discarded when delivered. sig may be a signal name string (case-insensitive)
// or a signal number. Returns true on success, or false and an error message
// on failure.
static int sigignore_lua(lua_State *L)
{
    int sig = get_signal(L, 1);
    if (signal(sig, SIG_IGN) == SIG_ERR) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

// ok, err = sigdefault(signame|signum)
// Restores the disposition of signal sig to SIG_DFL (the default action).
// sig may be a signal name string (case-insensitive) or a signal number.
// Returns true on success, or false and an error message on failure.
static int sigdefault_lua(lua_State *L)
{
    int sig = get_signal(L, 1);
    if (signal(sig, SIG_DFL) == SIG_ERR) {
        lua_pushboolean(L, 0);
        lua_pushstring(L, strerror(errno));
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

// remsec = alarm(sec)
// Schedules SIGALRM to be delivered to the calling process after sec seconds.
// A sec value of 0 cancels any pending alarm. Returns the number of seconds
// remaining on any previously scheduled alarm (0 if none was pending).
static int alarm_lua(lua_State *L)
{
    unsigned int sec = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (lua_Integer)alarm(sec));
    return 1;
}

// names = signames()
// Returns a bidirectional mapping table for all known signals:
//   names[signame] = signum           one entry per signal name
//   names[signum]  = signame          when the number maps to a single name
//   names[signum]  = {signame, ...}   when the number maps to multiple names
// Alias entries (e.g. SIGIOT, SIGCLD) appear only as name->number keys; the
// number->name entry always holds the canonical name (or an array that lists
// the canonical name first).
static int signames_lua(lua_State *L)
{
#if LUA_VERSION_NUM < 502
# define lua_rawlen lua_objlen
#endif

    lua_newtable(L); // result at absolute index 1

    for (const signal_entry_t *e = SIGNALS; e->name; e++) {
        // result[signame] = signum
        lua_pushstring(L, e->name);
        lua_pushinteger(L, e->num);
        lua_rawset(L, 1);

        // inspect existing result[signum]
        lua_pushinteger(L, e->num);
        lua_rawget(L, 1); // stack: [result, existing]

        int t = lua_type(L, -1);
        if (t == LUA_TNIL) {
            // first occurrence: result[signum] = signame
            lua_pop(L, 1);
            lua_pushinteger(L, e->num);
            lua_pushstring(L, e->name);
            lua_rawset(L, 1);
        } else if (t == LUA_TSTRING) {
            // second occurrence: convert string to array {existing, e->name}
            lua_newtable(L); // stack: [result, existing_str, arr]
            lua_pushvalue(L, -2);
            lua_rawseti(L, -2, 1); // arr[1] = existing_str
            lua_pushstring(L, e->name);
            lua_rawseti(L, -2, 2); // arr[2] = e->name
            // stack: [result, existing_str, arr]
            lua_pushinteger(L, e->num);
            lua_pushvalue(L, -2); // push arr again
            lua_rawset(L, 1);     // result[signum] = arr
            lua_pop(L, 2);        // pop existing_str, arr
        } else if (t == LUA_TTABLE) {
            // third or later: append to existing array
            int len = (int)lua_rawlen(L, -1);
            lua_pushstring(L, e->name);
            lua_rawseti(L, -2, len + 1);
            lua_pop(L, 1); // pop arr
        } else {
            lua_pop(L, 1);
        }
    }

    return 1;
}

LUALIB_API int luaopen_testcase_signal(lua_State *L)
{
    struct luaL_Reg funcs[] = {
        {"kill",       kill_lua      },
        {"raise",      raise_lua     },
        {"tosigname",  tosigname_lua },
        {"tosignum",   tosignum_lua  },
        {"signames",   signames_lua  },
        {"sigignore",  sigignore_lua },
        {"sigdefault", sigdefault_lua},
        {"alarm",      alarm_lua     },
        {NULL,         NULL          },
    };

    lua_createtable(L, 0, 8);
    for (struct luaL_Reg *ptr = funcs; ptr->name; ptr++) {
        lua_pushcfunction(L, ptr->func);
        lua_setfield(L, -2, ptr->name);
    }
    return 1;
}
