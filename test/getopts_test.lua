require('luacov')
local assert = require('assert')

local function test_getopts()
    local getopts = require('testcase.getopts')

    -- test that returns normalized command options and pathnames
    local opts = getopts({
        'arg1',
        '--help',
        '--coverage',
        '--checkall',
        '--unknown=value',
        'arg2',
    })
    assert.equal(opts, {
        [1] = 'arg1',
        [2] = 'arg2',
        help = true,
        coverage = true,
        checkall = true,
    })

    -- test default option values
    opts = getopts({
        'arg1',
    })
    assert.equal(opts, {
        [1] = 'arg1',
        help = false,
        coverage = false,
        checkall = false,
    })
end

test_getopts()
