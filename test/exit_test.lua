require('luacov')
local exit = os.exit
local assert = require('assertex')

local function test_exit()
    local testcase_exit = require('testcase.exit')

    -- test that os.exit is replaced after testcase.exit module loaded
    assert.not_equal(os.exit, exit)

    -- test that os.exit throws error
    local err = assert.throws(function()
        os.exit('exit hook')
    end)
    assert.match(err, 'OS_EXIT%s+exit hook', false)

    -- test that args contains arguments of exit
    assert.equal(testcase_exit.getargs(), {
        'exit hook',
    })
end

test_exit()
