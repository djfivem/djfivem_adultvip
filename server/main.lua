local pending = {}
local pendingBySource = {}
local pendingByTarget = {}
local sessions = {}
local cooldowns = {}
local rateBuckets = {}
local inviteSeq = 0

local function rateLimit(src, bucket, intervalMs)
    local now = GetGameTimer()
    rateBuckets[src] = rateBuckets[src] or {}
    local previous = rateBuckets[src][bucket] or 0
    if now - previous < intervalMs then
        return false
    end
    rateBuckets[src][bucket] = now
    return true
end

local function online(src)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    return GetPlayerName(src) ~= nil and GetPlayerPing(src) > 0
end

local function distanceBetween(a, b)
    local pedA = GetPlayerPed(a)
    local pedB = GetPlayerPed(b)
    if not pedA or not pedB or pedA == 0 or pedB == 0 then return nil end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

local function nearbyPlayers(src)
    local originPed = GetPlayerPed(src)
    if not originPed or originPed == 0 then return {} end
    local origin = GetEntityCoords(originPed)
    local maximum = Catalog.Distance()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target and target ~= src then
            local ped = GetPlayerPed(target)
            if ped and ped ~= 0 then
                local distance = #(origin - GetEntityCoords(ped))
                if distance <= maximum then
                    list[#list + 1] = {
                        id = target,
                        name = Bridge.GetName(target),
                        distance = math.floor(distance * 10 + 0.5) / 10,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.distance < b.distance
    end)
    return list
end

local function writeLog(action, actor, target, emoteKey)
    Storage.AppendLog({
        action = action,
        actorId = actor,
        actorName = actor and Bridge.GetName(actor) or nil,
        actorIdentifier = actor and Bridge.Identifier(actor) or nil,
        targetId = target,
        targetName = target and online(target) and Bridge.GetName(target) or nil,
        targetIdentifier = target and online(target) and Bridge.Identifier(target) or nil,
        emote = emoteKey,
    })
end

local function clearInvite(invite)
    if not invite then return end
    pending[invite.id] = nil
    if pendingBySource[invite.source] == invite.id then
        pendingBySource[invite.source] = nil
    end
    if pendingByTarget[invite.target] == invite.id then
        pendingByTarget[invite.target] = nil
    end
end

local function inviteView(invite, direction, viewer)
    local other = direction == 'incoming' and invite.source or invite.target
    return {
        id = invite.id,
        direction = direction,
        emote = invite.emote,
        label = invite.label,
        otherId = other,
        otherName = online(other) and Bridge.GetName(other) or 'Player',
        seconds = math.max(0, invite.expires - os.time()),
    }
end

local function closeInvite(invite, reason)
    clearInvite(invite)
    TriggerClientEvent('djerp:client:inviteClosed', invite.source, { id = invite.id, reason = reason })
    if online(invite.target) then
        TriggerClientEvent('djerp:client:inviteClosed', invite.target, { id = invite.id, reason = reason })
    end
end

local function endSession(src, reason)
    local session = sessions[src]
    if not session then return end
    local partner = session.partner
    sessions[src] = nil
    if partner and sessions[partner] and sessions[partner].partner == src then
        sessions[partner] = nil
    end
    TriggerClientEvent('djerp:client:sessionStopped', src, reason)
    if partner and online(partner) then
        TriggerClientEvent('djerp:client:sessionStopped', partner, reason == 'failed' and 'failed' or reason)
    end
end

local function playerBusy(src)
    return sessions[src] ~= nil or pendingBySource[src] ~= nil or pendingByTarget[src] ~= nil
end

local function requireAccess(src)
    local allowed, reason = Discord.Check(src)
    if not allowed then
        Bridge.Notify(src, Discord.Message(reason), 'error')
        return false
    end
    return true
end

local function usableBody(src)
    if Bridge.IsDown(src) then
        Bridge.Notify(src, 'You cannot do that right now.', 'error')
        return false
    end
    if not Config.AllowInVehicle and Bridge.InVehicle(src) then
        Bridge.Notify(src, 'Leave the vehicle first.', 'error')
        return false
    end
    return true
end

