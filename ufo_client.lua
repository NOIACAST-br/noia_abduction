local ufos = {} -- Tabela para armazenar IDs dos OVNIs
local inZone = false
local ufosInZones = {}
local currentZoneId = nil
local lastSpawnTime = 0  -- Variável para armazenar o último tempo de spawn
local ufoSpawnCooldown = {} -- Inicializa a tabela para armazenar cooldowns por zona
local playersInZone = {} -- Tabela para rastrear jogadores na zona

-- Função de debug
function debugPrint(message)
    if Config.Debug then
        print(message)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.NotificationCheckInterval)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local playerInZone = false

        for _, zone in ipairs(Config.UfoSpawnZones) do
            local distance = Vdist(playerCoords.x, playerCoords.y, playerCoords.z, zone.x, zone.y, zone.z)

            if distance < zone.radius then
                playerInZone = true
                currentZoneId = zone.id

                if not inZone then
                    inZone = true
                    TriggerServerEvent('playerEnteredUfoZone', currentZoneId) -- Envia evento para o servidor
                end

                break
            end
        end

        if not playerInZone and inZone then
            inZone = false
            currentZoneId = nil
            TriggerServerEvent('playerExitedUfoZone') -- Envia evento para o servidor
        end
    end
end)


function RemovePlayerFromZone(playerId)
    for i, id in ipairs(playersInZone) do
        if id == playerId then
            table.remove(playersInZone, i)
            break
        end
    end
end

function HandleUfoCooldown(zoneId)
    -- Redefine o cooldown para a zona
    ufoSpawnCooldown[zoneId] = GetGameTimer()
    debugPrint("Cooldown redefinido para a zona " .. zoneId)
end

function GetUfoSpawnCooldown(zoneId)
    return ufoSpawnCooldown[zoneId] or 0  
end

-- Verifica se o cooldown expirou para uma zona
function CanSpawnUfo(zoneId)
    local currentTime = GetGameTimer()
    return (ufoSpawnCooldown[zoneId] or 0) < currentTime
end

function GetPlayersInZone(zone)
    local playersInZone = {}

    -- Verifica todos os jogadores ativos no client-side
    for _, playerId in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)

        -- Verifica se o jogador está dentro do raio da zona
        if Vdist(zone.x, zone.y, zone.z, playerCoords.x, playerCoords.y, playerCoords.z) <= zone.radius then
            table.insert(playersInZone, playerId)
        end
    end

    return playersInZone
end

