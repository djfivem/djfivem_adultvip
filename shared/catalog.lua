DJERP = DJERP or {}

local function lower(value)
    if type(value) ~= 'string' then return nil end
    return value:lower()
end

local function listToSet(list)
    local set = {}
    if type(list) ~= 'table' then return set end
    for _, value in ipairs(list) do
        local key = lower(value)
        if key then set[key] = true end
    end
    return set
end

local function copyEmote(entry, categoryId)
    return {
        key = entry.key,
        label = entry.label or entry.key,
        category = categoryId,
        emoteType = entry.emoteType,
        partner = entry.partner,
        partnerLabel = nil,
        adult = entry.adult == true,
        paired = entry.emoteType == 'Shared',
        loop = entry.loop == true,
        prop = entry.prop == true,
        attach = entry.attach == true,
        dict = entry.dict,
        anim = entry.anim,
    }
end

---Build the player-facing menu from parsed RPEmotes entries and server config.
---Configured ids that are missing, animal, or scenario are reported and omitted.
function DJERP.BuildMenu(entries, options)
    options = options or {}
    local index = DJERP.IndexEmotes(entries or {})
    local disabled = listToSet(options.disabled)
    local runtimeDisabled = {}
    for key, value in pairs(options.runtimeDisabled or {}) do
        local id = lower(key)
        if id and value then runtimeDisabled[id] = true end
    end
    local runtimeForce = {}
    for key, mode in pairs(options.runtimeForce or {}) do
        local id = lower(key)
        if id and (mode == 'on' or mode == 'off') then runtimeForce[id] = mode end
    end
    local disabledCategories = options.disabledCategories or {}
    local runtimeAdded = {}
    for key, categoryId in pairs(options.runtimeAdded or {}) do
        local id = lower(key)
        if id and type(categoryId) == 'string' then runtimeAdded[id] = categoryId end
    end
    local categories = options.categories or {}
    local autoIncludeAdult = options.autoIncludeAdult == true

    local function isDisabledKey(key)
        local id = lower(key)
        if runtimeForce[id] == 'on' then return false end
        if runtimeForce[id] == 'off' then return true end
        return disabled[id] == true or runtimeDisabled[id] == true
    end

    local function categoryEnabled(category)
        if category.enabled == false then return false end
        if disabledCategories[category.id] == true then return false end
        return true
    end

    local assigned = {}
    local missing = {}
    local blocked = {}
    local emotes = {}
    local categoryCounts = {}

    local function block(key, reason)
        blocked[#blocked + 1] = { key = key, reason = reason }
    end

    local function consider(key, categoryId)
        local id = lower(key)
        if not id or assigned[id] then return end
        local entry = index[id]
        if not entry then
            missing[#missing + 1] = { key = key, category = categoryId }
            return
        end
        if entry.animal then
            block(entry.key, 'animal')
            assigned[id] = true
            return
        end
        if entry.scenario then
            block(entry.key, 'scenario')
            assigned[id] = true
            return
        end
        if isDisabledKey(entry.key) then
            block(entry.key, 'disabled')
            assigned[id] = true
            return
        end
        assigned[id] = true
        local item = copyEmote(entry, categoryId)
        emotes[#emotes + 1] = item
        categoryCounts[categoryId] = (categoryCounts[categoryId] or 0) + 1
    end

    for _, category in ipairs(categories) do
        if type(category) == 'table' and type(category.id) == 'string' and categoryEnabled(category) then
            for _, key in ipairs(category.emotes or {}) do
                consider(key, category.id)
            end
        elseif type(category) == 'table' and type(category.id) == 'string' then
            for _, key in ipairs(category.emotes or {}) do
                local id = lower(key)
                if id and not assigned[id] then
                    assigned[id] = true
                    block(key, 'category-disabled')
                end
            end
        end
    end

    for key, categoryId in pairs(runtimeAdded) do
        if not disabledCategories[categoryId] then
            consider(key, categoryId)
        end
    end

    for key, mode in pairs(runtimeForce) do
        if mode == 'on' then
            local categoryId = runtimeAdded[key] or 'custom'
            if not disabledCategories[categoryId] then
                consider(key, categoryId)
            end
        end
    end

    if autoIncludeAdult then
        local adultEnabled = true
        for _, category in ipairs(categories) do
            if category.id == 'adult' then
                adultEnabled = categoryEnabled(category)
                break
            end
        end
        if adultEnabled and not disabledCategories.adult then
            for _, entry in ipairs(entries or {}) do
                if entry.adult and not entry.animal and not entry.scenario and not assigned[entry.key:lower()] then
                    consider(entry.key, 'adult')
                end
            end
        end
    end

    for _, item in ipairs(emotes) do
        if item.partner then
            local partner = index[item.partner:lower()]
            item.partnerLabel = partner and partner.label or item.partner
        end
    end

    table.sort(emotes, function(a, b)
        if a.category == b.category then
            return a.label:lower() < b.label:lower()
        end
        return a.category < b.category
    end)

    local categoryPayload = {}
    for _, category in ipairs(categories) do
        if type(category) == 'table' and category.id and categoryEnabled(category) then
            categoryPayload[#categoryPayload + 1] = {
                id = category.id,
                label = category.label or category.id,
                description = category.description or '',
                count = categoryCounts[category.id] or 0,
            }
        end
    end

    return {
        emotes = emotes,
        categories = categoryPayload,
        missing = missing,
        blocked = blocked,
        discovered = #(entries or {}),
    }
end

function DJERP.FindEmote(menu, key)
    if type(key) ~= 'string' then return nil end
    local id = key:lower()
    for _, emote in ipairs(menu.emotes) do
        if emote.key:lower() == id then
            return emote
        end
    end
    return nil
end

---Every non-animal, non-scenario clip the parser found. Admin tools use this
---to enable a real identifier; it is never sent to regular players.
function DJERP.IndexDiscovered(entries)
    local list = {}
    for _, entry in ipairs(entries or {}) do
        if not entry.animal and not entry.scenario then
            list[#list + 1] = {
                key = entry.key,
                label = entry.label or entry.key,
                emoteType = entry.emoteType,
                adult = entry.adult == true,
                paired = entry.emoteType == 'Shared',
                partner = entry.partner,
            }
        end
    end
    table.sort(list, function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    return list
end
