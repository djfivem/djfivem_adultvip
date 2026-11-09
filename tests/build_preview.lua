local root = debug.getinfo(1, 'S').source:sub(2):match('(.*)/tests/') or '.'
package.path = root .. '/shared/?.lua;' .. package.path
dofile(root .. '/shared/parser.lua')
dofile(root .. '/shared/catalog.lua')
dofile(root .. '/config.lua')

local listPath = arg[1]
if not listPath then
    print('usage: lua5.4 tests/build_preview.lua path/to/AnimationList.lua')
    os.exit(1)
end

local handle = assert(io.open(listPath, 'rb'))
local body = handle:read('*a')
handle:close()

local menu = DJERP.BuildMenu(DJERP.ParseEmoteList(body), {
    categories = Config.Categories,
    disabled = Config.DisabledAnimations,
    autoIncludeAdult = Config.AutoIncludeAdult,
})

local function encode(value)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' then return value and 'true' or 'false' end
    if kind == 'number' then return string.format('%.10g', value) end
    if kind == 'string' then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
            local map = { ['\\'] = '\\\\', ['"'] = '\\"', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
            return map[char] or string.format('\\u%04x', string.byte(char))
        end) .. '"'
    end
    if kind ~= 'table' then return 'null' end
    local isArray = true
    local count = 0
    for key in pairs(value) do
        count = count + 1
        if type(key) ~= 'number' then isArray = false break end
    end
    if isArray and count == #value then
        local parts = {}
        for index = 1, #value do
            parts[index] = encode(value[index])
        end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local parts = {}
    for key, item in pairs(value) do
        parts[#parts + 1] = encode(tostring(key)) .. ':' .. encode(item)
    end
    table.sort(parts)
    return '{' .. table.concat(parts, ',') .. '}'
end

local payload = { emotes = menu.emotes, categories = menu.categories }
local out = 'window.DJERP_PREVIEW_CATALOG = ' .. encode(payload) .. ';\n'
local output = assert(io.open(root .. '/html/js/preview-data.js', 'wb'))
output:write(out)
output:close()
print(('wrote %d emotes'):format(#menu.emotes))