function SpawnUfosInZone(zone)
    -- Verifica se o jogador ainda está na zona antes de continuar
    if not inZone or currentZoneId ~= zone.id then
        debugPrint("Jogador não está mais na zona. Nenhum OVNI será gerado.")
        return -- Sai da função se o jogador não estiver na zona
    end

    local currentTime = GetGameTimer()
    local zoneId = zone.id

    -- Verifica se zoneId está definido
    if zoneId then
        local lastSpawnTime = ufoSpawnCooldown[zoneId] or 0  

        -- Define um valor padrão para ufoSpawnInterval se não estiver definido
        local spawnInterval = Config.UfoSpawnInterval or 10000  -- 10 segundos como padrão

        -- Verifica se o cooldown expirou ou se não há OVNIs na zona
        local shouldSpawnUfo = (currentTime - lastSpawnTime) > spawnInterval
        local currentUfoCount = ufosInZones[zoneId] or 0
        Citizen.InvokeNative(0x1794B4FCC84D812F, ufo, true)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ufo, 255, 0)

        -- Garante que apenas um OVNI será gerado por zona
        if currentUfoCount >= 1 then  
            debugPrint("Limite de OVNIs atingido para a zona " .. zoneId)
            return -- Interrompe o spawn se o número máximo de OVNIs for atingido
        end

        -- Continua o código de geração de OVNIs somente se o cooldown tiver expirado e o limite não tiver sido atingido
        if shouldSpawnUfo then
            -- Escolhe um jogador aleatório da lista de jogadores na zona
            local playersInZone = GetPlayersInZone(zone)  -- Função para obter a lista de jogadores na zona
            if #playersInZone > 0 then
                local playerIdToSpawn = playersInZone[math.random(#playersInZone)]
                local playerPed = GetPlayerPed(playerIdToSpawn)

                if playerPed and DoesEntityExist(playerPed) then
                    -- Adiciona um delay de 5 segundos antes de spawnar o OVNI
                    Citizen.Wait(5000) -- Aguarda 5 segundos
                    HandleUfoCooldown(zoneId) -- Atualiza o tempo do cooldown
                    debugPrint("Tentando spawnar OVNIs na zona " .. zoneId)

                    local spawnValid = false
                    local spawnX, spawnY, spawnZ

                    -- Tentativa de encontrar uma posição válida
                    for attempt = 1, 10 do
                        local offsetX = math.random(-zone.radius, zone.radius)
                        local offsetY = math.random(-zone.radius, zone.radius)
                        spawnX = zone.x + offsetX
                        spawnY = zone.y + offsetY
                        spawnZ = zone.z + 1.0 -- Spawna a 10 metros do chão

                        -- Verifica se o ponto está dentro do raio da zona
                        if Vdist(zone.x, zone.y, zone.z, spawnX, spawnY, spawnZ) <= zone.radius then
                            spawnValid = true

                            -- Verifica se não está muito próximo de outro OVNI já existente
                            for _, existingUfoId in ipairs(ufos) do
                                local existingUfo = NetworkGetEntityFromNetworkId(existingUfoId)
                                if DoesEntityExist(existingUfo) then
                                    local existingUfoCoords = GetEntityCoords(existingUfo)
                                    if Vdist(existingUfoCoords.x, existingUfoCoords.y, existingUfoCoords.z, spawnX, spawnY, spawnZ) < 20.0 then
                                        spawnValid = false
                                        debugPrint("Ponto de spawn muito próximo de outro OVNI existente.")
                                        break
                                    end
                                end
                            end

                            if spawnValid then
                                break
                            end
                        end
                    end

                    -- Se encontrou uma posição válida, cria o OVNI
                    if spawnValid then
                        local ufoId = SpawnUfo(spawnX, spawnY, spawnZ, zoneId)
                        if ufoId then
                            --FollowPlayer(ufoId) -- Faz o OVNI seguir o jogador
                            ufosInZones[zoneId] = (ufosInZones[zoneId] or 0) + 1  -- Incrementa o contador de OVNIs na zona
                            TriggerServerEvent('requestUfoSpawn', zoneId) -- Notifica o servidor que o OVNI foi spawnado
                        else
                            debugPrint("Falha ao criar o OVNI. Não foi possível seguir o jogador.")
                        end
                    else
                        debugPrint("Nenhuma posição válida encontrada para o spawn do OVNI.")
                    end
                else
                    debugPrint("Jogador não encontrado ou não existe.")
                end
            else
                debugPrint("Nenhum jogador presente na zona.")
            end
        else
            debugPrint("Cooldown não expirado ainda para a zona " .. zoneId)
        end
    else
        debugPrint("zoneId não definido.")
    end
end

function SpawnUfo(x, y, z, zoneId)
    local ufoModel = "s_ufo02x"

    -- Verifica se o modelo já está carregado antes de criar o OVNI
    if not HasModelLoaded(ufoModel) then
        RequestModel(ufoModel)
        while not HasModelLoaded(ufoModel) do
            Citizen.Wait(10)
        end
    end

    local ufo = CreateObject(ufoModel, x, y, z, true, true, false)
    Citizen.InvokeNative(0x1794B4FCC84D812F, ufo, true)  -- SetRandomOutfitVariation
    local ufoId = NetworkGetNetworkIdFromEntity(ufo)

    if DoesEntityExist(ufo) then
        table.insert(ufos, ufoId)
        debugPrint("OVNI criado com ID " .. ufoId .. " na zona " .. zoneId .. " com coordenadas (" .. x .. ", " .. y .. ", " .. z .. ")")

        -- Thread para seguir o jogador
        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local followDuration = 5000  -- 5 segundos
            local startTime = GetGameTimer()
            local originalZ = GetEntityCoords(playerPed).z

            -- Verifica se o jogador está montado em um cavalo ou veículo
            if IsPedOnMount(playerPed) then
                TaskDismountAnimal(playerPed, 0, 0, 0, 0, 0)
                Citizen.Wait(2000)
            elseif IsPedInAnyVehicle(playerPed, false) then
                TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 0)
                Citizen.Wait(2000)
            end

            -- Seguir o jogador por 5 segundos
            while GetGameTimer() - startTime < followDuration do
                Citizen.Wait(0)
                local playerCoords = GetEntityCoords(playerPed)
                SetEntityCoordsNoOffset(ufo, playerCoords.x, playerCoords.y, z + 10, false, false, false)
            end

            -- Levanta o jogador
            local pcoords = GetEntityCoords(playerPed)
            local pheading = GetEntityHeading(playerPed)
            FreezeEntityPosition(playerPed, true)
            Anim(playerPed, 'script_story@gng2@ig@ig12_bullard_controls', 'calm_looking_up')

            -- Levanta o jogador até a altura do OVNI
            while pcoords.z < z + 10 do
                pcoords = GetEntityCoords(playerPed)
                SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z + 0.03, pheading, 0.0, 0.0)
                Citizen.Wait(0)
            end

            SetEntityVisible(playerPed, false)  -- Esconde o jogador

            local currentHealth = GetEntityHealth(playerPed)  -- Obtém a saúde atual do jogador
            local newHealth = currentHealth - 80  -- Reduz a saúde em 80 pontos
            SetEntityHealth(playerPed, newHealth)  -- Define a nova saúde do jogador

            -- Animação e estresse durante a abdução pelo OVNI
            Anim(playerPed, 'script_story@gng2@ig@ig12_bullard_controls', 'calm_looking_up')  -- Animação de olhar para cima
            TriggerServerEvent("updateStressOnUfoAbduction", 20)  -- Envia para o servidor, adiciona 20 de estresse

            Citizen.Wait(10000)  -- Aguarda enquanto o jogador está invisível

            AnimpostfxPlay('cunsumefortgeneric01')
            if Config.HostilePlayer then
                local MaxIndex = #Config.HostileCoords
                local RandomIndex = math.random(1, MaxIndex)
                local SelectedCoords = Config.HostileCoords[RandomIndex]
                AnimpostfxPlay('playerwakeupdrunk')
                SetEntityCoords(playerPed, SelectedCoords.Coords.x, SelectedCoords.Coords.y, SelectedCoords.Coords.z + 2)
                SetEntityHeading(playerPed, SelectedCoords.Heading)
                SetEntityVisible(playerPed, true)
            else
                SetEntityVisible(playerPed, true)  -- Torna o jogador visível novamente
                Anim(playerPed, 'script_story@gng2@ig@ig12_bullard_controls', 'calm_looking_up')

                -- Baixa o jogador
                local ufoHeight = GetEntityCoords(ufo).z
                local groundZ = 0.0
                local foundGround, groundZ = GetGroundZFor_3dCoord(pcoords.x, pcoords.y, pcoords.z, false)

                while GetEntityCoords(playerPed).z > (groundZ + 3.0) or GetEntityCoords(playerPed).z > originalZ do
                    pcoords = GetEntityCoords(playerPed)

                    -- Mover o jogador para baixo se estiver acima do groundZ + 3.0
                    if GetEntityCoords(playerPed).z > (groundZ + 3.0) then
                        SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z - 0.03, pheading, 0.0, 0.0)
                    end

                    -- Mover o jogador para baixo se estiver acima do originalZ
                    if GetEntityCoords(playerPed).z > originalZ then
                        SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z - 0.03, pheading, 0.0, 0.0)
                    end

                    Citizen.Wait(0)
                end
            end  -- Fechando o bloco do "else"

            FreezeEntityPosition(playerPed, false)
            ClearPedTasksImmediately(playerPed)

            -- Verifica se o controle do OVNI é do cliente antes de deletar
            if DoesEntityExist(ufo) and NetworkHasControlOfEntity(ufo) then
                DeleteEntity(ufo)
            end
        end)
    end

    return ufoId
