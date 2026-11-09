# DJ ERP MENU

Phoenikera RP paired roleplay menu for FiveM, built by Diesel Dev Shack. Players with a configured Discord role browse RPEmotes clips, invite a nearby player, and both animations start only after that player accepts.

The menu title is **DJ ERP MENU**. The server mark is Phoenikera RP: black, sunset orange, gold, and desert purple. VIP access is the Discord role gate. Change `Config.Branding` if this copy is used on another community.

This build was checked against [rpemotes-reborn 2.2.0](https://github.com/alberttheprince/rpemotes-reborn) (`6eb7546`). It does not invent emote names. On start, the server reads `client/AnimationList.lua` and `client/AnimationListCustom.lua` from the running RPEmotes resource and hides any configured id that is not in those files.

Stock rpemotes-reborn does not ship shared sex-position clips such as missionary or doggy. The Positions category uses real paired poses from that version (`liftme`, `carrymecute`, `pback`, and the others listed in `config.lua`). Add your own shared ids under Custom after they exist in `AnimationListCustom.lua`.

Animal emote sections are never imported.

## Requirements

- FiveM server build 6683 or newer
- OneSync
- [rpemotes-reborn](https://github.com/alberttheprince/rpemotes-reborn) 2.2.0 or a fork that still provides:
  - `exports[resource]:Execute(name, emoteType)`
  - `exports[resource]:EmoteCancel(force)`
  - `exports[resource]:IsPlayerInAnim()`
  - `exports[resource]:GetEmoteCatalog()` (used when present; playback still works without it)
  - `rpemotes:client:syncEmote` and `rpemotes:client:syncEmoteSource`
- In the rpemotes `config.lua`: `SharedEmotesEnabled = true` and `AdultEmotesDisabled = false`
- A Discord bot in your guild, with the Server Members intent, if the role check is on
- QBCore, Qbox, ESX Legacy, or no framework
- oxmysql is optional. Without it, favorites and logs are stored in `data/*.json`

## Install

1. Place this folder in your server `resources` directory. The folder name can stay `dj-erp-menu`.
2. In `rpemotes-reborn/config.lua`, set `AdultEmotesDisabled = false` and leave shared emotes enabled.
3. Edit `config.lua` in this resource. Set `Config.Discord.GuildId` and `Config.Discord.RoleIds`, or turn `Config.Discord.Enabled` off for a private dev server.
4. Put the bot token in `server.cfg`. Do not put it in `config.lua`. That file is shared with players.

```cfg
ensure oxmysql
ensure rpemotes-reborn
ensure dj-erp-menu

set djerp_discord_token "YOUR_BOT_TOKEN"
add_ace group.admin djerp.admin allow
add_ace group.admin djerp.bypass allow
```

`set` keeps the token on the server. Do not use `setr` for it.

5. Import `sql/install.sql` only if you want the tables before first boot. When oxmysql is already started, the resource creates the same tables itself.
6. Start the server and, in the server console or as an admin, run `djerp_scan`. It prints how many emotes were parsed and how many the menu is showing. Config ids that are missing from RPEmotes are printed at start and are not shown in the menu.

Default command is `/djerp`, default key is `F6`, cancel is `X`. Change those in `config.lua`.

## Discord

The server reads `discord:` from the player's identifiers and calls `GET /guilds/{guild.id}/members/{user.id}` with the bot token. A successful check is cached (`Config.Discord.CacheSeconds`, default 10 minutes). A denial is cached for a shorter time. If Discord is down, access is denied unless the player has the bypass ace or is an admin and `Config.Admin.BypassDiscord` is true.

The bot needs to be in the guild. Role ids are the role snowflakes, not role names. Enable the Server Members intent on the bot.

Players without a linked Discord account are denied while the check is enabled. The token never leaves the server and is never written into the NUI.

## Frameworks

`Config.Framework = 'auto'` uses `qbx_core` if it is started, then `qb-core`, then `es_extended`, otherwise standalone.

| Framework | Character name | Admin check |
| --- | --- | --- |
| QBCore | `charinfo` first and last name | `QBCore.Functions.HasPermission` for `Config.Admin.Groups.qbcore`, plus the `djerp.admin` ace |
| Qbox | same player data through `exports.qbx_core:GetPlayer` | `exports.qbx_core:HasPermission` |
| ESX Legacy | `xPlayer.getName()` | `xPlayer.getGroup()` against `Config.Admin.Groups.esx` |
| Standalone | `GetPlayerName` | ace only |

Notifications use ox_lib when it is started, then the framework notification, then the native feed.

## How pairing works

1. The player opens the menu. The server checks Discord, then sends only the emotes that passed the config and the file parse.
2. Nearby players are measured on the server with `GetEntityCoords`. The client list is not trusted.
3. A paired emote sends an invite. The target must also pass the Discord check. Distance is checked again on accept.
4. After accept, the server fires the same two client events rpemotes-reborn uses in `server/Server.lua` after `confirmEmote`:
   - `rpemotes:client:syncEmote` on the accepting player, with the partner clip
   - `rpemotes:client:syncEmoteSource` on the requester, with the clip they picked
5. Either player can cancel with the cancel key. Disconnect, death, and the natural end of the animation clear the session and detach both peds.
6. Solo clips call `Execute(name, emoteType)` on the local player. Preview plays the same export, then cancels after `Config.PreviewSeconds`.

Clients cannot submit an animation dictionary or an arbitrary name. The server looks the id up in the parsed catalog. Unknown ids are ignored.

One pending invite per player. A player who is already in a session cannot send or receive another. Invites expire (`Config.InviteTimeout`) and the sender has a cooldown (`Config.InviteCooldown`).

## Adding custom emotes

1. Stream the `.ycd` the way rpemotes documents, and register the shared emote in `AnimationListCustom.lua` under `CustomDP.Shared`.
2. Put the **initiator** id in `Config.Categories` (usually `custom` or `positions`). Do not also list the partner id unless you want that side offered as its own card. The partner id is read from the fourth string, or from `secondPlayersAnim`.
3. Restart rpemotes-reborn and this resource, or run `djerp_reload` after rpemotes has restarted.
4. If the id is still missing, `djerp_scan` and the server console will say it was hidden.

`Config.AutoIncludeAdult = true` also pulls human clips flagged `AdultAnimation = true` into Adult. The denylist in `Config.DisabledAnimations` still applies. Animal clips stay out either way.

## Admin

Players with `djerp.admin` or a configured framework group get the Admin screen:

- enable or disable a category
- enable or disable a discovered emote (the id must exist in the parsed RPEmotes files)
- set distance (clamped to `Config.MaxInteractionDistance`), invite timeout, and cooldown
- set the guild id and role ids
- reload the animation files
- read the interaction log

The bot token is not editable from the menu. Change the convar and restart.

`djerp.bypass` skips the Discord role check. Admins skip it too while `Config.Admin.BypassDiscord` is true.

## Files

| Path | Role |
| --- | --- |
| `config.lua` | Framework, Discord ids, emote allowlist, distance, keys |
| `shared/parser.lua` | Reads RPEmotes list files without executing them |
| `shared/catalog.lua` | Applies the allowlist, denylist, and admin overrides |
| `bridge/` | QBCore, Qbox, ESX Legacy, standalone |
| `server/discord.lua` | Role lookup. Token stays here |
| `server/main.lua` | Invites, distance checks, sync, cleanup |
| `client/animation.lua` | `Execute`, cancel, session watch |
| `html/` | NUI |
| `sql/install.sql` | Optional tables |
| `data/` | JSON fallback and admin settings. Not sent to clients |
| `preview/` | UI captures of the NUI |
| `tests/parser_test.lua` | Parser and allowlist test |

Favorites and recent emotes are stored per license identifier. Interaction rows record invite, accept, decline, timeout, cancel, solo play, and disconnect. They are not a public feed.

## Browser preview

`html/js/preview-data.js` is a snapshot of the stock 2.2.0 allowlist so the NUI can be opened in a browser. FiveM ignores that snapshot and uses the server payload. Rebuild it, from a machine that has the rpemotes file, with:

```bash
lua5.4 tests/parser_test.lua /path/to/rpemotes-reborn/client/AnimationList.lua
lua5.4 tests/build_preview.lua /path/to/rpemotes-reborn/client/AnimationList.lua
```

## Limits

This environment did not boot a FiveM server, so QBCore, Qbox, ESX, and the Discord HTTP call were not executed live. The catalog parser was run against the rpemotes-reborn 2.2.0 animation list, and the NUI was exercised in a browser. On your server, confirm `djerp_scan` and one paired accept with `AdultEmotesDisabled` off before you open it to players.
