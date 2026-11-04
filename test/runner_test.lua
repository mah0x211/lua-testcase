require('luacov')
local pcall = pcall
local assert = require('assert')

local function test_runner()
    local fs = require('testcase.filesystem')
    local ok, err = pcall(function()
        local timer = require('testcase.timer').new()
        local registry = require('testcase.registry')
        local runner = require('testcase.runner')
        registry.clear()

        -- luacheck: ignore times
        local times = {}
        local calls = {}
        local before_all_error = false
        local before_each_error = false
        local after_each_error = false
        local after_all_error = true
        local before_all = function()
            calls.before_all = 1 + (calls.before_all or 0)
            times.before_all = timer:elapsed()
            if before_all_error then
                error('failed to before_all')
            end
        end
        local before_each = function()
            calls.before_each = 1 + (calls.before_each or 0)
            times.before_each = timer:elapsed()
            if before_each_error then
                error('failed to before_each')
            end
        end
        local after_each = function()
            calls.after_each = 1 + (calls.after_each or 0)
            times.after_each = timer:elapsed()
            if after_each_error then
                error('failed to after_each')
            end
        end
        local after_all = function()
            calls.after_all = 1 + (calls.after_all or 0)
            times.after_all = timer:elapsed()
            print('call after_all')
            if after_all_error then
                error('failed to after_all')
            end
        end
        local foofn = function()
            calls.foofn = 1 + (calls.foofn or 0)
            times.foofn = timer:elapsed()
        end
        local barfn = function()
            calls.barfn = 1 + (calls.barfn or 0)
            times.barfn = timer:elapsed()
        end
        local bazfn = function()
            calls.bazfn = 1 + (calls.bazfn or 0)
            times.bazfn = timer:elapsed()
            print('call bazfn')
            error('failed to bazfn')
        end

        for name, func in pairs({
            bar = barfn,
            foo = foofn,
            baz = bazfn,
            before_all = before_all,
            before_each = before_each,
            after_all = after_all,
            after_each = after_each,
        }) do
            local err = registry.add(name, func)
            assert(not err, err)
        end
        local list = registry.getlist()

        -- test that runner cannot run while blocking
        runner.block()
        timer:start()
        calls = {}
        times = {}
        local ok, err, nsuccess, nfailures, t = runner.run(list)
        assert(not ok, 'runner ran')
        assert.is_nil(nsuccess)
        assert.is_nil(nfailures)
        assert(not t, 'runner returns timer')
        assert.equal(err, 'cannot run test cases while blocking')
        assert.empty(times)
        assert.empty(calls)

        -- test that an empty selection runs all tests after unblocking
        runner.unblock()
        timer:start()
        calls = {}
        times = {}
        ok, err, nsuccess, nfailures, t = runner.run(list, {})
        assert(ok, 'runner did not run')
        assert.equal(nsuccess, 2)
        assert.equal(nfailures, 1)
        assert(t, 'runner did not returns the timer')
        assert(not err, 'runner returns an error')
        assert.equal(calls, {
            before_all = 1,
            before_each = 3,
            foofn = 1,
            barfn = 1,
            bazfn = 1,
            after_each = 3,
            after_all = 1,
        })
        assert.less(times.before_all, times.foofn)
        assert.less(times.foofn, times.barfn)
        assert.less(times.barfn, times.before_each)
        assert.less(times.before_each, times.bazfn)
        assert.less(times.bazfn, times.after_each)
        assert.less(times.after_each, times.after_all)

        -- test that runner executes only selected test cases
        calls = {}
        times = {}
        after_all_error = false
        ok, err, nsuccess, nfailures, t = runner.run(list, {
            'foo',
        })
        after_all_error = true
        assert(ok, 'runner did not run')
        assert.equal(nsuccess, 1)
        assert.equal(nfailures, 0)
        assert(t, 'runner did not returns the timer')
        assert(not err, 'runner returns an error')
        assert.equal(calls, {
            before_all = 1,
            before_each = 1,
            foofn = 1,
            after_each = 1,
            after_all = 1,
        })

        -- test that stops all tests when error occurs in before_all
        calls = {}
        times = {}
        before_all_error = true
        ok, err, nsuccess, nfailures, t = runner.run(list)
        before_all_error = false
        assert(ok, 'runner did not run')
        assert.equal(nsuccess, 0)
        assert.equal(nfailures, 3)
        assert(t, 'runner did not returns the timer')
        assert(not err, 'runner returns an error')
        assert.equal(calls, {
            before_all = 1,
        })

        -- test that stops all tests when error occurs in before_each
        calls = {}
        times = {}
        before_each_error = true
        ok, err, nsuccess, nfailures, t = runner.run(list)
        before_each_error = false
        assert(ok, 'runner did not run')
        assert.equal(nsuccess, 0)
        assert.equal(nfailures, 3)
        assert(t, 'runner did not returns the timer')
        assert(not err, 'runner returns an error')
        assert.equal(calls, {
            before_all = 1,
            before_each = 1,
            after_all = 1,
        })

        -- test that stops all tests when error occurs in before_each
        calls = {}
        times = {}
        after_each_error = true
        ok, err, nsuccess, nfailures, t = runner.run(list)
        after_each_error = false
        assert(ok, 'runner did not run')
        assert.equal(nsuccess, 1)
        assert.equal(nfailures, 2)
        assert(t, 'runner did not returns the timer')
        assert(not err, 'runner returns an error')
        assert.equal(calls, {
            before_all = 1,
            before_each = 1,
            after_each = 1,
            after_all = 1,
            foofn = 1,
        })

        -- test that a globally missing test case prevents test execution
        calls = {}
        times = {}
        ok, err, nsuccess, nfailures, t = runner.run(list, {
            'foo',
            'missing',
        })
        assert(not ok, 'runner did not report a missing test case')
        assert.equal(err, 'specified testcases not found')
        assert.is_nil(nsuccess)
        assert.is_nil(nfailures)
        assert.is_nil(t)
        assert.empty(calls)
    end)

    fs.chdir()
    assert(ok, err)
end

local function test_hook_errors()
    local runner = require('testcase.runner')

    for _, name in ipairs({
        'before_all',
        'before_each',
        'after_each',
        'after_all',
    }) do
        for ntest = 0, 1 do
            local src = {
                name = 'hook_errors',
                dirname = '.',
                tests = {},
            }
            if ntest > 0 then
                src.tests[1] = {
                    name = 'pass',
                    func = function()
                    end,
                }
            end
            src[name] = function()
                error('HOOK_ERROR_' .. name)
            end

            local ok, err, nsuccess, nfailure, _, errors = runner.run({src})
            local called = ntest > 0 or name == 'before_all' or
                               name == 'after_all'
            local blocked = name == 'before_all' or name == 'before_each'
            assert.is_true(ok)
            assert.is_nil(err)
            assert.equal(nsuccess, blocked and 0 or ntest)
            assert.equal(nfailure, blocked and ntest or 0)
            assert.equal(errors.count, called and 1 or 0)
            assert.equal(#errors, called and 1 or 0)
            if called then
                assert.equal(errors[1].name, src.name)
                assert.equal(#errors[1].errors, 1)
                assert.equal(errors[1].errors[1].name, name)
                assert.match(errors[1].errors[1].error, 'HOOK_ERROR_' .. name)
            end
        end
    end
end

test_runner()
test_hook_errors()
