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
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0.49, 0, 0, 151),
    BackgroundColor3 = Color3.fromRGB(20, 28, 42), BorderSizePixel = 0,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(345, 151) })
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
local title = control("TextLabel", "ESQUIVA DO BOSS · V5", 5, 30)
title.Size = UDim2.new(1, -49, 0, 30)
title.TextXAlignment = Enum.TextXAlignment.Left
local minimize = control("TextButton", "−", 6, 28)
minimize.Position, minimize.Size = UDim2.new(1, -36, 0, 6), UDim2.fromOffset(29, 28)
round(minimize, 6)
local status = control("TextLabel", "Desligada", 38, 49)
local toggle = control("TextButton", "Ligar esquiva", 92, 29)
local eggsToggle = control("TextButton", "Ovos da Área 1", 124, 21)
round(toggle, 7)
round(eggsToggle, 6)
local collapsed = false
minimize.Activated:Connect(function()
    collapsed = not collapsed
    status.Visible, toggle.Visible, eggsToggle.Visible = not collapsed, not collapsed, not collapsed
    panel.Size = UDim2.new(0.49, 0, 0, collapsed and 40 or 151)
    minimize.Text = collapsed and "+" or "−"
end)

local LINGER = 0.35
local LOOKAHEAD = { 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.44, 0.52 }
local TRIGGER_MARGIN, EXIT_MARGIN = 1.3, 6
local MIN_STEP, MAX_STEP, JUMP_INTERVAL = 24, 64, 0.12
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
    print(string.format("[Esquiva V5] %s | último salto lateral %.1f studs",
        status.Text, session.lastDistance))
end

local function isWarning(part)
    local color, size = part.Color, part.Size
    return color.R >= 0.9 and color.G <= 0.3 and color.B <= 0.3
        and part.Transparency >= 0.25 and part.Transparency <= 0.9
        and math.min(size.X, size.Y, size.Z) <= 0.5
        and math.max(size.X, size.Y, size.Z) >= 7
end

