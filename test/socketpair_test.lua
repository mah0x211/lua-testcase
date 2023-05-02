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

local function test_fd()
    local s1, s2 = assert(socketpair(true))
    for _, sock in ipairs({
        s1,
        s2,
    }) do
        assert.greater(sock:fd(), 0)
    end
end

local function test_nonblock()
    local s1, s2 = assert(socketpair(true))
    for _, sock in ipairs({
        s1,
        s2,
    }) do
        -- test that return true if set nonblock
        assert.is_true(sock:nonblock())

        -- test that set nonblock to false and return previous value
        assert.is_true(sock:nonblock(false))
        assert.is_false(sock:nonblock())

        -- test that throw error if argument is not a boolean
        local err = assert.throws(function()
            sock:nonblock('true')
        end)
        assert.match(err, 'boolean expected', false)
    end
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
    assert.equal(s1:fd(), -1)
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
test_fd()
test_nonblock()
test_read_write_close()
