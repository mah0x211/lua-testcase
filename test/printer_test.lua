require('luacov')
local unpack = unpack or table.unpack
local assert = require('assert')
local printer = require('testcase.printer')

local function test_new()
    -- test that return new instance of printer
    local p = printer.new()
    assert(p, 'new() did not returns new instance of printer')

    -- test that throws error with invalid arguments
    for _, v in ipairs({
        {
            arg = {
                true,
            },
            err = 'test',
        },
        {
            arg = {
                nil,
                {},
            },
            err = 'test',
        },
        {
            arg = {
                nil,
                nil,
                1,
            },
            err = 'test',
        },
    }) do
        local err = assert.throws(function()
            printer.new(unpack(v.arg))
        end)
        assert.match(err, v.err, false)
    end
end

local function test_parse_format()
    -- test that return 0 if an argument is not string
    for _, v in ipairs({
        1,
        true,
        false,
        {},
        function()
        end,
    }) do
        assert.equal(printer.parse_format(), 0)
    end

    -- test that returns number of params
    for _, v in ipairs({
        {
            fmt = '',
            nparam = 0,
        },
        {
            fmt = 'foo bar %',
            nparam = 1,
        },
        {
            fmt = 'foo %s bar %%d baz %q',
            nparam = 2,
        },
    }) do
        assert.equal(printer.parse_format(v.fmt), v.nparam)
    end
end

local function test_vstringify()
    -- test that returns all arguments as a single string without formatting
    assert.equal(printer.vstringify(false, 'foo %q baz', 'bar', 1, true, false),
                 'foo %q bazbar1truefalse')

    -- test that return string from arguments with formatting
    assert.equal(printer.vstringify(true, 'foo %q baz', 'bar', 1, true, false),
                 'foo "bar" baz1truefalse')

    -- test that return string from arguments without formatting
    assert.equal(printer.vstringify(true, 10, 'foo %q baz', 'bar', 1, true,
                                    false), '10foo %q bazbar1truefalse')

    -- test that throws an error with invalid format string
    local err = assert.throws(function()
        printer.vstringify(true, 'foo %', 'bar', 1, true, false)
    end)
    assert.match(err, "invalid .+ to 'format'", false)
end

local function test_call_printline()
    -- unrequire
    package.loaded['testcase.printer'] = nil
    _G['testcase.printer'] = nil
    -- hook stdout
    local stdout = _G.io.stdout
    local argv

    -- hook stdout
    _G.io.stdout = setmetatable({}, {
        __index = {
            setvbuf = function(_, ...)
                stdout:setvbuf(...)
            end,
            write = function(_, ...)
                for _, v in ipairs({
                    ...,
                }) do
                    argv[#argv + 1] = v
                end
            end,
        },
    })
    local printer = require('testcase.printer')

    -- test that print all arguments without prefix
    local p = printer.new()
    argv = {}
    p('format %q ', 'foo', ' a b ', 1, true, false)
    assert.equal(argv, {
        'format "foo"  a b 1truefalse',
    })

    -- test that print all arguments with prefix
    local prefix = 'hello > '
    p = printer.new(prefix)
    argv = {}
    p('format %q ', 'foo', ' a b ', 1, true, false, 'with\n\nnewline\n')
    assert.equal(argv, {
        prefix,
        'format "foo"  a b 1truefalsewith',
        '\n',
        prefix,
        '',
        '\n',
        prefix,
        'newline',
        '\n',
    })

    -- test that print all arguments and end with a suffix
    local suffix = '[done]'
    p = printer.new(prefix, suffix)
    argv = {}
    p('format %q ', 'foo', ' a b ', 1, true, false, 'with\n\nnewline\n')
    assert.equal(argv, {
        prefix,
        'format "foo"  a b 1truefalsewith',
        '\n',
        prefix,
        '',
        '\n',
        prefix,
        'newline',
        '\n',
        suffix,
    })

    -- test that print all arguments without formatting
    local suffix = '[done]'
    p = printer.new(prefix, suffix, false)
    argv = {}
    p('format %q ', 'foo', ' a b ', 1, true, false, 'with\n\nnewline\n')
    assert.equal(argv, {
        prefix,
        'format %q foo a b 1truefalsewith',
        '\n',
        prefix,
        '',
        '\n',
        prefix,
        'newline',
        '\n',
        suffix,
    })

    _G.io.stdout = stdout
    -- assert(ok, err)
end

test_new()
test_parse_format()
test_vstringify()
test_call_printline()
