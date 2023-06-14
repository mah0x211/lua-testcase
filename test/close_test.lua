local assert = require('assert')
local errno = require('errno')
local close = require('testcase.close')

local function test_close()
    local f = assert(io.tmpfile())

    -- test that close a file descriptor
    assert(close(f))
    local _, err = f:close()
    assert.is_nil(_)
    assert.match(err, errno.EBADF.message)
end

test_close()
