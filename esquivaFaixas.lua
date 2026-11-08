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
local function round(object, radius)
    make("UICorner", object, { CornerRadius = UDim.new(0, radius) })
end
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0.49, 0, 0, 220),
    BackgroundColor3 = Color3.fromRGB(30, 10, 13), BorderSizePixel = 0,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(345, 220) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 10) })

local function control(class, text, y, height)
    return make(class, panel, {
        Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, height),
        Text = text, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 235, 233),
        BackgroundTransparency = class == "TextLabel" and 1 or 0,
        BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
    })
end
local title = control("TextLabel", "ESQUIVA DO BOSS · V19", 5, 30)
title.Size = UDim2.new(1, -49, 0, 30)
title.TextXAlignment = Enum.TextXAlignment.Left
local minimize = control("TextButton", "−", 6, 28)
minimize.Position, minimize.Size = UDim2.new(1, -36, 0, 6), UDim2.fromOffset(29, 28)
round(minimize, 6)
local status = control("TextLabel", "Desligada", 38, 49)
local toggle = control("TextButton", "Ligar esquiva", 92, 29)
local eggsToggle = control("TextButton", "Lista de ovos", 124, 21)
round(toggle, 7)
round(eggsToggle, 6)
local collapsed = false
minimize.Activated:Connect(function()
    collapsed = not collapsed
    status.Visible, toggle.Visible, eggsToggle.Visible = not collapsed, not collapsed, not collapsed
    panel.Size = UDim2.new(0.49, 0, 0, collapsed and 40 or 220)
    minimize.Text = collapsed and "+" or "−"
end)

local LINGER = 0.35
local LOOKAHEAD = { 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.44, 0.52 }
local TRIGGER_MARGIN, EXIT_MARGIN = 1.3, 8
local MAX_RUN_DISTANCE, JUMP_INTERVAL = 24, 0.12
local directions = {}
for index = 0, 23 do
    local angle = index * math.pi / 12
    directions[index + 1] = Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local active
local enabled = false
local function finish(session, message)
    if active ~= session then return end
    active = nil
    session.hpConnection:Disconnect()
    if session.walking and session.humanoid.Parent and session.root.Parent then
        session.humanoid:MoveTo(session.root.Position)
    end
    toggle.Text = enabled and "Desligar esquiva" or "Ligar esquiva"
    status.Text = string.format("%s · %d esquivas\n%d quedas · %.2f HP perdido",
        message, session.moves, session.hits, session.damage)
    print(string.format("[Esquiva V19] %s | última rota a pé %.1f studs",
        status.Text, session.lastDistance))
end

local function isWarning(part, position)
    local color, size = part.Color, part.Size
    local thin = math.min(size.X, size.Y, size.Z)
    local span = math.max(size.X, size.Y, size.Z)
    return color.R >= 0.55 and color.R > color.G * 1.45 and color.R > color.B * 1.45
        and part.Transparency < 0.98 and thin <= 2 and span >= 5
        and math.abs(part.Position.Y - position.Y) <= 14
        and Vector3.new(part.Position.X-position.X, 0, part.Position.Z-position.Z).Magnitude <= 150 + span / 2
end

local function updateWarning(previous, part, now)
    local frame, size = part.CFrame, part.Size
    local warning = {
        frame = frame, size = size, seen = now,
        static = part.Transparency >= 0.60 or math.max(size.X, size.Y, size.Z) >= 18,
        movingUntil = previous and previous.movingUntil or 0,
        velocity = Vector3.zero, growth = Vector3.zero,
    }
    if previous then
        local elapsed = now - previous.seen
        if elapsed > 0 and elapsed < 0.25 then
            local shift = frame.Position - previous.frame.Position
            local sizeChange = size - previous.size
            warning.velocity = Vector3.new(shift.X, 0, shift.Z) / elapsed
            if warning.velocity.Magnitude > 180 then warning.velocity = warning.velocity.Unit * 180 end
            warning.growth = Vector3.new(
                math.clamp(sizeChange.X / elapsed, 0, 160),
                math.clamp(sizeChange.Y / elapsed, 0, 160),
                math.clamp(sizeChange.Z / elapsed, 0, 160)
            )
            if warning.velocity.Magnitude > 2 or warning.growth.Magnitude > 3 then
                warning.movingUntil = now + 0.25
            end
        end
    end
    return warning
end

local function projectWarnings(tracked, now)
    local areas, waves = {}, 0
    for part, warning in pairs(tracked) do
        if now - warning.seen > LINGER then
            tracked[part] = nil
        elseif warning.static or warning.movingUntil >= now then
            table.insert(areas, warning)
            if warning.movingUntil >= now then
                waves = waves + 1
                if warning.seen == now then
                    local previousTime = 0
                    for _, seconds in ipairs(LOOKAHEAD) do
                        local shift = warning.frame:VectorToObjectSpace(warning.velocity * (seconds - previousTime))
                        local sweep = Vector3.new(math.abs(shift.X), math.abs(shift.Y), math.abs(shift.Z))
                        table.insert(areas, {
                            frame = warning.frame + warning.velocity * ((seconds + previousTime) / 2),
                            size = warning.size + warning.growth * seconds + sweep,
                            projected = true,
                        })
                        previousTime = seconds
                    end
                end
            end
        end
    end
    return areas, waves
end

local function inside(position, warning, margin)
    local center = warning.frame.Position
    local localPoint = warning.frame:PointToObjectSpace(Vector3.new(position.X, center.Y, position.Z))
    local size = warning.size
    return math.abs(localPoint.X) <= size.X / 2 + margin
        and math.abs(localPoint.Y) <= size.Y / 2 + margin
        and math.abs(localPoint.Z) <= size.Z / 2 + margin
end

local function threatened(position, warnings, margin, currentOnly)
    for _, warning in pairs(warnings) do
        if (not currentOnly or not warning.projected) and inside(position, warning, margin) then return true end
    end
    return false
end

local function horizontalDistance(a, b)
    local delta = a - b
    return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

