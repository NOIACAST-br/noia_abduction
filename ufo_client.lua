local ufos = {} -- Tabela para armazenar IDs dos OVNIs
local inZone = false
local ufosInZones = {}
local currentZoneId = nil
local lastSpawnTime = 0  -- Variável para armazenar o último tempo de spawn
local ufoSpawnCooldown = {} -- Inicializa a tabela para armazenar cooldowns por zona

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
                    -- Notifica o jogador ao entrar na zona de OVNIs
                    TriggerEvent("vorp:TipBottom", Config.Messages.EnteredUfoZone, 5000)
                    print("Entrou na zona dos OVNIs: Zona " .. zone.id)
                    inZone = true

                    -- Redefine o cooldown e spawn OVNIs
                    HandleUfoCooldown(zone.id)
                    SpawnUfosInZone(zone)
                end
            
                break
            end
        end

        if not playerInZone and inZone then
            -- Limpa a contagem de OVNIs na zona ao sair
            ufosInZones[currentZoneId] = 0 
            -- Notifica o jogador ao sair da zona de OVNIs
            TriggerEvent("vorp:TipBottom", Config.Messages.LeftUfoZone, 5000)
            print("Saiu da zona dos OVNIs.")
            
            -- Redefine o cooldown para que novos OVNIs possam aparecer na próxima entrada
            ufoSpawnCooldown[currentZoneId] = nil  -- Mover esta linha para antes de definir currentZoneId como nil
            
            inZone = false
            currentZoneId = nil  -- Definir como nil após redefinir o cooldown
        end
    end
end)

function HandleUfoCooldown(zoneId)
    -- Redefine o cooldown para a zona
    ufoSpawnCooldown[zoneId] = 0  -- Corrigido: atribuindo diretamente à tabela
    print("Cooldown redefinido para a zona " .. zoneId)
end

function GetUfoSpawnCooldown(zoneId)
    return ufoSpawnCooldown[zoneId] or 0  -- Retorna 0 se zoneId não existir
end

function SpawnUfosInZone(zone)
    -- Verifica se o jogador ainda está na zona antes de continuar
    if not inZone or currentZoneId ~= zone.id then
        print("Jogador não está mais na zona. Nenhum OVNI será gerado.")
        return -- Sai da função se o jogador não estiver na zona
    end

    local currentTime = GetGameTimer()
    local zoneId = zone.id

    -- Verifica se zoneId está definido
    if zoneId then
        local lastSpawnTime = ufoSpawnCooldown[zoneId] or 0  -- Usa 0 como valor padrão se for nil

        -- Define um valor padrão para ufoSpawnInterval se não estiver definido
        local spawnInterval = Config.UfoSpawnInterval or 10000  -- 10 segundos como padrão

        -- Verifica se o cooldown expirou ou se não há OVNIs na zona
        local shouldSpawnUfo = (currentTime - lastSpawnTime) > spawnInterval
        local maxUfos = Config.UfoSpawnLimits[zoneId] or 1
        local currentUfoCount = ufosInZones[zoneId] or 0

        -- Aqui vamos garantir que o limite de OVNIs seja respeitado
        if currentUfoCount >= maxUfos then
            print("Limite de OVNIs atingido para a zona " .. zoneId)
            return -- Interrompe o spawn se o número máximo de OVNIs for atingido
        end

        -- Continua o código de geração de OVNIs somente se o limite não foi atingido
        if shouldSpawnUfo then
            ufoSpawnCooldown[zoneId] = currentTime -- Atualiza o tempo do cooldown
            print("Tentando spawnar OVNIs na zona " .. zoneId)

            -- Continua com o loop de geração de OVNIs, mas apenas um por vez
            for i = 1, 1 do -- Mantém o valor em 1 para gerar apenas um OVNI por intervalo
                local spawnValid = false
                local spawnX, spawnY, spawnZ

                -- Tentativa de encontrar uma posição válida
                for attempt = 1, 10 do
                    local offsetX = math.random(-zone.radius, zone.radius)
                    local offsetY = math.random(-zone.radius, zone.radius)
                    spawnX = zone.x + offsetX
                    spawnY = zone.y + offsetY
                    spawnZ = zone.z + 10.0 -- Spawna a 10 metros do chão

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
                                    print("Ponto de spawn muito próximo de outro OVNI existente.")
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
                        FollowPlayer(ufoId) -- Faz o OVNI seguir o jogador
                        ufosInZones[zoneId] = (ufosInZones[zoneId] or 0) + 1  -- Incrementa o contador de OVNIs na zona
                    else
                        print("Falha ao criar o OVNI. Não foi possível seguir o jogador.")
                    end
                else
                    print("Nenhuma posição válida encontrada para o spawn do OVNI.")
                end
            end
        else
            print("Cooldown não expirado ainda para a zona " .. zoneId)
        end
    else
        print("zoneId não definido.")
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
        print("OVNI criado com ID " .. ufoId .. " na zona " .. zoneId .. " com coordenadas (" .. x .. ", " .. y .. ", " .. z .. ")")

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
            Citizen.Wait(10000)

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

            FreezeEntityPosition(playerPed, false)
            ClearPedTasksImmediately(playerPed)

            -- Verifica se o controle do OVNI é do cliente antes de deletar
            if DoesEntityExist(ufo) and NetworkHasControlOfEntity(ufo) then
                DeleteObject(ufo)
                print("OVNI com ID " .. ufoId .. " removido após a abdução.")
                -- Remove o OVNI da tabela de contagem
                ufosInZones[zoneId] = (ufosInZones[zoneId] or 1) - 1

                -- Espera 30 segundos antes de spawnar um novo OVNI
                Citizen.Wait(30000)

                -- Gera um novo OVNI após a espera, apenas se o jogador ainda estiver na zona
                if inZone and currentZoneId == zoneId then
                    print("Criando um novo OVNI após 10 segundos.")
                    SpawnUfo(x, y, z, zoneId)
                end

            elseif not DoesEntityExist(ufo) then
                print("OVNI já foi removido anteriormente.")
            else
                print("Não é possível deletar o OVNI. Não temos controle da entidade.")
            end
        end)
    else
        print("Falha ao criar o OVNI com o modelo " .. ufoModel)
    end
