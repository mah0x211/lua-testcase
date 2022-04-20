--
-- Copyright (C) 2021 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--- file scope variables
local sort = table.sort
local find = string.find
local has_prefix = require('string.contains').prefix
local has_suffix = require('string.contains').suffix
local trim_prefix = require('string.trim').prefix
local trim_suffix = require('string.trim').suffix
local getcwd = require('getcwd')
local pchdir = require('chdir')
local fstat = require('fstat')
local dirname = require('dirname')
local basename = require('basename')
local realpath = require('realpath')
local opendir = require('opendir')
--- constants
local ENOENT = require('errno').ENOENT.errno
local CWD = assert(getcwd())

--- trim_cwd remove CWD prefix from pathname
--- @param pathname string
--- @return string pathname
local function trim_cwd(pathname)
    if has_prefix(pathname, CWD) then
        return trim_prefix(trim_prefix(pathname, CWD), '/')
    end
    return pathname
end

--- walkdir scans the given pathname recursively and push the name of lua file
--- to a files
--- @param files table<number, string>
--- @param pathname string
--- @param suffix string
local function walkdir(files, pathname, suffix)
    local dir, err = opendir(pathname)

    if err then
        return err
    end

    -- list up
    local entry
    entry, err = dir:readdir()
    if err then
        dir:closedir()
        return err
    end

    local dirs = {}
    while entry do
        -- ignore dotfiles
        if not find(entry, '^%.') then
            local fullname = pathname .. '/' .. entry
            local info, eno

            info, err, eno = fstat(fullname)
            if err then
                if eno ~= ENOENT then
                    return err
                end
            elseif info.type == 'directory' then
                dirs[#dirs + 1] = fullname
            elseif info.type == 'file' and has_suffix(entry, suffix) then
                files[#files + 1] = trim_cwd(fullname)
            end
        end

        entry, err = dir:readdir()
        if err then
            dir:closedir()
            return err
        end
    end
    dir:closedir()

    for _, fullname in ipairs(dirs) do
        err = walkdir(files, fullname, suffix)
        if err then
            return err
        end
    end
end

--- getfiles searche for the file with suffix '_test.lua' or specified `suffix`
--- in pathname and returns a list of files
--- @param pathname string
--- @param suffix string
--- @return table files
--- @return string error
local function getfiles(pathname, suffix)
    local files = {}
    local info, err, eno = fstat(pathname)

    if not info then
        if eno == ENOENT then
            return nil
        end
        return nil, err
    elseif info.type == 'file' then
        files[#files + 1] = trim_cwd(pathname)
        return files
    elseif info.type == 'directory' then
        err = walkdir(files, trim_suffix(pathname, '/'), suffix or '_test.lua')
        if err then
            return nil, err
        end
    end

    sort(files)
    return files
end

--- change working directory
--- @param pathname string
--- @return string error
local function chdir(pathname)
    local ok, err = pchdir(pathname or CWD)
    if not ok then
        return err
    end
end

--- cannonicalize filename
--- @param pathname string
--- @return table pathinfo
--- @return string error
local function getstat(pathname)
    local rpath, err, eno = realpath(pathname)
    -- failed to get realpath
    if not rpath then
        if eno == ENOENT then
            -- not found
            return nil
        end
        -- got erorr
        return nil, err
    end

    -- luacheck: ignore err
    local info, err = fstat(rpath, false)
    -- failed to get stat
    if not info then
        return nil, err
    end

    info.realpath = rpath
    info.basename = basename(rpath)
    info.pathname = trim_cwd(rpath)
    info.dirname = dirname(info.pathname)

    return info
end

return {
    chdir = chdir,
    getfiles = getfiles,
    getstat = getstat,
}
