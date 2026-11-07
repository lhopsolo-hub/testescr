
-- Protótipo local de coleta de ovos. No Studio, use como ModuleScript no cliente.
-- As áreas de demonstração são posicionadas em relação ao ponto de início.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
assert(player, "Execute em um contexto de cliente.")

local api = {}
local areas = {}
local unlocked = {}
local collected = {}
local health = 100
local currentArea
local base
local egg
local movement
local fleeing = false
local round = 0
local allUnlocked = false

local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function removeEgg()
    if egg then
        egg:Destroy()
        egg = nil
    end
end

local function cancelMovement()
    if movement then
        movement:Cancel()
        movement = nil
    end
end

local function moveTo(position)
    local root = rootPart()
    if not root then
        return false, "Personagem indisponível."
    end

    cancelMovement()
    movement = TweenService:Create(
        root,
        TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
        { Position = position }
    )
    movement:Play()
    return true
end

function api.onAllAreasUnlocked()
    print("Todas as áreas desbloqueadas!")
end

function api.syncUnlockedAreas()
    local count = 0
    for id, area in ipairs(areas) do
        if health >= area.requiredStrength then
            unlocked[id] = true
        end
        if unlocked[id] then
            count = count + 1
        end
    end
    if count > 0 and count == #areas and not allUnlocked then
        allUnlocked = true
        api.onAllAreasUnlocked()
    end
end

function api.onGameStart()
    local root = rootPart()
    if not root then
        return false, "Aguarde o personagem aparecer e chame onGameStart() novamente."
    end

    round = round + 1
    cancelMovement()
    removeEgg()
    base = root.Position
    health = 100
    currentArea = nil
    fleeing = false
    unlocked = {}
    collected = {}
    allUnlocked = false
    areas = {}

    for id = 1, 11 do
        local offset = Vector3.new(id * 24, 0, 0)
        areas[id] = {
            name = "Área " .. id,
            bossName = string.format("Boss_%02d", id),
            bossPosition = base + offset + Vector3.new(0, 0, 10),
            eggPosition = base + offset,
            requiredStrength = math.min(id * 10, 100),
        }
    end

    api.syncUnlockedAreas()
    print("Jogo iniciado!")
    return true
end

function api.canEnterArea(areaId)
    local area = areas[areaId]
    return area ~= nil and unlocked[areaId] == true
        and health >= area.requiredStrength
end

function api.spawnEgg(areaId)
    local area = areas[areaId]
    if not area or areaId ~= currentArea or collected[areaId] then
        return nil
    end
    if egg then
        return egg
    end

    egg = Instance.new("Part")
    egg.Name = "Egg"
    egg.Shape = Enum.PartType.Ball
    egg.Size = Vector3.new(2, 3, 2)
    egg.Anchored = true
    egg.CanCollide = false
    egg.BrickColor = BrickColor.new("Lime green")
    egg.Position = area.eggPosition
    egg.Parent = workspace
    return egg
end

function api.onEnterArea(areaId)
    if fleeing or collected[areaId] or not api.canEnterArea(areaId) then
        return false, "Área indisponível."
    end
    if currentArea ~= areaId then
        removeEgg()
        currentArea = areaId
    end
    api.spawnEgg(areaId)
    return true
end

function api.onReturnToBase()
    if not base then
        return false, "Inicie o jogo primeiro."
    end
    local moved, reason = moveTo(base)
    if not moved then
        return false, reason
    end
    round = round + 1
    fleeing = false
    currentArea = nil
    removeEgg()
    return true
end

function api.floatAway()
    local root = rootPart()
    local area = areas[currentArea]
    if not root or not area then
        return false, "Personagem ou área indisponível."
    end

    local difference = root.Position - area.bossPosition
    local horizontal = Vector3.new(difference.X, 0, difference.Z)
    local direction = horizontal.Magnitude > 0 and horizontal.Unit or Vector3.new(0, 0, -1)
    return moveTo(root.Position + direction * 25 + Vector3.new(0, 3, 0))
end

function api.onFleeing(areaId)
    if fleeing or not currentArea or (areaId and areaId ~= currentArea) then
        return false, "Fuga indisponível."
    end
    local moved, reason = api.floatAway()
    if not moved then
        return false, reason
    end

    fleeing = true
    round = round + 1
    local activeRound = round
    task.delay(30, function()
        if activeRound == round and fleeing then
            local returned = api.onReturnToBase()
            if not returned then
                fleeing = false
                currentArea = nil
                removeEgg()
            end
        end
    end)
    return true
end

function api.onEggCollected(areaId)
    if areaId ~= currentArea or not egg or collected[areaId] then
        return false, "Entre na área antes de coletar o ovo."
    end

    local started, reason = api.onFleeing(areaId)
    if not started then
        return false, reason
    end

    collected[areaId] = true
    removeEgg()
    print("Ovo coletado em " .. areas[areaId].name)
    return true
end

function api.die()
    health = 0
    local returned, reason = api.onReturnToBase()
    if not returned then
        round = round + 1
        fleeing = false
        currentArea = nil
        cancelMovement()
        removeEgg()
    end
    return returned, reason
end

function api.bossAttack()
    local area = areas[currentArea]
    if not area or health <= 0 then
        return false, "Nenhum ataque disponível."
    end

    health = math.max(0, health - math.random(10, 15))
    print(area.bossName .. " atacou! Vida: " .. health)
    if health == 0 then
        api.die()
    end
    return true
end

api.onDeath = api.die
api.gameStart = api.onGameStart
api.collectEgg = api.onEggCollected
api.startFleeing = api.onFleeing
api.returnToBase = api.onReturnToBase

local started, reason = api.onGameStart()
if not started then
    warn(reason)
end

return api