-- As paredes de CarryWalls podem ter CanQuery=false. Use a geometria delas.
local function cageBounds(origin)
    local cage = workspace:FindFirstChild("CarryWalls")
    if not cage then return end
    local xWalls, zWalls = {}, {}
    for _, part in ipairs(cage:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Field" or part.Name == "Force")
            and part.Size.Y >= 12 and part.Size.Z <= 1 and part.Size.X >= 8
            and math.abs(origin.Y - part.Position.Y) <= part.Size.Y / 2 + 2 then
            local x, z = part.Position.X, part.Position.Z
            local right = part.CFrame.RightVector
            if math.abs(right.Z) >= 0.99 then
                table.insert(xWalls, { at = x, low = z - part.Size.X / 2, high = z + part.Size.X / 2 })
            elseif math.abs(right.X) >= 0.99 then
                table.insert(zWalls, { at = z, low = x - part.Size.X / 2, high = x + part.Size.X / 2 })
            end
        end
    end

    local function bracket(walls, coordinate, across)
        local low, high
        for _, wall in ipairs(walls) do
            if across >= wall.low - 0.1 and across <= wall.high + 0.1 then
                if wall.at < coordinate and (not low or wall.at > low) then low = wall.at end
                if wall.at > coordinate and (not high or wall.at < high) then high = wall.at end
            end
        end
        return low, high
    end
    local function covers(walls, at, low, high)
        local spans = {}
        for _, wall in ipairs(walls) do
            if math.abs(wall.at - at) <= 0.15 then table.insert(spans, wall) end
        end
        table.sort(spans, function(a, b) return a.low < b.low end)
        local covered = low
        for _, span in ipairs(spans) do
            if span.low > covered + 0.2 then break end
            covered = math.max(covered, span.high)
            if covered >= high - 0.2 then return true end
        end
        return false
    end
    local minX, maxX = bracket(xWalls, origin.X, origin.Z)
    local minZ, maxZ = bracket(zWalls, origin.Z, origin.X)
    if minX and maxX and minZ and maxZ
        and covers(xWalls, minX, minZ, maxZ) and covers(xWalls, maxX, minZ, maxZ)
        and covers(zWalls, minZ, minX, maxX) and covers(zWalls, maxZ, minX, maxX) then
        return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
    end
end

local function inCage(point, bounds, margin)
    return bounds and point.X >= bounds.minX + margin and point.X <= bounds.maxX - margin
        and point.Z >= bounds.minZ + margin and point.Z <= bounds.maxZ - margin
end

local function safeStep(root, warnings, ray, bossPosition, bounds, margin, preferFar)
    local origin = root.Position
    local currentFloor = workspace:Raycast(origin, Vector3.new(0, -18, 0), ray)
    if not currentFloor or currentFloor.Normal.Y < 0.65 then return end
    local clearance = origin.Y - currentFloor.Position.Y
    local bossDistance = bossPosition and horizontalDistance(origin, bossPosition)
    local minimumBossDistance = bossDistance and (preferFar and bossDistance + 4 or math.max(0, bossDistance - 2))
    local first, last, increment = 2, MAX_RUN_DISTANCE, 1
    if preferFar then first, last, increment = MAX_RUN_DISTANCE, 5, -1 end
    for distance = first, last, increment do
        local best, bestDistance
        for _, direction in ipairs(directions) do
            local candidate = origin + direction * distance
            local distanceFromBoss = bossPosition and horizontalDistance(candidate, bossPosition)
            if inCage(candidate, bounds, 4)
                and (not minimumBossDistance or distanceFromBoss >= minimumBossDistance)
                and not threatened(candidate, warnings, margin) then
                local floor = workspace:Raycast(candidate + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), ray)
                if floor and floor.Normal.Y >= 0.65
                    and math.abs(floor.Position.Y - currentFloor.Position.Y) <= 2 then
                    local destination = floor.Position + Vector3.new(0, clearance, 0)
                    local travel = destination - origin
                    if not workspace:Raycast(origin, travel, ray)
                        and not workspace:Raycast(origin + Vector3.new(0, 1.5, 0), travel, ray) then
                        if not distanceFromBoss then return travel end
                        if not bestDistance or distanceFromBoss > bestDistance then
                            best, bestDistance = travel, distanceFromBoss
                        end
                    end
                end
            end
        end
        if best then return best end
    end
end

local function startFight()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hp = player:GetAttribute("BossHP")
    local carrying = player:GetAttribute("Carrying")
    if (carrying ~= 1 and carrying ~= true) or not root or not humanoid or humanoid.Health <= 0 or type(hp) ~= "number" or hp < 0 then
        status.Text = "Ligada · aguardando ovo na mão"
        return
    end

    local session = { moves = 0, hits = 0, damage = 0, interrupted = false, warnings = {}, lastDistance = 0, humanoid = humanoid, root = root }
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true
    active = session
    toggle.Text = "Desligar esquiva"
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
        local lastScan, lastJump = -math.huge, -math.huge
        local bounds, checkedAt = nil, -math.huge
        local ok, err = pcall(function()
            while gui.Parent and active == session do
                local now = os.clock()
                local carryingNow = player:GetAttribute("Carrying")
                if (carryingNow ~= 1 and carryingNow ~= true) or session.interrupted or player.Character ~= character or not root.Parent or humanoid.Health <= 0 then
                    finish(session, "Luta encerrada")
                    return
                end
                if now - checkedAt >= 0.25 then
                    bounds, checkedAt = cageBounds(root.Position), now
                end
                local insideArena = inCage(root.Position, bounds, 0.1)
                if not insideArena and session.walking then
                    humanoid:MoveTo(root.Position)
                    session.walking = false
                end
                local folder = workspace:FindFirstChild("BossFX")
                if now - (session.effectsAt or -math.huge) >= 0.12 then
                    session.effectsAt = now
                    session.fxParts = {}
                    session.bosses = {}
                    local known = {
                        ["Touro Gigante"] = true, ["Escaravelho Rei"] = true, ["Yeti Ancião"] = true,
                        ["Golem de Magma"] = true, ["Titã Cósmico"] = true,
                    }
                    local function scan(container)
                        for _, object in ipairs(container:GetDescendants()) do
                            if object:IsA("BasePart") then
                                table.insert(session.fxParts, object)
                            elseif object:IsA("Model") and (known[object.Name] or object:GetAttribute("BossId") ~= nil
                                or object:GetAttribute("IsBoss") == true or object:FindFirstChildOfClass("Humanoid")
                                or object.Name:lower():find("boss", 1, true)) then
                                table.insert(session.bosses, object)
                            end
                        end
                    end
                    if folder then scan(folder) end
                    for _, child in ipairs(workspace:GetChildren()) do
                        local name = child.Name:lower()
                        if child ~= folder and (name == "effects" or name == "vfx" or name == "bosses"
                            or name:find("bossfx", 1, true)) then
                            scan(child)
                        elseif child:IsA("BasePart") then
                            table.insert(session.fxParts, child)
                        elseif child:IsA("Model") and (known[child.Name] or child:GetAttribute("IsBoss") == true) then
                            table.insert(session.bosses, child)
                        end
                    end
                end
                for _, part in ipairs(session.fxParts) do
                    if part.Parent and isWarning(part, root.Position) then
                        session.warnings[part] = updateWarning(session.warnings[part], part, now)
                    end
                end
                local bossPosition, nearestBoss = nil, math.huge
                for _, boss in ipairs(session.bosses) do
                    if boss.Parent then
                        local position = boss:GetPivot().Position
                        local distance = horizontalDistance(root.Position, position)
                        if math.abs(position.Y - root.Position.Y) <= 30 and distance < nearestBoss then
                            bossPosition, nearestBoss = position, distance
                        end
                    end
                end
                local areas, waves = projectWarnings(session.warnings, now)
                local danger = threatened(root.Position, areas, TRIGGER_MARGIN)
                local closeBoss = nearestBoss <= 23
                local message = not insideArena and "Aguardando perímetro fechado" or "Dentro da arena"
                local goal = session.runGoal
                if session.walking and (not insideArena or not goal or not inCage(goal, bounds, 4)
                    or threatened(goal, areas, TRIGGER_MARGIN) or now >= session.runUntil
                    or horizontalDistance(root.Position, goal) <= 1.5) then
                    humanoid:MoveTo(root.Position)
                    session.walking, session.runGoal = false, nil
                end
                if session.walking then message = "Correndo para fora do ataque" end

                if insideArena and not session.walking and (danger or closeBoss) and now - lastScan >= 0.08 then
                    lastScan = now
                    ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                    local delta = safeStep(root, areas, ray, bossPosition, bounds, EXIT_MARGIN, not danger)
                    if not delta and danger then
                        delta = safeStep(root, areas, ray, nil, bounds, 2.5, false)
                    end
                    if delta then
                        local distance = horizontalDistance(Vector3.zero, delta)
                        session.runGoal = root.Position + delta
                        session.runUntil = now + math.clamp(distance / math.max(1, humanoid.WalkSpeed) + 0.55, 0.7, 3.5)
                        session.walking = true
                        humanoid:MoveTo(session.runGoal)
                        session.moves = session.moves + 1
                        session.lastDistance = distance
                        message = "Correndo para fora do ataque"
                    else
                        message = "Sem saída interna livre a pé"
                    end
                end
                if inCage(root.Position, bounds, 4) and now - lastJump >= JUMP_INTERVAL and humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid.Jump = true
                    lastJump = now
                end
                status.Text = string.format("HP %.2f · Ondas %d · Quedas %d\n%s · %.0f studs",
                    hp, waves, session.hits, message, session.lastDistance)
                task.wait(0.04)
            end
        end)
        if not ok then
            enabled = false
            warn("[Esquiva] " .. tostring(err))
            finish(session, "Erro · veja o console")
        end
    end)
