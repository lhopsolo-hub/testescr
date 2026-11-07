-- Ative depois que o jogo confirmar que o ovo está com você.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = assert(Players.LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")

for _, name in ipairs({ "EsquivaOvo", "PainelOvos" }) do
    local previous = playerGui:FindFirstChild(name)
    if previous then previous:Destroy() end
end

local DURATION = 30
local RADIUS = 8
local HEIGHTS = { 10, 16, 22 }
local heightIndex = 2
local active

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for name, value in pairs(properties) do instance[name] = value end
    instance.Parent = parent
    return instance
end

local gui = make("ScreenGui", playerGui, {
    Name = "EsquivaOvo", ResetOnSpawn = false, DisplayOrder = 30,
})
local card = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 154),
    BackgroundColor3 = Color3.fromRGB(20, 28, 42), BorderSizePixel = 0,
})
make("UISizeConstraint", card, { MaxSize = Vector2.new(370, 154) })
make("UICorner", card, { CornerRadius = UDim.new(0, 12) })

local function textControl(class, text, x, y, width, height)
    return make(class, card, {
        Position = UDim2.new(x, 10, 0, y), Size = UDim2.new(width, -20, 0, height),
        Text = text, TextSize = 14, TextColor3 = Color3.fromRGB(244, 248, 255),
        Font = Enum.Font.GothamBold, BackgroundTransparency = 1, TextWrapped = true,
    })
end

local title = textControl("TextLabel", "ESQUIVA DO BOSS", 0, 7, 1, 24)
title.TextXAlignment = Enum.TextXAlignment.Left
local status = textControl("TextLabel", "Pegue o ovo e ative a esquiva.", 0, 37, 1, 36)
status.TextXAlignment = Enum.TextXAlignment.Left
local start = textControl("TextButton", "Ativar por 30 s", 0, 86, 0.64, 50)
local height = textControl("TextButton", "Altura 16", 0.64, 86, 0.36, 50)
start.BackgroundColor3 = Color3.fromRGB(42, 103, 195)
height.BackgroundColor3 = Color3.fromRGB(43, 57, 79)
for _, control in ipairs({ start, height }) do
    control.BackgroundTransparency = 0
    control.BorderSizePixel = 0
    make("UICorner", control, { CornerRadius = UDim.new(0, 8) })
end

local function finish(message)
    local session = active
    if not session then return end
    active = nil
    session.heartbeat:Disconnect()
    session.force:Destroy()
    session.attachment:Destroy()
    start.Text = "Ativar por 30 s"
    status.Text = message
end

height.Activated:Connect(function()
    if active then return end
    heightIndex = heightIndex % #HEIGHTS + 1
    height.Text = "Altura " .. HEIGHTS[heightIndex]
end)

start.Activated:Connect(function()
    if active then
        finish("Esquiva cancelada. Movimento devolvido.")
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
        status.Text = "Personagem indisponível."
        return
    end

    local origin = root.Position
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    ray.RespectCanCollide = true
    local requestedHeight = HEIGHTS[heightIndex]
    local ceiling = workspace:Raycast(origin, Vector3.new(0, requestedHeight + 3, 0), ray)
    local lift = ceiling and math.min(requestedHeight, ceiling.Distance - 3) or requestedHeight
    if lift < 4 then
        status.Text = "Espaço insuficiente acima do personagem."
        return
    end

    local attachment = make("Attachment", root, { Name = "EsquivaOvo" })
    local force = make("AlignPosition", root, {
        Attachment0 = attachment, Mode = Enum.PositionAlignmentMode.OneAttachment,
        ApplyAtCenterOfMass = true, MaxForce = root.AssemblyMass * (workspace.Gravity + 650),
        MaxVelocity = 24, Responsiveness = 18, Position = origin,
    })
    local began = os.clock()
    local center = origin + Vector3.new(0, lift, 0)
    local direction, angle = 1, 0
    local lastHealth = humanoid.Health
    local session = { attachment = attachment, force = force }
    active = session
    start.Text = "Parar"

    session.heartbeat = RunService.Heartbeat:Connect(function(dt)
        if player.Character ~= character or not root:IsDescendantOf(workspace) or humanoid.Health <= 0 then
            finish("Esquiva encerrada: personagem indisponível.")
            return
        end

        local elapsed = os.clock() - began
        if elapsed >= DURATION + 3 then
            finish("Teste encerrado. Confira o ovo no jogo.")
            return
        end

        local health = humanoid.Health
        if elapsed < DURATION and health < lastHealth then direction = -direction end
        lastHealth = health
        angle = angle + direction * math.min(dt, 0.1) * 2.3
        local ramp = math.clamp(elapsed - 0.8, 0, 1)
        local target
        if elapsed < DURATION then
            target = center + Vector3.new(math.cos(angle) * RADIUS * ramp, 0, math.sin(angle) * RADIUS * ramp)
            status.Text = string.format("Esquiva · %ds · Vida %.0f", math.ceil(DURATION - elapsed), health)
        else
            target = origin
            status.Text = "Descendo no ponto de início..."
            if (root.Position - target).Magnitude < 3 then
                finish("30 s concluídos. Confira o ovo no jogo.")
                return
            end
        end

        local delta = target - root.Position
        if delta.Magnitude > 0.1 then
            local hit = workspace:Raycast(root.Position, delta, ray)
            if hit then target = root.Position + delta.Unit * math.max(0, hit.Distance - 3) end
        end
        force.Position = target
    end)
end)

gui.Destroying:Connect(function()
    finish("Esquiva encerrada.")
end)
