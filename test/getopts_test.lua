require('luacov')
local assert = require('assert')

local function test_getopts()
    local getopts = require('testcase.getopts')

    -- test that return a table of parsed arguments
    local opts = getopts({
        'arg1',
        '--opt-arg1=opt-arg1-val',
        '-opt-arg2=opt-arg2-val',
        'arg2',
        '--flag-arg',
    })
    assert.equal(opts, {
        [1] = 'arg1',
        [2] = 'arg2',
        ['--opt-arg1'] = 'opt-arg1-val',
        ['-opt-arg2'] = 'opt-arg2-val',
        ['--flag-arg'] = true,
    })
end

test_getopts()
