std = 'max'
include_files = {
    'bin/*.lua',
    'lib/*.lua',
    'test/*_test.lua',
}
ignore = {
    -- Value assigned to a local variable is mutated but never accessed.
    -- '331',

}
