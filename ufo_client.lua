local ufos = {} 
local inZone = false
local ufosInZones = {}
local currentZoneId = nil
local lastSpawnTime = 0  
local ufoSpawnCooldown = {} 
local playersInZone = {} 

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
                    TriggerEvent("vorp:TipBottom", _U('EnteredUfoZone'), 5000)
                    if Config.DebugPrints then print("Entrou na zona dos OVNIs: Zona " .. zone.id)end
                    inZone = true

                    TriggerServerEvent('playerEnteredUfoZone', currentZoneId)
                end

                break
            end
        end

        if not playerInZone and inZone then
            TriggerEvent("vorp:TipBottom", _U('LeftUfoZone'), 5000)
            if Config.DebugPrints then print("Saiu da zona dos OVNIs.")end
            
            inZone = false
            currentZoneId = nil
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
    ufoSpawnCooldown[zoneId] = GetGameTimer()
    if Config.DebugPrints then print("Cooldown redefinido para a zona " .. zoneId)end
end

function GetUfoSpawnCooldown(zoneId)
    return ufoSpawnCooldown[zoneId] or 0  
end

function CanSpawnUfo(zoneId)
    local currentTime = GetGameTimer()
    return (ufoSpawnCooldown[zoneId] or 0) < currentTime
end

function GetPlayersInZone(zone)
    local playersInZone = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)

        if Vdist(zone.x, zone.y, zone.z, playerCoords.x, playerCoords.y, playerCoords.z) <= zone.radius then
            table.insert(playersInZone, playerId)
        end
    end

    return playersInZone
end

