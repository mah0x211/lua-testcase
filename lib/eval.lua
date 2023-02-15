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
_G._assert = _G.assert
_G.assert = require('assert')
local error = error
local loadfile = loadfile
local open = io.open
local pcall = pcall
local xpcall = xpcall
local traceback = debug.traceback
local find = string.find
local format = string.format
local sub = string.sub
local trim = require('testcase.trim')
-- constants
local LUAVER = trim.prefix(_VERSION, 'Lua ')
local LOADCHUNK = LUAVER == '5.1' and loadstring or load
local EINVAL = 'invalid inline option `lua-testcase` value: %q at lineno:%d'
local EALREADY = 'invalid inline option `lua-testcase` at lineno:%d: ' ..
                     'its already defined in lineno:%d'
local ENOCODE = 'inline option `lua-testcase` is defined at lineno:%d, ' ..
                    'but the placeholder `local testcase = {}` is ' ..
                    'not declared at the next line'
local INLINE_CODE = [[local testcase = require('testcase')]]
local CRLF = '\r*\n'
local INLINE_OPT = '^%s*[-]+%s*lua[-]testcase:%s*'
local PLACEHOLDER = '^%s*local%s+testcase%s*=%s*{%s*}'
local VALID_OPTVAL = {
    ['true'] = true,
    ['false'] = false,
}

--- checkline parses the inline option or the placeholder code
--- @param ctx table
--- @param line string
--- @param lineno number
--- @param head number
--- @param tail number
local function checkline(ctx, line, lineno, head, tail)
    if ctx.chknext then
        -- the next line must be placeholder code
        if not find(line, PLACEHOLDER) then
            -- placeholder is not declared in the next line
            error(format(ENOCODE, lineno))
        end
        ctx.chknext = false
        ctx.decl = {
            head,
            tail,
        }
        -- NOTE:
        -- found the declaration, but continue parsing to prevent misuses
        return
    end

    -- check inline option
    local opt_head, opt_tail = find(line, INLINE_OPT)
    if opt_head then
        -- verify option value
        local optval = trim.space(sub(line, opt_tail + 1))
        local ok = VALID_OPTVAL[optval]
        if ok == nil then
            -- option value is not true|false
            error(format(EINVAL, optval, lineno))
        elseif ctx.defline then
            -- inline option already defined
            error(format(EALREADY, lineno, ctx.defline))
        elseif ok then
            -- check the placeholder declaration in the next line
            ctx.chknext = true
            ctx.defline = lineno
        end
    end
end

--- parse_inlineopt searches for the inline option in a file
--- @param s string
--- @return string
local function parse_inlineopt(s)
    -- search for the inline option '-- lua-testcase: true|false' in file
    local len = #s
    local head, tail = find(s, CRLF)
    local pos = 1
    local lineno = 0
    local ctx = {}

    while head do
        local line = sub(s, pos, head - 1)
        lineno = lineno + 1
        checkline(ctx, line, lineno, pos, head - 1)
        pos = tail + 1
        head, tail = find(s, CRLF, pos)
    end

    if pos < len then
        lineno = lineno + 1
        checkline(ctx, sub(s, pos), lineno, pos, len)
    end

    if ctx.decl then
        return sub(s, 1, ctx.decl[1] - 1) .. INLINE_CODE ..
                   sub(s, ctx.decl[2] + 1)
    elseif ctx.chknext then
        -- placeholder is not declared in the next line
        error(format(ENOCODE, lineno))
    end
end

--- readfile returns contents of a file
---@param filename string
---@return string
local function readfile(filename)
    local f, err = open(filename)
    if err then
        error(err)
    end

    local s = f:read('*a')
    f:close()
    return s
end

--- eval loads filename and executes it
--- @param filename string
--- @return boolean ok
--- @return any error
local function eval(filename)
    local suffix = '_test.lua'
    local func
    local err

    if sub(filename, -#suffix) == suffix then
        func, err = loadfile(filename, 't')
        if not func then
            return false, err
        end
    else
        local ok, s = pcall(readfile, filename)
        if not ok then
            return false, s
        end

        ok, s = pcall(parse_inlineopt, s)
        if not ok then
            return false, s
        elseif not s then
            -- inline option not found
            return true
        end

        func, err = LOADCHUNK(s, filename)
        if not func then
            return false, err
        end
    end

    -- luacheck: ignore err
    local ok, err = xpcall(func, traceback)
    if not ok then
        return ok, err
    end

    return true
end

return eval