end

toggle.Activated:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "Desligar esquiva" or "Ligar esquiva"
    if not enabled then
        if active then finish(active, "Desligada") else status.Text = "Desligada" end
    end
end)

task.spawn(function()
    while gui.Parent do
        if enabled and not active then startFight() end
        task.wait(0.25)
    end
end)

gui.Destroying:Connect(function()
    if active then
        active.hpConnection:Disconnect()
        active = nil
    end
end)

local eggsPanel = make("Frame", gui, {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12),
    Size = UDim2.new(0.40, 0, 0.76, 0), BackgroundColor3 = Color3.fromRGB(30, 10, 13),
    BorderSizePixel = 0,
})
round(eggsPanel, 10)
make("UISizeConstraint", eggsPanel, { MaxSize = Vector2.new(260, 540) })
local eggsTitle = make("TextLabel", eggsPanel, {
    Text = "OVOS · ÁREA 1", Position = UDim2.fromOffset(9, 4), Size = UDim2.new(1, -46, 0, 31),
    TextColor3 = Color3.fromRGB(232, 243, 255), Font = Enum.Font.GothamBold, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
})
local hideEggs = make("TextButton", eggsPanel, {
    Text = "×", Position = UDim2.new(1, -33, 0, 5), Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = Color3.fromRGB(89, 23, 31), TextColor3 = Color3.new(1, 1, 1),
})
round(hideEggs, 6)
hideEggs.Activated:Connect(function() eggsPanel.Visible = false end)
eggsToggle.Activated:Connect(function() eggsPanel.Visible = not eggsPanel.Visible end)

local list = make("ScrollingFrame", eggsPanel, {
    Position = UDim2.fromOffset(6, 73), Size = UDim2.new(1, -12, 1, -157),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0,
})
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local collectionStatus = make("TextLabel", eggsPanel, {
    Position = UDim2.new(0, 7, 1, -47), Size = UDim2.new(1, -14, 0, 42),
    BackgroundColor3 = Color3.fromRGB(59, 19, 24), TextColor3 = Color3.fromRGB(229, 240, 255),
    Text = "Escolha um ovo e toque em Coletar.", TextSize = 12, TextWrapped = true,
    Font = Enum.Font.Gotham,
})
round(collectionStatus, 6)

local auto = false
local selectedZone = 1
local autoButton = make("TextButton", eggsPanel, {
    Position = UDim2.new(0, 7, 1, -81), Size = UDim2.new(1, -14, 0, 29),
    BackgroundColor3 = Color3.fromRGB(157, 31, 40), TextColor3 = Color3.fromRGB(255, 237, 234),
    Font = Enum.Font.GothamBold, Text = "Auto Coletar · OFF", TextSize = 13,
})
round(autoButton, 6)
local function setAuto(value)
    auto = value
    autoButton.Text = value and "Auto Coletar · ON" or "Auto Coletar · OFF"
    autoButton.BackgroundColor3 = value and Color3.fromRGB(201, 57, 48) or Color3.fromRGB(124, 29, 38)
end

local inputService = game:GetService("UserInputService")
local function stylePanel(frame, handle)
    make("UIStroke", frame, { Color = Color3.fromRGB(232, 68, 52), Thickness = 1.5, Transparency = 0.15 })
    make("UIGradient", frame, { Rotation = 90, Color = ColorSequence.new(
        Color3.fromRGB(255, 157, 143), Color3.fromRGB(162, 96, 104)) })
    handle.Active = true
    local touch, origin, original
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            touch, origin, original = input, input.Position, frame.Position
        end
    end)
    local move = inputService.InputChanged:Connect(function(input)
        if not touch then return end
        if touch.UserInputType == Enum.UserInputType.Touch then
            if input ~= touch then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local change = input.Position - origin
        local camera = workspace.CurrentCamera
        if not camera then return end
        local view = camera.ViewportSize
        local x = original.X.Scale * view.X + original.X.Offset + change.X
        local y = original.Y.Scale * view.Y + original.Y.Offset + change.Y
        local left = frame.AbsoluteSize.X * frame.AnchorPoint.X
        x = math.clamp(x, left, math.max(left, view.X - frame.AbsoluteSize.X + left))
        y = math.clamp(y, 0, math.max(0, view.Y - 80))
        frame.Position = UDim2.fromOffset(x, y)
    end)
    local ended = inputService.InputEnded:Connect(function(input)
        if input == touch then touch = nil end
    end)
    gui.Destroying:Connect(function() move:Disconnect(); ended:Disconnect() end)
end
stylePanel(panel, title)
stylePanel(eggsPanel, eggsTitle)

local function carryingEgg()
    local value = player:GetAttribute("Carrying")
    return value == 1 or value == true
end

local collecting = false
local function promptPosition(prompt)
    local host = prompt.Parent
    if host:IsA("Attachment") then return host.WorldPosition end
    if host:IsA("BasePart") then return host.Position end
    if host:IsA("Model") then return host:GetPivot().Position end
