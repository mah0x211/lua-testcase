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
--- file scope variables
local print = print
local format = string.format
local stderr = io.stderr
local stdout = io.stdout

local function default_on_start()
end
local on_startfn = default_on_start

-- luacheck: no unused args
local function default_on_hook(...)
end
local on_hookfn = default_on_hook

local function default_on_end()
end
local on_endfn = default_on_end

local is_blocked = false

local function block()
    is_blocked = true
end

local function unblock()
    is_blocked = false
end

local is_hooked = false

local function printout(...)
    if is_blocked then
        return
    elseif not is_hooked then
        is_hooked = true
        on_startfn()
    end
    on_hookfn(...)
end

local stdwriter = setmetatable({}, {
    __metatable = 1,
    __index = {
        write = function(_, ...)
            printout(...)
        end,
    },
})

--- hook print, and stdout and stderr
---@param hookfn function
---@param startfn function
---@param endfn function
local function hook(hookfn, startfn, endfn)
    hookfn = hookfn or default_on_hook
    startfn = startfn or default_on_start
    endfn = endfn or default_on_end
    if type(hookfn) ~= 'function' then
        error(format('invalid argument #1 (function expected, got %s)',
                     type(hookfn)), 2)
    elseif type(startfn) ~= 'function' then
        error(format('invalid argument #2 (function expected, got %s)',
                     type(startfn)), 2)
    elseif type(endfn) ~= 'function' then
        error(format('invalid argument #3 (function expected, got %s)',
                     type(endfn)), 2)
    end

    on_hookfn = hookfn
    on_startfn = startfn
    on_endfn = endfn
    is_hooked = false
    _G.io.stderr = stdwriter
    _G.io.stdout = stdwriter
    _G.print = printout
end

local function unhook()
    _G.io.stderr = stderr
    _G.io.stdout = stdout
    _G.print = print
    if is_hooked then
        is_hooked = false
        on_endfn()
    end
    on_hookfn = default_on_hook
    on_startfn = default_on_start
    on_endfn = default_on_end
end

return {
    block = block,
    unblock = unblock,
    hook = hook,
    unhook = unhook,
}
