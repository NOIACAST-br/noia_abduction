local ufosInZones = {}
local zoneCooldowns = {}
local ufoSpawned = {}
local ufoSpawnCooldown = {}
local Core = exports.vorp_core:GetCore() -- Obter o core

-- Função de debug
function debugPrint(message)
    if Config.Debug then
        print(message)
    end
end

RegisterNetEvent('playerEnteredUfoZone')
AddEventHandler('playerEnteredUfoZone', function(zoneId)
    local src = source -- O jogador que entrou na zona
    local currentTime = GetGameTimer()

    if (ufoSpawnCooldown[zoneId] or 0) < currentTime then
        local playersInZone = GetPlayersInZone(zoneId)
        if #playersInZone > 0 then
            if not ufosInZones[zoneId] or (ufosInZones[zoneId].owner ~= src) then
                local chosenPlayer = playersInZone[math.random(#playersInZone)]

                TriggerClientEvent('spawnufos_cl', chosenPlayer, Config.UfoSpawnZones[zoneId].x, Config.UfoSpawnZones[zoneId].y, Config.UfoSpawnZones[zoneId].z, zoneId)

                ufoSpawnCooldown[zoneId] = currentTime + Config.UfoSpawnInterval
                ufosInZones[zoneId] = { count = 1, owner = chosenPlayer } -- Marca que um OVNI foi spawnado e quem é o dono
                debugPrint("OVNI spawnado na zona " .. zoneId .. " para o jogador " .. chosenPlayer)
            else
                debugPrint("OVNI já existe na zona " .. zoneId .. " e pertence ao jogador " .. ufosInZones[zoneId].owner)
            end
        end
    else
        debugPrint("Cooldown ativo para a zona " .. zoneId)
    end
end)

RegisterNetEvent('playerExitedUfoZone')
AddEventHandler('playerExitedUfoZone', function(zoneId)
    local src = source -- O jogador que saiu da zona

    if ufosInZones[zoneId] and ufosInZones[zoneId].owner == src then
        ufosInZones[zoneId] = nil
        debugPrint("OVNI removido da zona " .. zoneId .. " porque o jogador " .. src .. " saiu.")
    end
end)

local function CalculateDistance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function GetPlayersInZone(zoneId)
    local playersInZone = {}
    local zone = Config.UfoSpawnZones[zoneId]

    for _, playerId in ipairs(GetPlayers()) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)

        if CalculateDistance(playerCoords.x, playerCoords.y, playerCoords.z, zone.x, zone.y, zone.z) <= zone.radius then
            table.insert(playersInZone, playerId)
        end
    end

    return playersInZone
end

RegisterNetEvent('requestUfoSpawn')
AddEventHandler('requestUfoSpawn', function(zoneId)
    if not ufosInZones[zoneId] then
        -- Spawnar o OVNI
        local zone = Config.UfoSpawnZones[zoneId]
        local spawnX, spawnY, spawnZ = zone.x + math.random(-zone.radius, zone.radius), zone.y + math.random(-zone.radius, zone.radius), zone.z + 10.0

        local players = GetPlayers()
        local playersNearby = {}
        local maxDistance = 500.0 -- Distância máxima para considerar jogadores próximos

        for _, playerId in ipairs(players) do
            local playerPed = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(playerPed)

            local distance = #(playerCoords - vector3(spawnX, spawnY, spawnZ))

            if distance <= maxDistance then
                table.insert(playersNearby, playerId)
            end
        end

        if #playersNearby > 0 then
            local randomPlayer = playersNearby[math.random(1, #playersNearby)]

            TriggerClientEvent('spawnufos_cl', randomPlayer, spawnX, spawnY, spawnZ, zoneId)

            ufosInZones[zoneId] = { count = 1, owner = randomPlayer }

            debugPrint("OVNI spawnado na zona " .. zoneId .. " para o jogador " .. randomPlayer .. ". Total de OVNIs: " .. ufosInZones[zoneId].count)
        else
            debugPrint("Nenhum jogador próximo o suficiente para spawnar o OVNI.")
        end
    else
        debugPrint("OVNI já spawnado na zona " .. zoneId .. ".")
    end
end)

function table.contains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

RegisterNetEvent('removeUfo')
AddEventHandler('removeUfo', function(zoneId)
    if ufosInZones[zoneId] and ufosInZones[zoneId].count > 0 then
        local ufoId = ufoIds[zoneId] -- Obtém o ID do OVNI
        if DoesEntityExist(ufoId) then
            DeleteEntity(ufoId) -- ou a função específica que remove o OVNI
            ufosInZones[zoneId].count = ufosInZones[zoneId].count - 1 -- Limpa a contagem de OVNIs na zona
            debugPrint("OVNI removido da zona " .. zoneId .. ". OVNIs restantes: " .. ufosInZones[zoneId].count)
            ufoSpawned[zoneId] = nil -- Limpar a marcação do OVNI spawnado
            ufoSpawnCooldown[zoneId] = nil -- Limpar o cooldown
        else
            debugPrint("OVNI não existe mais para remover na zona " .. zoneId .. ".")
        end
    else
        debugPrint("Nenhum OVNI para remover na zona " .. zoneId .. ".")
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ufosInZones = {}
        ufoSpawnInProgress = {}
        if Config.DebugPrints then print("Contagem de OVNIs redefinida ao parar o recurso.") end
    end
end)

------NOTIFY
RegisterServerEvent('playerEnteredUfoZone')
AddEventHandler('playerEnteredUfoZone', function(zoneId)
    local playerId = source -- Obter o ID do jogador
    local Character = Core.getUser(playerId).getUsedCharacter

    Core.NotifyLeft(playerId, Config.Messages.EnteredUfoZoneTitle,
        Config.Messages.EnteredUfoZoneSubtitle,
        Config.Messages.EnteredUfoZoneDict,
        Config.Messages.EnteredUfoZoneIcon,
        Config.Messages.EnteredUfoZoneDuration,
        Config.Messages.EnteredUfoZoneColor)

    debugPrint("Jogador " .. playerId .. " entrou na zona dos OVNIs: Zona " .. zoneId)
end)

RegisterServerEvent('playerExitedUfoZone')
AddEventHandler('playerExitedUfoZone', function()
    local playerId = source -- Obter o ID do jogador

    Core.NotifyLeft(playerId, Config.Messages.LeftUfoZoneTitle,
        Config.Messages.LeftUfoZoneSubtitle,
        Config.Messages.LeftUfoZoneDict,
        Config.Messages.LeftUfoZoneIcon,
        Config.Messages.LeftUfoZoneDuration,
        Config.Messages.LeftUfoZoneColor)

    debugPrint("Jogador " .. playerId .. " saiu da zona dos OVNIs.")
end)