end

local function approach(character, root, egg, target, reach)
    local origin = root.Position
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true
    ray.FilterDescendantsInstances = { character, egg }
    local radius = math.min(3, reach / 2)
    for _, direction in ipairs(directions) do
        local point = target + direction * radius
        local ground = workspace:Raycast(point + Vector3.new(0, 7, 0), Vector3.new(0, -17, 0), ray)
        if ground and ground.Normal.Y >= 0.65 then
            local destination = ground.Position + Vector3.new(0, 3, 0)
            local delta = destination - origin
            if (destination - target).Magnitude <= reach and not workspace:Raycast(origin, delta, ray) then
                if carryingEgg() then return false end
                character:PivotTo(character:GetPivot() + delta)
                return true
            end
        end
    end
    return false
end

local function visibleControl(object)
    local node = object
    while node and node ~= guiParent do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return node == guiParent
end

local function hasLabel(object, expected)
    for _, child in ipairs(object:GetDescendants()) do
        if child:IsA("TextLabel") and visibleControl(child) and child.Text == expected then return true end
    end
    return false
end

local function findFace(scope, text, zoneNumber)
    if not scope then return end
    local found
    for _, object in ipairs(scope:GetDescendants()) do
        if object.Name == "Face" and object:IsA("GuiButton") and visibleControl(object)
            and hasLabel(object, text) then
            local card = object.Parent and object.Parent.Parent
            if not zoneNumber or (card and hasLabel(card, tostring(zoneNumber))) then
                if found then return end
                found = object
            end
        end
    end
    return found
end

local function waitFor(root, timeout, check)
    local deadline = os.clock() + timeout
    repeat
        if not gui.Parent or not root.Parent then return end
        local result = check()
        if result then return result end
        task.wait(0.08)
    until os.clock() >= deadline
end

local function signalFace(face, input, clicks)
    if type(firesignal) ~= "function" then return false, "firesignal indisponível" end
    local ok, err = pcall(firesignal, face.Activated, input, clicks or 1)
    return ok, ok and nil or tostring(err)
end

local function nearestEggZone(position)
    local folder = workspace:FindFirstChild("Eggs")
    local nearest, distance
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local zoneNumber = tonumber(egg:GetAttribute("Zone"))
        local point = egg:IsA("BasePart") and egg.Position or (egg:IsA("Model") and egg:GetPivot().Position)
        if zoneNumber and point then
            local gap = horizontalDistance(position, point)
            if not distance or gap < distance then nearest, distance = zoneNumber, gap end
        end
    end
    return nearest, distance
end

local function launchZone(character, root, input, clicks, allowed, zoneNumber)
    local hud = guiParent:FindFirstChild("HUD")
    local map = workspace:FindFirstChild("Map")
    local base = map and map:FindFirstChild("Base")
    local zone = base and base:FindFirstChild("ThrowZone")
    local function inThrowZone()
        if not zone or not zone:IsA("BasePart") then return false end
        local point = zone.CFrame:PointToObjectSpace(root.Position)
        return math.abs(point.X) <= zone.Size.X/2 + 1 and math.abs(point.Z) <= zone.Size.Z/2 + 1
            and math.abs(point.Y) < 12
    end
    local function control(scopeName, label, area)
        return waitFor(root, 4, function()
            return findFace(hud and hud:FindFirstChild(scopeName, true), label, area)
        end)
    end
    local function step(scopeName, label, area)
        collectionStatus.Text = "Área " .. zoneNumber .. " · " .. label
        local face = control(scopeName, label, area)
        if allowed and not allowed() then return false, "Ciclo desligado." end
        if not face then return false, "Área " .. zoneNumber .. ": " .. label .. " indisponível ou bloqueado." end
        local ok, reason = signalFace(face, input, clicks)
        if not ok then return false, label .. ": " .. reason end
        return true
    end

    local visibleCard = findFace(hud and hud:FindFirstChild("Panel", true), "IR!", zoneNumber)
    if not visibleCard then
        if not inThrowZone() then
            local ok, reason = step("TopNav", "Lançar")
            if not ok then return false, reason end
            if not waitFor(root, 5, inThrowZone) then return false, "Lançar: a zona de lançamento não foi confirmada." end
        end
        local ok, reason = step("Actions", "ARREMESSAR")
        if not ok then return false, reason end
    end
    local before = root.Position
    local ok, reason = step("Panel", "IR!", zoneNumber)
    if not ok then return false, reason end

    collectionStatus.Text = "Aguardando chegada à Área " .. zoneNumber .. "..."
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local arrived = waitFor(root, 10, function()
        if player.Character ~= character then return end
        local current = root.Position
        local nearby, distance = nearestEggZone(current)
        return horizontalDistance(before, current) >= 55 and nearby == zoneNumber and distance <= 230
            and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
    end)
    if not arrived then return false, "IR!: chegada à Área " .. zoneNumber .. " não confirmada." end
    if allowed and not allowed() then return false, "Ciclo desligado." end
    local invite = guiParent:FindFirstChild("FightUI")
    invite = invite and invite:FindFirstChild("FightInvite")
    local skip = invite and invite:FindFirstChild("FightSkip")
    local face = skip and skip:FindFirstChild("Face")
    if face and face:IsA("GuiButton") and visibleControl(face) then
        local dismissed = signalFace(face, input, clicks)
        if not dismissed or not waitFor(root, 2, function() return not visibleControl(face) end) then
            return false, "Feche o convite de luta e toque em Coletar novamente."
        end
    end
    return true
end

