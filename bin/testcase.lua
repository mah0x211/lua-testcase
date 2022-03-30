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
local ipairs = ipairs
local pcall = pcall
local realpath = require('realpath')
local eval = require('testcase.eval')
local osexit = require('testcase.exit').exit
local print = require('testcase.printer').new(nil, '\n')
local printCode = require('testcase.printer').new('  >     ', '\n')
local getfiles = require('testcase.filesystem').getfiles
local getopts = require('testcase.getopts')
local registry = require('testcase.registry')
local runner = require('testcase.runner')
local ENOENT = require('errno').ENOENT.errno
local ARGV = _G.arg
local HEADLINE = string.rep('=', 80)
local USAGE = [[
testcase - a small helper tool to run the test files

Usage:
  testcase [--help] [--coverage] [--checkall] <pathname>

Options:
  --help        show this help message and exit
  --coverage    do code coverage analysis with `luacov`
  --checkall    any file with a `.lua` extension will be evaluated as a test file
]]

local function exit(code, msg, ...)
    if msg then
        print(msg, ...)
    end
    osexit(code)
end

--- loadfiles loads test files and runs it once for initialization
--- @param files table<number, string>
--- @return table<number, table<string, string>> errfiles
local function loadfiles(files)
    local errfiles = {}

    for _, filename in ipairs(files) do
        local ok, err = eval(filename)
        if not ok then
            errfiles[#errfiles + 1] = {
                filename,
                err,
            }
        end
    end

    return errfiles
end

do
    local opts = getopts(ARGV)

    if opts['--help'] then
        exit(0, USAGE)
    elseif not opts[1] then
        exit(-1, USAGE)
    elseif opts['--coverage'] then
        local ok, err = pcall(require, 'luacov')
        if not ok then
            exit(-1, 'failed to load luacov module: %s', err)
        end
    end

    -- confirm pathname
    local pathname, err, eno = realpath(opts[1])
    if not pathname then
        if eno ~= ENOENT then
            exit(-1, 'failed to resolve path %q: %s', opts[1], err)
        end
        exit(-1, 'failed to resolve path %q', opts[1])
    end

    -- luacheck: ignore err
    local files, err = getfiles(pathname, opts['--checkall'] and '.lua')
    if err then
        exit(-1, 'failed to get test files from %q: %s', pathname, err)
    end

    -- load test files
    runner.block()
    local errfiles = loadfiles(files)

    -- print test info
    local list, ntest = registry.getlist()
    print('')
    print('Test on %s', os.date('%FT%H:%M:%S%z'))
    print(HEADLINE, '\n')
    print('Total: %d test cases in %d files.\n', ntest, #list)
    for _, src in ipairs(list) do
        print('- ', src.name, ' has `', #src.tests, '` test cases')
    end
    -- print error files
    if #errfiles > 0 then
        print('\nUntested Files\n')
        for _, v in ipairs(errfiles) do
            print('- %s  ', v[1])
            printCode('%s', v[2])
        end
    end
    runner.unblock()

    local ok, nsuccess, nfailure, t, err = runner.run()
    if not ok then
        exit(-1, 'failed to runner.run(): ', err)
    end

    local total, fmt = t:total()
    print('### Total: %d successes, %d failures (' .. fmt .. ')', nsuccess,
          nfailure, total, '\n')

    -- exit failure
    if nfailure > 0 or #errfiles > 0 then
        exit(-1)
    end
end
