--
-- Copyright (C) 2021 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local sub = string.sub
local find = string.find
local match = string.match
local ipairs = ipairs

--- @class testcase.options
--- @field help boolean
--- @field coverage boolean
--- @field checkall boolean
--- @field testcase string[]

--- parse_testcase parses the value of the "--testcase" option
--- @param value string
--- @return table? names
--- @return string? error
local function parse_testcase(value)
    if value == '' then
        return nil, 'option "--testcase" requires one or more test case names'
    end

    local names = {}
    local seen = {}
    local offset = 1

    while true do
        local comma = find(value, ',', offset, true)
        local name = sub(value, offset, comma and comma - 1)
        if name == '' then
            return nil,
                   'option "--testcase" requires one or more test case names'
        elseif not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end

        if not comma then
            return names
        end
        offset = comma + 1
    end
end

--- getopts parses command line options
--- @param arg table command line arguments
--- @return testcase.options? opts
--- @return string? error
local function getopts(arg)
    local opts = {
        help = false,
        coverage = false,
        checkall = false,
        testcase = {},
    }
    local has_testcase = false

    for _, s in ipairs(arg) do
        if sub(s, 1, 1) == '-' then
            local k, v = match(s, '^([^=]*)=?(.*)$')
            if k == '--help' then
                opts.help = true
            elseif k == '--coverage' then
                opts.coverage = true
            elseif k == '--checkall' then
                opts.checkall = true
            elseif k == '--testcase' then
                if has_testcase then
                    return nil,
                           'option "--testcase" must not be specified more than once'
                end
                has_testcase = true

                local names, err = parse_testcase(v)
                if not names then
                    return nil, err
                end
                opts.testcase = names
            end
        else
            opts[#opts + 1] = s
        end
    end

    return opts
end

return getopts
