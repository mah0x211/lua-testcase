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
require('testcase.exit')
local pcall = pcall
local ipairs = ipairs
local chdir = require('testcase.filesystem').chdir
local registry = require('testcase.registry')
local timer = require('testcase.timer')
local printer = require('testcase.printer')
local print = printer.new(nil, '\n')
local printf = printer.new()
local printCode = printer.new('  >     ', '\n')
local iohook = require('testcase.iohook')
local HR = string.rep('-', 80)

--- call a function by pcall
--- @param t userdata
--- @param func function
--- @param hookfn function
--- @param hook_startfn string
--- @param hook_endfn string
--- @return boolean ok
--- @return string err
--- @return number elapsed
--- @return string elapsed_format
local function call(t, func, hookfn, hook_startfn, hook_endfn)
    iohook.hook(hookfn, hook_startfn, hook_endfn)
    t:start()
    local ok, err = pcall(func)
    local elapsed, fmt = t:stop()
    iohook.unhook()

    return ok, err, elapsed, fmt
end

local function test_hook(...)
    printCode(...)
end

local function test_hook_start()
    print('  ')
end

local function test_hook_end()
    printf('  ')
end

--- run test function
---@param t userdata
---@param name string
---@param func function
---@return number
local function run_test(t, name, func)
    printf('- %s ... ', name)
    local ok, err, elapsed, fmt = call(t, func, test_hook, test_hook_start,
                                       test_hook_end)
    printf('%s (' .. fmt .. ')', ok and 'ok' or 'fail', elapsed)
    if ok then
        printf('\n')
        return 1
    end
    printf('  \n')
    printCode(err)
    return 0
end

local function setup_teardown_hook(...)
    printCode(...)
end

local function setup_teardown_end()

end

--- run setup or teardown function
---@param t userdata
---@param name string
---@param func function
---@return boolean
local function run_setup_teadown(t, name, func)
    local ok, err = call(t, func, setup_teardown_hook, function()
        print('- ', name)
    end, setup_teardown_end)

    if not ok and err then
        print('  failed to call ', name)
        printCode(err)
    end

    return ok
end

local function run_file(t, src)
    local ntest = #src.tests
    local nsuccess = 0

    print('\n', HR)
    print('%s: %d test cases', src.name, ntest)
    print(HR)

    -- move to test file directory
    local err = chdir(src.dirname)
    if err then
        print('failed to chdir(%q)', src.dirname, err)
        return 0
    end

    --- call before_all
    if src.before_all and not run_setup_teadown(t, 'before_all', src.before_all) then
        return 0
    end

    for _, test in ipairs(src.tests) do
        -- call before_each
        if src.before_each and
            not run_setup_teadown(t, 'before_each', src.before_each) then
            break
        end

        -- call test
        nsuccess = nsuccess + run_test(t, test.name, test.func)

        -- call after_each
        if src.after_each and
            not run_setup_teadown(t, 'after_each', src.after_each) then
            break
        end
    end

    -- call after_all function
    if src.after_all then
        run_setup_teadown(t, 'after_all', src.after_all)
    end

    print('\n%d successes, %d failures', nsuccess, ntest - nsuccess)

    -- move to the initial working directory
    err = chdir()
    if err then
        print('failed to chdir()', err)
        return nsuccess
    end

    return nsuccess
end

local DO_NOT_RUN = false

local function block()
    DO_NOT_RUN = true
end

local function unblock()
    DO_NOT_RUN = false
end

--- run registered test funcs
---@return boolean ok
---@return number nsuccess
---@return number nfailures
---@return userdata timer
---@return string error
local function run()
    if DO_NOT_RUN then
        return false, 0, 0, nil, 'cannot run test cases while blocking'
    end

    local list, ntest = registry.getlist()
    local t = timer.new()
    local nsuccess = 0
    for _, src in ipairs(list) do
        nsuccess = nsuccess + run_file(t, src)
    end
    chdir()
    print('\n', HR, '\n')

    return true, nsuccess, ntest - nsuccess, t
end

return {
    block = block,
    unblock = unblock,
    run = run,
}
