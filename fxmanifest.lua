fx_version 'cerulean'
game 'gta5'

author 'Valder'
description 'Garage system'
version '1.5.2'

shared_scripts {
    '@ox_lib/init.lua',
    'Config/shared.lua'
}

client_scripts {
    'Config/client.lua',
    'Client/**.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@vrp/lib/utils.lua',
    'Config/server.lua',
    'Server/**.lua'
}
ui_page 'web/index.html'
files {
    'web/index.html',
    'web/script.js',
    'web/style.css',
}