function SpawnUfosInZone(zone)
    if not inZone or currentZoneId ~= zone.id then
        if Config.DebugPrints then print("Jogador não está mais na zona. Nenhum OVNI será gerado.")end
        return -- Sai da função se o jogador não estiver na zona
    end

    local currentTime = GetGameTimer()
    local zoneId = zone.id

    if zoneId then
        local lastSpawnTime = ufoSpawnCooldown[zoneId] or 0  

        local spawnInterval = Config.UfoSpawnInterval or 10000  -- 10 segundos como padrão

        local shouldSpawnUfo = (currentTime - lastSpawnTime) > spawnInterval
        local currentUfoCount = ufosInZones[zoneId] or 0
        Citizen.InvokeNative(0x1794B4FCC84D812F, ufo, true)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ufo, 255, 0)

        if currentUfoCount >= 1 then  
            if Config.DebugPrints then print("Limite de OVNIs atingido para a zona " .. zoneId)end
            return -- Interrompe o spawn se o número máximo de OVNIs for atingido
        end

        if shouldSpawnUfo then
            local playersInZone = GetPlayersInZone(zone)  -- Função para obter a lista de jogadores na zona
            if #playersInZone > 0 then
                local playerIdToSpawn = playersInZone[math.random(#playersInZone)]
                local playerPed = GetPlayerPed(playerIdToSpawn)

                if playerPed and DoesEntityExist(playerPed) then
                    Citizen.Wait(5000) -- Aguarda 5 segundos
                    HandleUfoCooldown(zoneId) -- Atualiza o tempo do cooldown
                    if Config.DebugPrints then print("Tentando spawnar OVNIs na zona " .. zoneId)end

                    local spawnValid = false
                    local spawnX, spawnY, spawnZ

                    for attempt = 1, 10 do
                        local offsetX = math.random(-zone.radius, zone.radius)
                        local offsetY = math.random(-zone.radius, zone.radius)
                        spawnX = zone.x + offsetX
                        spawnY = zone.y + offsetY
                        spawnZ = zone.z + 10.0 -- Spawna a 10 metros do chão

                        if Vdist(zone.x, zone.y, zone.z, spawnX, spawnY, spawnZ) <= zone.radius then
                            spawnValid = true

                            for _, existingUfoId in ipairs(ufos) do
                                local existingUfo = NetworkGetEntityFromNetworkId(existingUfoId)
                                if DoesEntityExist(existingUfo) then
                                    local existingUfoCoords = GetEntityCoords(existingUfo)
                                    if Vdist(existingUfoCoords.x, existingUfoCoords.y, existingUfoCoords.z, spawnX, spawnY, spawnZ) < 20.0 then
                                        spawnValid = false
                                        if Config.DebugPrints then print("Ponto de spawn muito próximo de outro OVNI existente.")end
                                        break
                                    end
                                end
                            end

                            if spawnValid then
                                break
                            end
                        end
                    end

                    if spawnValid then
                        local ufoId = SpawnUfo(spawnX, spawnY, spawnZ, zoneId)
                        if ufoId then
                            FollowPlayer(ufoId) -- Faz o OVNI seguir o jogador
                            ufosInZones[zoneId] = (ufosInZones[zoneId] or 0) + 1  -- Incrementa o contador de OVNIs na zona
                            TriggerServerEvent('requestUfoSpawn', zoneId) -- Notifica o servidor que o OVNI foi spawnado
                        else
                            if Config.DebugPrints then print("Falha ao criar o OVNI. Não foi possível seguir o jogador.")end
                        end
                    else
                        if Config.DebugPrints then print("Nenhuma posição válida encontrada para o spawn do OVNI.")end
                    end
                else
                    if Config.DebugPrints then print("Jogador não encontrado ou não existe.")end
                end
            else
                if Config.DebugPrints then print("Nenhum jogador presente na zona.")end
            end
        else
            if Config.DebugPrints then print("Cooldown não expirado ainda para a zona " .. zoneId)end
        end
    else
        if Config.DebugPrints then print("zoneId não definido.")end
    end
end

function SpawnUfo(x, y, z, zoneId)
    local ufoModel = "s_ufo02x"

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
        if Config.DebugPrints then print("OVNI criado com ID " .. ufoId .. " na zona " .. zoneId .. " com coordenadas (" .. x .. ", " .. y .. ", " .. z .. ")") end

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local followDuration = 5000  -- 5 segundos
            local startTime = GetGameTimer()
            local originalZ = GetEntityCoords(playerPed).z

            if IsPedOnMount(playerPed) then
                TaskDismountAnimal(playerPed, 0, 0, 0, 0, 0)
                Citizen.Wait(2000)
            elseif IsPedInAnyVehicle(playerPed, false) then
                TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 0)
                Citizen.Wait(2000)
            end

            while GetGameTimer() - startTime < followDuration do
                Citizen.Wait(0)
                local playerCoords = GetEntityCoords(playerPed)
                SetEntityCoordsNoOffset(ufo, playerCoords.x, playerCoords.y, z + 10, false, false, false)
            end

            local pcoords = GetEntityCoords(playerPed)
            local pheading = GetEntityHeading(playerPed)
            FreezeEntityPosition(playerPed, true)
            Anim(playerPed, 'script_story@gng2@ig@ig12_bullard_controls', 'calm_looking_up')

            while pcoords.z < z + 10 do
                pcoords = GetEntityCoords(playerPed)
                SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z + 0.03, pheading, 0.0, 0.0)
                Citizen.Wait(0)
            end

            SetEntityVisible(playerPed, false)  -- Esconde o jogador
            Citizen.Wait(10000)
            AnimpostfxPlay('cunsumefortgeneric01')
            if Config.HostilePlayer then
                local MaxIndex = #Config.HostileCoords
                local RandomIndex = math.random(1,MaxIndex)
                local SelectedCoords = Config.HostileCoords[RandomIndex]
			    AnimpostfxPlay('playerwakeupdrunk')
                SetEntityCoords(playerPed,SelectedCoords.Coords.x,SelectedCoords.Coords.y,SelectedCoords.Coords.z -1)
                SetEntityHeading(playerPed,SelectedCoords.Heading)
                SetEntityVisible(playerPed, true)
            else
            SetEntityVisible(playerPed, true)  -- Torna o jogador visível novamente
            Anim(playerPed, 'script_story@gng2@ig@ig12_bullard_controls', 'calm_looking_up')

            local ufoHeight = GetEntityCoords(ufo).z
            local groundZ = 0.0
            local foundGround, groundZ = GetGroundZFor_3dCoord(pcoords.x, pcoords.y, pcoords.z, false)

            while GetEntityCoords(playerPed).z > (groundZ + 3.0) or GetEntityCoords(playerPed).z > originalZ do
                pcoords = GetEntityCoords(playerPed)
                
                if GetEntityCoords(playerPed).z > (groundZ + 3.0) then
                    SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z - 0.03, pheading, 0.0, 0.0)
                end
                
                if GetEntityCoords(playerPed).z > originalZ then
                    SetEntityCoordsNoOffset(playerPed, pcoords.x, pcoords.y, pcoords.z - 0.03, pheading, 0.0, 0.0)
                end
            
                Citizen.Wait(0)
            end
            end
            FreezeEntityPosition(playerPed, false)
            ClearPedTasksImmediately(playerPed)

            if DoesEntityExist(ufo) and NetworkHasControlOfEntity(ufo) then
                DeleteEntity(ufo)
            end
        end)
    end

    return ufoId
end

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
                        if Config.DebugPrints then print("Deletando OVNI com ID " .. ufoId)end
                        DeleteEntity(ufo)
                    else
                        if Config.DebugPrints then print("Falha ao obter controle do OVNI ID " .. ufoId)end
                    end
                else
                    if Config.DebugPrints then print("OVNI " .. ufoId .. " já foi removido.")end
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
                if Config.DebugPrints then print("Animation Failed to Load")end
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
        --FollowPlayer(ufoId) -- Faz o OVNI seguir o jogador
    end
end)