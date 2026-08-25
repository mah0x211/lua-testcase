local assert = require('assert')
local errno = require('errno')
local rlimit = require('testcase.rlimit')

-- all resource names accepted by rlimit()
local RESOURCE_NAMES = {
    'as',
    'core',
    'cpu',
    'data',
    'fsize',
    'locks',
    'memlock',
    'msgqueue',
    'nice',
    'nofile',
    'nproc',
    'rss',
    'rtprio',
    'rttime',
    'sigpending',
    'stack',
}

-- a limit is either -1 (RLIM_INFINITY) or a non-negative integer
local function islimit(v)
    return v == -1 or (v >= 0 and math.floor(v) == v)
end

local function test_get()
    local rlim, err = rlimit('nofile')
    assert(not err, err)
    assert(rlim, 'expected a rlimit table')
    assert.equal(rlim.resource, 'nofile')
    assert(islimit(rlim.cur), 'cur must be -1 or a non-negative integer')
    assert(islimit(rlim.max), 'max must be -1 or a non-negative integer')
    if rlim.cur ~= -1 and rlim.max ~= -1 then
        assert(rlim.cur <= rlim.max, 'cur must not exceed max')
    end
end

local function test_get_all_resources()
    -- every known resource name either returns its limits or fails with
    -- ENOSYS when the platform does not support it
    for _, name in ipairs(RESOURCE_NAMES) do
        local rlim, err = rlimit(name)
        if rlim then
            assert.equal(rlim.resource, name)
            assert(islimit(rlim.cur), name .. ': invalid cur')
            assert(islimit(rlim.max), name .. ': invalid max')
        else
            assert.equal(err.type, errno.ENOSYS)
        end
    end
end

local function test_set_cur()
    local orig, err = rlimit('nofile')
    assert(not err, err)
    assert(orig, 'expected a rlimit table')

    -- lower the soft limit to 16 (well below any usable limit), then restore
    local newcur = (orig.cur ~= -1 and orig.cur <= 16) and orig.cur or 16
    local rlim, e = rlimit('nofile', newcur)
    assert(not e, e)
    assert(rlim, 'expected a rlimit table')
    assert.equal(rlim.resource, 'nofile')
    assert.equal(rlim.cur, newcur)
    -- the hard limit must be unchanged
    assert.equal(rlim.max, orig.max)

    -- the getter must observe the new value
    rlim, e = rlimit('nofile')
    assert(not e, e)
    assert.equal(rlim.cur, newcur)

    -- restore the original soft limit (always allowed: cur <= max)
    rlim, e = rlimit('nofile', orig.cur)
    assert(not e, e)
    assert.equal(rlim.cur, orig.cur)
    assert.equal(rlim.max, orig.max)
end

local function test_set_infinity()
    -- -1 is a valid argument meaning RLIM_INFINITY; it must never raise an
    -- argument error
    local orig, err = rlimit('nofile')
    assert(not err, err)

    local ok, rlim, e = pcall(rlimit, 'nofile', -1)
    assert(ok, 'must not raise an argument error for -1')
    if rlim then
        -- raising the soft limit up to the hard limit succeeded
        assert.equal(rlim.cur, -1)
        assert.equal(rlim.max, orig.max)
        -- restore the original soft limit
        local restored, e2 = rlimit('nofile', orig.cur)
        assert(not e2, e2)
        assert.equal(restored.cur, orig.cur)
    else
        -- raising the soft limit beyond a finite hard limit fails with EINVAL
        assert.equal(e.type, errno.EINVAL)
        -- the failed setrlimit must not change the current limits
        local cur, e2 = rlimit('nofile')
        assert(not e2, e2)
        assert.equal(cur.cur, orig.cur)
    end
end

local function test_cur_gt_max()
    local orig, err = rlimit('nofile')
    assert(not err, err)

    if orig.max ~= -1 then
        -- a soft limit above the hard limit is rejected with EINVAL
        local rlim, e = rlimit('nofile', orig.max + 1)
        assert.is_nil(rlim)
        assert(e, 'expected an error for cur > max')
        assert.equal(e.type, errno.EINVAL)
        -- limits must be unchanged after the failed setrlimit
        rlim, e = rlimit('nofile')
        assert(not e, e)
        assert.equal(rlim.cur, orig.cur)
        assert.equal(rlim.max, orig.max)
    end
end

local function test_invalid_resource()
    local ok, err = pcall(rlimit, 'unknown_resource')
    assert(not ok, 'expected an error for an unknown resource')
    assert.match(err, 'unknown_resource')
end

local function test_no_limits_specified()
    local ok, err = pcall(rlimit, 'nofile', nil)
    assert(not ok, 'expected an error when neither cur nor max is specified')
    assert.match(err, 'either cur or max must be specified')

    ok = pcall(rlimit, 'nofile', nil, nil)
    assert(not ok, 'expected an error when neither cur nor max is specified')
end

local function test_negative_limits()
    local ok, err = pcall(rlimit, 'nofile', -2)
    assert(not ok, 'expected an error for a negative cur')
    assert.match(err, 'invalid cur')

    ok, err = pcall(rlimit, 'nofile', nil, -100)
    assert(not ok, 'expected an error for a negative max')
    assert.match(err, 'invalid max')
end

test_get()
test_get_all_resources()
test_set_cur()
test_set_infinity()
test_cur_gt_max()
test_invalid_resource()
test_no_limits_specified()
test_negative_limits()
