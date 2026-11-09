Catalog = {
    entries = {},
    index = {},
    menu = { emotes = {}, categories = {}, missing = {}, blocked = {}, discovered = 0 },
    resource = nil,
    files = {},
    settings = {
        distance = nil,
        timeout = nil,
        cooldown = nil,
        discordEnabled = nil,
        guildId = nil,
        roleIds = nil,
        disabledCategories = {},
        runtimeForce = {},
        runtimeAdded = {},
    },
}

local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return nil
end

local function cleanSettings(data)
    local settings = {
        distance = DJERP.Clamp(data.distance, 1.0, Config.MaxInteractionDistance or 5.0),
        timeout = DJERP.Clamp(data.timeout, 5, 60),
        cooldown = DJERP.Clamp(data.cooldown, 1, 120),
        discordEnabled = type(data.discordEnabled) == 'boolean' and data.discordEnabled or nil,
        guildId = type(data.guildId) == 'string' and data.guildId or nil,
        roleIds = nil,
        disabledCategories = {},
        runtimeForce = {},
        runtimeAdded = {},
    }
    if settings.guildId and not DJERP.IsSnowflake(settings.guildId) then
        settings.guildId = nil
    end
    if type(data.roleIds) == 'table' then
        settings.roleIds = {}
        for _, roleId in ipairs(data.roleIds) do
            roleId = tostring(roleId)
            if DJERP.IsSnowflake(roleId) and #settings.roleIds < 10 then
                settings.roleIds[#settings.roleIds + 1] = roleId
            end
        end
    end
    if type(data.disabledCategories) == 'table' then
        for _, category in ipairs(Config.Categories or {}) do
            if data.disabledCategories[category.id] == true then
                settings.disabledCategories[category.id] = true
            end
        end
    end
    if type(data.runtimeForce) == 'table' then
        for key, mode in pairs(data.runtimeForce) do
            if DJERP.IsEmoteKey(key) and (mode == 'on' or mode == 'off') then
                settings.runtimeForce[key:lower()] = mode
            end
        end
    end
    if type(data.runtimeAdded) == 'table' then
        for key, categoryId in pairs(data.runtimeAdded) do
            if DJERP.IsEmoteKey(key) and type(categoryId) == 'string' then
                settings.runtimeAdded[key:lower()] = categoryId
            end
        end
    end
    return settings
end

function Catalog.SaveSettings()
    local encoded = json.encode(Catalog.settings)
    SaveResourceFile(GetCurrentResourceName(), 'data/settings.json', encoded, #encoded)
end

function Catalog.LoadSettings()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/settings.json')
    local data = decode(raw)
    if data then
        Catalog.settings = cleanSettings(data)
    end
end

local function mergeEntries(chunks)
    local merged = {}
    local order = {}
    for _, chunk in ipairs(chunks) do
        for _, entry in ipairs(DJERP.ParseEmoteList(chunk.body)) do
            if not merged[entry.key] then
                order[#order + 1] = entry.key
            end
            merged[entry.key] = entry
        end
    end
    local list = {}
    for _, key in ipairs(order) do
        list[#list + 1] = merged[key]
    end
    return list
end

function Catalog.RebuildMenu()
    Catalog.menu = DJERP.BuildMenu(Catalog.entries, {
        categories = Config.Categories,
        disabled = Config.DisabledAnimations,
        runtimeForce = Catalog.settings.runtimeForce,
        runtimeAdded = Catalog.settings.runtimeAdded,
        disabledCategories = Catalog.settings.disabledCategories,
        autoIncludeAdult = Config.AutoIncludeAdult,
    })
    Catalog.index = {}
    for _, emote in ipairs(Catalog.menu.emotes) do
        Catalog.index[emote.key:lower()] = emote
    end
end

function Catalog.Reload()
    Catalog.resource = DJERP.ResolveEmoteResource()
    Catalog.files = {}
    Catalog.entries = {}
    if not Catalog.resource then
        print('[dj-erp] RPEmotes was not found. Start rpemotes-reborn (or set Config.RPEmotes.Resource) and restart.')
        Catalog.RebuildMenu()
        return
    end
    local sources = DJERP.ReadEmoteSources(Catalog.resource)
    for _, source in ipairs(sources) do
        Catalog.files[#Catalog.files + 1] = source.file
    end
    Catalog.entries = mergeEntries(sources)
    Catalog.RebuildMenu()
    print(('[dj-erp] %s parsed %d emotes from %s. Menu shows %d. Missing config ids: %d.'):format(
        Catalog.resource,
        #Catalog.entries,
        table.concat(Catalog.files, ', '),
        #Catalog.menu.emotes,
        #Catalog.menu.missing
    ))
    for _, item in ipairs(Catalog.menu.missing) do
        print(('[dj-erp] hidden, not in RPEmotes: %s (%s)'):format(item.key, item.category))
    end
    for _, item in ipairs(Catalog.menu.blocked) do
        if item.reason == 'animal' or item.reason == 'scenario' then
            print(('[dj-erp] blocked %s (%s)'):format(item.key, item.reason))
        end
    end
end

function Catalog.GetEmote(key)
    if not DJERP.IsEmoteKey(key) then return nil end
    return Catalog.index[key:lower()]
end

function Catalog.FindDiscovered(key)
    if not DJERP.IsEmoteKey(key) then return nil end
    local id = key:lower()
    for _, entry in ipairs(Catalog.entries) do
        if entry.key:lower() == id and not entry.animal and not entry.scenario then
            return entry
        end
    end
    return nil
end

function Catalog.Distance()
    return Catalog.settings.distance or Config.InteractionDistance
end

function Catalog.Timeout()
    return math.floor(Catalog.settings.timeout or Config.InviteTimeout)
end

function Catalog.Cooldown()
    return math.floor(Catalog.settings.cooldown or Config.InviteCooldown)
end

function Catalog.DiscordEnabled()
    if Catalog.settings.discordEnabled ~= nil then
        return Catalog.settings.discordEnabled
    end
    return Config.Discord.Enabled == true
end

function Catalog.GuildId()
    return Catalog.settings.guildId or Config.Discord.GuildId or ''
end

function Catalog.RoleIds()
    if Catalog.settings.roleIds then
        return Catalog.settings.roleIds
    end
    return Config.Discord.RoleIds or {}
end

function Catalog.ResourceName()
    return Catalog.resource
end

function Catalog.PlayerPayload()
    local emotes = {}
    for _, emote in ipairs(Catalog.menu.emotes) do
        emotes[#emotes + 1] = {
            key = emote.key,
            label = emote.label,
            category = emote.category,
            emoteType = emote.emoteType,
            partner = emote.partner,
            partnerLabel = emote.partnerLabel,
            paired = emote.paired,
            loop = emote.loop,
            prop = emote.prop,
            attach = emote.attach,
            dict = emote.dict,
            anim = emote.anim,
        }
    end
    return {
        emotes = emotes,
        categories = Catalog.menu.categories,
    }
end

function Catalog.AdminView()
    local discovered = DJERP.IndexDiscovered(Catalog.entries)
    local enabled = {}
    for _, emote in ipairs(Catalog.menu.emotes) do
        enabled[emote.key:lower()] = emote.category
    end
    for _, entry in ipairs(discovered) do
        local category = enabled[entry.key:lower()]
        entry.enabled = category ~= nil
        entry.category = category
    end
    return {
        resource = Catalog.resource,
        files = Catalog.files,
        parsed = #Catalog.entries,
        shown = #Catalog.menu.emotes,
        missing = Catalog.menu.missing,
        distance = Catalog.Distance(),
        timeout = Catalog.Timeout(),
        cooldown = Catalog.Cooldown(),
        maxDistance = Config.MaxInteractionDistance,
        discordEnabled = Catalog.DiscordEnabled(),
        guildId = Catalog.GuildId(),
        roleIds = Catalog.RoleIds(),
        tokenSet = Discord.Token() ~= '',
        categories = Catalog.menu.categories,
        disabledCategories = Catalog.settings.disabledCategories,
        discovered = discovered,
    }
end

function Catalog.SetDistance(value)
    Catalog.settings.distance = DJERP.Clamp(value, 1.0, Config.MaxInteractionDistance or 5.0)
    Catalog.SaveSettings()
end

function Catalog.SetTimeout(value)
    Catalog.settings.timeout = math.floor(DJERP.Clamp(value, 5, 60) or Config.InviteTimeout)
    Catalog.SaveSettings()
end

function Catalog.SetCooldown(value)
    Catalog.settings.cooldown = math.floor(DJERP.Clamp(value, 1, 120) or Config.InviteCooldown)
    Catalog.SaveSettings()
end

function Catalog.SetCategory(categoryId, enabled)
    local known = false
    for _, category in ipairs(Config.Categories) do
        if category.id == categoryId then known = true break end
    end
    if not known then return false end
    if enabled then
        Catalog.settings.disabledCategories[categoryId] = nil
    else
        Catalog.settings.disabledCategories[categoryId] = true
    end
    Catalog.SaveSettings()
    Catalog.RebuildMenu()
    return true
end

function Catalog.SetEmote(key, enabled, categoryId)
    local entry = Catalog.FindDiscovered(key)
    if not entry then return false end
    local id = entry.key:lower()
    if enabled then
        Catalog.settings.runtimeForce[id] = 'on'
        local listed = false
        for _, category in ipairs(Config.Categories) do
            for _, configured in ipairs(category.emotes or {}) do
                if configured:lower() == id then listed = true break end
            end
        end
        if not listed then
            local chosen = categoryId or 'custom'
            local valid = false
            for _, category in ipairs(Config.Categories) do
                if category.id == chosen then valid = true break end
            end
            Catalog.settings.runtimeAdded[id] = valid and chosen or 'custom'
        end
    else
        Catalog.settings.runtimeForce[id] = 'off'
    end
    Catalog.SaveSettings()
    Catalog.RebuildMenu()
    return true
end

function Catalog.SetDiscord(payload)
    if type(payload.discordEnabled) == 'boolean' then
        Catalog.settings.discordEnabled = payload.discordEnabled
    end
    if type(payload.guildId) == 'string' then
        if payload.guildId == '' then
            Catalog.settings.guildId = nil
        elseif DJERP.IsSnowflake(payload.guildId) then
            Catalog.settings.guildId = payload.guildId
        else
            return false
        end
    end
    if type(payload.roleIds) == 'table' then
        local roles = {}
        for _, roleId in ipairs(payload.roleIds) do
            roleId = tostring(roleId)
            if DJERP.IsSnowflake(roleId) and #roles < 10 then
                roles[#roles + 1] = roleId
            elseif roleId ~= '' then
                return false
            end
        end
        Catalog.settings.roleIds = roles
    end
    Catalog.SaveSettings()
    Discord.Invalidate()
    return true
end