local function settingsPayload()
    return {
        distance = Catalog.Distance(),
        timeout = Catalog.Timeout(),
        cooldown = Catalog.Cooldown(),
        previewSeconds = Config.PreviewSeconds or 8,
        title = Config.Branding.Title,
        subtitle = Config.Branding.Subtitle,
        studio = Config.Branding.Studio,
        tagline = Config.Branding.Tagline,
        command = Config.Command,
        keybind = Config.Keybind,
        cancelKey = Config.CancelKey,
        discordEnabled = Catalog.DiscordEnabled(),
    }
end

local function filterKnown(keys)
    local menu = Catalog.PlayerPayload()
    local known = {}
    for _, emote in ipairs(menu.emotes) do
        known[emote.key] = true
    end
    local list = {}
    for _, key in ipairs(keys or {}) do
        if known[key] then
            list[#list + 1] = key
        end
    end
    return list
end

RegisterNetEvent('djerp:server:requestOpen', function()
    local src = source
    if not rateLimit(src, 'open', 700) then return end
    if not requireAccess(src) then
        TriggerClientEvent('djerp:client:openResult', src, { allowed = false })
        return
    end
    local identifier = Bridge.Identifier(src)
    local menu = Catalog.PlayerPayload()
    local payload = {
        allowed = true,
        profile = {
            name = Bridge.GetName(src),
            serverId = src,
            vip = true,
            admin = Bridge.IsAdmin(src),
        },
        emotes = menu.emotes,
        categories = menu.categories,
        favorites = filterKnown(Storage.GetFavorites(identifier)),
        recent = filterKnown(Storage.GetRecent(identifier)),
        players = nearbyPlayers(src),
        settings = settingsPayload(),
        resource = Catalog.ResourceName(),
        resourceStarted = Catalog.ResourceName() and GetResourceState(Catalog.ResourceName()) == 'started' or false,
    }
    if payload.profile.admin then
        payload.admin = Catalog.AdminView()
    end
    TriggerClientEvent('djerp:client:openResult', src, payload)
end)

RegisterNetEvent('djerp:server:nearby', function()
    local src = source
    if not rateLimit(src, 'nearby', 750) then return end
    if not requireAccess(src) then return end
    TriggerClientEvent('djerp:client:nearby', src, nearbyPlayers(src))
end)

RegisterNetEvent('djerp:server:favorite', function(emoteKey)
    local src = source
    if not rateLimit(src, 'favorite', 200) then return end
    if not DJERP.IsEmoteKey(emoteKey) then return end
    if not requireAccess(src) then return end
    local emote = Catalog.GetEmote(emoteKey)
    if not emote then return end
    local on, favorites = Storage.ToggleFavorite(Bridge.Identifier(src), emote.key)
    TriggerClientEvent('djerp:client:favorites', src, {
        key = emote.key,
        on = on,
        favorites = filterKnown(favorites),
    })
end)

RegisterNetEvent('djerp:server:solo', function(emoteKey, preview)
    local src = source
    if not rateLimit(src, 'solo', 500) then return end
    if not DJERP.IsEmoteKey(emoteKey) then return end
    if sessions[src] then
        Bridge.Notify(src, 'Finish the current interaction first.', 'error')
        return
    end
    if not requireAccess(src) or not usableBody(src) then return end
    local emote = Catalog.GetEmote(emoteKey)
    if not emote or emote.paired then return end
    local resource = Catalog.ResourceName()
    if not resource or GetResourceState(resource) ~= 'started' then
        Bridge.Notify(src, 'RPEmotes is not running.', 'error')
        return
    end
    local isPreview = preview == true
    TriggerClientEvent('djerp:client:playSolo', src, {
        key = emote.key,
        emoteType = emote.emoteType,
        label = emote.label,
        preview = isPreview,
        previewMs = (Config.PreviewSeconds or 8) * 1000,
        resource = resource,
    })
    if not isPreview then
        Storage.PushRecent(Bridge.Identifier(src), emote.key)
        writeLog('solo', src, nil, emote.key)
    end
end)

RegisterNetEvent('djerp:server:invite', function(targetId, emoteKey)
    local src = source
    if not rateLimit(src, 'invite', 600) then return end
    targetId = tonumber(targetId)
    if not targetId or not DJERP.IsEmoteKey(emoteKey) then return end
    if targetId == src or not online(targetId) then
        Bridge.Notify(src, 'That player is not available.', 'error')
        return
    end
    if not requireAccess(src) or not usableBody(src) then return end

    local now = os.time()
    if cooldowns[src] and now < cooldowns[src] then
        Bridge.Notify(src, 'Wait a moment before sending another request.', 'error')
        return
    end
    if playerBusy(src) or playerBusy(targetId) then
        Bridge.Notify(src, 'One of you already has an interaction pending.', 'error')
        return
    end

    local emote = Catalog.GetEmote(emoteKey)
    if not emote or not emote.paired then
        Bridge.Notify(src, 'Choose a paired animation first.', 'error')
        return
    end
    if Bridge.IsDown(targetId) or (not Config.AllowInVehicle and Bridge.InVehicle(targetId)) then
        Bridge.Notify(src, 'That player cannot accept an interaction right now.', 'error')
        return
    end

    local distance = distanceBetween(src, targetId)
    if not distance or distance > Catalog.Distance() + 0.05 then
        Bridge.Notify(src, 'That player is too far away.', 'error')
        return
    end

    local targetAllowed, targetReason = Discord.Check(targetId)
    if not targetAllowed then
        Bridge.Notify(src, 'That player does not have access to this menu.', 'error')
        DJERP.Debug('invite denied for target', targetId, targetReason)
        return
    end

    inviteSeq = inviteSeq + 1
    local invite = {
        id = ('%d-%d-%d'):format(now, src, inviteSeq),
        source = src,
        target = targetId,
        emote = emote.key,
        label = emote.label,
        expires = now + Catalog.Timeout(),
    }
    pending[invite.id] = invite
    pendingBySource[src] = invite.id
    pendingByTarget[targetId] = invite.id
    cooldowns[src] = now + Catalog.Cooldown()

    TriggerClientEvent('djerp:client:inviteSent', src, inviteView(invite, 'outgoing', src))
    TriggerClientEvent('djerp:client:inviteReceived', targetId, inviteView(invite, 'incoming', targetId))
    Bridge.Notify(src, ('Request sent to %s.'):format(Bridge.GetName(targetId)), 'success')
    writeLog('invite', src, targetId, emote.key)
end)

RegisterNetEvent('djerp:server:respond', function(inviteId, accepted)
    local src = source
    if not rateLimit(src, 'respond', 400) then return end
    if type(inviteId) ~= 'string' or not inviteId:match('^[%w%-]+$') or #inviteId > 64 then return end
    local invite = pending[inviteId]
    if not invite or invite.target ~= src then return end
    clearInvite(invite)

    if accepted ~= true then
        Bridge.Notify(invite.source, ('%s declined.'):format(Bridge.GetName(src)), 'error')
        Bridge.Notify(src, 'You declined the request.', 'info')
        TriggerClientEvent('djerp:client:inviteClosed', invite.source, { id = invite.id, reason = 'declined' })
        TriggerClientEvent('djerp:client:inviteClosed', src, { id = invite.id, reason = 'declined' })
        writeLog('decline', src, invite.source, invite.emote)
        return
    end

    if os.time() > invite.expires or not online(invite.source) then
        Bridge.Notify(src, 'That request expired.', 'error')
        if online(invite.source) then
            Bridge.Notify(invite.source, 'Your request expired.', 'error')
            TriggerClientEvent('djerp:client:inviteClosed', invite.source, { id = invite.id, reason = 'expired' })
        end
        writeLog('timeout', invite.source, src, invite.emote)
        return
    end

    local emote = Catalog.GetEmote(invite.emote)
    local resource = Catalog.ResourceName()
    if not emote or not emote.paired or not resource or GetResourceState(resource) ~= 'started' then
        Bridge.Notify(src, 'That animation is no longer available.', 'error')
        Bridge.Notify(invite.source, 'That animation is no longer available.', 'error')
        return
    end
    if sessions[src] or sessions[invite.source] then
        Bridge.Notify(src, 'One of you is already in an interaction.', 'error')
        return
    end
    if Bridge.IsDown(src) or Bridge.IsDown(invite.source) then
        Bridge.Notify(src, 'Both players need to be conscious.', 'error')
        return
    end
    if not Config.AllowInVehicle and (Bridge.InVehicle(src) or Bridge.InVehicle(invite.source)) then
        Bridge.Notify(src, 'Both players need to be out of a vehicle.', 'error')
        return
    end
    local distance = distanceBetween(src, invite.source)
    if not distance or distance > Catalog.Distance() + 0.25 then
        Bridge.Notify(src, 'You moved too far apart.', 'error')
        Bridge.Notify(invite.source, 'You moved too far apart.', 'error')
        return
    end

    local partnerKey = emote.partner or emote.key
    sessions[invite.source] = {
        partner = src,
        emote = emote.key,
        resource = resource,
        started = os.time(),
    }
    sessions[src] = {
        partner = invite.source,
        emote = emote.key,
        resource = resource,
        started = os.time(),
    }

    -- Same pairing rpemotes-reborn uses after confirmEmote:
    -- the accepting player plays the partner clip, and the requester is placed
    -- on the clip they selected.
    TriggerClientEvent('rpemotes:client:syncEmote', src, partnerKey, invite.source)
    TriggerClientEvent('rpemotes:client:syncEmoteSource', invite.source, emote.key, src)

    local view = {
        emote = emote.key,
        label = emote.label,
        resource = resource,
        partnerKey = partnerKey,
    }
    TriggerClientEvent('djerp:client:sessionStarted', invite.source, {
        emote = view.emote,
        label = view.label,
        resource = resource,
        partnerKey = partnerKey,
        partnerName = Bridge.GetName(src),
    })
    TriggerClientEvent('djerp:client:sessionStarted', src, {
        emote = view.emote,
        label = view.label,
        resource = resource,
        partnerKey = partnerKey,
        partnerName = Bridge.GetName(invite.source),
    })
    Storage.PushRecent(Bridge.Identifier(invite.source), emote.key)
    Storage.PushRecent(Bridge.Identifier(src), emote.key)
    writeLog('accept', src, invite.source, emote.key)
end)

RegisterNetEvent('djerp:server:cancel', function()
    local src = source
    if not rateLimit(src, 'cancel', 300) then return end
    if sessions[src] then
        local partner = sessions[src].partner
        local emote = sessions[src].emote
        endSession(src, 'cancel')
        writeLog('cancel', src, partner, emote)
        return
    end
    local outgoing = pendingBySource[src] and pending[pendingBySource[src]]
    if outgoing then
        closeInvite(outgoing, 'cancelled')
        if online(outgoing.target) then
            Bridge.Notify(outgoing.target, 'The request was cancelled.', 'info')
        end
        writeLog('cancel-invite', src, outgoing.target, outgoing.emote)
        return
    end
    local incoming = pendingByTarget[src] and pending[pendingByTarget[src]]
    if incoming then
        closeInvite(incoming, 'declined')
        if online(incoming.source) then
            Bridge.Notify(incoming.source, ('%s declined.'):format(Bridge.GetName(src)), 'error')
        end
        writeLog('decline', src, incoming.source, incoming.emote)
    end
end)

RegisterNetEvent('djerp:server:playFailed', function()
    local src = source
    local session = sessions[src]
    if not session then return end
    if os.time() - (session.started or 0) > 5 then return end
    local partner = session.partner
    local emote = session.emote
    endSession(src, 'failed')
    writeLog('failed', src, partner, emote)
end)

RegisterNetEvent('djerp:server:ended', function()
    local src = source
    if not rateLimit(src, 'ended', 500) then return end
    local session = sessions[src]
    if not session then return end
    local partner = session.partner
    local emote = session.emote
    endSession(src, 'ended')
    writeLog('ended', src, partner, emote)
end)

RegisterNetEvent('djerp:server:admin', function(payload)
    local src = source
    if not rateLimit(src, 'admin', 250) then return end
    if not Bridge.IsAdmin(src) then return end
    if type(payload) ~= 'table' or type(payload.kind) ~= 'string' then return end

    local ok = true
    if payload.kind == 'distance' then
        Catalog.SetDistance(payload.value)
    elseif payload.kind == 'timeout' then
        Catalog.SetTimeout(payload.value)
    elseif payload.kind == 'cooldown' then
        Catalog.SetCooldown(payload.value)
    elseif payload.kind == 'category' then
        if type(payload.id) ~= 'string' or type(payload.enabled) ~= 'boolean' then return end
        ok = Catalog.SetCategory(payload.id, payload.enabled)
    elseif payload.kind == 'emote' then
        if not DJERP.IsEmoteKey(payload.key) or type(payload.enabled) ~= 'boolean' then return end
        ok = Catalog.SetEmote(payload.key, payload.enabled, payload.category)
    elseif payload.kind == 'discord' then
        ok = Catalog.SetDiscord(payload)
    elseif payload.kind == 'reload' then
        Catalog.Reload()
    else
        return
    end

    if ok == false then
        Bridge.Notify(src, 'That setting was rejected.', 'error')
    end
    local menu = Catalog.PlayerPayload()
    TriggerClientEvent('djerp:client:menu', src, menu)
    TriggerClientEvent('djerp:client:adminState', src, Catalog.AdminView())
end)

RegisterNetEvent('djerp:server:logs', function()
    local src = source
    if not rateLimit(src, 'logs', 1000) then return end
    if not Bridge.IsAdmin(src) then return end
    TriggerClientEvent('djerp:client:logs', src, Storage.GetLogs(80))
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = sessions[src]
    if session then
        local partner = session.partner
        sessions[src] = nil
        if partner and sessions[partner] and sessions[partner].partner == src then
            sessions[partner] = nil
            if online(partner) then
                TriggerClientEvent('djerp:client:sessionStopped', partner, 'disconnect')
            end
        end
        writeLog('disconnect', src, partner, session.emote)
    end

    local outgoing = pendingBySource[src] and pending[pendingBySource[src]]
    if outgoing then
        clearInvite(outgoing)
        if online(outgoing.target) then
            TriggerClientEvent('djerp:client:inviteClosed', outgoing.target, { id = outgoing.id, reason = 'disconnect' })
        end
    end
    local incoming = pendingByTarget[src] and pending[pendingByTarget[src]]
    if incoming then
        clearInvite(incoming)
        if online(incoming.source) then
            TriggerClientEvent('djerp:client:inviteClosed', incoming.source, { id = incoming.id, reason = 'disconnect' })
            Bridge.Notify(incoming.source, 'The other player left.', 'error')
        end
    end

    rateBuckets[src] = nil
    cooldowns[src] = nil
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        local expired = {}
        for id, invite in pairs(pending) do
            if invite.expires <= now then
                expired[#expired + 1] = id
            end
        end
        for _, id in ipairs(expired) do
            local invite = pending[id]
            if invite then
                closeInvite(invite, 'expired')
                if online(invite.source) then
                    Bridge.Notify(invite.source, 'Your request expired.', 'error')
                end
                if online(invite.target) then
                    Bridge.Notify(invite.target, 'The request expired.', 'info')
                end
                writeLog('timeout', invite.source, invite.target, invite.emote)
            end
        end
    end
end)

RegisterCommand('djerp_scan', function(src)
    if src ~= 0 and not Bridge.IsAdmin(src) then
        Bridge.Notify(src, 'You cannot scan the emote catalog.', 'error')
        return
    end
    local lines = {
        ('resource: %s'):format(Catalog.ResourceName() or 'not found'),
        ('parsed: %d  shown: %d  missing: %d'):format(#Catalog.entries, #Catalog.menu.emotes, #Catalog.menu.missing),
        ('distance: %.1fm  timeout: %ss  cooldown: %ss'):format(Catalog.Distance(), Catalog.Timeout(), Catalog.Cooldown()),
    }
    for _, line in ipairs(lines) do
        if src == 0 then
            print('[dj-erp] ' .. line)
        else
            TriggerClientEvent('chat:addMessage', src, { color = { 80, 150, 255 }, args = { 'DJ ERP', line } })
        end
    end
end, false)

RegisterCommand('djerp_reload', function(src)
    if src ~= 0 and not Bridge.IsAdmin(src) then
        Bridge.Notify(src, 'You cannot reload the catalog.', 'error')
        return
    end
    Catalog.Reload()
    if src ~= 0 then
        Bridge.Notify(src, 'Emote catalog reloaded.', 'success')
    end
end, false)

CreateThread(function()
    Wait(500)
    Catalog.LoadSettings()
    Catalog.Reload()
    Storage.Init()
    print(('[dj-erp] framework=%s discord=%s title=%s'):format(
        Bridge.Framework(),
        Catalog.DiscordEnabled() and 'on' or 'off',
        Config.Branding.Title
    ))
end)
