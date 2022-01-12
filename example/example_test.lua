local testcase = require('testcase')

-- The built-in assert function will be replaced by the lua-assert module.
-- The name of the original assert function has been changed to _assert.
-- local assert = require('assert')

-- measure code coverage with luacov module
-- require('luacov')

-- Setup and Teardown
-- following names are reserved for setup and teardown functions;
--
--   before_all
--   after_all
--   before_each
--   after_each
--
-- these functions are enabled only in this test file and cannot be defined
-- twice.

-- before_all is called only once at the start.
-- if an error occurs in before_all, stop the this test immediately without
-- calling any function.
function testcase.before_all()
    print('do before_all')
end

-- after_all is called only once at the end.
function testcase.after_all()
    print('do after_all')
end

-- before_each is called before run each test.
-- if an error occurs in before_each, stop the run of all susequent tests
-- without calling the after_each function.
function testcase.before_each()
    print('do before_each')
end

-- after_each is called after ran each test.
-- if an error occurs in after_each, stop the run of all susequent tests.
function testcase.after_each()
    print('do after_each')
end

function testcase.hello()
    print('do hello')
end

function testcase.world()
    assert.throws(function()
        print('do world')
    end)
end
