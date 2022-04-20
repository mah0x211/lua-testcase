local assert = require('assert')
local timer = require('testcase.timer')

local function val2ns(v, unit)
    local us = 1000
    local ms = us * 1000
    local sec = ms * 1000
    local min = sec * 60
    local tbl = {
        ns = 1,
        us = us,
        ms = ms,
        s = sec,
        m = min,
    }

    return v * tbl[unit]
end

local function test_usleep()
    -- test that sleep 60ms
    local t = timer.nanotime()
    timer.usleep(60000)
    t = timer.nanotime() - t
    assert.is_true(0.05 < t and t < 0.07)
end

local function test_sleep()
    -- test that sleep 60ms
    local t = timer.nanotime()
    timer.sleep(0.06)
    t = timer.nanotime() - t
    assert.is_true(0.05 < t and t < 0.07)
end

local function test_new()
    -- test that return a instance of testcase.timer
    local t = timer.new()
    assert.match(tostring(t), '^testcase.timer: ', false)
end

local function test_start()
    local t = timer.new()

    -- test that timer:start() returns true
    assert(t:start())
end

local function test_elapsed()
    local t = timer.new()
    t:start()
    t:stop()
    -- sleep 1 sec
    timer.sleep(1)

    -- test that timer:elpased() returns a value of clock_gettime
    local v, fmt, unit = assert(t:elapsed())
    assert.is_unsigned(v)
    assert.equal(fmt, '%.3f s')
    assert.equal(unit, 's')

    -- test that the elapsed time increases
    local prev = val2ns(v, unit)
    local _
    v, _, unit = assert(t:elapsed())
    assert.equal(unit, 's')
    v = val2ns(v, unit)
    assert.greater(v, prev)

    -- test that timer:elpased() returns a value of clock_gettime - start time
    assert(t:start())
    prev = v
    v, _, unit = assert(t:elapsed())
    assert.less(val2ns(v, unit), prev)
end

local function test_stop_total_reset()
    local t = timer.new()
    assert(t:start())

    -- test that timer:stop() returns the elapsed time, time format and time unit
    local v, fmt, unit = assert(t:stop())
    assert.is_unsigned(v)
    assert.is_string(fmt)
    assert.is_string(unit)

    -- test that timer:total() returns the sum of elapsed time
    local total, tfmt, tunit = assert(t:total())
    assert.equal(total, v)
    assert.equal(tfmt, fmt)
    assert.equal(tunit, unit)

    local v1 = val2ns(v, unit)
    local v2, _
    v2, _, unit = assert(t:stop())
    v2 = val2ns(v2, unit)

    total, _, unit = assert(t:total())
    total = val2ns(total, unit)
    assert.equal(total, v1 + v2)

    -- test that timer:reset() that clear internal values of total and start
    t:reset()
    total, tfmt, tunit = assert(t:total())
    assert.equal(total, 0.0)
    assert.equal(tfmt, '%d ns')
    assert.equal(tunit, 'ns')
end

test_usleep()
test_sleep()
test_new()
test_start()
test_elapsed()
test_stop_total_reset()
