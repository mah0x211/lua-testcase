local assert = require('assert')
local fork = require('testcase.fork')
local signal = require('testcase.signal')
local getpid = require('testcase.getpid')

local function test_tosignum()
    -- test that returns a signal number for a valid signal name
    local num = signal.tosignum('SIGTERM')
    assert.is_uint(num)
    assert.greater(num, 0)

    -- test that signal name lookup is case-insensitive
    assert.equal(signal.tosignum('sigterm'), num)
    assert.equal(signal.tosignum('SiGtErM'), num)

    -- test that SIGKILL is recognized
    local knum = signal.tosignum('SIGKILL')
    assert.is_uint(knum)
    assert.greater(knum, 0)

    -- test that returns nil for an unknown signal name
    assert.is_nil(signal.tosignum('SIGUNKNOWN_XYZ'))
end

local function test_tosigname()
    -- test that returns a signal name for a valid signal number
    local termnum = signal.tosignum('SIGTERM')
    local name = signal.tosigname(termnum)
    assert.equal(name, 'SIGTERM')

    -- test that returns a signal name for SIGKILL
    local killnum = signal.tosignum('SIGKILL')
    assert.equal(signal.tosigname(killnum), 'SIGKILL')

    -- test that returns nil for an unknown signal number
    assert.is_nil(signal.tosigname(999999))
end

local function test_kill()
    local pid = getpid()

    -- test that kill sends SIGWINCH to the current process (default action: ignore)
    local ok, err = signal.kill('SIGWINCH', pid)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that kill accepts signal number
    local signum = signal.tosignum('SIGWINCH')
    ok, err = signal.kill(signum, pid)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that kill is case-insensitive for signal name
    ok, err = signal.kill('sigwinch', pid)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that kill returns false and an error message for an invalid pid
    ok, err = signal.kill('SIGTERM', -999999)
    assert.is_false(ok)
    assert.is_string(err)

    -- test that kill raises an error for an invalid signal name
    local _, errmsg = pcall(signal.kill, 'SIGUNKNOWN_XYZ', pid)
    assert.is_string(errmsg)
end

local function test_raise()
    -- test that raise sends SIGWINCH to the current process (default action: ignore)
    local ok, err = signal.raise('SIGWINCH')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that raise accepts signal number
    local signum = signal.tosignum('SIGWINCH')
    ok, err = signal.raise(signum)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that raise is case-insensitive for signal name
    ok, err = signal.raise('sigwinch')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that raise raises an error for an invalid signal name
    local _, errmsg = pcall(signal.raise, 'SIGUNKNOWN_XYZ')
    assert.is_string(errmsg)
end

local function test_signames()
    local names = signal.signames()
    assert.is_table(names)

    -- test that every signal name maps to its number
    local termnum = signal.tosignum('SIGTERM')
    assert.equal(names['SIGTERM'], termnum)
    assert.equal(names['SIGKILL'], signal.tosignum('SIGKILL'))

    -- test that result[signum] is either a string (unique) or a table (aliases)
    local v = names[termnum]
    if type(v) == 'string' then
        assert.equal(v, 'SIGTERM')
    else
        assert.is_table(v)
        local found = false
        for _, name in ipairs(v) do
            if name == 'SIGTERM' then
                found = true
                break
            end
        end
        assert.is_true(found)
    end

    -- test that an unknown number is not in the table
    assert.is_nil(names[999999])
end

local function test_sigignore()
    -- test that sigignore sets SIG_IGN so the signal no longer terminates
    local ok, err = signal.sigignore('SIGUSR1')
    assert.is_true(ok)
    assert.is_nil(err)

    -- raise the now-ignored signal: process should continue
    ok, err = signal.raise('SIGUSR1')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that sigignore accepts signal number
    local signum = signal.tosignum('SIGUSR2')
    ok, err = signal.sigignore(signum)
    assert.is_true(ok)
    assert.is_nil(err)

    -- restore defaults
    signal.sigdefault('SIGUSR1')
    signal.sigdefault('SIGUSR2')

    -- test that sigignore raises an error for an invalid signal name
    local _, errmsg = pcall(signal.sigignore, 'SIGUNKNOWN_XYZ')
    assert.is_string(errmsg)
end

local function test_sigdefault()
    -- ignore SIGWINCH first, then restore default (default action: ignore)
    signal.sigignore('SIGWINCH')
    local ok, err = signal.sigdefault('SIGWINCH')
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that sigdefault accepts signal number
    local signum = signal.tosignum('SIGWINCH')
    ok, err = signal.sigdefault(signum)
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that sigdefault raises an error for an invalid signal name
    local _, errmsg = pcall(signal.sigdefault, 'SIGUNKNOWN_XYZ')
    assert.is_string(errmsg)
end

local function test_alarm()
    -- set a 2-second alarm; no previous alarm so remaining seconds = 0
    local rem = signal.alarm(2)
    assert.equal(rem, 0)

    -- cancel the alarm immediately; remaining should be > 0
    rem = signal.alarm(0)
    assert.greater(rem, 0)
end

local function test_alarm_delivery()
    -- verify that SIGALRM is actually delivered after the specified interval
    local proc, err = fork()
    assert.is_nil(err)

    if proc:is_child() then
        -- ensure SIGALRM has default action (terminate) in case parent changed it
        signal.sigdefault('SIGALRM')
        -- schedule SIGALRM in 1 second
        signal.alarm(1)
        -- sleep for 5 seconds; SIGALRM fires at ~1s and terminates this child
        os.execute('sleep 5')
        os.exit(0) -- should not be reached
    end

    -- parent: child must have been terminated by SIGALRM
    local st = proc:wait()
    assert.equal(st.sigterm, signal.tosignum('SIGALRM'))
end

test_tosignum()
test_tosigname()
test_kill()
test_raise()
test_signames()
test_sigignore()
test_sigdefault()
test_alarm()
test_alarm_delivery()
