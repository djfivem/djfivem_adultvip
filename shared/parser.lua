DJERP = DJERP or {}

-- Sections we know how to read. AnimalEmotes is intentionally absent so those
-- clips never enter the catalog, even if a list marks them AdultAnimation.
DJERP.EMOTE_SECTIONS = {
    Shared = 'Shared',
    Emotes = 'Emotes',
    Dances = 'Dances',
    PropEmotes = 'PropEmotes',
}

local SCENARIO_TYPES = {
    Scenario = true,
    MaleScenario = true,
    ScenarioObject = true,
}

local function addPrefix(state, text)
    if text == '' then return end
    state.prefix = state.prefix .. text
    if #state.prefix > 240 then
        state.prefix = state.prefix:sub(#state.prefix - 239)
    end
end

local function namedField(flat, field)
    return flat:match(field .. '%s*=%s*"([^"]*)"')
        or flat:match(field .. "%s*=%s*'([^']*)'")
end

local function finishCapture(state)
    local capture = state.capture
    if not capture then return end

    local strings = capture.strings
    local flat = capture.flat
    local dict = strings[1]
    local anim = strings[2]
    local label = strings[3]
    local partner = capture.emoteType == 'Shared' and strings[4] or nil

    if not dict or dict == '' then dict = namedField(flat, 'dict') end
    if not anim or anim == '' then anim = namedField(flat, 'anim') end
    if not label or label == '' then label = namedField(flat, 'label') end
    if capture.emoteType == 'Shared' and (not partner or partner == '') then
        partner = namedField(flat, 'secondPlayersAnim')
    end

    local scenario = SCENARIO_TYPES[dict] == true
    if not scenario and (not dict or dict == '') and namedField(flat, 'scenario') then
        scenario = true
    end

    local entry = {
        key = capture.key,
        emoteType = capture.emoteType,
        dict = dict,
        anim = anim,
        label = label or capture.key,
        partner = partner,
        adult = flat:match('AdultAnimation%s*=%s*true') ~= nil,
        animal = flat:match('AnimalEmote%s*=%s*true') ~= nil,
        scenario = scenario,
        loop = flat:match('EmoteLoop%s*=%s*true') ~= nil or flat:match('AnimFlag%.LOOP') ~= nil,
        prop = flat:match('[^%w]Prop%s*=') ~= nil or flat:match('^Prop%s*=') ~= nil,
        attach = flat:match('Attachto%s*=%s*true') ~= nil,
    }

    if not state.byKey[entry.key] then
        state.order[#state.order + 1] = entry.key
    end
    state.byKey[entry.key] = entry
    state.capture = nil
end

---Parse an RPEmotes AnimationList or AnimationListCustom file without executing it.
---Returns an array of emote records in file order. Later definitions replace earlier ones.
function DJERP.ParseEmoteList(content)
    local state = {
        byKey = {},
        order = {},
        prefix = '',
        capture = nil,
    }

    if type(content) ~= 'string' or content == '' then
        return {}
    end

    local i, n = 1, #content
    local depth = 0
    local section = nil
    local sectionDepth = nil

    while i <= n do
        local c = content:sub(i, i)
        local nxt = content:sub(i + 1, i + 1)

        if c == '-' and nxt == '-' then
            if content:sub(i + 2, i + 3) == '[[' then
                local closeAt = content:find(']]', i + 4, true)
                if not closeAt then break end
                i = closeAt + 2
            else
                local nl = content:find('\n', i + 2, true)
                i = nl and (nl + 1) or (n + 1)
            end
        elseif c == '"' or c == "'" then
            local quote = c
            local start = i
            i = i + 1
            local value = {}
            while i <= n do
                local ch = content:sub(i, i)
                if ch == '\\' then
                    value[#value + 1] = content:sub(i + 1, i + 1)
                    i = i + 2
                elseif ch == quote then
                    i = i + 1
                    break
                else
                    value[#value + 1] = ch
                    i = i + 1
                end
            end
            local raw = content:sub(start, i - 1)
            addPrefix(state, raw)
            if state.capture and depth == state.capture.depth then
                state.capture.strings[#state.capture.strings + 1] = table.concat(value)
            end
            if state.capture then
                state.capture.flat = state.capture.flat .. raw
            end
        elseif c == '[' and nxt == '[' then
            local closeAt = content:find(']]', i + 2, true)
            if not closeAt then break end
            if state.capture then
                state.capture.flat = state.capture.flat .. content:sub(i, closeAt + 1)
            end
            i = closeAt + 2
        elseif c == '{' then
            local owner, sectionName = state.prefix:match('([%w_]+)%.([%w_]+)%s*=%s*$')
            local directOwner, directSection, directKey = state.prefix:match('([%w_]+)%.([%w_]+)%s*%[%s*["\']([^"\']+)["\']%s*%]%s*=%s*$')
            local inlineKey = state.prefix:match('%[%s*["\']([^"\']+)["\']%s*%]%s*=%s*$')
            state.prefix = ''
            depth = depth + 1

            if owner and (owner == 'RP' or owner == 'CustomDP') and DJERP.EMOTE_SECTIONS[sectionName] then
                section = DJERP.EMOTE_SECTIONS[sectionName]
                sectionDepth = depth
            end

            local emoteType, key
            if directOwner and (directOwner == 'RP' or directOwner == 'CustomDP') and DJERP.EMOTE_SECTIONS[directSection] and directKey then
                emoteType = DJERP.EMOTE_SECTIONS[directSection]
                key = directKey
            elseif inlineKey and section and depth == (sectionDepth or -1) + 1 then
                emoteType = section
                key = inlineKey
            end

            if emoteType and key and not state.capture then
                state.capture = {
                    key = key,
                    depth = depth,
                    emoteType = emoteType,
                    strings = {},
                    flat = '',
                }
            end
            i = i + 1
        elseif c == '}' then
            depth = depth - 1
            if state.capture and depth < state.capture.depth then
                finishCapture(state)
            end
            if section and sectionDepth and depth < sectionDepth then
                section = nil
                sectionDepth = nil
            end
            state.prefix = ''
            i = i + 1
        elseif c:match('%s') then
            if state.prefix ~= '' and state.prefix:sub(-1) ~= ' ' then
                addPrefix(state, ' ')
            end
            if state.capture then
                state.capture.flat = state.capture.flat .. c
            end
            i = i + 1
        else
            addPrefix(state, c)
            if state.capture then
                state.capture.flat = state.capture.flat .. c
            end
            i = i + 1
        end
    end

    local list = {}
    for index = 1, #state.order do
        list[index] = state.byKey[state.order[index]]
    end
    return list
end

function DJERP.IndexEmotes(entries)
    local index = {}
    for _, entry in ipairs(entries) do
        index[entry.key:lower()] = entry
    end
    return index
end