end

-- Remove todos os OVNIs ao reiniciar o script
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, ufoId in ipairs(ufos) do
            local ufo = NetworkGetEntityFromNetworkId(ufoId)

            if DoesEntityExist(ufo) then
                if not NetworkHasControlOfEntity(ufo) then
                    NetworkRequestControlOfEntity(ufo)

                    local timeout = 1000  -- Aumentar o timeout para 1 segundo
                    while not NetworkHasControlOfEntity(ufo) and timeout > 0 do
                        Citizen.Wait(10)
                        timeout = timeout - 10
                    end
                end

                if DoesEntityExist(ufo) then
                    if not NetworkHasControlOfEntity(ufo) then
                        NetworkRequestControlOfEntity(ufo)

                        -- Aguarda até obter controle
                        local timeout = 1000  -- Timeout aumentado para 1 segundo
                        while not NetworkHasControlOfEntity(ufo) and timeout > 0 do
                            Citizen.Wait(10)
                            timeout = timeout - 10
                        end
                    end

                    if NetworkHasControlOfEntity(ufo) then
                        debugPrint("Deletando OVNI com ID " .. ufoId)
                        DeleteEntity(ufo)
                    else
                        debugPrint("Falha ao obter controle do OVNI ID " .. ufoId)
                    end
                else
                    debugPrint("OVNI " .. ufoId .. " já foi removido.")
                end
            end                
        end
        ufos = {}
    end
end)

function Anim(actor, dict, body, duration, flags, introtiming, exittiming)
    Citizen.CreateThread(function()
        RequestAnimDict(dict)
        local dur = duration or -1
        local flag = flags or 1
        local intro = tonumber(introtiming) or 1.0
        local exit = tonumber(exittiming) or 2.0
        timeout = 5
        while (not HasAnimDictLoaded(dict) and timeout>0) do
            timeout = timeout-1
            if timeout == 0 then
                debugPrint("Animation Failed to Load")
            end
            Citizen.Wait(300)
        end
        TaskPlayAnim(actor, dict, body, intro, exit, dur, flag, 1, false, false, false, 0, true)
    end)
end

RegisterNetEvent('spawnufos_cl')
AddEventHandler('spawnufos_cl', function(spawnX, spawnY, spawnZ, zoneId)
    local ufoId = SpawnUfo(spawnX, spawnY, spawnZ, zoneId)
    if ufoId then
    end
end)
