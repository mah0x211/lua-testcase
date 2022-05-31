local assert = require('assert')
local fork = require('testcase.fork')
local getpid = require('testcase.getpid')

local function test_getpid()
    -- test that get a pid
    local pid = assert(getpid())
    assert.is_uint(pid)

    -- test that get a child pid
    local p = assert(fork())
    if p:is_child() then
        assert.not_equal(getpid(), pid)
        return
    end

    local res = assert(p:wait())
    assert.equal(res.exit, 0)
end

test_getpid()