local function collectEgg(egg, input, clicks, fromAuto)
    if collecting or (auto and not fromAuto) then return end
    if carryingEgg() then collectionStatus.Text = "Você já está carregando um ovo."; return end
    collecting = true
    local function allowed() return gui.Parent ~= nil and (not fromAuto or auto) end
    local heldPrompt
    local ok, message, finished, eggName = pcall(function()
        local eggs = workspace:FindFirstChild("Eggs")
        local zoneNumber = tonumber(egg:GetAttribute("Zone"))
        if not eggs or egg.Parent ~= eggs or not zoneNumber or zoneNumber < 1 or zoneNumber > 12 then
            return "Ovo indisponível. Escolha outro."
        end
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt or not prompt.Enabled or not prompt.ActionText:lower():find("pegar ovo", 1, true) then
            return "A coleta desse ovo está indisponível."
        end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local target = promptPosition(prompt)
        if not root or not target then return "Personagem ou ovo indisponível." end
        local nearby, distance = nearestEggZone(root.Position)
        if (root.Position.Z > -50 or nearby ~= zoneNumber or not distance or distance > 230)
            and (root.Position - target).Magnitude > prompt.MaxActivationDistance then
            local launched, reason = launchZone(character, root, input, clicks, allowed, zoneNumber)
            if not launched then return reason end
            if not allowed() or player.Character ~= character or not root.Parent
                or not prompt:IsDescendantOf(egg) or not prompt.Enabled then
                return "Ovo indisponível após o lançamento. Escolha outro."
            end
            target = promptPosition(prompt)
            if not target then return "Ovo indisponível após o lançamento." end
        end
        collectionStatus.Text = "Indo até o ovo..."
        if (root.Position - target).Magnitude > prompt.MaxActivationDistance then
            if not approach(character, root, egg, target, prompt.MaxActivationDistance) then
                return "Sem trajeto livre. Aproxime-se e tente de novo."
            end
            task.wait(0.35)
        end
        if not allowed() or player.Character ~= character or not root.Parent then return "Coleta cancelada." end
        if carryingEgg() then return "Você já está carregando um ovo." end
        if not prompt:IsDescendantOf(egg) or not prompt.Enabled then return "Ovo indisponível." end
        target = promptPosition(prompt)
        if not target or (root.Position - target).Magnitude > prompt.MaxActivationDistance then
            return "O jogo não manteve o personagem perto do ovo."
        end

        local name = prompt.ObjectText
        collectionStatus.Text = "Segurando a interação de coleta..."
        heldPrompt = prompt
        local holdDuration = math.max(0, prompt.HoldDuration)
        prompt:InputHoldBegin()
        local releaseAt = os.clock() + holdDuration
        while os.clock() < releaseAt and allowed() and player.Character == character and prompt.Parent do
            task.wait(math.min(0.04, math.max(0, releaseAt - os.clock())))
        end
        pcall(function() prompt:InputHoldEnd() end)
        heldPrompt = nil
        local confirmationEnd = os.clock() + 1.25
        while not carryingEgg() and allowed() and player.Character == character and os.clock() < confirmationEnd do
            task.wait(0.04)
        end
        if not allowed() or player.Character ~= character then return "Coleta cancelada." end
        if not carryingEgg() then return "O jogo não confirmou a coleta." end

        enabled = true
        toggle.Text = "Desligar esquiva"
        collectionStatus.Text = "Ovo na mão · esquiva ligada."
        local pickedAt = os.clock()
        local deadline = pickedAt + 65
        while allowed() and carryingEgg() and os.clock() < deadline do task.wait(0.2) end
        if not allowed() then return "Coleta interrompida." end
        if carryingEgg() then return "Ovo ainda em transporte." end
        if fromAuto then
            if os.clock() - pickedAt < 27 then return "Transporte terminou cedo. Confira o ovo." end
            local returned = waitFor(root, 8, function()
                return not allowed() or root.Position.Z > -50
            end)
            if not returned or not allowed() then return "Retorno à base não confirmado." end
        end
        return "Transporte terminou. Confira o ovo na base.", true, name
    end)
    if heldPrompt then pcall(function() heldPrompt:InputHoldEnd() end) end
    collecting = false
    if not ok then warn("[Coleta Área 1] " .. tostring(message)) end
    if gui.Parent then collectionStatus.Text = ok and message or "Erro na coleta. Veja o console." end
    return ok and finished == true, eggName
end

local order = { common = 1, comum = 1, uncommon = 2, incomum = 2, rare = 3, raro = 3,
    epic = 4, epico = 4, ["épico"] = 4, legendary = 5, lendario = 5, ["lendário"] = 5,
    mythic = 6, mythical = 6, mitico = 6, ["mítico"] = 6, divine = 7, secret = 8 }
local colors = { Color3.fromRGB(197, 210, 230), Color3.fromRGB(104, 220, 144),
    Color3.fromRGB(107, 174, 255), Color3.fromRGB(195, 135, 255), Color3.fromRGB(255, 192, 83),
    Color3.fromRGB(255, 116, 150), Color3.fromRGB(129, 245, 240), Color3.fromRGB(252, 227, 125) }

local function field(object, names)
    for _, key in ipairs(names) do
        local value = object:GetAttribute(key)
        if value ~= nil then return value end
        local child = object:FindFirstChild(key)
        if child and (child:IsA("StringValue") or child:IsA("IntValue")) then return child.Value end
    end
end

local function previewEgg(icon, object)
    local view = make("ViewportFrame", icon, {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(170, 170, 170),
    })
    local model = make("Model", view, {})
    local parts = object:GetDescendants()
    if object:IsA("BasePart") then table.insert(parts, 1, object) end
    local count = 0
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") and part.Archivable and part.Transparency < 0.99 then
            local clone = part:Clone()
            if clone then
                for _, child in ipairs(clone:GetChildren()) do
                    if not (child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("Texture")
                        or child:IsA("SurfaceAppearance")) then child:Destroy() end
                end
                clone.Anchored = true
                clone.Parent = model
                count = count + 1
                if count >= 70 then break end
            end
        end
    end
    if count == 0 then view:Destroy(); return end
    local center, size = model:GetBoundingBox()
    local distance = math.max(size.X, size.Y, size.Z) * 2.4
    local camera = make("Camera", view, {
        FieldOfView = 32,
        CFrame = CFrame.lookAt(center.Position + Vector3.new(0.48, 0.25, 1).Unit * distance, center.Position),
    })
    view.CurrentCamera = camera
    icon.Text = ""
end

