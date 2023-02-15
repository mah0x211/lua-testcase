--
-- Copyright (C) 2023 Masatoshi Fukunaga
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
local match = string.match

--- trim_space returns s with all leading and trailing whitespace removed.
--- @param s string
--- @return string
local function trim_space(s)
    return match(s, '^%s*(.-)%s*$')
end

--- trim_suffix returns s with the suffix removed.
--- @param s string
--- @param suffix string
--- @return string
local function trim_suffix(s, suffix)
    if sub(s, -#suffix) == suffix then
        -- remove suffix
        return sub(s, 1, #s - #suffix)
    end
    return s
end

--- trim_prefix returns s with the prefix removed.
--- @param s string
--- @param prefix string
--- @return string
local function trim_prefix(s, prefix)
    if sub(s, 1, #prefix) == prefix then
        return sub(s, #prefix + 1)
    end
    return s
end

return {
    prefix = trim_prefix,
    suffix = trim_suffix,
    space = trim_space,
}
