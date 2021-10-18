# lua-testcase

[![test](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-testcase/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-testcase?branch=master)

a small helper tool to run the test files.

## Installation

```
luarocks install testcase
```

## Usage

describe a test like a [example/example_test.lua](example/example_test.lua), and execute the installed `testcase ./example/` command.

the `testcase` command searches for a test file with the suffix `_test.lua` in the specified `pathname` and executes the test file. if the `pathname` is a file, the `testcase` command will execute the test file.

```lua
local testcase = require('testcase')
local assert = require('assertex')

-- measure code coverage with luacov module
-- require('luacov')

-- Setup and Teardown
-- following names are reserved as setup and teardown functions;
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
```

run `testcase` command.

```
$ testcase example/

Test on 2021-10-18T10:46:13+0900
================================================================================

Total: 2 test cases in 1 files.

- example/example_test.lua has `2` test cases

--------------------------------------------------------------------------------
example/example_test.lua: 2 test cases
--------------------------------------------------------------------------------
- before_all
  >     do before_all
- before_each
  >     do before_each
- hello ...   
  >     do hello
  ok (10.830 us)
- after_each
  >     do after_each
- before_each
  >     do before_each
- world ...   
  >     do world
  fail (17.314 us)  
  >     example/example_test.lua:45: <function: 0x7fae35c05d70> should throw an error
- after_each
  >     do after_each
- after_all
  >     do after_all

1 successes, 1 failures

--------------------------------------------------------------------------------

### Total: 1 successes, 1 failures (110.459 us)

```
