# lua-testcase

[![test](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-testcase/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-testcase/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-testcase)

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


## C Helper Modules

The following modules are provided as C extensions for use in test code. Each is loaded with `require`.

---

## ok, err = testcase.chdir(pathname)

Changes the working directory of the calling process.

```lua
local chdir = require('testcase.chdir')
local ok, err = chdir('./foo/bar')
```

**Parameters**

- `pathname:string`: Path to the target directory.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:error|nil`: Error object on failure.

---

## ok, err = testcase.close(fd)

Closes a file descriptor via `close(2)`.

```lua
local close = require('testcase.close')
local ok, err = close(fd)
```

**Parameters**

- `fd:integer|file`: File descriptor integer or a Lua file object.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:error|nil`: Error object on failure.

---

## proc, err, again = testcase.fork()

Creates a child process by calling `fork(2)`. In the child the returned `proc` has PID `0`; in the parent it holds the child's PID. When the `proc` userdata is garbage-collected the child calls `exit(0)` and the parent sends `SIGKILL` and waits.

```lua
local fork = require('testcase.fork')
local proc, err, again = fork()
```

**Returns**

- `proc:userdata`: Process object on success.
- `err:string|nil`: Error message on failure.
- `again:boolean|integer|nil`: `true` if the error is `EAGAIN`, otherwise the `errno` integer.

### pid = proc:pid()

Get a process id.

```lua
local pid = proc:pid()
```

**Returns**

- `pid:integer`: Stored PID (`0` in the child, positive in the parent, negative after the process has exited).

### ok = proc:is_child()

```lua
local ok = proc:is_child()
```

**Returns**

- `ok:boolean`: `true` when called from the child process.

### stat, errmsg, errno = proc:wait()

Waits for the child to change state (`WUNTRACED|WCONTINUED`).

```lua
local stat, errmsg, errno = proc:wait()
```

**Returns**

- `stat:table|nil`: Status table on success (see below), `nil` on failure.
- `errmsg:string|nil`: Error message on failure.
- `errno:integer|nil`: `errno` value on failure.

The status table contains `pid:integer` and exactly one of the following fields:

- `exit:integer`: Exit code on normal termination.
- `sigterm:integer`: Signal number that terminated the process. `coredump:boolean` is also set to `true` when a core dump was produced.
- `sigstop:integer`: Signal number that stopped the process.
- `sigcont:boolean`: `true` if the process was continued.

---

## stat, err = testcase.fstat(pathname [, followsymlinks])

Retrieves file status for the given path.

```lua
local fstat = require('testcase.fstat')
local stat, err = fstat('./foo/bar')
```

**Parameters**

- `pathname:string`: Path to the file.
- `followsymlinks:boolean`: Follow symbolic links via `stat(2)` when `true` (default). Use `lstat(2)`-equivalent behaviour when `false`.

**Returns**

- `stat:table|nil`: Stat table on success (see below), `nil` on failure.
- `err:error|nil`: Error object on failure.

The stat table has the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `dev` | integer | Device ID |
| `ino` | integer | Inode number |
| `mode` | integer | Raw file mode bits |
| `nlink` | integer | Number of hard links |
| `uid` | integer | Owner user ID |
| `gid` | integer | Owner group ID |
| `rdev` | integer | Device ID (for special files) |
| `size` | integer | Total size in bytes |
| `blksize` | integer | Preferred I/O block size |
| `blocks` | integer | Number of 512-byte blocks allocated |
| `atime` | integer | Last access time (seconds since epoch) |
| `mtime` | integer | Last modification time (seconds since epoch) |
| `ctime` | integer | Last status-change time (seconds since epoch) |
| `perm` | string | Octal permission string, e.g. `"0755"` |
| `type` | string | File type: `"file"`, `"directory"`, `"symlink"`, `"character_device"`, `"block_device"`, `"socket"`, or `"fifo"` |

---

## pid = testcase.getpid()

Returns the PID of the calling process.

```lua
local getpid = require('testcase.getpid')
local pid = getpid()
```

**Returns**

- `pid:integer`: Process ID.

---

## ok, err = testcase.nosigchld(enabled)

Installs or restores a no-op `SIGCHLD` handler. The handler is installed without `SA_RESTART` so that blocking system calls such as `poll(2)` return `EINTR` when a child process changes state, rather than being restarted transparently.

```lua
local nosigchld = require('testcase.nosigchld')
local ok, err = nosigchld(true)
```

**Parameters**

- `enabled:boolean`: `true` to install the no-op handler; `false` to restore the previously saved disposition.

**Returns**

- `ok:boolean`: `true` on success, or on platforms without `SIGCHLD` support.
- `err:string|nil`: Error message if `sigaction(2)` failed.

---

## testcase.nosigpipe

`require('testcase.nosigpipe')` installs `SIG_IGN` for `SIGPIPE` as a side effect of loading the module, so that writes to broken pipes return `EPIPE` rather than raising `SIGPIPE`. Returns `true` on platforms that have `SIGPIPE`, `false` otherwise.

```lua
require('testcase.nosigpipe')
```

---

## val = testcase.readdir(pathname, fn)

Iterates over the entries in a directory, calling `fn(name)` for each one. Iteration stops when `fn` returns a non-`nil` value, in which case that value is returned. If `fn` raises an error, iteration stops and the error is re-raised wrapped in an error object.

```lua
local readdir = require('testcase.readdir')
local val = readdir('./foo/bar', function(name)
    if name == 'target' then
        return name
    end
end)
```

**Parameters**

- `pathname:string`: Path to the directory.
- `fn:function`: Callback invoked with each entry name. Returning a non-`nil` value stops iteration early.

**Returns**

- `val:any`: The first non-`nil` value returned by `fn`, `nil` when iteration completes normally, or an error object if `opendir`/`readdir` or `fn` failed.

---

## path, err = testcase.realpath(pathname)

Resolves a path to its canonical absolute form by following all symlinks.

```lua
local realpath = require('testcase.realpath')
local path, err = realpath('./foo/bar')
```

**Parameters**

- `pathname:string`: Path to resolve.

**Returns**

- `path:string|nil`: Resolved absolute path on success, `nil` on failure.
- `err:error|nil`: Error object on failure.

---

## testcase.select

Returns a table with three utility functions for variadic argument lists.

```lua
local select = require('testcase.select')
```

### n = select.len(...)

Returns the number of arguments passed.

**Returns**

- `n:integer`: Argument count.

### ... = select.head(n, ...)

Returns the first `n` arguments. If `n` exceeds the argument count all arguments are returned; if `n <= 0` nothing is returned.

**Parameters**

- `n:integer`: Number of leading arguments to keep.

**Returns**

- `...:any`: The first `n` values.

### ... = select.tail(n, ...)

Returns arguments starting from position `n` (1-based). If `n` exceeds the argument count nothing is returned; if `n <= 1` all arguments are returned.

**Parameters**

- `n:integer`: Starting position (1-based).

**Returns**

- `...:any`: Arguments from position `n` onward.

---

## testcase.signal

Provides functions for sending signals, controlling signal disposition, and querying signal metadata.

```lua
local signal = require('testcase.signal')
```

### ok, err = signal.kill(signame|signum, pid)

Sends a signal to the process identified by `pid`.

**Parameters**

- `signame|signum:string|integer`: Signal name (case-insensitive, e.g. `"SIGTERM"`) or signal number.
- `pid:integer`: Target process ID.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = signal.raise(signame|signum)

Sends a signal to the calling process.

**Parameters**

- `signame|signum:string|integer`: Signal name (case-insensitive) or signal number.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = signal.sigignore(signame|signum)

Sets the disposition of a signal to `SIG_IGN` so it is silently discarded when delivered.

**Parameters**

- `signame|signum:string|integer`: Signal name (case-insensitive) or signal number.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = signal.sigdefault(signame|signum)

Restores the disposition of a signal to `SIG_DFL` (the platform default action).

**Parameters**

- `signame|signum:string|integer`: Signal name (case-insensitive) or signal number.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### remsec = signal.alarm(sec)

Schedules `SIGALRM` to be delivered to the calling process after `sec` seconds. Passing `0` cancels any pending alarm.

**Parameters**

- `sec:integer`: Seconds until `SIGALRM` is delivered; `0` cancels a pending alarm.

**Returns**

- `remsec:integer`: Seconds remaining on any previously scheduled alarm, or `0` if none was pending.

### name = signal.tosigname(signum)

Returns the canonical name for a signal number.

**Parameters**

- `signum:integer`: Signal number.

**Returns**

- `name:string|nil`: Signal name (e.g. `"SIGTERM"`), or `nil` if the number is not known.

### num = signal.tosignum(signame)

Returns the number for a signal name.

**Parameters**

- `signame:string`: Signal name (case-insensitive, e.g. `"SIGTERM"` or `"sigterm"`).

**Returns**

- `num:integer|nil`: Signal number, or `nil` if the name is not known.

### names = signal.signames()

Returns a bidirectional mapping table for all signals known on the current platform.

```lua
local names = signal.signames()
-- names["SIGTERM"] == 15
-- names[15]        == "SIGTERM"
-- names[signum]    == { "SIGPOLL", "SIGIO" }  -- when multiple names share a number
```

**Returns**

- `names:table`: A table where `names[signame] = signum` for every known name, and `names[signum] = signame` (unique) or `names[signum] = {signame, ...}` (aliases).

---

## ok, err = testcase.shutdown(fd, how)

Shuts down part or all of a socket's communication channel via `shutdown(2)`.

```lua
local shutdown = require('testcase.shutdown')
local ok, err = shutdown(fd, 'rdwr')
```

**Parameters**

- `fd:integer|file`: Socket file descriptor or a Lua file object.
- `how:string`: `"rd"` (read), `"wr"` (write), or `"rdwr"` (both). Defaults to `"rdwr"`.

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:error|nil`: Error object on failure.

---

## sock1, sock2 = testcase.socketpair([nonblock])

Creates a connected pair of `AF_UNIX`/`SOCK_STREAM` sockets. Both sockets are closed automatically on garbage collection.

```lua
local socketpair = require('testcase.socketpair')
local sock1, sock2 = socketpair()
```

**Parameters**

- `nonblock:boolean`: If `true`, both sockets are put into non-blocking mode. Defaults to `false`.

**Returns**

- `sock1:userdata`: First socket object on success (see methods below).
- `sock2:userdata`: Second socket object on success.
- On failure: `nil` followed by an error message string.

### fd = sock:fd()

```lua
local fd = sock:fd()
```

**Returns**

- `fd:integer`: Underlying file descriptor.

### prev, err = sock:nonblock([enabled])

Gets or sets the `O_NONBLOCK` flag.

```lua
local prev, err = sock:nonblock(true)
```

**Parameters**

- `enabled:boolean` *(optional)*: New flag value.

**Returns**

- `prev:boolean|nil`: Previous `O_NONBLOCK` state, `nil` on failure.
- `err:string|nil`: Error message on failure.

### size, err = sock:recvbuf([size])

Gets or sets the receive buffer size (`SO_RCVBUF`).

```lua
local size, err = sock:recvbuf(4096)
```

**Parameters**

- `size:integer` *(optional)*: New buffer size in bytes.

**Returns**

- `size:integer|nil`: Current buffer size, `nil` on failure.
- `err:string|nil`: Error message on failure.

### size, err = sock:sendbuf([size])

Gets or sets the send buffer size (`SO_SNDBUF`).

```lua
local size, err = sock:sendbuf(4096)
```

**Parameters**

- `size:integer` *(optional)*: New buffer size in bytes.

**Returns**

- `size:integer|nil`: Current buffer size, `nil` on failure.
- `err:string|nil`: Error message on failure.

### sock:close()

Closes the socket immediately. Safe to call multiple times.

### ok, err = sock:shutdown()

Shuts down both directions (`SHUT_RDWR`).

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = sock:shutrd()

Shuts down the read direction (`SHUT_RD`).

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = sock:shutwr()

Shuts down the write direction (`SHUT_WR`).

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### data, err, again = sock:read()

Reads up to 4096 bytes from the socket.

**Returns**

- `data:string|nil`: Data read on success; `nil` if the peer closed the connection or on error.
- `err:string|nil`: Error message on failure.
- `again:boolean|nil`: `true` if `EAGAIN`/`EWOULDBLOCK` (non-blocking mode only).

### n, err, again = sock:write(data)

Writes data to the socket.

```lua
local n, err, again = sock:write('hello')
```

**Parameters**

- `data:string`: Data to send.

**Returns**

- `n:integer|nil`: Number of bytes written on success, `nil` on failure.
- `err:string|nil`: Error message on failure.
- `again:boolean|nil`: `true` if `EAGAIN`/`EWOULDBLOCK` (non-blocking mode only).

---

## testcase.timer

Returns a table with a constructor and utility functions.

```lua
local timer = require('testcase.timer')
```

### t = timer.new()

Creates a new timer object.

```lua
local t = timer.new()
```

**Returns**

- `t:userdata`: Timer object (see methods below).

### timer.sleep(sec)

Sleeps for the given number of seconds, supporting fractional values via `nanosleep(2)`.

```lua
timer.sleep(1.2)
```

**Parameters**

- `sec:number`: Sleep duration in seconds.

### timer.usleep(usec)

Sleeps for the given number of microseconds via `usleep(3)`.

```lua
timer.usleep(100)
```

**Parameters**

- `usec:integer`: Sleep duration in microseconds.

### sec, err = timer.nanotime()

Returns the current monotonic time as a fractional number of seconds.

```lua
local sec, err = timer.nanotime()
```

**Returns**

- `sec:number|nil`: Seconds since an arbitrary epoch (monotonic clock), `nil` on failure.
- `err:string|nil`: Error message on failure.

### ok, err = t:start()

Records the current monotonic time as the timer's start point.

```lua
local ok, err = t:start()
```

**Returns**

- `ok:boolean`: `true` on success, `false` on failure.
- `err:string|nil`: Error message on failure.

### val, fmt, unit = t:stop()

Stops the timer, accumulates the elapsed time into the running total, and returns the elapsed time since the last `start()`.

```lua
local val, fmt, unit = t:stop()
```

**Returns**

- `val:number`: Elapsed value.
- `fmt:string`: Format string for the value, e.g. `"%.3f ms"`.
- `unit:string`: Unit string: `"ns"`, `"us"`, `"ms"`, `"s"`, or `"m"`.

### val, fmt, unit = t:elapsed()

Returns the time elapsed since the last `start()` without stopping the timer.

```lua
local val, fmt, unit = t:elapsed()
```

**Returns**

- `val:number`: Elapsed value.
- `fmt:string`: Format string.
- `unit:string`: Unit string.

### val, fmt, unit = t:total()

Returns the total accumulated time across all `start()`/`stop()` intervals.

```lua
local val, fmt, unit = t:total()
```

**Returns**

- `val:number`: Total value.
- `fmt:string`: Format string.
- `unit:string`: Unit string.

### t:reset()

Resets the accumulated total and start time to zero.

---

## ok, result = testcase.xpcall(fn, msgh)

Calls `fn` in protected mode with `msgh` as the message handler. If `fn` raises an error, `msgh` is called with the error object and its return value is returned as `result`.

```lua
local xpcall = require('testcase.xpcall')
local ok, result = xpcall(fn, msgh)
```

**Parameters**

- `fn:function`: Function to call.
- `msgh:function`: Message handler called with the error object on failure.

**Returns**

- `ok:boolean`: `true` if `fn` succeeded, `false` on error.
- `result:any`: Return value of `msgh(error)` on failure; absent on success.

---

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
