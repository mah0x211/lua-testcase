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
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
// lua
#include <lauxlib.h>
#include <lua.h>
// external library
#include "lua_errno.h"

static inline void pushint2tbl(lua_State *L, const char *k, lua_Integer v)
{
    lua_pushinteger(L, v);
    lua_setfield(L, -2, k);
}

static inline void pushstr2tbl(lua_State *L, const char *k, const char *v)
{
    lua_pushstring(L, v);
    lua_setfield(L, -2, k);
}

static int fstat_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    int flgs         = O_RDONLY | O_CLOEXEC;
    int fd           = -1;
    struct stat buf  = {0};
    char perm[6]     = {0};

    // followsymlinks option: default true
    if (!lua_isnoneornil(L, 2)) {
        luaL_checktype(L, 2, LUA_TBOOLEAN);
        if (!lua_toboolean(L, 2)) {
            flgs |= O_NOFOLLOW;
        }
    }
    lua_settop(L, 1);

    if ((fd = open(path, flgs)) == -1) {
        lua_pushnil(L);
        lua_errno_new(L, errno, "fstat");
        return 2;
    }

    // got error
    if (fstat(fd, &buf) == -1) {
        close(fd);
        lua_pushnil(L);
        lua_errno_new(L, errno, "fstat");
        return 2;
    }
    close(fd);

    // set fields
    lua_createtable(L, 0, 14);
    // add descriptor
    pushint2tbl(L, "dev", buf.st_dev);
    pushint2tbl(L, "ino", buf.st_ino);
    pushint2tbl(L, "mode", buf.st_mode);
    pushint2tbl(L, "nlink", buf.st_nlink);
    pushint2tbl(L, "uid", buf.st_uid);
    pushint2tbl(L, "gid", buf.st_gid);
    pushint2tbl(L, "rdev", buf.st_rdev);
    pushint2tbl(L, "size", buf.st_size);
    pushint2tbl(L, "blksize", buf.st_blksize);
    pushint2tbl(L, "blocks", buf.st_blocks);
    pushint2tbl(L, "atime", buf.st_atime);
    pushint2tbl(L, "mtime", buf.st_mtime);
    pushint2tbl(L, "ctime", buf.st_ctime);
    snprintf(perm, sizeof(perm), "%#o", buf.st_mode & 01777);
    pushstr2tbl(L, "perm", perm);
    switch (buf.st_mode & S_IFMT) {
    case S_IFREG:
        pushstr2tbl(L, "type", "file");
        break;
    case S_IFDIR:
        pushstr2tbl(L, "type", "directory");
        break;
    case S_IFLNK:
        pushstr2tbl(L, "type", "symlink");
        break;
    case S_IFCHR:
        pushstr2tbl(L, "type", "character_device");
        break;
    case S_IFBLK:
        pushstr2tbl(L, "type", "block_device");
        break;
    case S_IFSOCK:
        pushstr2tbl(L, "type", "socket");
        break;
    case S_IFIFO:
        pushstr2tbl(L, "type", "fifo");
        break;
    }

    return 1;
}

LUALIB_API int luaopen_testcase_fstat(lua_State *L)
{
    lua_errno_loadlib(L);
    lua_pushcfunction(L, fstat_lua);
    return 1;
}
