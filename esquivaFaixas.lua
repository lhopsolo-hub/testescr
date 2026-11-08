-- Protótipo para Delta. Pegue o ovo manualmente e ative durante a luta.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local guiParent = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
for _, name in ipairs({ "EsquivaFaixas", "EsquivaOvo" }) do
    local old = guiParent:FindFirstChild(name)
    if old then old:Destroy() end
end

local function make(class, parent, props)
    local object = Instance.new(class)
    for name, value in pairs(props) do object[name] = value end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", guiParent, {
    Name = "EsquivaFaixas", ResetOnSpawn = false, DisplayOrder = 45,
})
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0.86, 0, 0, 124),
    BackgroundColor3 = Color3.fromRGB(20, 28, 42), BorderSizePixel = 0,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(345, 124) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 10) })

local function control(class, text, y, height)
    return make(class, panel, {
        Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, height),
        Text = text, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(240, 246, 255),
        BackgroundTransparency = class == "TextLabel" and 1 or 0,
        BackgroundColor3 = Color3.fromRGB(45, 94, 165), BorderSizePixel = 0,
    })
end
control("TextLabel", "ESQUIVA DAS FAIXAS", 4, 24)
local status = control("TextLabel", "Pegue o ovo e ative por 30 s.", 29, 43)
local toggle = control("TextButton", "Ativar por 30 s", 78, 36)
make("UICorner", toggle, { CornerRadius = UDim.new(0, 7) })

local DURATION, LINGER, MARGIN, MAX_STEP = 30, 0.35, 1.3, 24
local directions = {}
for index = 0, 23 do
    local angle = index * math.pi / 12
    directions[index + 1] = Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local active
local function finish(session, message)
    if active ~= session then return end
    active = nil
    session.hpConnection:Disconnect()
    toggle.Text = "Ativar por 30 s"
    status.Text = string.format("%s · %d esquivas\n%d quedas · %.2f HP perdido",
        message, session.moves, session.hits, session.damage)
    print("[Esquiva] " .. status.Text)
end

local function isWarning(part)
    local color, size = part.Color, part.Size
    return color.R >= 0.9 and color.G <= 0.3 and color.B <= 0.3
        and part.Transparency >= 0.65 and part.Transparency <= 0.9
        and math.min(size.X, size.Y, size.Z) <= 0.5
        and math.max(size.X, size.Y, size.Z) >= 7
end

local function inside(position, warning)
    local center = warning.frame.Position
    local localPoint = warning.frame:PointToObjectSpace(Vector3.new(position.X, center.Y, position.Z))
    local size = warning.size
    return math.abs(localPoint.X) <= size.X / 2 + MARGIN
        and math.abs(localPoint.Y) <= size.Y / 2 + MARGIN
        and math.abs(localPoint.Z) <= size.Z / 2 + MARGIN
end

local function threatened(position, warnings)
    for _, warning in pairs(warnings) do
        if inside(position, warning) then return true end
    end
    return false
end

local function safeStep(root, warnings, ray)
    local origin = root.Position
    local currentFloor = workspace:Raycast(origin, Vector3.new(0, -9, 0), ray)
    if not currentFloor or currentFloor.Normal.Y < 0.65 then return end
    local clearance = origin.Y - currentFloor.Position.Y
    for distance = 2, MAX_STEP do
        for _, direction in ipairs(directions) do
            local delta = direction * distance
            local candidate = origin + delta
            if not threatened(candidate, warnings) then
                local floor = workspace:Raycast(candidate + Vector3.new(0, 2, 0), Vector3.new(0, -11, 0), ray)
                if floor and floor.Normal.Y >= 0.65
                    and math.abs(floor.Position.Y - currentFloor.Position.Y) <= 2 then
                    local destination = floor.Position + Vector3.new(0, clearance, 0)
                    local travel = destination - origin
                    if not workspace:Raycast(origin, travel, ray)
                        and not workspace:Raycast(origin + Vector3.new(0, 1.5, 0), travel, ray) then
                        return travel
                    end
                end
            end
        end
    end
end

toggle.Activated:Connect(function()
    if active then finish(active, "Interrompido"); return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local hp = player:GetAttribute("BossHP")
    if not root or type(hp) ~= "number" or hp < 0 then
        status.Text = "Entre na luta até BossHP aparecer."
        return
    end

    local session = { moves = 0, hits = 0, damage = 0, interrupted = false, warnings = {} }
    local deadline = os.clock() + DURATION
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true
    active = session
    toggle.Text = "Parar"
    session.hpConnection = player:GetAttributeChangedSignal("BossHP"):Connect(function()
        local value = player:GetAttribute("BossHP")
        if type(value) ~= "number" or value < 0 then
            session.interrupted = true
        elseif value < hp then
            session.hits = session.hits + 1
            session.damage = session.damage + hp - value
            print(string.format("[Esquiva] BossHP %.2f -> %.2f", hp, value))
        end
        if type(value) == "number" and value >= 0 then hp = value end
    end)

    task.spawn(function()
        local lastMove, lastScan = -math.huge, -math.huge
        local ok, err = pcall(function()
            while gui.Parent and active == session do
                local now = os.clock()
                if session.interrupted or player.Character ~= character or not root.Parent then
                    finish(session, "Luta encerrada")
                    return
                end
                if now >= deadline then
                    finish(session, "30 s concluídos")
                    return
                end
                local folder = workspace:FindFirstChild("BossFX")
                if folder then
                    for _, part in ipairs(folder:GetChildren()) do
                        if part:IsA("BasePart") and isWarning(part) then
                            session.warnings[part] = { frame = part.CFrame, size = part.Size, seen = now }
                        end
                    end
                end
                for part, warning in pairs(session.warnings) do
                    if now - warning.seen > LINGER then session.warnings[part] = nil end
                end

                local danger = threatened(root.Position, session.warnings)
                local message = danger and "Buscando saída" or "Fora das marcas"
                if danger and now - lastMove >= 0.15 and now - lastScan >= 0.10 then
                    lastScan = now
                    ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                    local delta = safeStep(root, session.warnings, ray)
                    if delta then
                        character:PivotTo(character:GetPivot() + delta)
                        session.moves = session.moves + 1
                        lastMove = now
                        message = "Saída solicitada"
                    else
                        message = "Sem saída livre em até 24 studs"
                    end
                end
                status.Text = string.format("%ds · HP %.2f · %d quedas\n%s · %d esquivas",
                    math.ceil(deadline - now), hp, session.hits, message, session.moves)
                task.wait(0.04)
            end
        end)
        if not ok then
            warn("[Esquiva] " .. tostring(err))
            finish(session, "Erro · veja o console")
        end
    end)
end)

gui.Destroying:Connect(function()
    if active then
        active.hpConnection:Disconnect()
        active = nil
    end
end)
