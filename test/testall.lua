local exit = os.exit
local dofile = dofile
local flush = io.flush
local format = string.format
local write = io.write
local getpid = require('testcase.getpid')
local PID = getpid()

local TESTFILES = {
    'test/cli_test.lua',
    'test/close_test.lua',
    'test/eval_test.lua',
    'test/exit_test.lua',
    'test/filesystem_test.lua',
    'test/getopts_test.lua',
    'test/getpid_test.lua',
    'test/iohook_test.lua',
    'test/printer_test.lua',
    'test/registry_test.lua',
    'test/rlimit_test.lua',
    'test/runner_test.lua',
    'test/shutdown_test.lua',
    'test/socketpair_test.lua',
    'test/stat_test.lua',
    'test/testcase_test.lua',
    'test/timer_test.lua',
}

for i, pathname in ipairs(TESTFILES) do
    write(format('[%d/%d] %s\n', i, #TESTFILES, pathname))
    flush()
    dofile(pathname)
    if getpid() ~= PID then
        exit(0)
    end
end
