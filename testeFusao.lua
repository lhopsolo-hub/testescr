local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("TesteFusao")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TesteFusao"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.Parent = playerGui

local function control(class, text, y)
    local item = Instance.new(class)
    item.Size = UDim2.new(.55, 0, 0, 44)
    item.Position = UDim2.new(.225, 0, .04, y)
    item.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    item.TextColor3 = Color3.fromRGB(175, 255, 229)
    item.TextWrapped = true
    item.Text = text
    item.Parent = gui
    return item
end

local test = control("TextButton", "Ir à máquina e testar 1 fusão", 0)
local status = control("TextLabel", "Comece na base, perto da área de lançamento.", 46)
local badge = { H = "HYPER", M = "MEGA", U = "ULTRA" }
local nextTier = { BASE = "HYPER", HYPER = "MEGA", MEGA = "ULTRA" }
local busy, uncertain = false, false

local function visible(object)
    while object and object ~= playerGui do
        if (object:IsA("GuiObject") and not object.Visible)
            or (object:IsA("ScreenGui") and not object.Enabled) then return false end
        object = object.Parent
    end
    return object == playerGui
end

local function normalize(text)
    return (text:gsub("\194\160", " "):gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

local function readCards(list)
    local cards = {}
    for _, card in ipairs(list:GetChildren()) do
        if card:IsA("GuiButton") and visible(card) then
            local name, count, ready, tier
            local image = card:FindFirstChild("PetImage")
            for _, label in ipairs(card:GetDescendants()) do
                if label:IsA("TextLabel") and visible(label) then
                    local text = normalize(label.ContentText)
                    local quantity = text:match("^x(%d+)")
                    if quantity then
                        count = tonumber(quantity)
                        ready = text:find("PRONTO", 1, true) ~= nil
                    elseif badge[text] then
                        tier = badge[text]
                    elseif text ~= "" then
                        name = text
                    end
                end
            end
            if name and count and image and image:IsA("ImageLabel") and image.Image ~= "" then
                cards[#cards + 1] = { button = card, name = name, count = count,
                    ready = ready, tier = tier or "BASE", image = image.Image }
            end
        end
    end
    return cards
end

local function group(cards, source, tier)
    local count, matches = 0, 0
    for _, card in ipairs(cards) do
        if card.name == source.name and card.image == source.image and card.tier == tier then
            count, matches = card.count, matches + 1
        end
    end
    return count, matches
end

local function waitFor(check)
    local deadline = os.clock() + 5
    repeat
        if not gui.Parent then return false end
        if check() then return true end
        task.wait(.1)
    until os.clock() >= deadline
    return false
end

local function machinePrompt(root)
    local nearest, target, distance
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled
            and normalize(object.ObjectText):lower() == "máquina de fusão"
            and normalize(object.ActionText):lower() == "abrir" then
            local parent = object.Parent
            local point = parent and ((parent:IsA("Attachment") and parent.WorldPosition)
                or (parent:IsA("BasePart") and parent.Position)
                or (parent:IsA("Model") and parent:GetPivot().Position))
            if point then
                local gap = (root.Position - point).Magnitude
                if not distance or gap < distance then nearest, target, distance = object, point, gap end
            end
        end
    end
    return nearest, target
end

local function openMachine()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return false, "Personagem indisponível." end
    local prompt, point = machinePrompt(root)
    if not prompt then return false, "Aviso da máquina não encontrado. Comece perto da área de lançamento." end
    local function inReach()
        return (root.Position - point).Magnitude <= prompt.MaxActivationDistance
    end
    if not inReach() then
        status.Text = "Indo até a máquina..."
        local offset = root.Position - point
        local flat = Vector3.new(offset.X, 0, offset.Z)
        local goal = point + (flat.Magnitude > .1 and flat.Unit or Vector3.zero)
            * math.max(1, prompt.MaxActivationDistance * .55)
        local path = game:GetService("PathfindingService"):CreatePath()
        path:ComputeAsync(root.Position, goal)
        if path.Status ~= Enum.PathStatus.Success then return false, "Sem rota até a máquina." end
        for _, waypoint in ipairs(path:GetWaypoints()) do
            if inReach() then break end
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
            humanoid:MoveTo(waypoint.Position)
            if not waitFor(function()
                return inReach() or (root.Position - waypoint.Position).Magnitude <= 3
            end) then
                humanoid:MoveTo(root.Position)
                return false, "Caminhada interrompida antes da máquina."
            end
        end
        humanoid:MoveTo(root.Position)
    end
    if not inReach() or not prompt.Enabled or not prompt:IsDescendantOf(workspace)
        or not gui.Parent or player.Character ~= character then
        return false, "Aviso da máquina fora de alcance."
    end
    status.Text = "Abrindo a máquina..."
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration + .1)
    prompt:InputHoldEnd()
    if not waitFor(function()
        local fusion = playerGui:FindFirstChild("Fusion")
        local panel = fusion and fusion:FindFirstChild("Panel")
        return panel and visible(panel)
    end) then
        return false, "O jogo não confirmou a abertura da máquina."
    end
    return true
