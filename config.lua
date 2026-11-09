Config = {}

-- 'auto' detects qbx_core, then qb-core, then es_extended.
-- Or set 'qbcore', 'qbox', 'esx', or 'standalone'.
Config.Framework = 'auto'

Config.Debug = false

Config.Command = 'djerp'
Config.Keybind = 'F6'
Config.CancelKey = 'X'

Config.Branding = {
    Studio = 'Phoenikera RP',
    -- Menu title. The server mark and sunset colors come from the Phoenikera RP logo.
    Title = 'DJ ERP MENU',
    Subtitle = 'Choose an animation, pick a nearby player, and wait for them to accept.',
    Tagline = 'Los Angeles · Desert Sunset',
}

-- Metres. The server measures this itself and clamps admin edits to the max.
Config.InteractionDistance = 3.0
Config.MaxInteractionDistance = 5.0
Config.InviteTimeout = 15
Config.InviteCooldown = 8
Config.PreviewSeconds = 8
Config.AllowInVehicle = false
Config.MinHealth = 102
Config.DisableCombat = true
Config.RecentLimit = 12
Config.LogLimit = 200

Config.Notify = {
    -- Uses ox_lib when that resource is started, then the active framework, then a feed post.
    UseOxLib = true,
}

Config.Database = {
    -- 'auto' uses oxmysql when it is started, otherwise data/players.json.
    Driver = 'auto',
}

-- The bot token is not a config value. A token in this file would be sent to players.
-- server.cfg: set djerp_discord_token "YOUR_BOT_TOKEN"
Config.Discord = {
    Enabled = true,
    GuildId = '',
    RoleIds = {},
    CacheSeconds = 600,
    DenyCacheSeconds = 45,
}

Config.Admin = {
    Ace = 'djerp.admin',
    BypassAce = 'djerp.bypass',
    -- Admins and the bypass ace skip the Discord role check.
    BypassDiscord = true,
    Groups = {
        qbcore = { 'god', 'admin' },
        qbox = { 'god', 'admin' },
        esx = { 'admin', 'superadmin' },
    },
}

-- Inspected against rpemotes-reborn 2.2.0 (commit 6eb7546).
-- Playback uses that build's Execute, EmoteCancel, IsPlayerInAnim, and the
-- sync events its own server fires after a shared emote is accepted.
Config.RPEmotes = {
    Resource = 'rpemotes-reborn',
    Fallbacks = { 'rpemotes' },
    Files = {
        'client/AnimationList.lua',
        'client/AnimationListCustom.lua',
    },
}

-- When true, human clips flagged AdultAnimation in RPEmotes are added to Adult
-- even if they are not listed below. Animal clips are never imported.
Config.AutoIncludeAdult = false

-- These never appear, including when AutoIncludeAdult is on.
-- pee* and hump* are real rpemotes-reborn ids and are intentionally left out.
Config.DisabledAnimations = {
    'pee',
    'pee2',
    'pee3',
    'hump',
    'hump2',
}

-- Only the initiator id is listed. The partner id is read from RPEmotes.
-- An id that is not in the running resource is hidden. It is not shown as a fake card.
Config.Categories = {
    {
        id = 'adult',
        label = 'Adult',
        description = 'Solo adult clips from the running RPEmotes resource.',
        enabled = true,
        emotes = {
            'fspose', 'fspose2', 'fspose3',
            'showboobs', 'showboobs2',
            'watchstripper', 'watchstripper2',
            'twerk',
            'lapdance', 'lapdance2', 'lapdance3', 'lapdance4', 'lapdance5', 'lapdance6',
            'lapdancewith', 'lapdancewith2', 'lapdancewith3',
            'wank', 'wank2', 'wank3', 'wank4', 'wank5',
            'jerkf',
            'selfieslut', 'selfiefu3',
        },
    },
    {
        id = 'couples',
        label = 'Couples',
        description = 'Paired couple emotes. The other player gets the partner clip.',
        enabled = true,
        emotes = {
            'hug', 'hugpose', 'hugtip',
            'couplehhands', 'couplewed1a', 'couplewed2a',
            'coupleanim', 'cutepicpose', 'sitwithmepose',
        },
    },
    {
        id = 'romantic',
        label = 'Romantic',
        description = 'Kisses and romantic holds from RP.Shared.',
        enabled = true,
        emotes = {
            'hugr', 'kiss', 'kiss3',
            'kisscuteneck', 'kisscutecheek', 'kisscutefh', 'kisslips',
        },
    },
    {
        id = 'positions',
        label = 'Positions',
        description = 'Paired position emotes that ship in rpemotes-reborn 2.2.0.',
        enabled = true,
        emotes = {
            'liftme', 'liftme3', 'liftme5',
            'carrymecute', 'carrycmg', 'pback',
        },
    },
    {
        id = 'custom',
        label = 'Custom',
        description = 'Shared emotes you added in AnimationListCustom.lua.',
        enabled = true,
        -- Stock rpemotes-reborn has no missionary/doggy shared emotes.
        -- Add the initiator id here after it exists in AnimationListCustom.lua.
        -- Example: 'missionary',
        emotes = {},
    },
}
