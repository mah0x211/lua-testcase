# lua-testcase

[![test](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-testcase/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-testcase?branch=master)

a small helper tool to run the test files.

## Installation

```
luarocks install testcase
```

## Usage

```
testcase - a small helper tool to run the test files

Usage:
  testcase [--coverage] [--checkall] <pathname>

Options:
  --coverage    do code coverage analysis with `luacov`
  --checkall    any file with a `.lua` extension will be evaluated as a test file.
```

### Assertion module

The original assert function will be renamed to `_G._assert` and the https://github.com/mah0x211/lua-assert module will be loaded into the global variable `assert`.


### How to write a test

describe a test like a [example/example_test.lua](example/example_test.lua), and execute the installed `testcase ./example/` command.

the `testcase` command searches for a test file with the suffix `_test.lua` in the specified `pathname` and executes the test file. if the `pathname` is a file, the `testcase` command will execute the test file.

the test file must be named with the suffix `_test.lua`. if it does not have this suffix, it will be executed as a test file for [testing private functions](#testing-private-functions).


**NOTE**: a `collectgarbage('collect')` is always executed before executing user-defined functions.

```lua
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


### Testing private functions

testcase can be used to tests private functions with the inline option `lua-testcase: <boolean>`.

the inline option is enabled by putting `lua-testcase: true` in the one-line comment of Lua. To disable it, specify `false`. Then, in the next line of the inline option, declare the placeholder `local testcase = {}`.

when you run the testcase command, replace the placeholder with `local testcase = require(‘testcase')` and run the test. When you run the testcase command, the placeholder will be replaced with `local testcase = require('testcase)` and the test will be executed.


```lua
-- The built-in assert function will be replaced by the lua-assert module.
-- The name of the original assert function has been changed to _assert.
-- local assert = require('assert')

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
```
