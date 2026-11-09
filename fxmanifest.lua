fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dj-erp-menu'
author 'Diesel Dev Shack'
description 'DJ ERP Menu for Phoenikera RP - paired adult roleplay interactions for RPEmotes'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/util.lua',
    'shared/parser.lua',
    'shared/catalog.lua',
    'shared/resource.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/animation.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/discord.lua',
    'server/storage.lua',
    'server/catalog.lua',
    'server/main.lua',
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/preview-data.js',
    'html/assets/brand-mark.webp',
    'html/assets/fonts/outfit-400.woff2',
    'html/assets/fonts/outfit-600.woff2',
    'html/assets/fonts/outfit-800.woff2',
}

escrow_ignore {
    'config.lua',
    'bridge/*.lua',
    'shared/*.lua',
    'server/*.lua',
    'client/*.lua',
}
