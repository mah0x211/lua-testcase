require('luacov')
local assert = require('assertex')
local foofn = function()
end

local function test_testcase()
    local testcase = require('testcase')
    local registry = require('testcase.registry')
    registry.clear()

    -- test that add name and function
    testcase.foo = foofn

    -- test that throws if name already defined
    local err = assert.throws(function()
        testcase.foo = foofn
    end)
    assert.match(err, 'already defined at')
end

test_testcase()
