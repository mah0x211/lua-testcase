local assert = require('assert')
local stat = require('testcase.stat')

-- run a shell command and assert success. os.execute returns the exit code on
-- Lua 5.1 / luajit (0 == success) and true/nil on 5.2 and later.
local function cmd(s)
    local ok = os.execute(s)
    assert(ok == true or ok == 0,
           'command failed: ' .. s .. ' (' .. tostring(ok) .. ')')
end

local function test_file()
    local path = os.tmpname()
    local f = assert(io.open(path, 'w'))
    assert(f:write('hello'))
    assert(f:close())

    local info, err = stat(path)
    assert(not err, err)
    assert.equal(info.type, 'file')
    assert.equal(info.size, 5)
    assert.equal(type(info.perm), 'string')

    os.remove(path)
end

local function test_directory()
    local info, err = stat('./test')
    assert(not err, err)
    assert.equal(info.type, 'directory')
end

local function test_followsymlinks()
    local target = os.tmpname()
    local f = assert(io.open(target, 'w'))
    assert(f:write('x'))
    assert(f:close())

    local link = target .. '.lnk'
    os.remove(link)
    cmd('ln -s ' .. target .. ' ' .. link)

    -- omitted followsymlinks defaults to true: stat() follows the link
    local info, err = stat(link)
    assert(not err, err)
    assert.equal(info.type, 'file')

    -- explicit true follows the link
    info, err = stat(link, true)
    assert(not err, err)
    assert.equal(info.type, 'file')

    -- explicit false does not follow: lstat() reports the link itself
    info, err = stat(link, false)
    assert(not err, err)
    assert.equal(info.type, 'symlink')

    os.remove(link)
    os.remove(target)
end

local function test_fifo()
    -- regression: testcase.fstat (open + O_RDONLY) blocks on a fifo, but
    -- stat()/lstat() succeeds and reports type == "fifo"
    local path = os.tmpname()
    os.remove(path)
    cmd('mkfifo ' .. path)

    local info, err = stat(path)
    assert(not err, err)
    assert.equal(info.type, 'fifo')

    os.remove(path)
end

local function test_error()
    local info, err = stat('./nonexistent_path_for_stat_test')
    assert.is_nil(info)
    assert(err, 'expected an error for a non-existent path')
end

test_file()
test_directory()
test_followsymlinks()
test_fifo()
test_error()
