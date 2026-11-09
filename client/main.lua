local menuOpen = false

local function setMenu(open)
    menuOpen = open
    SetNuiFocus(open, open)
    if not open then
        SendNUIMessage({ action = 'menu', open = false })
    end
end

local function closeMenu()
    setMenu(false)
end

RegisterCommand(Config.Command, function()
    if menuOpen then
        closeMenu()
        return
    end
    TriggerServerEvent('djerp:server:requestOpen')
end, false)

RegisterKeyMapping(Config.Command, 'Open DJ ERP Menu', 'keyboard', Config.Keybind or 'F6')

RegisterCommand('djerp_cancel', function()
    TriggerServerEvent('djerp:server:cancel')
end, false)

RegisterKeyMapping('djerp_cancel', 'Cancel DJ ERP interaction', 'keyboard', Config.CancelKey or 'X')

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Open the DJ ERP menu')
    TriggerEvent('chat:addSuggestion', '/djerp_cancel', 'Cancel the current DJ ERP interaction or request')
end)

RegisterNetEvent('djerp:client:playSolo', function()
    menuOpen = false
end)

RegisterNetEvent('djerp:client:sessionStarted', function()
    menuOpen = false
end)

RegisterNetEvent('djerp:client:openResult', function(payload)
    if type(payload) ~= 'table' or payload.allowed ~= true then
        return
    end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = payload })
end)

RegisterNetEvent('djerp:client:nearby', function(players)
    if type(players) ~= 'table' then return end
    SendNUIMessage({ action = 'players', players = players })
end)

RegisterNetEvent('djerp:client:favorites', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'favorites', payload = payload })
end)

RegisterNetEvent('djerp:client:inviteSent', function(invite)
    SendNUIMessage({ action = 'invite', invite = invite })
end)

RegisterNetEvent('djerp:client:inviteReceived', function(invite)
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'invite', invite = invite })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent('djerp:client:inviteClosed', function(payload)
    SendNUIMessage({ action = 'inviteClosed', payload = payload or {} })
end)

RegisterNetEvent('djerp:client:menu', function(menu)
    if type(menu) ~= 'table' then return end
    SendNUIMessage({ action = 'menuData', menu = menu })
end)

RegisterNetEvent('djerp:client:adminState', function(admin)
    SendNUIMessage({ action = 'admin', admin = admin })
end)

RegisterNetEvent('djerp:client:logs', function(logs)
    SendNUIMessage({ action = 'logs', logs = logs or {} })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('favorite', function(data, cb)
    if type(data) == 'table' and DJERP.IsEmoteKey(data.key) then
        TriggerServerEvent('djerp:server:favorite', data.key)
    end
    cb({ ok = true })
end)

RegisterNUICallback('invite', function(data, cb)
    local target = type(data) == 'table' and tonumber(data.target) or nil
    local emote = type(data) == 'table' and data.emote or nil
    if target and DJERP.IsEmoteKey(emote) then
        TriggerServerEvent('djerp:server:invite', target, emote)
    end
    cb({ ok = true })
end)

RegisterNUICallback('respond', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('djerp:server:respond', data.id, data.accepted == true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    TriggerServerEvent('djerp:server:cancel')
    cb({ ok = true })
end)

RegisterNUICallback('solo', function(data, cb)
    if type(data) == 'table' and DJERP.IsEmoteKey(data.key) then
        TriggerServerEvent('djerp:server:solo', data.key, false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    if type(data) == 'table' and DJERP.IsEmoteKey(data.key) then
        TriggerServerEvent('djerp:server:solo', data.key, true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('nearby', function(_, cb)
    TriggerServerEvent('djerp:server:nearby')
    cb({ ok = true })
end)

RegisterNUICallback('admin', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('djerp:server:admin', data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('logs', function(_, cb)
    TriggerServerEvent('djerp:server:logs')
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
