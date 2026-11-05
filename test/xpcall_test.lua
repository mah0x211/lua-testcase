require('luacov')
local assert = require('assert')
local xpcall = require('testcase.xpcall')

local function test_success()
    local called = false
    local function check_results(...)
        assert.equal(select('#', ...), 1)
        assert.is_true(...)
    end
    check_results(xpcall(function()
        return 'ignored'
    end, function()
        called = true
    end))
    assert.is_false(called)
end

local function test_error_handler_once()
    local calls = 0
    local ok, result = xpcall(function()
        error('original', 0)
    end, function(err)
        calls = calls + 1
        return 'handled:' .. err
    end)
    assert.is_false(ok)
    assert.equal(calls, 1)
    assert.equal(result, 'handled:original')
end

local function test_error_objects()
    for _, case in ipairs({
        {value = {}},
        {value = nil},
        {value = false},
        {value = 42},
    }) do
        local original = {}
        local function check_results(...)
            assert.equal(select('#', ...), 2)
            local ok, result = ...
            assert.is_false(ok)
            assert(result == case.value)
        end
        check_results(xpcall(function()
            error(original)
        end, function(err)
            assert(err == original)
            return case.value
        end))
    end
end

local function test_handler_error_is_protected()
    local survived, ok, result = pcall(xpcall, function()
        error('original', 0)
    end, function()
        error('handler failed', 0)
    end)
    assert.is_true(survived)
    assert.is_false(ok)
    assert.is_string(result)
    assert.match(result, 'error')
end

local function test_arguments()
    local err = assert.throws(function()
        xpcall(nil, function()
        end)
    end)
    assert.match(err, 'function expected')
    err = assert.throws(function()
        xpcall(function()
        end, nil)
    end)
    assert.match(err, 'function expected')
end

test_success()
test_error_handler_once()
test_error_objects()
test_handler_error_is_protected()
test_arguments()
