Discord = {}

local cache = {}
local warnedToken = false

local function httpGet(url, token)
    local pending = promise.new()
    PerformHttpRequest(url, function(status, body)
        pending:resolve({ status = status or 0, body = body or '' })
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json',
        ['User-Agent'] = 'DJERPMenu (Diesel Dev Shack)',
    })
    return Citizen.Await(pending)
end

function Discord.Id(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        local discordId = identifier:match('^discord:(%d+)$')
        if discordId then return discordId end
    end
    return nil
end

function Discord.Token()
    return GetConvar('djerp_discord_token', '')
end

local function remember(key, ok, reason, seconds)
    cache[key] = {
        ok = ok,
        reason = reason,
        expires = os.time() + seconds,
    }
end

function Discord.Invalidate()
    cache = {}
end

---Returns allowed, reason. Reason is nil when access is granted.
function Discord.Check(src)
    if not Catalog.DiscordEnabled() then
        return true, nil
    end
    if Bridge.HasBypass(src) then
        return true, 'bypass'
    end

    local discordId = Discord.Id(src)
    if not discordId then
        return false, 'no-discord'
    end

    local guildId = Catalog.GuildId()
    local roleIds = Catalog.RoleIds()
    if not DJERP.IsSnowflake(guildId) or #roleIds == 0 then
        return false, 'not-configured'
    end
    for _, roleId in ipairs(roleIds) do
        if not DJERP.IsSnowflake(tostring(roleId)) then
            return false, 'not-configured'
        end
    end

    local cacheKey = guildId .. ':' .. discordId
    local cached = cache[cacheKey]
    if cached and cached.expires > os.time() then
        return cached.ok, cached.reason
    end

    local token = Discord.Token()
    if token == '' then
        if not warnedToken then
            warnedToken = true
            print('[dj-erp] Discord is enabled but convar djerp_discord_token is empty. Non-bypass players are denied.')
        end
        return false, 'not-configured'
    end

    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(guildId, discordId)
    local result = httpGet(url, token)
    local status = result.status

    if status == 200 then
        local ok, data = pcall(json.decode, result.body)
        local owned = {}
        if ok and type(data) == 'table' and type(data.roles) == 'table' then
            for _, roleId in ipairs(data.roles) do
                owned[tostring(roleId)] = true
            end
        end
        for _, roleId in ipairs(roleIds) do
            if owned[tostring(roleId)] then
                remember(cacheKey, true, nil, Config.Discord.CacheSeconds or 600)
                return true, nil
            end
        end
        remember(cacheKey, false, 'no-role', Config.Discord.DenyCacheSeconds or 45)
        return false, 'no-role'
    end

    if status == 404 then
        remember(cacheKey, false, 'not-in-guild', Config.Discord.DenyCacheSeconds or 45)
        return false, 'not-in-guild'
    end

    if status == 401 or status == 403 then
        print(('[dj-erp] Discord rejected the bot token or guild lookup (HTTP %s).'):format(status))
        remember(cacheKey, false, 'unavailable', 20)
        return false, 'unavailable'
    end

    DJERP.Debug('Discord HTTP', status)
    if cached then
        return cached.ok, cached.reason
    end
    remember(cacheKey, false, 'unavailable', 15)
    return false, 'unavailable'
end

function Discord.Message(reason)
    if reason == 'no-discord' then
        return 'Link Discord in the FiveM client, then restart the game.'
    end
    if reason == 'no-role' or reason == 'not-in-guild' then
        return 'Your Discord account does not have the role required for this menu.'
    end
    if reason == 'not-configured' then
        return 'This menu\'s Discord check is not configured yet.'
    end
    return 'Discord could not be verified. Try again in a moment.'
end
