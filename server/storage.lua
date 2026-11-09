Storage = { mode = 'json', players = {}, logs = {} }

local function identifierOk(value)
    return type(value) == 'string' and #value > 0 and #value <= 80 and not value:find('[%c]')
end

local function query(sql, params)
    local pending = promise.new()
    exports.oxmysql:query(sql, params or {}, function(result)
        pending:resolve(result)
    end)
    return Citizen.Await(pending)
end

local function saveJson()
    local encodedPlayers = json.encode(Storage.players)
    local encodedLogs = json.encode(Storage.logs)
    SaveResourceFile(GetCurrentResourceName(), 'data/players.json', encodedPlayers, #encodedPlayers)
    SaveResourceFile(GetCurrentResourceName(), 'data/logs.json', encodedLogs, #encodedLogs)
end

local function loadJson()
    local playersRaw = LoadResourceFile(GetCurrentResourceName(), 'data/players.json')
    local logsRaw = LoadResourceFile(GetCurrentResourceName(), 'data/logs.json')
    if playersRaw and playersRaw ~= '' then
        local ok, data = pcall(json.decode, playersRaw)
        if ok and type(data) == 'table' then
            Storage.players = data
        end
    end
    if logsRaw and logsRaw ~= '' then
        local ok, data = pcall(json.decode, logsRaw)
        if ok and type(data) == 'table' then
            Storage.logs = data
        end
    end
end

local function bucket(identifier)
    local record = Storage.players[identifier]
    if type(record) ~= 'table' then
        record = { favorites = {}, recent = {} }
        Storage.players[identifier] = record
    end
    record.favorites = record.favorites or {}
    record.recent = record.recent or {}
    return record
end

local function createTables()
    query([[CREATE TABLE IF NOT EXISTS `djerp_favorites` (
        `identifier` VARCHAR(80) NOT NULL,
        `emote_key` VARCHAR(48) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`identifier`, `emote_key`)
    )]])
    query([[CREATE TABLE IF NOT EXISTS `djerp_recent` (
        `identifier` VARCHAR(80) NOT NULL,
        `emote_key` VARCHAR(48) NOT NULL,
        `used_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`identifier`, `emote_key`)
    )]])
    query([[CREATE TABLE IF NOT EXISTS `djerp_logs` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `action` VARCHAR(32) NOT NULL,
        `actor_id` INT NULL,
        `actor_name` VARCHAR(128) NULL,
        `actor_identifier` VARCHAR(80) NULL,
        `target_id` INT NULL,
        `target_name` VARCHAR(128) NULL,
        `target_identifier` VARCHAR(80) NULL,
        `emote_key` VARCHAR(48) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_djerp_logs_created` (`created_at`)
    )]])
end

function Storage.Init()
    local driver = (Config.Database and Config.Database.Driver) or 'auto'
    if driver == 'auto' then
        driver = GetResourceState('oxmysql') == 'started' and 'oxmysql' or 'json'
    end
    if driver == 'oxmysql' then
        local ok, err = pcall(createTables)
        if ok then
            Storage.mode = 'oxmysql'
            print('[dj-erp] favorites and logs use oxmysql')
            return
        end
        print(('[dj-erp] oxmysql setup failed (%s). Using JSON files.'):format(tostring(err)))
    end
    Storage.mode = 'json'
    loadJson()
    print('[dj-erp] favorites and logs use data/players.json and data/logs.json')
end

function Storage.GetFavorites(identifier)
    if not identifierOk(identifier) then return {} end
    if Storage.mode == 'oxmysql' then
        local ok, rows = pcall(query, 'SELECT emote_key FROM djerp_favorites WHERE identifier = ? ORDER BY created_at ASC', { identifier })
        if not ok or type(rows) ~= 'table' then return {} end
        local list = {}
        for _, row in ipairs(rows) do
            list[#list + 1] = row.emote_key
        end
        return list
    end
    return DJERP.CopyList(bucket(identifier).favorites)
end

function Storage.ToggleFavorite(identifier, emoteKey)
    if not identifierOk(identifier) or not DJERP.IsEmoteKey(emoteKey) then
        return false, Storage.GetFavorites(identifier)
    end
    if Storage.mode == 'oxmysql' then
        local existing = query('SELECT emote_key FROM djerp_favorites WHERE identifier = ? AND emote_key = ? LIMIT 1', { identifier, emoteKey })
        local on = not (type(existing) == 'table' and existing[1] ~= nil)
        if on then
            query('INSERT INTO djerp_favorites (identifier, emote_key) VALUES (?, ?)', { identifier, emoteKey })
        else
            query('DELETE FROM djerp_favorites WHERE identifier = ? AND emote_key = ?', { identifier, emoteKey })
        end
        return on, Storage.GetFavorites(identifier)
    end

    local record = bucket(identifier)
    local on = true
    local nextList = {}
    for _, key in ipairs(record.favorites) do
        if key == emoteKey then
            on = false
        else
            nextList[#nextList + 1] = key
        end
    end
    if on then nextList[#nextList + 1] = emoteKey end
    record.favorites = nextList
    saveJson()
    return on, nextList
end

function Storage.PushRecent(identifier, emoteKey)
    if not identifierOk(identifier) or not DJERP.IsEmoteKey(emoteKey) then return end
    if Storage.mode == 'oxmysql' then
        pcall(query, [[INSERT INTO djerp_recent (identifier, emote_key) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE used_at = CURRENT_TIMESTAMP]], { identifier, emoteKey })
        return
    end
    local record = bucket(identifier)
    local nextList = { { key = emoteKey, at = os.time() } }
    for _, item in ipairs(record.recent) do
        if item.key ~= emoteKey then
            nextList[#nextList + 1] = item
        end
        if #nextList >= (Config.RecentLimit or 12) then break end
    end
    record.recent = nextList
    saveJson()
end

function Storage.GetRecent(identifier)
    if not identifierOk(identifier) then return {} end
    if Storage.mode == 'oxmysql' then
        local limit = math.floor(tonumber(Config.RecentLimit) or 12)
        if limit < 1 then limit = 1 end
        if limit > 50 then limit = 50 end
        local ok, rows = pcall(query, ('SELECT emote_key FROM djerp_recent WHERE identifier = ? ORDER BY used_at DESC LIMIT %d'):format(limit), {
            identifier,
        })
        if not ok or type(rows) ~= 'table' then return {} end
        local list = {}
        for _, row in ipairs(rows) do
            list[#list + 1] = row.emote_key
        end
        return list
    end
    local list = {}
    for _, item in ipairs(bucket(identifier).recent) do
        list[#list + 1] = item.key
    end
    return list
end

function Storage.AppendLog(entry)
    entry = entry or {}
    if Storage.mode == 'oxmysql' then
        pcall(query, [[INSERT INTO djerp_logs
            (action, actor_id, actor_name, actor_identifier, target_id, target_name, target_identifier, emote_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], {
            tostring(entry.action or 'event'):sub(1, 32),
            entry.actorId,
            entry.actorName,
            entry.actorIdentifier,
            entry.targetId,
            entry.targetName,
            entry.targetIdentifier,
            entry.emote,
        })
        return
    end
    Storage.logs[#Storage.logs + 1] = {
        action = entry.action,
        actorId = entry.actorId,
        actorName = entry.actorName,
        targetId = entry.targetId,
        targetName = entry.targetName,
        emote = entry.emote,
        at = os.time(),
    }
    local limit = Config.LogLimit or 200
    while #Storage.logs > limit do
        table.remove(Storage.logs, 1)
    end
    saveJson()
end

function Storage.GetLogs(limit)
    limit = math.floor(tonumber(limit) or 80)
    if limit < 1 then limit = 1 end
    if limit > 100 then limit = 100 end
    if Storage.mode == 'oxmysql' then
        local ok, rows = pcall(query, ([[SELECT action, actor_id AS actorId, actor_name AS actorName,
            target_id AS targetId, target_name AS targetName, emote_key AS emote,
            UNIX_TIMESTAMP(created_at) AS at
            FROM djerp_logs ORDER BY id DESC LIMIT %d]]):format(limit), {})
        if not ok or type(rows) ~= 'table' then return {} end
        return rows
    end
    local list = {}
    for index = #Storage.logs, 1, -1 do
        list[#list + 1] = Storage.logs[index]
        if #list >= limit then break end
    end
    return list
end
