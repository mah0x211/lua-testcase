require('luacov')
local dump = require('dump')
local unpack = unpack or table.unpack
local pcall = pcall
local assert = require('assertex')

local function test_printer()
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

    local ok, err = pcall(function()
        local printer = require('testcase.printer')

        -- test that print with format
        local p = printer.new()
        argv = {}
        p('format value %q ', 'foo', 'and print following values as a string: ',
          1, true, false)
        assert.equal(argv, {
            '',
            'format value "foo" and print following values as a string: 1truefalse',
        })

        -- test that arguments is not formatted if first argument is not format string
        argv = {}
        p('non-format string %%', 'hello', 'world')
        assert.equal(argv, {
            '',
            'non-format string %%helloworld',
        })

        argv = {}
        p(1, 'non-format string %s', 'hello')
        assert.equal(argv, {
            '',
            '1non-format string %shello',
        })

        -- test that print each line with prefix, and suffix to last line
        p = printer.new('=prefix=', '=suffix=')
        argv = {}
        p('foo\nbar\n\nbaz\n')
        assert.equal(argv, {
            '=prefix=',
            'foo',
            '\n',
            '=prefix=',
            'bar',
            '\n',
            '=prefix=',
            '',
            '\n',
            '=prefix=',
            'baz',
            '\n',
            '=suffix=',
        })

        -- test that throw error if invalid format string
        local err = assert.throws(function()
            p('non-format string %', 'hello')
        end)
        assert.match(err, "invalid .+ 'format'", false)

        -- test that throw error with invalid arguments
        for _, v in ipairs({
            {
                args = {
                    true,
                },
                match = '#1 (nil or string',
            },
            {
                args = {
                    '',
                    true,
                },
                match = '#2 (nil or string',
            },
        }) do
            err = assert.throws(function()
                printer.new(unpack(v.args))
            end)
            assert.match(err, v.match)
        end
    end)

    _G.io.stdout = stdout
    assert(ok, err)
end

test_printer()
