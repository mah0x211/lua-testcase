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
local has_prefix = require('stringex').has_prefix
local has_suffix = require('stringex').has_suffix
local trim_prefix = require('stringex').trim_prefix
local trim_suffix = require('stringex').trim_suffix
local getcwd = require('process').getcwd
local pchdir = require('process').chdir
local stat = require('path.pathc').stat
local dirname = require('path.pathc').dirname
local basename = require('path.pathc').basename
local exists = require('path.pathc').exists
local readdir = require('path.pathc').readdir
--- constants
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
    local ents, err = readdir(pathname)

    if err then
        return err
    end

    -- list up
    for _, ent in ipairs(ents) do
        -- ignore dotfiles
        if not find(ent, '^%.') then
            local fullname = pathname .. '/' .. ent
            -- luacheck: ignore err
            local info, err = stat(fullname)

            if err then
                return err
            elseif info.type == 'dir' then
                err = walkdir(files, fullname, suffix)
                if err then
                    return err
                end
            elseif info.type == 'reg' and has_suffix(ent, suffix) then
                files[#files + 1] = trim_cwd(fullname)
            end
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
    local info, err = stat(pathname)

    if not info then
        return nil, err
    elseif info.type == 'reg' then
        files[#files + 1] = trim_cwd(pathname)
        return files
    elseif info.type == 'dir' then
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
    return pchdir(pathname or CWD)
end

--- cannonicalize filename
--- @param pathname string
--- @return table pathinfo
--- @return string error
local function getstat(pathname)
    local rpath, err = exists(pathname)
    -- failed to get realpath
    if not rpath then
        -- not found or got erorr
        return nil, err
    end

    -- luacheck: ignore err
    local info, err = stat(rpath, false)
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