local lastSignature
local function refreshEggs()
    local rows = {}
    local zoneNumber = selectedZone
    local eggs = workspace:FindFirstChild("Eggs")
    local rarityNames = { [1] = "Comum", [2] = "Raro", [3] = "Épico", [4] = "Lendário" }
    for _, object in ipairs(eggs and eggs:GetChildren() or {}) do
        local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
        if tonumber(object:GetAttribute("Zone")) == zoneNumber and prompt and prompt.Enabled then
            local value = field(object, { "EggRarity", "Rarity" })
            local numeric = tonumber(value)
            local rarity = numeric and (rarityNames[numeric] or ("Raridade " .. numeric))
                or tostring(value or "Sem raridade")
            local image = field(object, { "Image", "Icon", "ImageId", "IconId", "Thumbnail" })
            if type(image) == "number" or (type(image) == "string" and image:match("^%d+$")) then
                image = "rbxassetid://" .. tostring(image)
            end
            local rank = order[rarity:lower()] or 0
            local location = object:IsA("BasePart") and object.Position
                or (object:IsA("Model") and object:GetPivot().Position)
            local label = prompt.ObjectText ~= "" and prompt.ObjectText or object.Name
            table.insert(rows, { name = label, rarity = rarity, rank = rank,
                image = type(image) == "string" and image or "",
                location = location and tostring(location) or "", object = object })
        end
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.rarity ~= b.rarity then return a.rarity < b.rarity end
        return a.location < b.location
    end)
    local keys = {}
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        keys[index] = row.name .. "|" .. row.rarity .. "|" .. row.image .. "|" .. row.location
    end
    local signature = zoneNumber .. ":" .. #rows .. ":" .. table.concat(keys, "\n")
    if lastSignature == signature then return end
    lastSignature = signature
    for _, item in ipairs(list:GetChildren()) do
        if not item:IsA("UIListLayout") then item:Destroy() end
    end
    eggsTitle.Text = "OVOS · ÁREA " .. zoneNumber .. " (" .. #rows .. ")"
    if #rows == 0 then
        make("TextLabel", list, {
            Text = "Nenhum ovo desta área carregado.", Size = UDim2.new(1, -4, 0, 62),
            BackgroundTransparency = 1, TextWrapped = true, TextSize = 12,
            TextColor3 = Color3.fromRGB(198, 211, 231), Font = Enum.Font.Gotham,
        })
    end
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        local item = make("Frame", list, {
            LayoutOrder = index, Size = UDim2.new(1, -5, 0, 82),
            BackgroundColor3 = Color3.fromRGB(59, 19, 24), BorderSizePixel = 0,
        })
        round(item, 6)
        local icon = make("TextLabel", item, {
            Text = "🥚", Position = UDim2.fromOffset(4, 7), Size = UDim2.fromOffset(35, 36),
            TextSize = 24, BackgroundTransparency = 1,
        })
        if row.image ~= "" then
            make("ImageLabel", icon, {
                Image = row.image, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
            })
        elseif index <= 12 then
            pcall(previewEgg, icon, row.object)
        end
        make("TextLabel", item, {
            Text = row.name .. "\n" .. row.rarity, Position = UDim2.fromOffset(44, 4),
            Size = UDim2.new(1, -48, 0, 44), BackgroundTransparency = 1, TextSize = 12,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
            TextColor3 = colors[row.rank] or Color3.fromRGB(211, 221, 238),
        })
        local collect = make("TextButton", item, {
            Text = "Coletar", Position = UDim2.fromOffset(5, 51), Size = UDim2.new(1, -10, 0, 26),
            BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
            TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = Enum.Font.GothamBold,
        })
        round(collect, 5)
        collect.Activated:Connect(function(input, clicks) collectEgg(row.object, input, clicks) end)
    end
end

task.spawn(function()
    while gui.Parent do
        if eggsPanel.Visible then refreshEggs() end
        task.wait(3)
    end
end)

local function ownPen()
    local map = workspace:FindFirstChild("Map")
    local base = map and map:FindFirstChild("Base")
    local plots = base and base:FindFirstChild("Plots")
    for _, plot in ipairs(plots and plots:GetChildren() or {}) do
        if tonumber(plot:GetAttribute("OwnerId")) == player.UserId then
            return plot:FindFirstChild("PenEggs")
        end
    end
end

local function eggNameKey(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("^%s*🥚%s*", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function findEggTool(character, name, previousTools)
    local expected = eggNameKey(name)
    if expected == "" then return end
    local function match(container)
        local found
        for _, object in ipairs(container and container:GetChildren() or {}) do
            if object:IsA("Tool") and not previousTools[object] and (eggNameKey(object.Name) == expected or eggNameKey(object:GetAttribute("EggName")) == expected) then
                if found then return nil, true end
                found = object
            end
        end
        return found
    end
    local equipped, ambiguous = match(character)
    if equipped or ambiguous then return equipped end
    return match(player:FindFirstChildOfClass("Backpack"))
end

local function hotbarSnapshot()
    local inventory = guiParent:FindFirstChild("Inventory")
    local bar = inventory and inventory:FindFirstChild("Hotbar")
    local slots = {}
    for _, slot in ipairs(bar and bar:GetDescendants() or {}) do
        if slot.Name == "BarSlot" and slot:IsA("GuiObject") then table.insert(slots, slot) end
    end
    table.sort(slots, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)
    local result = {}
    for index, slot in ipairs(slots) do
        local evidence, labels = {}, {}
        local nodes = slot:GetDescendants()
        table.insert(nodes, 1, slot)
        for _, node in ipairs(nodes) do
            for key, value in pairs(node:GetAttributes()) do
                local lower = key:lower()
                if lower:find("item", 1, true) or lower:find("egg", 1, true)
                    or lower == "count" or lower == "amount" then
                    table.insert(evidence, node.Name .. ":" .. key .. "=" .. tostring(value))
                end
            end
            if node:IsA("TextLabel") or node:IsA("TextButton") then
                if node.Text ~= "" and node.Visible then
                    table.insert(labels, node.Text)
                    table.insert(evidence, node.Name .. ":text=" .. node.Text)
                end
            elseif (node:IsA("ImageLabel") or node:IsA("ImageButton")) and node.Visible and node.Image ~= "" then
                table.insert(evidence, node.Name .. ":image=" .. node.Image)
            elseif node:IsA("ObjectValue") and node.Value then
                table.insert(evidence, node.Name .. ":value=" .. node.Value:GetFullName())
            end
        end
        table.sort(evidence)
        local button = slot:IsA("GuiButton") and slot or slot:FindFirstChild("Face", true)
        if button and not button:IsA("GuiButton") then button = nil end
        result[index] = { button = button, fingerprint = table.concat(evidence, "|"), labels = labels }
    end
    return result
end

local function newEggSlot(previous, name)
    local matched, changes = {}, {}
    for index, row in ipairs(hotbarSnapshot()) do
        local before = previous[index]
        if row.button and visibleControl(row.button) and row.fingerprint ~= "" then
            local expected = eggNameKey(name)
            for _, label in ipairs(row.labels) do
                if expected ~= "" and eggNameKey(label) == expected then
                    table.insert(matched, row.button)
                    break
                end
            end
            if not before or before.fingerprint ~= row.fingerprint then
                table.insert(changes, row.button)
            end
        end
    end
    if #matched == 1 then return matched[1] end
    if #changes == 1 then return changes[1] end
end

local function worldPoint()
    local camera = workspace.CurrentCamera
    if not camera then return end
    for _, x in ipairs({ 0.50, 0.43, 0.57 }) do
        local point = Vector2.new(camera.ViewportSize.X * x, camera.ViewportSize.Y * 0.68)
        local blocked = false
        for _, item in ipairs(guiParent:GetGuiObjectsAtPosition(point.X, point.Y)) do
            if item:IsA("GuiButton") or item.Active or item:IsDescendantOf(gui) then
                blocked = true
                break
            end
        end
        if not blocked then return point end
    end
end

local function penTimes()
    local raw = player:GetAttribute("PenEggTimes")
    if type(raw) ~= "string" then return end
    local ok, times = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not ok or type(times) ~= "table" then return end
    local counts = {}
    for _, timestamp in ipairs(times) do
        if type(timestamp) == "number" then counts[timestamp] = (counts[timestamp] or 0) + 1 end
    end
    return counts
end

local function performPlacement(character, root, pen, name, previousTools, previousSlots, input, clicks, placed)
    local nearest, distance
    for _, item in ipairs(pen:GetChildren()) do
        local point = item:IsA("BasePart") and item.Position or (item:IsA("Model") and item:GetPivot().Position)
        if point then
            local delta = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
            if not distance or delta.Magnitude < distance then nearest, distance = delta, delta.Magnitude end
        end
    end
    -- Cercado vazio: procure um piso pertencente ao lote, na direção da entrada.
    if not nearest and pen.Parent then
        local plot = pen.Parent
        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X, 0, forward.Z)
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = { character }
        ray.RespectCanCollide = true
        if forward.Magnitude > 0.1 then
            for _, step in ipairs({ 12, 9, 6 }) do
                local delta = forward.Unit * step
                local point = root.Position + delta
                local floor = workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), ray)
                if floor and floor.Instance:IsDescendantOf(plot) and floor.Normal.Y >= 0.65
                    and not workspace:Raycast(root.Position, delta, ray) then
                    nearest, distance = delta, step
                    break
                end
            end
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local pending = "Interior do cercado não confirmado"
    local function eligible()
        return gui.Parent and auto and root.Parent and player.Character == character
            and ownPen() == pen and not carryingEgg()
    end
    local function confirm(seconds)
        waitFor(root, seconds, function() return placed() or not eligible() end)
        return placed()
    end
    if humanoid and nearest and distance <= 30 then
        collectionStatus.Text = "Entrando no seu cercado..."
        local target = root.Position + nearest
        humanoid:MoveTo(target)
        waitFor(root, 4, function()
            return not eligible() or horizontalDistance(root.Position, target) <= 2.5
        end)
        if root.Parent then humanoid:MoveTo(root.Position) end
        if eligible() and horizontalDistance(root.Position, target) <= 2.5 then
            local tool = name and name ~= "" and findEggTool(character, name, previousTools)
            if tool then
                if tool.Parent ~= character then humanoid:EquipTool(tool) end
                task.wait(0.2)
                if eligible() and tool.Parent == character then
                    collectionStatus.Text = "Ativando o ovo equipado..."
                    tool:Activate()
                    if confirm(2) then return true end
                end
            end

            if eligible() then
                pending = "Ovo novo não identificado na barra"
                collectionStatus.Text = "Procurando o ovo na barra..."
                local slot = waitFor(root, 3, function()
                    return eligible() and newEggSlot(previousSlots, name)
                end)
                if slot and eligible() then
                    pending = "A barra não aceitou a seleção"
                    collectionStatus.Text = "Selecionando o ovo na barra..."
                    if signalFace(slot, input, clicks) then
                        if confirm(0.45) then return true end
                        local equipped = findEggTool(character, name, previousTools)
                        if equipped and equipped.Parent == character and eligible() then
                            collectionStatus.Text = "Ativando o ovo selecionado..."
                            equipped:Activate()
                            if confirm(2) then return true end
                        end
                        pending = "O jogo não confirmou a colocação pelo toque"
                        local point = eligible() and worldPoint()
                        if point and type(firesignal) == "function" then
                            collectionStatus.Text = "Colocando ovo no cercado..."
                            pcall(function() firesignal(inputService.TouchTapInWorld, point, false) end)
                            if confirm(2) then return true end
                            if eligible() then
                                pcall(function() firesignal(inputService.TouchTap, { point }, false) end)
                                if confirm(2) then return true end
                            end
                        else
                            pending = "Não foi possível enviar um toque ao cercado"
                        end
                    end
                end
            end
        end
    end

    if not eligible() then return false, "Ciclo interrompido." end
    collectionStatus.Text = pending .. " · confirmando..."
    if confirm(3) then return true end
    return false, pending .. ". Colocação não confirmada."
