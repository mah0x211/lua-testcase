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
-- file scope variables
io.stderr:setvbuf('no')
io.stdout:setvbuf('no')
local error = error
local stdout = io.stdout
local type = type
local pcall = pcall
local tostring = tostring
local setmetatable = setmetatable
local sub = string.sub
local find = string.find
local format = string.format
local select_len = require('selectex').len
local select_head = require('selectex').head
local select_tail = require('selectex').tail
local is_string = require('isa').String
-- constants
local NEWLINE = '\r?\n'

local function has_formatter(s)
    if not is_string(s) then
        return 0
    end

    local len = #s
    local nparam = 0
    local open = 0

    for i = 1, len do
        local c = sub(s, i, i)

        if c == '%' then
            if open == 0 then
                -- found '%'
                open = i
            else
                -- escape '%%'
                open = 0
            end
        elseif open > 0 and c == ' ' then
            if i - open > 1 then
                -- found parameter '%<c> '
                nparam = nparam + 1
            end
            open = 0
        end
    end

    if open > 0 then
        -- found specifier '%<c>'
        nparam = nparam + 1
    end

    return nparam
end

local function printline(self, s, ...)
    local prefix = self.prefix or ''
    local suffix = self.suffix
    local nparam = has_formatter(s)
    local narg = select_len(...) - nparam + 1
    local argv

    if nparam == 0 then
        argv = {
            s,
            ...,
        }
    else
        local ok, res = pcall(format, s, select_head(nparam, ...))
        if not ok then
            error(res, 2)
        end
        argv = {
            res,
            select_tail(nparam + 1, ...),
        }
    end

    for i = 1, narg do
        s = is_string(argv[i]) and argv[i] or tostring(argv[i])
        local head = 1
        local tail = find(s, NEWLINE)

        -- add a prefix to each line
        while tail do
            local line = sub(s, head, tail - 1)
            stdout:write(prefix, line, '\n')
            head = tail + 1
            tail = find(s, NEWLINE, head)
        end

        if head <= #s then
            local line = sub(s, head)
            stdout:write(prefix, line)
        end
    end

    -- add a suffix
    if suffix then
        stdout:write(suffix)
    end
end

--- new println
--- @param prefix string
--- @param suffix string
--- @return table println
local function new(prefix, suffix)
    if prefix ~= nil and not is_string(prefix) then
        error(format('invalid argument #1 (nil or string expected, got %s',
                     type(prefix)), 2)
    elseif suffix ~= nil and not is_string(suffix) then
        error(format('invalid argument #2 (nil or string expected, got %s',
                     type(suffix)), 2)
    end

    return setmetatable({
        prefix = prefix,
        suffix = suffix,
    }, {
        __call = printline,
    })
end

return {
    new = new,
}
