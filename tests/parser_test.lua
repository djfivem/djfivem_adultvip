local root = debug.getinfo(1, 'S').source:sub(2):match('(.*)/tests/') or '.'
package.path = root .. '/shared/?.lua;' .. package.path

dofile(root .. '/shared/parser.lua')
dofile(root .. '/shared/catalog.lua')

local failures = 0

local function eq(actual, expected, message)
    if actual ~= expected then
        failures = failures + 1
        print(('FAIL %s\n  expected: %s\n  actual:   %s'):format(message, tostring(expected), tostring(actual)))
    end
end

local function readFile(path)
    local handle = io.open(path, 'rb')
    if not handle then return nil end
    local body = handle:read('*a')
    handle:close()
    return body
end

local function indexOf(entries)
    return DJERP.IndexEmotes(entries)
end

local sample = readFile(root .. '/tests/fixtures/sample_list.lua')
local parsed = DJERP.ParseEmoteList(sample)
local index = indexOf(parsed)

eq(index.bdogfhump, nil, 'animal section is not imported')
eq(index.kiss.emoteType, 'Shared', 'kiss type')
eq(index.kiss.partner, 'kiss2', 'kiss partner id')
eq(index.kiss.label, 'Kiss', 'kiss label')
eq(index.kiss.dict, 'hs3_ext-20', 'kiss dict')
eq(index.kiss.anim, 'cs_lestercrest_3_dual-20', 'kiss anim')
eq(index.kiss.loop, false, 'kiss is not a loop')
eq(index.hugpose.partner, 'hugpose2', 'hugpose partner')
eq(index.hugpose.loop, true, 'hugpose loop flag inside AnimationOptions')
eq(index.hugpose2.attach, true, 'hugpose2 attach flag')
eq(index.lapdance.emoteType, 'Dances', 'lapdance section')
eq(index.lapdance.label, 'Lapdance', 'lapdance label')
eq(index.fspose.adult, true, 'fspose adult flag')
eq(index.fspose.emoteType, 'Emotes', 'fspose section')
eq(index.fspose.animal, false, 'fspose is not animal')
eq(index.pee.adult, true, 'pee adult flag survives nested tables')
eq(index.atm.scenario, true, 'scenario emote flagged')
eq(index.jerkf.emoteType, 'PropEmotes', 'prop section')
eq(index.jerkf.prop, true, 'prop flag')
eq(index.jerkf.adult, true, 'prop adult flag')
eq(index.csdog.animal, true, 'shared animal flag')
eq(index.custompose.label, 'Custom Pose', 'direct CustomDP assignment')
eq(index.custompose.loop, true, 'EmoteLoop named flag')
eq(index.smoke.label, 'Smoke', 'comment does not open a new section')

local menu = DJERP.BuildMenu(parsed, {
    categories = {
        { id = 'adult', label = 'Adult', description = 'Solo', enabled = true, emotes = { 'fspose', 'jerkf', 'pee', 'csdog', 'atm', 'not-a-real-emote' } },
        { id = 'romantic', label = 'Romantic', description = 'Paired', enabled = true, emotes = { 'kiss', 'hugpose' } },
        { id = 'custom', label = 'Custom', description = 'Server', enabled = false, emotes = { 'custompose' } },
    },
    disabled = { 'pee' },
    autoIncludeAdult = false,
})

local function has(key)
    for _, emote in ipairs(menu.emotes) do
        if emote.key == key then return emote end
    end
    return nil
end

