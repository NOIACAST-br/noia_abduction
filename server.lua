local ufosInZones = {}

-- Inicializa a tabela de contagem de OVNIs por zona
for i, zone in ipairs(Config.UfoSpawnZones) do
    zone.id = i
    ufosInZones[i] = 0
end

-- Evento para solicitar spawn de OVNIs
RegisterNetEvent('requestUfoSpawn')
AddEventHandler('requestUfoSpawn', function(zoneId)
    local maxUfos = Config.UfoSpawnLimits[zoneId]

    if ufosInZones[zoneId] < maxUfos then
        ufosInZones[zoneId] = ufosInZones[zoneId] + 1

        local zone = Config.UfoSpawnZones[zoneId]
        local spawnX, spawnY, spawnZ = zone.x + math.random(-zone.radius, zone.radius), zone.y + math.random(-zone.radius, zone.radius), zone.z + 10.0

        -- Obter uma lista de jogadores conectados
        local players = GetPlayers()
        local playersNearby = {}
        local maxDistance = 500.0 -- Distância máxima para considerar jogadores próximos

        -- Checar a proximidade de cada jogador
        for _, playerId in ipairs(players) do
            local playerPed = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(playerPed)

            -- Calcular a distância entre o jogador e o ponto de spawn
            local distance = #(playerCoords - vector3(spawnX, spawnY, spawnZ))

            -- Verificar se o jogador está dentro da distância permitida
            if distance <= maxDistance then
                table.insert(playersNearby, playerId)
            end
        end

        -- Selecionar um jogador aleatório da lista de jogadores próximos
        if #playersNearby > 0 then
            local randomPlayer = playersNearby[math.random(1, #playersNearby)]

            -- Notificar apenas o jogador selecionado para spawnar o OVNI
            TriggerClientEvent('spawnufos_cl', randomPlayer, spawnX, spawnY, spawnZ, zoneId)

            -- Log no servidor
            print("OVNI spawnado na zona " .. zoneId .. " para o jogador " .. randomPlayer .. ". Total de OVNIs: " .. ufosInZones[zoneId])
        else
            print("Nenhum jogador próximo o suficiente para spawnar o OVNI.")
        end
    else
        print("Limite de OVNIs atingido na zona " .. zoneId .. ". Max: " .. maxUfos)
    end
end)

-- Evento para remover OVNIs (pode ser chamado após uma abdução ou morte)
RegisterNetEvent('removeUfo')
AddEventHandler('removeUfo', function(zoneId)
    if ufosInZones[zoneId] and ufosInZones[zoneId] > 0 then
        ufosInZones[zoneId] = ufosInZones[zoneId] - 1
        print("OVNI removido da zona " .. zoneId .. ". OVNIs restantes: " .. ufosInZones[zoneId])
    else
        print("Nenhum OVNI para remover na zona " .. zoneId .. ".")
    end
end)

-- Evento para informar ao cliente que um OVNI foi removido
RegisterServerEvent('notifyUfoRemoval')
AddEventHandler('notifyUfoRemoval', function(zoneId)
    TriggerClientEvent('ufo:client:removeUfo', -1, zoneId)
end)

-- Remove todos os OVNIs ao reiniciar o script
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Redefine a tabela de contagem de OVNIs
        ufosInZones = {}
        print("Contagem de OVNIs redefinida ao parar o recurso.")
    end
end)
