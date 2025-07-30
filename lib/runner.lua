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
local exit = require('testcase.exit').exit
local collectgarbage = collectgarbage
local ipairs = ipairs
local traceback = debug.traceback
local xpcall = require('testcase.xpcall')
local getcwd = require('testcase.getcwd')
local chdir = require('testcase.filesystem').chdir
local registry = require('testcase.registry')
local timer = require('testcase.timer')
local getpid = require('testcase.getpid')
local printer = require('testcase.printer')
local print = printer.new(nil, '\n')
local printf = printer.new()
local printCode = printer.new('  >     ', '\n', false)
local iohook = require('testcase.iohook')
--- constants
local PID = getpid()
local HR = string.rep('-', 80)

--- call a function by xpcall
--- @param t userdata
--- @param func function
--- @param hookfn function
--- @param hook_startfn function
--- @param hook_endfn function
--- @return boolean ok
--- @return string err
--- @return number elapsed
--- @return string elapsed_format
local function call(t, func, hookfn, hook_startfn, hook_endfn)
    local cwd = assert(getcwd())

    collectgarbage('collect')
    iohook.hook(hookfn, hook_startfn, hook_endfn)
    t:start()
    local ok, err = xpcall(func, traceback)
    local elapsed, fmt = t:stop()
    iohook.unhook()

    -- exit if process is forked in func
    if getpid() ~= PID then
        exit()
    end

    -- move to test working directory
    local cerr = chdir(cwd)
    assert(not cerr, cerr)

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
---@return boolean ok
---@return any err
local function run_test(t, name, func)
    printf('- %s ... ', name)
    local ok, err, elapsed, fmt = call(t, func, test_hook, test_hook_start,
                                       test_hook_end)
    printf('%s (' .. fmt .. ')', ok and 'ok' or 'fail', elapsed)
    if ok then
        printf('\n')
        return true
    end
    printf('  \n')
    printCode(err)
    return false, err
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
---@return any err
local function run_setup_teadown(t, name, func)
    local ok, err = call(t, func, setup_teardown_hook, function()
        print('- ', name)
    end, setup_teardown_end)

    if not ok and err then
        print('  failed to call ', name)
        printCode(err)
        return false, err
    end

    return ok
end

--- run test file
--- @param t userdata timer
--- @param src table
--- @return number nsuccess
--- @return table[] errors
local function run_file(t, src)
    local ntest = #src.tests

    print('')
    print(HR)
    print('%s: %d test cases', src.name, ntest)
    print(HR)

    local errs = {}
    --- call before_all
    if src.before_all then
        local ok, err = run_setup_teadown(t, 'before_all', src.before_all)
        if not ok then
            return 0, {
                name = 'before_all',
                error = err,
            }
        end
    end

    local nsuccess = 0
    for _, test in ipairs(src.tests) do
        -- call before_each
        if src.before_each then
            local ok, err = run_setup_teadown(t, 'before_each', src.before_each)
            if not ok then
                errs[#errs + 1] = {
                    name = 'before_each',
                    error = err,
                }
                break
            end
        end

        -- call test
        local ok, err = run_test(t, test.name, test.func)
        if ok then
            nsuccess = nsuccess + 1
        else
            errs[#errs + 1] = {
                name = test.name,
                error = err,
            }
        end

        -- call after_each
        if src.after_each then
            ok, err = run_setup_teadown(t, 'after_each', src.after_each)
            if not ok then
                errs[#errs + 1] = {
                    name = 'after_each',
                    error = err,
                }
                break
            end
        end
    end

    -- call after_all function
    if src.after_all then
        local ok, err = run_setup_teadown(t, 'after_all', src.after_all)
        if not ok then
            errs[#errs + 1] = {
                name = 'after_all',
                error = err,
            }
        end
    end

    print('\n%d successes, %d failures', nsuccess, ntest - nsuccess)

    return nsuccess, errs
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
---@return string? err
---@return number? nsuccess
---@return number? nfailures
---@return userdata? timer
---@return table[]? errors
local function run()
    if DO_NOT_RUN then
        return false, 'cannot run test cases while blocking'
    end

    local list, ntest = registry.getlist()
    local t = timer.new()
    local nsuccess = 0
    local errors = {}
    local nerrors = 0
    for _, src in ipairs(list) do
        -- move to test file directory
        local err = chdir()
        assert(not err, err)
        err = chdir(src.dirname)
        assert(not err, err)

        local n, errs = run_file(t, src)
        nsuccess = nsuccess + n
        if #errs > 0 then
            errors[#errors + 1] = {
                name = src.name,
                errors = errs,
            }
            nerrors = nerrors + #errs
        end
    end
    -- set the number of errors in the errors table
    errors.count = nerrors

    -- move to the initial working directory
    chdir()
    print('')
    print(HR)
    print('')

    return true, nil, nsuccess, ntest - nsuccess, t, errors
end

return {
    block = block,
    unblock = unblock,
    run = run,
}
