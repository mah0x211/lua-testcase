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
local exit = os.exit
local concat = table.concat
local tostring = tostring
local EXIT_ARGS = {}

--- getargs returns a arguments of dummy_exit
---@return table
local function getargs()
    return EXIT_ARGS
end

--- dummy_exit throws error with arguments
local function dummy_exit(...)
    EXIT_ARGS = {...}
    local arr = {'OS_EXIT'}
    for i, v in ipairs(EXIT_ARGS) do
        arr[i + 1] = tostring(v)
    end
    error(concat(arr, ' '), 2)
end

-- disabling os.exit function
_G.os.exit = dummy_exit

return {
    getargs = getargs,
    exit = exit,
}
