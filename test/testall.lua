local exit = os.exit
local dofile = dofile
local getpid = require('testcase.getpid')
local PID = getpid()

for _, pathname in ipairs({
    'test/eval_test.lua',
    'test/exit_test.lua',
    'test/filesystem_test.lua',
    'test/getopts_test.lua',
    'test/getpid_test.lua',
    'test/iohook_test.lua',
    'test/printer_test.lua',
    'test/registry_test.lua',
    'test/runner_test.lua',
    'test/testcase_test.lua',
    'test/timer_test.lua',
}) do
    dofile(pathname)
    if getpid() ~= PID then
        exit(0)
    end
end