end

function FollowPlayer(ufoId)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500) -- Espera meio segundo entre as atualizações

            local playerCoords = GetEntityCoords(PlayerPedId())
            local ufo = NetworkGetEntityFromNetworkId(ufoId)

            if DoesEntityExist(ufo) then
                -- Verifica se o cliente tem controle sobre o OVNI
                if NetworkHasControlOfEntity(ufo) then
                    -- Define a nova posição do OVNI para um pouco acima do jogador
                    local newX = playerCoords.x
                    local newY = playerCoords.y
                    local newZ = playerCoords.z + 15.0 -- Ajuste a altura conforme necessário

                    -- Move o OVNI para a nova posição
                    SetEntityCoords(ufo, newX, newY, newZ, false, false, false, true)
                else
                    print("Sem controle sobre o OVNI com ID: " .. tostring(ufoId))
                    break -- Sai da função se não tiver controle
                end
            else
                print("OVNI não existe mais. Parando a função de seguir.")
                break -- Para a thread se o OVNI não existir mais
            end
        end
    end)
end

-- Remove todos os OVNIs ao reiniciar o script
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, ufoId in ipairs(ufos) do
            local ufo = NetworkGetEntityFromNetworkId(ufoId)

            -- Verifica se a entidade existe
            if DoesEntityExist(ufo) then
                -- Tenta obter o controle da entidade antes de deletar
                if not NetworkHasControlOfEntity(ufo) then
                    NetworkRequestControlOfEntity(ufo)
                
                    -- Aguarda até obter controle
                    local timeout = 1000  -- Aumentar o timeout para 1 segundo
                    while not NetworkHasControlOfEntity(ufo) and timeout > 0 do
                        Citizen.Wait(10)
                        timeout = timeout - 10
                    end
                end

                -- Verifica se o controle foi obtido e se a entidade ainda existe antes de deletar
                if DoesEntityExist(ufo) then
                    -- Solicita controle sobre a entidade novamente antes de deletar
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
                        print("Deletando OVNI com ID " .. ufoId)
                        DeleteObject(ufo)
                    else
                        print("Falha ao obter controle do OVNI ID " .. ufoId)
                    end
                else
                    print("OVNI " .. ufoId .. " já foi removido.")
                end
            end                
        end

        -- Limpa a tabela de OVNIs
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
                print("Animation Failed to Load")
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
        FollowPlayer(ufoId) -- Faz o OVNI seguir o jogador
    end
end)
