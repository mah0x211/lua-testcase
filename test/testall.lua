local dofile = dofile

for _, pathname in ipairs({
    'test/eval_test.lua',
    'test/exit_test.lua',
    'test/filesystem_test.lua',
    'test/getopts_test.lua',
    'test/iohook_test.lua',
    'test/printer_test.lua',
    'test/registry_test.lua',
    'test/runner_test.lua',
    'test/testcase_test.lua',
    'test/timer_test.lua',
}) do
    dofile(pathname)
end
