local activeResource
local catalogTypes
local inSession = false
local sessionToken = 0
local previewToken = 0

local function resolvedResource(preferred)
    if type(preferred) == 'string' and GetResourceState(preferred) == 'started' then
        return preferred
    end
    if activeResource and GetResourceState(activeResource) == 'started' then
        return activeResource
    end
    local detected = DJERP.ResolveEmoteResource()
    if detected and GetResourceState(detected) == 'started' then
        activeResource = detected
        return detected
    end
    return nil
end

local function stopLocal(resourceName)
    local resource = resolvedResource(resourceName)
    local cancelled = false
    if resource then
        cancelled = pcall(function()
            exports[resource]:EmoteCancel(true)
        end)
    end
    if not cancelled then
        local ped = PlayerPedId()
        DetachEntity(ped, true, false)
        ClearPedTasksImmediately(ped)
    end
end

local function playing(resourceName)
    local resource = resolvedResource(resourceName)
    if not resource then return false, false end
    local ok, name = pcall(function()
        return exports[resource]:IsPlayerInAnim()
    end)
    if not ok then return false, false end
    return true, name ~= nil and name ~= false and name ~= ''
end

local function catalogAllows(key, emoteType)
    if not catalogTypes then return true end
    return catalogTypes[key:lower()] == emoteType
end

local function rememberCatalog(resourceName)
    local resource = resolvedResource(resourceName)
    if not resource then return end
    local ok, catalog, err = pcall(function()
        return exports[resource]:GetEmoteCatalog()
    end)
    if not ok then
        catalogTypes = nil
        return
    end
    if type(catalog) ~= 'table' then
        if err == 'catalog_not_ready' then return end
        catalogTypes = nil
        return
    end
    catalogTypes = {}
    for _, entry in ipairs(catalog) do
        if type(entry) == 'table' and type(entry.name) == 'string' and type(entry.emoteType) == 'string' then
            catalogTypes[entry.name:lower()] = entry.emoteType
        end
    end
end

local function watchSession(token, resourceName, emoteKey)
    CreateThread(function()
        Wait(1200)
        if token ~= sessionToken or not inSession then return end
        local checked, isPlaying = playing(resourceName)
        if checked and not isPlaying then
            TriggerServerEvent('djerp:server:playFailed')
            return
        end
        local sawPlay = isPlaying
        while inSession and token == sessionToken do
            Wait(700)
            if IsEntityDead(PlayerPedId()) or IsPedFatallyInjured(PlayerPedId()) then
                TriggerServerEvent('djerp:server:cancel')
                return
            end
            local ok, active = playing(resourceName)
            if ok and active then
                sawPlay = true
            elseif ok and sawPlay and not active then
                TriggerServerEvent('djerp:server:ended')
                return
            end
        end
    end)
end

RegisterNetEvent('djerp:client:playSolo', function(data)
    if type(data) ~= 'table' or not DJERP.IsEmoteKey(data.key) then return end
    local allowed = { Emotes = true, Dances = true, PropEmotes = true }
    if not allowed[data.emoteType] then return end
    local resource = resolvedResource(data.resource)
    if not resource then
        TriggerEvent('djerp:client:notify', 'RPEmotes is not running.', 'error')
        return
    end
    rememberCatalog(resource)
    if not catalogAllows(data.key, data.emoteType) then
        TriggerEvent('djerp:client:notify', 'That emote is not in the running RPEmotes catalog.', 'error')
        return
    end

    previewToken = previewToken + 1
    local token = previewToken
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'menu', open = false })
    SendNUIMessage({
        action = 'hint',
        show = true,
        text = data.preview and 'Preview' or 'Playing',
        label = data.label or data.key,
    })

    local ok = pcall(function()
        exports[resource]:Execute(data.key, data.emoteType)
    end)
    if not ok then
        SendNUIMessage({ action = 'hint', show = false })
        TriggerEvent('djerp:client:notify', 'RPEmotes rejected that emote.', 'error')
        return
    end

    if data.preview == true then
        local waitMs = tonumber(data.previewMs) or 8000
        CreateThread(function()
            Wait(waitMs)
            if token ~= previewToken then return end
            stopLocal(resource)
            SendNUIMessage({ action = 'hint', show = false })
        end)
    end
end)

RegisterNetEvent('djerp:client:sessionStarted', function(data)
    if type(data) ~= 'table' then return end
    sessionToken = sessionToken + 1
    previewToken = previewToken + 1
    inSession = true
    local token = sessionToken
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'menu', open = false })
    SendNUIMessage({
        action = 'hint',
        show = true,
        text = 'Synced with ' .. tostring(data.partnerName or 'partner'),
        label = data.label or 'Emote',
        session = true,
    })
    rememberCatalog(data.resource)
    local known = not catalogTypes
        or (data.emote and catalogTypes[tostring(data.emote):lower()] ~= nil)
        or (data.partnerKey and catalogTypes[tostring(data.partnerKey):lower()] ~= nil)
    if catalogTypes and not known then
        TriggerServerEvent('djerp:server:playFailed')
        return
    end
    watchSession(token, data.resource, data.emote)
end)

RegisterNetEvent('djerp:client:sessionStopped', function(reason)
    if not inSession and reason ~= 'failed' then
        stopLocal(nil)
        SendNUIMessage({ action = 'hint', show = false })
        return
    end
    inSession = false
    sessionToken = sessionToken + 1
    stopLocal(nil)
    SendNUIMessage({ action = 'hint', show = false })
    if reason == 'disconnect' then
        TriggerEvent('djerp:client:notify', 'The other player left.', 'info')
    elseif reason == 'failed' then
        TriggerEvent('djerp:client:notify', 'The emote did not start. In rpemotes, set AdultEmotesDisabled to false and keep SharedEmotesEnabled on.', 'error')
    elseif reason == 'ended' then
        TriggerEvent('djerp:client:notify', 'Interaction ended.', 'info')
    elseif reason == 'cancel' then
        TriggerEvent('djerp:client:notify', 'Interaction cancelled.', 'info')
    end
end)

CreateThread(function()
    while true do
        if inSession and Config.DisableCombat then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if inSession then
        stopLocal(nil)
    end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
end)

CreateThread(function()
    Wait(1500)
    local resource = DJERP.ResolveEmoteResource()
    if not resource then
        print('[dj-erp] RPEmotes is not started.')
        return
    end
    activeResource = resource
    for _ = 1, 20 do
        local ok, catalog, err = pcall(function()
            return exports[resource]:GetEmoteCatalog()
        end)
        if ok and type(catalog) == 'table' then
            rememberCatalog(resource)
            print(('[dj-erp] GetEmoteCatalog ready (%d entries) from %s'):format(#catalog, resource))
            return
        end
        if not ok or err ~= 'catalog_not_ready' then
            print('[dj-erp] This RPEmotes build has no GetEmoteCatalog export. Playback uses Execute and the sync events.')
            return
        end
        Wait(500)
    end
end)