local function updateWarning(previous, part, now)
    local frame, size = part.CFrame, part.Size
    local warning = {
        frame = frame, size = size, seen = now,
        static = part.Transparency >= 0.65,
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

local function safeStep(root, warnings, ray, bossPosition, shortRange)
    local origin = root.Position
    local currentFloor = workspace:Raycast(origin, Vector3.new(0, -18, 0), ray)
    if not currentFloor or currentFloor.Normal.Y < 0.65 then return end
    local clearance = origin.Y - currentFloor.Position.Y
    local bossDistance = bossPosition and horizontalDistance(origin, bossPosition)
    local minimumBossDistance = bossDistance and math.max(bossDistance, math.min(26, math.max(14, bossDistance + 5)))
    local first, last, increment = MAX_STEP, MIN_STEP, -2
    if shortRange then first, last, increment = 2, shortRange, 1 end
    for distance = first, last, increment do
        local best, bestDistance
        for _, direction in ipairs(directions) do
            local candidate = origin + direction * distance
            local distanceFromBoss = bossPosition and horizontalDistance(candidate, bossPosition)
            if (not minimumBossDistance or distanceFromBoss >= minimumBossDistance)
                and not threatened(candidate, warnings, EXIT_MARGIN) then
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
    if not root or not humanoid or humanoid.Health <= 0 or type(hp) ~= "number" or hp < 0 then
        status.Text = "Ligada · aguardando luta"
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
        local lastMove, lastScan, lastJump = -math.huge, -math.huge, -math.huge
        local ok, err = pcall(function()
            while gui.Parent and active == session do
                local now = os.clock()
                if session.interrupted or player.Character ~= character or not root.Parent or humanoid.Health <= 0 then
                    finish(session, "Luta encerrada")
                    return
                end
                local folder = workspace:FindFirstChild("BossFX")
                if folder then
                    for _, part in ipairs(folder:GetChildren()) do
                        if part:IsA("BasePart") and isWarning(part) then
                            session.warnings[part] = updateWarning(session.warnings[part], part, now)
                        end
                    end
                end
                local areas, waves = projectWarnings(session.warnings, now)
                local danger = threatened(root.Position, areas, TRIGGER_MARGIN)
                local message = danger and "Buscando saída" or "Fora das marcas"
                if danger and now - lastMove >= 0.15 and now - lastScan >= 0.10 then
                    lastScan = now
                    ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                    local bossPosition
                    local nearestBoss = math.huge
                    if folder then
                        for _, model in ipairs(folder:GetChildren()) do
                            if model:IsA("Model") and (model:FindFirstChildOfClass("Humanoid")
                                or model.Name == "Touro Gigante" or model.Name:lower():find("boss", 1, true)) then
                                local position = model:GetPivot().Position
                                local distance = horizontalDistance(root.Position, position)
                                if distance < nearestBoss then
                                    bossPosition, nearestBoss = position, distance
                                end
                            end
                        end
                    end
                    local shortRange = math.floor(math.min(5, humanoid.WalkSpeed * 0.18))
                    local short
                    local immediate = threatened(root.Position, areas, TRIGGER_MARGIN, true)
                    local waiting = session.walking and not immediate and now < (session.runUntil or 0)
                    if not waiting and not immediate and waves > 0 and shortRange >= 2 and now >= (session.nextRun or 0) then
                        short = safeStep(root, areas, ray, nil, shortRange)
                    end
                    local delta
                    if short then
                        humanoid:MoveTo(root.Position + short)
                        session.nextRun = now + 0.55
                        session.runUntil = now + 0.18
                        session.walking = true
                        message = "Saída a pé"
                    elseif not waiting then
                        delta = safeStep(root, areas, ray, bossPosition)
                    end
                    if delta then
                        if session.walking then
                            humanoid:MoveTo(root.Position)
                            session.walking = false
                        end
                        character:PivotTo(character:GetPivot() + delta)
                        session.moves = session.moves + 1
                        session.lastDistance = horizontalDistance(Vector3.zero, delta)
                        lastMove = now
                        message = "Saída solicitada"
                    elseif not short and not waiting then
                        message = "Sem saída livre entre 24 e 64 studs"
                    end
                end
                if now - lastJump >= JUMP_INTERVAL and humanoid.FloorMaterial ~= Enum.Material.Air then
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
    Size = UDim2.new(0.40, 0, 0.76, 0), BackgroundColor3 = Color3.fromRGB(20, 28, 42),
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
    BackgroundColor3 = Color3.fromRGB(43, 62, 89), TextColor3 = Color3.new(1, 1, 1),
})
round(hideEggs, 6)
hideEggs.Activated:Connect(function() eggsPanel.Visible = false end)
eggsToggle.Activated:Connect(function() eggsPanel.Visible = not eggsPanel.Visible end)

local list = make("ScrollingFrame", eggsPanel, {
    Position = UDim2.fromOffset(6, 38), Size = UDim2.new(1, -12, 1, -44),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0,
})
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local order = { common = 1, comum = 1, uncommon = 2, incomum = 2, rare = 3, raro = 3,
    epic = 4, epico = 4, ["épico"] = 4, legendary = 5, lendario = 5, ["lendário"] = 5,
    mythic = 6, mythical = 6, mitico = 6, ["mítico"] = 6, divine = 7, secret = 8 }
local colors = { Color3.fromRGB(197, 210, 230), Color3.fromRGB(104, 220, 144),
    Color3.fromRGB(107, 174, 255), Color3.fromRGB(195, 135, 255), Color3.fromRGB(255, 192, 83),
    Color3.fromRGB(255, 116, 150), Color3.fromRGB(129, 245, 240), Color3.fromRGB(252, 227, 125) }