eq(has('fspose') ~= nil, true, 'fspose is shown')
eq(has('jerkf') ~= nil, true, 'jerkf is shown')
eq(has('kiss') ~= nil, true, 'kiss is shown')
eq(has('kiss').partnerLabel, 'Kiss 2', 'partner label resolved')
eq(has('pee'), nil, 'disabled emote hidden')
eq(has('csdog'), nil, 'animal emote hidden even if configured')
eq(has('atm'), nil, 'scenario hidden')
eq(has('not-a-real-emote'), nil, 'missing id hidden')
eq(has('custompose'), nil, 'disabled category hidden')
eq(#menu.missing, 1, 'one missing id reported')
eq(menu.missing[1].key, 'not-a-real-emote', 'missing id preserved')

local adultAuto = DJERP.BuildMenu(parsed, {
    categories = {
        { id = 'adult', label = 'Adult', enabled = true, emotes = {} },
    },
    disabled = { 'pee' },
    autoIncludeAdult = true,
})
local autoKeys = {}
for _, emote in ipairs(adultAuto.emotes) do
    autoKeys[emote.key] = emote.category
end
eq(autoKeys.fspose, 'adult', 'auto adult includes fspose')
eq(autoKeys.jerkf, 'adult', 'auto adult includes prop emote')
eq(autoKeys.custompose, 'adult', 'auto adult includes custom adult emote')
eq(autoKeys.pee, nil, 'auto adult still honors the denylist')
eq(autoKeys.bdogfhump, nil, 'auto adult cannot see animal section')
eq(autoKeys.csdog, nil, 'auto adult skips AnimalEmote shared clips')

local fullPath = arg[1]
if fullPath and fullPath ~= '' then
    local full = readFile(fullPath)
    if not full then
        failures = failures + 1
        print('FAIL could not read ' .. fullPath)
    else
        local fullEntries = DJERP.ParseEmoteList(full)
        local fullIndex = indexOf(fullEntries)
        local required = {
            'fspose', 'fspose2', 'fspose3', 'showboobs', 'showboobs2', 'watchstripper', 'watchstripper2',
            'twerk', 'lapdance', 'lapdance2', 'lapdance3', 'lapdance4', 'lapdance5', 'lapdance6',
            'lapdancewith', 'lapdancewith2', 'lapdancewith3', 'wank', 'wank2', 'wank3', 'wank4', 'wank5',
            'jerkf', 'selfieslut', 'selfiefu3', 'hug', 'hugr', 'kiss', 'kiss3', 'kisscuteneck',
            'kisscutecheek', 'kisscutefh', 'kisslips', 'hugpose', 'hugtip', 'couplehhands',
            'couplewed1a', 'couplewed2a', 'coupleanim', 'cutepicpose', 'sitwithmepose',
            'liftme', 'liftme3', 'liftme5', 'carrymecute', 'carrycmg', 'pback',
        }
        for _, key in ipairs(required) do
            if not fullIndex[key] then
                failures = failures + 1
                print('FAIL real list missing ' .. key)
            end
        end
        eq(fullIndex.kiss.partner, 'kiss2', 'real kiss partner')
        eq(fullIndex.fspose.adult, true, 'real fspose adult')
        eq(fullIndex.bdogfhump, nil, 'real animal hump excluded')
        eq(fullIndex.lapdance.emoteType, 'Dances', 'real lapdance type')
        eq(fullIndex.jerkf.emoteType, 'PropEmotes', 'real jerkf type')
        eq(fullIndex.hugpose2.attach, true, 'real hugpose2 attach')
        print(('real AnimationList entries parsed: %d'):format(#fullEntries))
        dofile(root .. '/config.lua')
        for _, key in ipairs(Config.DisabledAnimations or {}) do
            if not fullIndex[key:lower()] then
                failures = failures + 1
                print('FAIL disabled id is not a real emote: ' .. key)
            end
        end
        local realMenu = DJERP.BuildMenu(fullEntries, {
            categories = Config.Categories,
            disabled = Config.DisabledAnimations,
            autoIncludeAdult = Config.AutoIncludeAdult,
        })
    if #realMenu.missing > 0 then
        failures = failures + 1
        print('FAIL config references emotes that are not in the inspected RPEmotes list:')
        for _, item in ipairs(realMenu.missing) do
            print('  ' .. item.category .. ' -> ' .. item.key)
        end
    else
        print(('config menu emotes: %d'):format(#realMenu.emotes))
    end
    end
end

if failures > 0 then
    print(failures .. ' failure(s)')
    os.exit(1)
end

print('parser tests passed')
