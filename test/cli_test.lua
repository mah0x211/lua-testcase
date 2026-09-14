require('luacov')
local assert = require('assert')
local concat = table.concat
local find = string.find
local format = string.format
local gsub = string.gsub
local open = io.open
local execute = os.execute
local remove = os.remove
local tmpname = os.tmpname

local function shell_quote(s)
    return "'" .. gsub(s, "'", "'\\''") .. "'"
end

local function command(s)
    local ok = execute(s)
    assert(ok == true or ok == 0,
           'command failed: ' .. s .. ' (' .. tostring(ok) .. ')')
end

local function write_file(pathname, content)
    local f = assert(open(pathname, 'w'))
    assert(f:write(content))
    assert(f:close())
end

local function write_test(pathname, name, marker)
    write_file(pathname, format([[
local testcase = require('testcase')

print(%q)

function testcase.%s()
    print(%q)
end
]], marker .. '_LOAD', name, marker .. '_RUN'))
end

local function write_inline_test(pathname, name, marker)
    write_file(pathname, format([[
-- lua-testcase: true
local testcase = {}

print(%q)

function testcase.%s()
    print(%q)
end
]], marker .. '_LOAD', name, marker .. '_RUN'))
end

local function count_occurrences(s, pattern)
    local count = 0
    local init = 1

    while true do
        local first, last = find(s, pattern, init, true)
        if not first then
            return count
        end
        count = count + 1
        init = last + 1
    end
end

local function run_cli(output_file, ...)
    local args = {
        ...,
    }
    local command_line = 'lua ./bin/testcase.lua'

    for i, pathname in ipairs(args) do
        args[i] = shell_quote(pathname)
    end
    if #args > 0 then
        command_line = command_line .. ' ' .. concat(args, ' ')
    end
    command_line = command_line .. ' > ' .. shell_quote(output_file) ..
                       ' 2>&1'

    local status = execute(command_line)
    local f = assert(open(output_file, 'r'))
    local output = assert(f:read('*a'))
    assert(f:close())

    return status == true or status == 0, output
end

local function assert_markers(output, alpha, beta)
    assert.equal(count_occurrences(output, 'CLI_ALPHA_MARKER_RUN'), alpha)
    assert.equal(count_occurrences(output, 'CLI_BETA_MARKER_RUN'), beta)
end

local function test_single_path(output_file, alpha_file)
    local ok, output = run_cli(output_file, alpha_file)
    assert(ok, output)
    assert_markers(output, 1, 0)
end

local function test_multiple_files(output_file, alpha_file, beta_file)
    local ok, output = run_cli(output_file, beta_file, alpha_file)
    assert(ok, output)
    assert_markers(output, 1, 1)
    local beta_pos = assert(find(output, 'CLI_BETA_MARKER_LOAD', 1, true))
    local alpha_pos = assert(find(output, 'CLI_ALPHA_MARKER_LOAD', 1, true))
    assert(beta_pos < alpha_pos, 'test files loaded out of argument order')
end

local function test_multiple_directories(output_file, alpha_dir, beta_dir)
    local ok, output = run_cli(output_file, alpha_dir, beta_dir)
    assert(ok, output)
    assert_markers(output, 1, 1)
end

local function test_overlapping_paths(output_file, alpha_dir, alpha_file,
                                      beta_file)
    local ok, output =
        run_cli(output_file, alpha_dir, alpha_file, beta_file)
    assert(ok, output)
    assert_markers(output, 1, 1)
end

local function test_checkall(output_file, alpha_dir, beta_dir)
    local ok, output =
        run_cli(output_file, '--checkall', alpha_dir, beta_dir)
    assert(ok, output)
    assert_markers(output, 1, 1)
    assert.equal(count_occurrences(output, 'CLI_PLAIN_MARKER_RUN'), 1)
end

local function test_duplicate_path(output_file, alpha_file)
    local ok, output = run_cli(output_file, alpha_file, alpha_file)
    assert(not ok, 'duplicate pathname succeeded')
    assert.match(output, 'duplicate pathname')
    assert_markers(output, 0, 0)
    assert.equal(count_occurrences(output, 'CLI_ALPHA_MARKER_LOAD'), 0)
end

local function test_duplicate_canonical_path(output_file, alpha_file,
                                             alpha_alias)
    local ok, output = run_cli(output_file, alpha_file, alpha_alias)
    assert(not ok, 'duplicate canonical pathname succeeded')
    assert.match(output, 'duplicate pathname')
    assert_markers(output, 0, 0)
    assert.equal(count_occurrences(output, 'CLI_ALPHA_MARKER_LOAD'), 0)
end

local function test_missing_path(output_file, alpha_file, missing_file)
    local ok, output = run_cli(output_file, alpha_file, missing_file)
    assert(not ok, 'missing pathname succeeded')
    assert.match(output, 'failed to resolve path')
    assert_markers(output, 0, 0)
    assert.equal(count_occurrences(output, 'CLI_ALPHA_MARKER_LOAD'), 0)
end

local function test_cli()
    local base = tmpname()
    local alpha_dir = base .. '/alpha'
    local beta_dir = base .. '/beta'
    local alpha_file = alpha_dir .. '/alpha_test.lua'
    local alpha_spelling = alpha_dir .. '/../alpha/alpha_test.lua'
    local alpha_alias = base .. '/alpha_alias_test.lua'
    local beta_file = beta_dir .. '/beta_test.lua'
    local plain_file = alpha_dir .. '/plain.lua'
    local missing_file = base .. '/missing_test.lua'
    local output_file = base .. '/output.log'

    remove(base)
    local ok, err = pcall(function()
        command('mkdir ' .. shell_quote(base))
        command('mkdir ' .. shell_quote(alpha_dir))
        command('mkdir ' .. shell_quote(beta_dir))
        write_test(alpha_file, 'alpha', 'CLI_ALPHA_MARKER')
        write_test(beta_file, 'beta', 'CLI_BETA_MARKER')
        write_inline_test(plain_file, 'plain', 'CLI_PLAIN_MARKER')

        test_single_path(output_file, alpha_file)
        test_multiple_files(output_file, alpha_file, beta_file)
        test_multiple_directories(output_file, alpha_dir, beta_dir)
        test_overlapping_paths(output_file, alpha_dir, alpha_file, beta_file)
        test_checkall(output_file, alpha_dir, beta_dir)
        test_duplicate_path(output_file, alpha_file)
        test_duplicate_canonical_path(output_file, alpha_file, alpha_spelling)

        command('ln -s ' .. shell_quote(alpha_file) .. ' ' ..
                    shell_quote(alpha_alias))
        test_duplicate_canonical_path(output_file, alpha_file, alpha_alias)

        test_missing_path(output_file, alpha_file, missing_file)
    end)

    for _, pathname in ipairs({
        output_file,
        alpha_alias,
        alpha_file,
        beta_file,
        plain_file,
        alpha_dir,
        beta_dir,
        base,
    }) do
        remove(pathname)
    end
    assert(ok, err)
end

test_cli()
