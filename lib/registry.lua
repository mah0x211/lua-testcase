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
local type = type
local pairs = pairs
local sort = table.sort
local getinfo = debug.getinfo
local string = require('stringex')
local trim_prefix = string.trim_prefix
local format = string.format
local fs = require('testcase.filesystem')

local function cmp_name(a, b)
    return a.name < b.name
end

local function cmp_lineno(a, b)
    return a.lineno < b.lineno
end

-- REGISTRY = {
--     [<srcfile:string>] = {
--         dirname = <dirname>,
--         pathname = <pathname>,
--         tests = {
--             [<func_name:string>] = {
--                 name = <string>,
--                 func = <function>,
--                 lineno = <number>,
--             }
--         }
--     }
-- }
local REGISTRY = {}
local SETUP_AND_TEARDOWN = {
    before_all = true,
    after_all = true,
    before_each = true,
    after_each = true,
}

--- getlist returns a list of registered test cases
--- @return table list
--- @return number nfunc
local function getlist()
    local slist = {}
    local ntest = 0

    -- create sorted source list
    for src, stat in pairs(REGISTRY) do
        -- create sorted func list
        local tests = {}
        local item = {
            name = src,
            basename = stat.basename,
            dirname = stat.dirname,
            realpath = stat.realpath,
            tests = tests,
        }
        for name, test in pairs(stat.tests) do
            if SETUP_AND_TEARDOWN[name] then
                -- use as a setup or teardown
                item[name] = test.func
            else
                tests[#tests + 1] = test
            end
        end
        sort(tests, cmp_lineno)

        slist[#slist + 1] = item
        ntest = ntest + #tests
    end
    sort(slist, cmp_name)

    return slist, ntest
end

--- clear registry
local function clear()
    REGISTRY = {}
end

--- add function to registry
--- @param name string
--- @param func function
--- @return string error
local function add(name, func)
    -- verify arguments
    if type(name) ~= 'string' then
        return format('invalid argument #1 (string expected, got %s)',
                      type(name))
    elseif type(func) ~= 'function' then
        return format('invalid argument #2 (function expected, got %s)',
                      type(func))
    end

    local info = getinfo(func, 'nS')
    local lineno = info.linedefined
    local stat, err = fs.getstat(trim_prefix(info.source, '@'))

    if not stat then
        return format('failed to get fileinfo %s', err or '')
    end

    if not REGISTRY[stat.pathname] then
        REGISTRY[stat.pathname] = {
            dirname = stat.dirname,
            basename = stat.basename,
            pathname = stat.pathname,
            realpath = stat.realpath,
            tests = {},
        }
    end

    local tests = REGISTRY[stat.pathname].tests
    -- test case already exists
    if tests[name] then
        return format('testcase <%s:%d> already defined at lineno:%d', name,
                      lineno, tests[name].lineno)
    end

    tests[name] = {
        name = name,
        func = func,
        lineno = lineno,
    }
end

return {
    add = add,
    clear = clear,
    getlist = getlist,
}
