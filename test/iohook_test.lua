require('luacov')
local pcall = pcall
local unpack = unpack or table.unpack
local assert = require('assertex')

local function test_iohook()
    local print_bk = _G.print
    local stdout_bk = _G.io.stdout
    local stderr_bk = _G.io.stderr
    local ok, err = pcall(function()
        local iohook = require('testcase.iohook')
        local call_hookfn = 0
        local call_startfn = 0
        local call_endfn = 0
        local hookargs
        local hookfn = function(...)
            call_hookfn = call_hookfn + 1
            hookargs = {
                ...,
            }
        end
        local startfn = function()
            call_startfn = call_startfn + 1
        end
        local endfn = function()
            call_endfn = call_endfn + 1
        end

        -- test that hook() is replace io.stdout, io.stderr and print
        iohook.hook(hookfn, startfn, endfn)
        assert(print ~= print_bk)
        assert(io.stdout ~= stdout_bk)
        assert(io.stderr ~= stderr_bk)

        -- test that hookfn and startfn functions are called
        for i, v in ipairs({
            {
                func = print,
                args = {
                    'call',
                    'print',
                },
            },
            {
                func = function(...)
                    io.stdout:write(...)
                end,
                args = {
                    'call',
                    'stdout:write',
                },
            },
            {
                func = function(...)
                    io.stderr:write(...)
                end,
                args = {
                    'call',
                    'stderr:write',
                },
            },
        }) do
            hookargs = nil
            print(unpack(v.args))
            assert.equal(call_startfn, 1)
            assert.equal(call_hookfn, i)
            assert.equal(call_endfn, 0)
            assert.equal(hookargs, v.args)
        end

        -- test that hook functions are not called after iohook.block()
        iohook.block()
        for _, func in ipairs({
            print,
            function(...)
                io.stdout:write(...)
            end,
            function(...)
                io.stderr:write(...)
            end,
        }) do
            hookargs = nil
            func('blocked')
            assert.equal(call_startfn, 1)
            assert.equal(call_hookfn, call_hookfn)
            assert.equal(call_endfn, 0)
            assert.is_nil(hookargs)
        end

        -- test that hook functions are called after iohook.unblock()
        iohook.unblock()
        call_hookfn = 0
        for i, func in ipairs({
            print,
            function(...)
                io.stdout:write(...)
            end,
            function(...)
                io.stderr:write(...)
            end,
        }) do
            hookargs = nil
            func('unblocked')
            assert.equal(call_startfn, 1)
            assert.equal(call_hookfn, i)
            assert.equal(call_endfn, 0)
            assert.equal(hookargs, {
                'unblocked',
            })
        end

        -- test that endfn is called when unhooked
        hookargs = nil
        iohook.unhook()
        assert.equal(call_startfn, 1)
        assert.equal(call_hookfn, 3)
        assert.equal(call_endfn, 1)
        assert.is_nil(hookargs)

        -- test that unhook() revert the io.stdout, io.stderr and print
        assert(print == print_bk)
        assert(io.stdout == stdout_bk)
        assert(io.stderr == stderr_bk)

        -- test that throw error with invalid argument
        for _, v in ipairs({
            {
                args = {
                    true,
                },
                match = '#1 (function expected, got boolean',
            },
            {
                args = {
                    function()
                    end,
                    1,
                },
                match = '#2 (function expected, got number',
            },
            {
                args = {
                    function()
                    end,
                    function()
                    end,
                    {},
                },
                match = '#3 (function expected, got table',
            },
        }) do
            local err = assert.throws(function()
                iohook.hook(unpack(v.args))
            end)
            assert.match(err, v.match)
        end

        -- test that endfn is not called if the hookfn function is not called
        call_hookfn = 0
        call_startfn = 0
        call_endfn = 0
        iohook.hook(hookfn, nil, endfn)
        iohook.unhook(hookfn, nil, endfn)
        assert.equal(call_startfn, 0)
        assert.equal(call_hookfn, 0)
        assert.equal(call_endfn, 0)
        assert.is_nil(hookargs)
    end)

    _G.print = print_bk
    _G.io.stdout = stdout_bk
    _G.io.stderr = stderr_bk
    assert(ok, err)
end

test_iohook()
