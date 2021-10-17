require('luacov')
local getcwd = require('process').getcwd
local assert = require('assertex')
local CWD = assert(getcwd())

local function test_chdir()
    local fs = require('testcase.filesystem')

    -- test that change working directory to './test'
    local err = fs.chdir('./test')
    assert(not err, err)
    local wd = assert(getcwd())
    assert.equal(wd, CWD .. '/test')

    -- test that change working directory to initial working directory
    err = fs.chdir()
    assert(not err, err)
    wd = assert(getcwd())
    assert.equal(wd, CWD)

    -- test that returns error if cannot change working directory
    assert(fs.chdir('foobarbaz'), 'chdir to "foobarbaz"')
end

local function test_getfiles()
    local fs = require('testcase.filesystem')

    -- test that returns list of a file with suffix '_test.lua'
    local files, err = fs.getfiles('.')
    assert(not err, err)
    assert.equal(files, {
        './test/exit_test.lua',
        './test/filesystem_test.lua',
        './test/getopts_test.lua',
        './test/iohook_test.lua',
        './test/printer_test.lua',
        './test/registry_test.lua',
        './test/runner_test.lua',
        './test/testcase_test.lua',
    })

    -- test that returns files only contains pathname
    files, err = fs.getfiles('./test/testall.lua')
    assert(not err, err)
    assert.equal(files, {'./test/testall.lua'})

    -- test that returns nil if pathname is not found
    files, err = fs.getfiles('./foobarbaz')
    assert(not err, err)
end

local function test_getstat()
    local fs = require('testcase.filesystem')

    -- test that returns stat
    local stat, err = fs.getstat('./test')
    assert(not err, err)
    assert.equal({
        realpath = stat.realpath,
        type = stat.type,
    }, {
        realpath = CWD .. '/test',
        type = 'dir',
    })

    -- test that returns nil
    stat, err = fs.getstat('./foobarbaz')
    assert(not err, err)
    assert(not stat, 'getstat() returns not nil')
end

test_chdir()
test_getfiles()
test_getstat()