local function areaOne(object)
    local node = object
    while node and node ~= workspace do
        local name = node.Name:lower():gsub("[%s_%-]", "")
        local id = node:GetAttribute("AreaId") or node:GetAttribute("ZoneId")
        if id ~= nil then return tonumber(id) == 1 end
        if name == "area1" or name == "area01" or name == "área1" or name == "zone1" or name == "zone01" then
            return true
        end
        node = node.Parent
    end
    return false
end

local function looksLikeEgg(object)
    if not (object:IsA("Model") or object:IsA("BasePart")) then return false end
    local name = object.Name:gsub("(%l)(%u)", "%1 %2"):lower()
    return object:GetAttribute("IsEgg") == true or object:GetAttribute("EggId") ~= nil
        or name:find("%f[%a]egg%f[%A]") ~= nil or name:find("%f[%a]ovo%f[%A]") ~= nil
end

local function field(object, names)
    for _, key in ipairs(names) do
        local value = object:GetAttribute(key)
        if value ~= nil then return value end
        local child = object:FindFirstChild(key)
        if child and (child:IsA("StringValue") or child:IsA("IntValue")) then return child.Value end
    end
end

local lastSignature
local function refreshEggs()
    local rows = {}
    for _, object in ipairs(workspace:GetDescendants()) do
        if looksLikeEgg(object) and areaOne(object) then
            local ancestor, nested = object.Parent, false
            while ancestor and ancestor ~= workspace do
                if looksLikeEgg(ancestor) and areaOne(ancestor) then nested = true; break end
                ancestor = ancestor.Parent
            end
            if not nested then
                local rarity = tostring(field(object, { "Rarity", "EggRarity", "Raridade", "Tier" }) or "Sem raridade")
                local image = field(object, { "Image", "Icon", "ImageId", "IconId", "Thumbnail" })
                if not image then
                    local decal = object:FindFirstChildWhichIsA("Decal", true)
                    if decal then image = decal.Texture end
                end
                if type(image) == "number" or (type(image) == "string" and image:match("^%d+$")) then
                    image = "rbxassetid://" .. tostring(image)
                end
                if type(image) ~= "string" then image = "" end
                local rank = order[rarity:lower()] or 0
                table.insert(rows, { name = object.Name, rarity = rarity, rank = rank, image = image })
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.rarity ~= b.rarity then return a.rarity < b.rarity end
        return a.image < b.image
    end)
    local keys = {}
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        keys[index] = row.name .. "|" .. row.rarity .. "|" .. row.image
    end
    local signature = #rows .. ":" .. table.concat(keys, "\n")
    if lastSignature == signature then return end
    lastSignature = signature
    for _, item in ipairs(list:GetChildren()) do
        if not item:IsA("UIListLayout") then item:Destroy() end
    end
    eggsTitle.Text = "OVOS · ÁREA 1 (" .. #rows .. ")"
    if #rows == 0 then
        make("TextLabel", list, {
            Text = "Nenhum ovo da Área 1 identificado no cliente.", Size = UDim2.new(1, -4, 0, 62),
            BackgroundTransparency = 1, TextWrapped = true, TextSize = 12,
            TextColor3 = Color3.fromRGB(198, 211, 231), Font = Enum.Font.Gotham,
        })
    end
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        local item = make("Frame", list, {
            LayoutOrder = index, Size = UDim2.new(1, -5, 0, 52),
            BackgroundColor3 = Color3.fromRGB(36, 51, 73), BorderSizePixel = 0,
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
        end
        make("TextLabel", item, {
            Text = row.name .. "\n" .. row.rarity, Position = UDim2.fromOffset(44, 4),
            Size = UDim2.new(1, -48, 0, 44), BackgroundTransparency = 1, TextSize = 12,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
            TextColor3 = colors[row.rank] or Color3.fromRGB(211, 221, 238),
        })
    end
end

task.spawn(function()
    while gui.Parent do
        if eggsPanel.Visible then refreshEggs() end
        task.wait(3)
    end
end)
