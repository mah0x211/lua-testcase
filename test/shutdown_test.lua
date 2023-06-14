local assert = require('assert')
local errno = require('errno')
local socketpair = require('testcase.socketpair')
local shutdown = require('testcase.shutdown')

local function test_shutdown()
    -- test that shutdown a socket file descriptor
    local s1, _ = assert(socketpair())
    assert(shutdown(s1:fd()))

    -- test that shutdown the read side of a socket file descriptor
    s1, _ = assert(socketpair())
    assert(shutdown(s1:fd(), 'rd'))

    -- test that shutdown the write side of a socket file descriptor
    assert(shutdown(s1:fd(), 'wr'))

    -- test that cannot shutdown a non-socket file descriptor
    local f = assert(io.tmpfile())
    local ok, err = shutdown(f)
    assert.is_false(ok)
    assert.equal(err.type, errno.ENOTSOCK)
end

test_shutdown()
