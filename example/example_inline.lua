local assert = require('assertex')

-- test private functions using the `lua-testcase: <boolean>` inline option.
-- and be sure to declare the placeholder `local testcase = {}` at the next line.
-- lua-testcase: true
local testcase = {}

function testcase.inline_hello()
    print('do inline hello')
end

function testcase.inline_world()
    assert.throws(function()
        print('do inline world')
    end)
end
