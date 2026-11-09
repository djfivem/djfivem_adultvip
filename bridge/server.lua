Bridge = {}

local qbCore
local esx

local function detect()
    local mode = Config.Framework or 'auto'
    if mode ~= 'auto' then
        return mode
    end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

function Bridge.Framework()
    return detect()
end

local function coreObject()
    if qbCore then return qbCore end
    local framework = Bridge.Framework()
    if framework ~= 'qbcore' and framework ~= 'qbox' then return nil end
    local ok, object = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok then qbCore = object end
    return qbCore
end

local function esxObject()
    if esx then return esx end
    if Bridge.Framework() ~= 'esx' then return nil end
    local ok, object = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if ok then esx = object end
    return esx
end

local function qboxPlayer(src)
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayer(src)
    end)
    if ok then return player end
    return nil
end

local function qbPlayer(src)
    local framework = Bridge.Framework()
    if framework == 'qbox' then
        return qboxPlayer(src)
    end
    if framework ~= 'qbcore' then return nil end
    local core = coreObject()
    if not core or not core.Functions or not core.Functions.GetPlayer then return nil end
    local ok, player = pcall(function()
        return core.Functions.GetPlayer(src)
    end)
    if ok then return player end
    return nil
end

local function esxPlayer(src)
    local object = esxObject()
    if not object or not object.GetPlayerFromId then return nil end
    local ok, player = pcall(function()
        return object.GetPlayerFromId(src)
    end)
    if ok then return player end
    return nil
end

function Bridge.GetName(src)
    local framework = Bridge.Framework()
    if framework == 'qbcore' or framework == 'qbox' then
        local player = qbPlayer(src)
        local info = player and player.PlayerData and player.PlayerData.charinfo
        if info and info.firstname and info.firstname ~= '' then
            return (info.firstname .. ' ' .. (info.lastname or '')):gsub('%s+$', '')
        end
    elseif framework == 'esx' then
        local player = esxPlayer(src)
        if player and player.getName then
            local ok, name = pcall(function()
                return player.getName()
            end)
            if ok and type(name) == 'string' and name ~= '' then
                return name
            end
        end
    end
    return GetPlayerName(src) or ('Player %s'):format(src)
end

function Bridge.Identifier(src)
    local prefixes = { 'license:', 'license2:', 'fivem:', 'discord:' }
    local identifiers = GetPlayerIdentifiers(src)
    for _, prefix in ipairs(prefixes) do
        for _, identifier in ipairs(identifiers) do
            if identifier:sub(1, #prefix) == prefix then
                return identifier
            end
        end
    end
    return 'player:' .. tostring(src)
end

local function groupAllowed(src, groups, checker)
    for _, group in ipairs(groups or {}) do
        local ok, allowed = pcall(checker, group)
        if ok and allowed then
            return true
        end
    end
    return false
end

function Bridge.IsAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.Admin.Ace) then
        return true
    end

    local framework = Bridge.Framework()
    if framework == 'qbcore' then
        local core = coreObject()
        if core and core.Functions and core.Functions.HasPermission then
            return groupAllowed(src, Config.Admin.Groups.qbcore, function(group)
                return core.Functions.HasPermission(src, group)
            end)
        end
    elseif framework == 'qbox' then
        return groupAllowed(src, Config.Admin.Groups.qbox, function(group)
            return exports.qbx_core:HasPermission(src, group)
        end)
    elseif framework == 'esx' then
        local player = esxPlayer(src)
        if player and player.getGroup then
            local ok, group = pcall(function()
                return player.getGroup()
            end)
            if ok and type(group) == 'string' then
                for _, allowed in ipairs(Config.Admin.Groups.esx or {}) do
                    if group == allowed then return true end
                end
            end
        end
    end

    return false
end

function Bridge.HasBypass(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.Admin.BypassAce) then
        return true
    end
    if Config.Admin.BypassDiscord and Bridge.IsAdmin(src) then
        return true
    end
    return false
end

function Bridge.IsDown(src)
    local framework = Bridge.Framework()
    if framework == 'qbcore' or framework == 'qbox' then
        local player = qbPlayer(src)
        local metadata = player and player.PlayerData and player.PlayerData.metadata
        if metadata and (metadata.isdead or metadata.inlaststand) then
            return true
        end
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end
    local health = GetEntityHealth(ped)
    if health and health <= (Config.MinHealth or 102) then
        return true
    end
    return false
end

function Bridge.InVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetVehiclePedIsIn(ped, false) ~= 0
end

function Bridge.Notify(src, message, kind)
    TriggerClientEvent('djerp:client:notify', src, message, kind or 'info')
end
