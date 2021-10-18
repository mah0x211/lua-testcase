require('luacov')
local unpack = unpack or table.unpack
local assert = require('assertex')
local before_all = function()
end
local before_each = function()
end
local after_all = function()
end
local after_each = function()
end
local foofn = function()
end
local barfn = function()
end

local function test_registry_add()
    local registry = require('testcase.registry')
    registry.clear()

    -- test that add name and function
    for name, func in pairs({
        bar = barfn,
        foo = foofn,
        before_all = before_all,
        before_each = before_each,
        after_all = after_all,
        after_each = after_each,
    }) do

        local err = registry.add(name, func)
        assert(not err, err)
    end

    -- test that cannot add if name already defined
    for name, func in pairs({
        bar = barfn,
        foo = foofn,
        before_all = before_all,
        before_each = before_each,
        after_all = after_all,
        after_each = after_each,
    }) do
        local err = registry.add(name, func)
        assert.match(err, 'already defined at')
    end

    -- test that returns error with invalid arguments
    for _, v in ipairs({
        {
            args = {true},
            match = '#1 (string expected, got boolean)',
        },
        {
            args = {'hello', {}},
            match = '#2 (function expected, got table)',
        },
    }) do
        local err = registry.add(unpack(v.args))
        assert.match(err, v.match)
    end
end

local function test_registry_getlist()
    local registry = require('testcase.registry')
    registry.clear()

    for name, func in pairs({
        bar = barfn,
        foo = foofn,
        before_all = before_all,
        before_each = before_each,
        after_all = after_all,
        after_each = after_each,
    }) do
        local err = registry.add(name, func)
        assert(not err, err)
    end

    -- test that get list of added functions
    local files, ntest = registry.getlist()
    assert.equal(ntest, 2)
    assert.equal(#files, 1)
    assert.match(files[1].realpath, '/registry_test.lua')
    files[1].realpath = nil
    assert.equal(files[1], {
        after_all = after_all,
        after_each = after_each,
        before_all = before_all,
        before_each = before_each,
        basename = 'registry_test.lua',
        dirname = 'test',
        name = 'test/registry_test.lua',
        tests = {
            -- sorted by lineno
            {
                name = 'foo',
                func = foofn,
                lineno = 12,
            },
            {
                name = 'bar',
                func = barfn,
                lineno = 14,
            },
        },
    })
end

test_registry_add()
test_registry_getlist()
