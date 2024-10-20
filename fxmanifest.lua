fx_version 'cerulean'
games { 'rdr3', 'gta5' }

author 'NOIACAST'
description 'Noia Abduction'
version '1.0.1'

shared_scripts {
    'config.lua',
    'languages/translation.lua',
}

client_scripts {
    'ufo_client.lua'
}

server_scripts {
    'server.lua'
}

-- Aviso de pré-lançamento
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
