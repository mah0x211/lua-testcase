require('luacov')
local pcall = pcall
local date = os.date
local remove = os.remove
local open = io.open
local assert = require('assert')

local function truncate(filename)
    local f = assert(open(filename, 'w'))
    f:close()
end

local function test_eval()
    local testfile = date('%FT%H%M%S%Z') .. '_test.lua'
    local inlinefile = date('%FT%H%M%S%Z') .. '.lua'
    local ftest = assert(open(testfile, 'w'))
    local finline = assert(open(inlinefile, 'w'))
    ftest:setvbuf('no')
    finline:setvbuf('no')

    local ok, err = pcall(function()
        local eval = require('testcase.eval')
        local registry = require('testcase.registry')

        -- test that eval a file with suffix '_test.lua'
        registry.clear()
        assert(eval('example/example_test.lua'))
        local list, nfunc = registry.getlist()
        assert.equal(#list, 1)
        assert.equal(nfunc, 2)
        assert.equal(list[1].name, 'example/example_test.lua')

        -- test that eval a file contains inline option
        registry.clear()
        assert(eval('example/example_inline.lua'))
        list, nfunc = registry.getlist()
        assert.equal(#list, 1)
        assert.equal(nfunc, 2)
        assert.equal(list[1].name, 'example/example_inline.lua')

        -- test that returns true if no inline option defined
        registry.clear()
        assert(eval(inlinefile))
        assert.empty(registry.getlist())

        -- test that no test functions are registered
        registry.clear()
        finline:seek('set', 0)
        assert(finline:write([[-- lua-testcase: false]]))
        assert(eval(inlinefile))
        truncate(inlinefile)
        assert.empty(registry.getlist())

        -- test that returns error with non exits test file
        local ok, err = eval('no_file_test.lua')
        assert(not ok, 'eval() returns true')
        assert.match(err, 'cannot .+ no_file_test.lua', false)

        -- test that returns error with non exits inline file
        ok, err = eval('no_file_inline.lua')
        assert(not ok, 'eval() returns true')
        assert.match(err, 'such file')

        -- test that returns error with eval an invalid test file
        assert(ftest:seek('set', 0))
        assert(ftest:write([[x = nil + 1]]))
        ok, err = eval(testfile)
        assert(not ok, 'eval() returns true')
        assert.match(err, 'arithmetic on a nil value')

        -- test that returns invalid option value error
        finline:seek('set', 0)
        assert(finline:write([[-- lua-testcase: foo]]))
        ok, err = eval(inlinefile)
        truncate(inlinefile)
        assert(not ok, 'eval() returns true')
        assert.match(err, 'invalid inline option')

        -- test that returns invalid option value error
        for _, v in ipairs({
            '-- lua-testcase: true',
            '\n\n-- lua-testcase: true\n\n',
            '\n-- lua-testcase: true\n\nlocal testcase = {}',
            '--lua-testcase: true\nlocal testcase',
        }) do
            finline:seek('set', 0)
            assert(finline:write(v))
            ok, err = eval(inlinefile)
            truncate(inlinefile)
            assert(not ok, 'eval() returns true')
            assert.match(err, 'placeholder .+ not declared at the next line',
                         false)
        end

        -- test that cannot inline option defined twice
        finline:seek('set', 0)
        assert(finline:write([[
            --lua-testcase:true
            local testcase = {}

            -- lua-testcase: true
        ]]))
        ok, err = eval(inlinefile)
        truncate(inlinefile)
        assert(not ok, 'eval() returns true')
        assert.match(err, 'its already defined in lineno', false)
    end)

    for filename, f in pairs({
        [testfile] = ftest,
        [inlinefile] = finline,
    }) do
        f:close()
        assert(remove(filename))
    end
    assert(ok, err)
end

test_eval()
