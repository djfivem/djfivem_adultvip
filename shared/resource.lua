DJERP = DJERP or {}

function DJERP.ResolveEmoteResource()
    local tried = {}

    local function consider(name)
        if type(name) ~= 'string' or name == '' or tried[name] then
            return nil
        end
        tried[name] = true
        local state = GetResourceState(name)
        if state == 'missing' or state == 'unknown' then
            return nil
        end
        local files = (Config.RPEmotes and Config.RPEmotes.Files) or { 'client/AnimationList.lua' }
        for _, file in ipairs(files) do
            local body = LoadResourceFile(name, file)
            if body and body ~= '' then
                return name
            end
        end
        return nil
    end

    local found = consider(Config.RPEmotes and Config.RPEmotes.Resource)
    if found then return found end

    for _, name in ipairs((Config.RPEmotes and Config.RPEmotes.Fallbacks) or {}) do
        found = consider(name)
        if found then return found end
    end

    return nil
end

function DJERP.ReadEmoteSources(resourceName)
    local sources = {}
    if not resourceName then return sources end
    for _, file in ipairs((Config.RPEmotes and Config.RPEmotes.Files) or {}) do
        local body = LoadResourceFile(resourceName, file)
        if body and body ~= '' then
            sources[#sources + 1] = { file = file, body = body }
        end
    end
    return sources
end
