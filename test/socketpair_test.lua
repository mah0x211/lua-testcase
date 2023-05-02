local assert = require('assert')
local socketpair = require('testcase.socketpair')

local function test_new()
    -- test that socketpair() returns two socket objects
    local s1, s2 = assert(socketpair())
    assert.match(tostring(s1), '^testcase.socketpair: ', false)
    assert.match(tostring(s2), '^testcase.socketpair: ', false)

    -- test that throw error if argument is not a boolean
    local err = assert.throws(function()
        socketpair('true')
    end)
    assert.match(err, 'boolean expected', false)
end

local function test_read_write_close()
    local s1, s2 = assert(socketpair(true))

    -- test that read nothing
    local msg, err, again = s1:read()
    assert.is_nil(msg)
    assert.is_nil(err)
    assert.is_true(again)

    -- test that write
    local n
    n, err, again = s1:write('hello')
    assert.equal(n, 5)
    assert.is_nil(err)
    assert.is_nil(again)

    -- test that read 'hello'
    msg, err, again = s2:read()
    assert.equal(msg, 'hello')
    assert.is_nil(err)
    assert.is_nil(again)

    -- test that return error if operate on closed socket
    s1:close()
    msg, err, again = s1:read()
    assert.is_nil(msg)
    assert.is_string(err)
    assert.is_nil(again)

    -- test that return nil if peer socket is closed
    msg, err, again = s2:read()
    assert.is_nil(msg)
    assert.is_nil(err)
    assert.is_nil(again)
end

test_new()
test_read_write_close()
