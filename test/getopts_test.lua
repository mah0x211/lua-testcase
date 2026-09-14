require('luacov')
local assert = require('assert')

local function test_getopts()
    local getopts = require('testcase.getopts')

    -- test that returns normalized command options and pathnames
    local opts, err = getopts({
        'arg1',
        '--help',
        '--coverage',
        '--checkall',
        '--testcase=foo,foo,bar',
        '--unknown=value',
        'arg2',
    })
    assert(not err, err)
    assert.equal(opts, {
        [1] = 'arg1',
        [2] = 'arg2',
        help = true,
        coverage = true,
        checkall = true,
        testcase = {
            'foo',
            'bar',
        },
    })

    -- test default option values
    opts, err = getopts({
        'arg1',
    })
    assert(not err, err)
    assert.equal(opts, {
        [1] = 'arg1',
        help = false,
        coverage = false,
        checkall = false,
        testcase = {},
    })

    -- test that repeated testcase options are rejected
    opts, err = getopts({
        '--testcase=foo',
        '--testcase=bar',
    })
    assert.is_nil(opts)
    assert.match(err, 'must not be specified more than once')

    -- test that invalid testcase values are rejected
    for _, option in ipairs({
        '--testcase',
        '--testcase=',
        '--testcase=,foo',
        '--testcase=foo,',
        '--testcase=foo,,bar',
    }) do
        opts, err = getopts({
            option,
        })
        assert.is_nil(opts)
        assert.match(err, 'requires one or more test case names')
    end
end

test_getopts()
