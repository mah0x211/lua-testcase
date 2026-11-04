require('luacov')
local assert = require('assert')

local function shell_quote(s)
    return "'" .. string.gsub(s, "'", "'\\''") .. "'"
end

local function run_cli(pathname, output_file, selected)
    local cmd = 'lua ./bin/testcase.lua '
    if selected then
        cmd = cmd .. '--testcase=pass '
    end
    local status = os.execute(cmd .. shell_quote(pathname) .. ' > ' ..
                                  shell_quote(output_file) .. ' 2>&1')
    local f = assert(io.open(output_file))
    local output = assert(f:read('*a'))
    assert(f:close())
    return status == true or status == 0, output
end

local function test_cli_hooks()
    -- Keep the fixture in a directory so its filename has the required suffix.
    local base = os.tmpname()
    local pathname = base .. '/hooks_test.lua'
    local output_file = base .. '/output.log'
    os.remove(base)
    local ok, err = pcall(function()
        local status = os.execute('mkdir ' .. shell_quote(base))
        assert(status == true or status == 0)

        for _, scenario in ipairs({
            {ntest = 1},
            {ntest = 1, selected = true},
            {ntest = 0},
        }) do
            for _, hook in ipairs({
                'before_all',
                'before_each',
                'after_each',
                'after_all',
                'none',
            }) do
                local f = assert(io.open(pathname, 'w'))
                assert(f:write("local testcase = require('testcase')\n"))
                if scenario.ntest > 0 then
                    assert(f:write('function testcase.pass() end\n'))
                end
                if scenario.selected then
                    assert(f:write([[function testcase.unselected()
    error('UNSELECTED_TEST_RAN')
end
]]))
                end
                if hook ~= 'none' then
                    assert(f:write(string.format([[
function testcase.%s()
    error('CLI_HOOK_ERROR_%s')
end
]], hook, hook)))
                end
                assert(f:close())

                local passed, output = run_cli(pathname, output_file,
                                                scenario.selected)
                local failed = hook ~= 'none' and
                                   (scenario.ntest > 0 or
                                       hook == 'before_all' or
                                       hook == 'after_all')
                assert.equal(passed, not failed, output)
                assert.not_match(output, 'UNSELECTED_TEST_RAN')
                if failed then
                    assert.match(output, '#### 1 testcases in ')
                    assert.match(output, '- ' .. hook)
                    assert.match(output, 'CLI_HOOK_ERROR_' .. hook)
                end
            end
        end
    end)

    os.remove(output_file)
    os.remove(pathname)
    os.remove(base)
    assert(ok, err)
end

test_cli_hooks()