end

test.Activated:Connect(function(input)
    if busy or uncertain then return end
    busy = true
    local ok, message = pcall(function()
        local fusion = playerGui:FindFirstChild("Fusion")
        local panel = fusion and fusion:FindFirstChild("Panel")
        if not panel or not visible(panel) then
            local opened, reason = openMachine()
            if not opened then return reason end
            fusion = playerGui:FindFirstChild("Fusion")
            panel = fusion and fusion:FindFirstChild("Panel")
        end
        local body = panel and panel:FindFirstChild("Body")
        local list = body and body:FindFirstChild("ScrollingFrame")
        local details = body and body:FindFirstChild("Frame")
        local wrapper = details and details:FindFirstChild("Button")
        local face = wrapper and wrapper:FindFirstChild("Face")
        if not list or not face or not face:IsA("GuiButton") or not visible(face) then
            return "Abra a máquina de fusão no jogo."
        end
        if type(firesignal) ~= "function" then return "Ativação indisponível nesta versão do Delta." end

        local cards = readCards(list)
        table.sort(cards, function(a, b) return a.button.LayoutOrder < b.button.LayoutOrder end)
        local source, targetTier, targetBefore
        for _, card in ipairs(cards) do
            local tier = nextTier[card.tier]
            if tier and card.count >= 4 and card.ready and card.button.Interactable then
                local _, sourceMatches = group(cards, card, card.tier)
                local count, targetMatches = group(cards, card, tier)
                if sourceMatches == 1 and targetMatches <= 1 then
                    source, targetTier, targetBefore = card, tier, count
                    break
                end
            end
        end
        if not source then return "Nenhum grupo PRONTO com quatro pets e identificação inequívoca." end

        local name = source.tier == "BASE" and source.name or (source.tier .. " " .. source.name)
        local selection = string.format("%s (%d/4)", name, source.count)
        status.Text = "Selecionando " .. selection
        firesignal(source.button.Activated, input, 1)

        local observedSelection, observedAction
        local function selectionMatches()
            observedSelection, observedAction = nil, nil
            local selected, action = false, false
            for _, label in ipairs(details:GetDescendants()) do
                if (label:IsA("TextLabel") or label:IsA("TextButton")) and visible(label) then
                    local text = normalize(label.ContentText)
                    local pet, count, required = text:match("^(.-)%s*%(%s*(%d+)%s*/%s*(%d+)%s*%)$")
                    if pet then
                        observedSelection = text
                        selected = selected or (normalize(pet):upper() == name:upper()
                            and tonumber(count) == source.count and tonumber(required) == 4)
                    end
                    if (label == face or label:IsDescendantOf(face)) and text ~= "" then
                        observedAction = text
                        action = action or text:upper() == "FUNDIR EM " .. targetTier
                    end
                end
            end
            return selected and action and visible(face) and face.Interactable
        end
        if not waitFor(selectionMatches) then
            return string.format("Esperava %s → %s. Vi %s | %s | botão %s.",
                selection, targetTier, observedSelection or "sem seleção", observedAction or "sem texto",
                visible(face) and face.Interactable and "disponível" or "indisponível")
        end

        status.Text = "Fundindo " .. name .. " em " .. targetTier .. "..."
        uncertain = true
        firesignal(face.Activated, input, 1)
        if not waitFor(function()
            if not visible(list) then return false end
            local current = readCards(list)
            local sourceCount, sourceMatches = group(current, source, source.tier)
            local targetCount, targetMatches = group(current, source, targetTier)
            return sourceMatches <= 1 and sourceCount == source.count - 4
                and targetMatches == 1 and targetCount == targetBefore + 1
        end) then
            return "Resultado incerto. Confira a máquina antes de executar de novo."
        end
        uncertain = false
        return string.format("Confirmada: %s %d→%d | %s %d→%d",
            name, source.count, source.count - 4, targetTier, targetBefore, targetBefore + 1)
    end)
    status.Text = ok and message or ("Erro: " .. tostring(message))
    busy = false
end)