end

local function placeInPen(character, root, pen, name, previousTools, previousSlots, input, clicks)
    local before = tonumber(player:GetAttribute("PenEggs"))
    if not before then return false, "Contador do cercado indisponível." end
    local original = penTimes()
    local confirmed = false
    local function placed()
        if confirmed then return true end
        if ownPen() ~= pen then return false end
        if (tonumber(player:GetAttribute("PenEggs")) or before) > before then
            confirmed = true
        elseif original then
            for timestamp, count in pairs(penTimes() or {}) do
                if count > (original[timestamp] or 0) then
                    confirmed = true
                    break
                end
            end
        end
        return confirmed
    end
    local countChanged = player:GetAttributeChangedSignal("PenEggs"):Connect(placed)
    local timesChanged = player:GetAttributeChangedSignal("PenEggTimes"):Connect(placed)
    local ok, result, reason = pcall(performPlacement, character, root, pen, name,
        previousTools, previousSlots, input, clicks, placed)
    countChanged:Disconnect()
    timesChanged:Disconnect()
    if not ok then error(result) end
    return result, reason
end

local function hatchReady(root, pen, input, clicks)
    while gui.Parent and auto and ownPen() == pen and root.Parent do
        local canHatch = false
        for _, egg in ipairs(pen:GetChildren()) do
            local prompt = egg:FindFirstChild("HatchPrompt", true)
            local point = prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and promptPosition(prompt)
            if point and (point - root.Position).Magnitude <= math.max(8, prompt.MaxActivationDistance) then
                canHatch = true
                break
            end
        end
        if not canHatch then return true end
        local hatch = guiParent:FindFirstChild("HatchButton")
        local face = hatch and hatch:FindFirstChild("Face", true)
        local before = tonumber(player:GetAttribute("PenEggs"))
        if not face or not face:IsA("GuiButton") or not visibleControl(face) or not before then return true end
        collectionStatus.Text = "Chocando ovo pronto..."
        if not signalFace(face, input, clicks) or not waitFor(root, 3, function()
            return not auto or (tonumber(player:GetAttribute("PenEggs")) or before) < before
        end) then
            return false, "Eclosão não confirmada. Confira o botão Chocar."
        end
        task.wait(0.55)
    end
    return false, "Ciclo interrompido."
end

local function bestEgg(root, zoneNumber)
    local folder = workspace:FindFirstChild("Eggs")
    local selected, rank, distance
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
        if tonumber(egg:GetAttribute("Zone")) == zoneNumber and prompt and prompt.Enabled then
            local position = promptPosition(prompt)
            local rarity = tonumber(egg:GetAttribute("EggRarity") or egg:GetAttribute("Rarity")) or 0
            local d = position and (position - root.Position).Magnitude
            if d and (not rank or rarity > rank or (rarity == rank and d < distance)) then
                selected, rank, distance = egg, rarity, d
            end
        end
    end
    return selected
end

