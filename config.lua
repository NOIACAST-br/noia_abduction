--- ████    ██  ██████  ██████    ██████
--- ██ ██   ██ ██    ██   ██     ██    ██
--- ██  ██  ██ ██    ██   ██    ██      ██
--- ██   ██ ██ ██    ██   ██    ██████████
--- ██    █████  ██████ ██████  ██      ██

Config = {}
Config.DebugPrints = true

Config.UfoSpawnZones = {
    {id = 1, x = -445.59, y = 8.94, z = 42.47, radius = 55.0 }, 
    -- Add more zones
}

Config.UfoSpawnInterval = 20000 -- Interval of 10 seg for spawns

Config.HostilePlayer = true
Config.HostileCoords = {
    { Coords = vector3(-1782.5574, -556.5885, 156.0640), Heading = 0.0 }, -- STRAWBERRY
    { Coords = vector3(-1495.7021, -1449.3928, 94.5889), Heading = 0.0}, -- BLACKWATER
    { Coords = vector3(-2643.6550, -2546.9980, 73.7439), Heading = 0.0}, -- MC FARLENS
    -- Add more
}

Config.Messages = {
    EnteredUfoZoneTitle = "Você entrou na zona de OVNI!",
    EnteredUfoZoneSubtitle = "Cuidado, algo estranho está acontecendo.",
    EnteredUfoZoneDict = "BLIPS",
    EnteredUfoZoneIcon = "blip_ambient_eyewitness",
    EnteredUfoZoneDuration = 5000,
    EnteredUfoZoneColor = "COLOR_GREEN",

    LeftUfoZoneTitle = "Você saiu da zona de OVNI.",
    LeftUfoZoneSubtitle = "Parece que você está seguro agora.",
    LeftUfoZoneDict = "BLIPS",
    LeftUfoZoneIcon = "blip_ambient_eyewitness",
    LeftUfoZoneDuration = 5000,
    LeftUfoZoneColor = "COLOR_RED"
}