local looping = false
autoButton.Activated:Connect(function(input, clicks)
    if auto then setAuto(false); collectionStatus.Text = "Desligando ciclo..."; return end
    if looping or collecting or carryingEgg() then return end
    local zoneNumber = selectedZone
    setAuto(true)
    looping = true
    task.spawn(function()
        local failures, depositsSkipped = 0, 0
        local function runRound()
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then return false, "Aguardando personagem" end
            if carryingEgg() then return false, "Aguardando fim do transporte" end
            local nearby, distance = nearestEggZone(root.Position)
            if root.Position.Z > -50 or nearby ~= zoneNumber or not distance or distance > 230 then
                local launched, problem = launchZone(character, root, input, clicks,
                    function() return auto and gui.Parent end, zoneNumber)
                if not launched then return false, problem end
            end
            if not gui.Parent or not auto then return false, "Ciclo desligado" end
            local egg = waitFor(root, 8, function() return not auto or bestEgg(root, zoneNumber) end)
            if not auto then return false, "Ciclo desligado" end
            if not egg then return false, "Aguardando ovos da Área " .. zoneNumber end
            local previousSlots = hotbarSnapshot()
            local previousTools = {}
            for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then previousTools[tool] = true end
                end
            end
            local collected, name = collectEgg(egg, input, clicks, true)
            if not collected then return false, collectionStatus.Text end
            if not auto then return false, "Ciclo desligado" end
            local pen = ownPen()
            local deposited, problem
            if pen then
                local ran, result, message = pcall(placeInPen, character, root, pen, name,
                    previousTools, previousSlots, input, clicks)
                deposited = ran and result
                problem = ran and message or tostring(result)
            else
                problem = "Seu cercado não foi encontrado"
            end
            if not deposited then
                depositsSkipped = depositsSkipped + 1
                warn("[Colocação V19] " .. tostring(problem) .. " · coleta continua")
                return true, "Colocação não confirmada · seguindo"
            end
            if auto and pen then
                local ran, hatched, hatchProblem = pcall(hatchReady, root, pen, input, clicks)
                if not ran or not hatched then warn("[Eclosão] " .. tostring(ran and hatchProblem or hatched)) end
            end
            return true, "Ovo colocado · próxima rodada"
        end
        while gui.Parent and auto do
            local ok, success, reason = pcall(runRound)
            if not gui.Parent or not auto then break end
            if ok and success then
                failures = 0
                collectionStatus.Text = reason
            else
                failures = failures + 1
                local detail = ok and reason or tostring(success)
                collectionStatus.Text = tostring(detail) .. " · tentando novamente"
                if not ok then warn("[Auto Coletar V19] " .. detail) end
            end
            autoButton.Text = string.format("Auto ON · %d sem depósito", depositsSkipped)
            local delay = failures == 0 and 2 or math.min(25, 2 + failures * 3)
            local untilTime = os.clock() + delay
            while gui.Parent and auto and os.clock() < untilTime do task.wait(0.2) end
        end
        looping = false
        if gui.Parent then
            setAuto(false)
            collectionStatus.Text = "Ciclo desligado."
        end
    end)
end)


local function arcadeButton(parent, caption, position, size)
    local button = make("TextButton", parent, {
        Position = position, Size = size, Text = caption, TextSize = 12,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(242, 250, 255),
        BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
        TextWrapped = true,
    })
    round(button, 6)
    return button
end

local previousArea = arcadeButton(eggsPanel, "‹", UDim2.fromOffset(7, 39), UDim2.fromOffset(29, 27))
local nextArea = arcadeButton(eggsPanel, "›", UDim2.new(1, -36, 0, 39), UDim2.fromOffset(29, 27))
local areaLabel = make("TextLabel", eggsPanel, {
    Position = UDim2.fromOffset(38, 39), Size = UDim2.new(1, -76, 0, 27),
    Text = "ÁREA 01 / 12", BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(242, 250, 255),
    Font = Enum.Font.GothamBold, TextSize = 12,
})
local function chooseArea(delta)
    if auto or collecting then
        collectionStatus.Text = "Desligue o ciclo antes de trocar de área."
        return
    end
    selectedZone = (selectedZone - 1 + delta) % 12 + 1
    areaLabel.Text = string.format("ÁREA %02d / 12", selectedZone)
    list.CanvasPosition = Vector2.zero
    refreshEggs()
end
previousArea.Activated:Connect(function() chooseArea(-1) end)
nextArea.Activated:Connect(function() chooseArea(1) end)

local palettes = {
    { "Neon", Color3.fromRGB(15, 15, 31), Color3.fromRGB(35, 31, 65), Color3.fromRGB(90, 57, 169), Color3.fromRGB(124, 232, 255) },
    { "Crimson", Color3.fromRGB(29, 12, 18), Color3.fromRGB(56, 22, 35), Color3.fromRGB(149, 40, 63), Color3.fromRGB(255, 118, 108) },
    { "Menta", Color3.fromRGB(12, 27, 25), Color3.fromRGB(25, 57, 49), Color3.fromRGB(28, 113, 93), Color3.fromRGB(101, 245, 194) },
    { "Âmbar", Color3.fromRGB(33, 22, 13), Color3.fromRGB(63, 43, 28), Color3.fromRGB(141, 82, 26), Color3.fromRGB(255, 204, 107) },
}
local themeIndex = 1
local theme = arcadeButton(panel, "Tema · Neon", UDim2.fromOffset(8, 151), UDim2.new(1, -16, 0, 27))
local mainScale = make("UIScale", panel, { Scale = 1 })
local eggScale = make("UIScale", eggsPanel, { Scale = 1 })
local sizes = {}
for index, option in ipairs({
    { "Painel −", mainScale, -0.1 }, { "Painel +", mainScale, 0.1 },
    { "Ovos −", eggScale, -0.1 }, { "Ovos +", eggScale, 0.1 },
}) do
    local control = arcadeButton(panel, option[1], UDim2.new((index - 1) * .25, 5, 0, 183), UDim2.new(.25, -10, 0, 27))
    sizes[index] = control
    control.Activated:Connect(function()
        option[2].Scale = math.clamp(option[2].Scale + option[3], 0.65, 1.25)
        control.Text = option[1] .. " " .. math.floor(option[2].Scale * 100 + .5) .. "%"
    end)
end
minimize.Activated:Connect(function()
    theme.Visible = not collapsed
    for _, control in ipairs(sizes) do control.Visible = not collapsed end
end)

local function paint(object)
    local palette = palettes[themeIndex]
    if object == panel or object == eggsPanel then
        object.BackgroundColor3 = palette[2]
    elseif object:IsA("UIStroke") then
        object.Color = palette[5]
    elseif object:IsA("UIGradient") then
        object.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(201, 201, 223))
    elseif object:IsA("TextButton") then
        object.BackgroundColor3 = palette[4]
    elseif object == collectionStatus or (object:IsA("Frame") and object.Parent == list) then
        object.BackgroundColor3 = palette[3]
    elseif object == title or object == eggsTitle or object == areaLabel then
        object.TextColor3 = palette[5]
    end
end
local function repaint()
    theme.Text = "Tema · " .. palettes[themeIndex][1]
    for _, object in ipairs(gui:GetDescendants()) do paint(object) end
end
theme.Activated:Connect(function()
    themeIndex = themeIndex % #palettes + 1
    repaint()
end)
gui.DescendantAdded:Connect(paint)
repaint()
