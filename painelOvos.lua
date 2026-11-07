-- Painel local. No Studio, coloque em um LocalScript em StarterPlayerScripts.
local player = game:GetService("Players").LocalPlayer
local inputService = game:GetService("UserInputService")
local tags = game:GetService("CollectionService")
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("PainelOvos")
if previous then previous:Destroy() end

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local palette = {
    bg = Color3.fromRGB(22, 26, 36),
    card = Color3.fromRGB(39, 48, 66),
    text = Color3.fromRGB(243, 246, 252),
    accent = Color3.fromRGB(61, 105, 194),
}
local gui = make("ScreenGui", playerGui, {
    Name = "PainelOvos", ResetOnSpawn = false, DisplayOrder = 20,
})
local marks = make("Folder", gui, { Name = "Marcadores" })
local minimized = false
local expandedSize = UDim2.new(1, -24, 0.78, 0)
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = expandedSize,
    BackgroundColor3 = palette.bg,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(720, 680) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 12) })

local function label(parent, text, position, size)
    return make("TextLabel", parent, {
        Text = text, Position = position, Size = size, TextSize = 14,
        Font = Enum.Font.Gotham, TextColor3 = palette.text, BackgroundTransparency = 1,
    })
end
local function button(parent, text, position, size)
    local control = make("TextButton", parent, {
        Text = text, Position = position, Size = size, TextSize = 14,
        Font = Enum.Font.GothamBold, TextColor3 = palette.text, BackgroundColor3 = palette.card,
        BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    make("UICorner", control, { CornerRadius = UDim.new(0, 6) })
    return control
end
local function scroll(parent, position, size)
    return make("ScrollingFrame", parent, {
        Position = position, Size = size, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
    })
end

local title = label(panel, "RASTREADOR DE OVOS", UDim2.fromOffset(12, 4), UDim2.new(1, -76, 0, 36))
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
local minimize = button(panel, "−", UDim2.new(1, -56, 0, 6), UDim2.fromOffset(46, 32))
local body = make("Frame", panel, {
    Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -56),
    BackgroundTransparency = 1,
})
local grip = button(panel, "Redimensionar ↘", UDim2.new(1, -128, 1, -27), UDim2.fromOffset(118, 22))
local toggle = button(body, "Rastreador desligado", UDim2.fromOffset(10, 1), UDim2.new(1, -20, 0, 34))
minimize.Activated:Connect(function()
    minimized = not minimized
    body.Visible, grip.Visible = not minimized, not minimized
    panel.Size = minimized and UDim2.fromOffset(math.min(panel.AbsoluteSize.X, 290), 44) or expandedSize
    minimize.Text = minimized and "+" or "−"
end)

local dragging, origin, initialSize
grip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, origin, initialSize = input, input.Position, panel.AbsoluteSize
    end
end)
local resize = inputService.InputChanged:Connect(function(input)
    if not dragging or minimized then return end
    if dragging.UserInputType == Enum.UserInputType.Touch then
        if input ~= dragging then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local delta = input.Position - origin
    local maxWidth = math.max(1, math.min(720, viewport.X - 28))
    local maxHeight = math.max(1, math.min(680, viewport.Y - 90))
    expandedSize = UDim2.fromOffset(
        math.clamp(initialSize.X + delta.X, math.min(255, maxWidth), maxWidth),
        math.clamp(initialSize.Y + delta.Y, math.min(245, maxHeight), maxHeight)
    )
    panel.Size = expandedSize
end)
local resizeEnd = inputService.InputEnded:Connect(function(input)
    if dragging == input then dragging = nil end
end)
gui.Destroying:Connect(function()
    resize:Disconnect()
    resizeEnd:Disconnect()
end)
local filterButton = button(body, "Filtro · Todos", UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 34))
local status = label(body, "Ative para buscar ovos no mapa.", UDim2.fromOffset(10, 75), UDim2.new(1, -20, 0, 25))
local list = scroll(body, UDim2.fromOffset(10, 103), UDim2.new(1, -20, 1, -122))
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local detail = make("Frame", body, {
    Visible = false, Position = UDim2.fromOffset(8, 39), Size = UDim2.new(1, -16, 1, -57),
    BackgroundColor3 = palette.bg, BorderSizePixel = 0,
})
local back = button(detail, "Voltar à lista", UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 34))
local detailScroll = scroll(detail, UDim2.fromOffset(4, 42), UDim2.new(1, -8, 1, -121))
local info = label(detailScroll, "", UDim2.new(), UDim2.new(1, -8, 0, 0))
info.AutomaticSize = Enum.AutomaticSize.Y
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
local teleport = button(detail, "Teleportar até o ovo", UDim2.new(0, 2, 1, -71), UDim2.new(1, -4, 0, 33))
local collect = button(detail, "Ir e coletar", UDim2.new(0, 2, 1, -35), UDim2.new(1, -4, 0, 33))
local progress = label(gui, "", UDim2.new(0.5, 0, 1, -70), UDim2.new(1, -24, 0, 32))
progress.AnchorPoint = Vector2.new(0.5, 0)
progress.BackgroundColor3 = palette.bg
progress.BackgroundTransparency = 0.1
progress.Visible = false
local running = false
local runId = 0

local rarityNames = {
    common = "Comum", comum = "Comum", uncommon = "Incomum", incomum = "Incomum",
    rare = "Raro", raro = "Raro", rara = "Raro",
    epic = "Épico", epico = "Épico", ["épico"] = "Épico",
    legendary = "Lendário", lendario = "Lendário", ["lendário"] = "Lendário",
    mythic = "Mítico", mythical = "Mítico", mitico = "Mítico", ["mítico"] = "Mítico",
}
local rarityColors = {
    ["Comum"] = Color3.fromRGB(205, 215, 229),
    ["Incomum"] = Color3.fromRGB(100, 225, 144),
    ["Raro"] = Color3.fromRGB(97, 174, 255),
    ["Épico"] = Color3.fromRGB(199, 126, 255),
    ["Lendário"] = Color3.fromRGB(255, 188, 63),
    ["Mítico"] = Color3.fromRGB(255, 103, 132),
}
local missing = "Sem dados de raridade"
local enabled, filter, selected = false, "Todos", nil
local filters = { "Todos" }
local filterIndex = 1
local activeMarks = {}

local function eggText(value)
    local name = tostring(value):gsub("(%l)(%u)", "%1 %2"):lower()
    return name:match("%f[%a]eggs?%f[%A]") ~= nil or name:match("%f[%a]ovos?%f[%A]") ~= nil
end

local function eggCandidate(object)
    if not (object:IsA("Model") or object:IsA("BasePart")) then return false end
    if tags:HasTag(object, "Egg") or object:GetAttribute("IsEgg") == true then return true end
    for key, value in pairs(object:GetAttributes()) do
        key = key:lower()
        if key == "eggid" or key == "eggtype" or key == "eggrarity"
            or ((key == "type" or key == "itemtype") and eggText(value)) then
            return true
        end
    end
    return eggText(object.Name)
end

local function promptTarget(prompt)
    local parent = prompt.Parent
    if parent and parent:IsA("Attachment") then parent = parent.Parent end
    return parent
end

local function collectionPrompt(prompt)
    local action = prompt.ActionText:lower()
    if action:find("buy", 1, true) or action:find("compr", 1, true)
        or action:find("hatch", 1, true) or action:find("chocar", 1, true) then
        return false
    end
    return prompt.Enabled and prompt.HoldDuration >= 0.75 and prompt.HoldDuration <= 3
end

local function anchorOf(object)
    if object:IsA("BasePart") then return object end
    return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
end

local function metadata(object, key)
    for name, value in pairs(object:GetAttributes()) do
        if name:lower() == key then return value, "atributo " .. name end
    end
    for _, child in ipairs(object:GetChildren()) do
        if child.Name:lower() == key and (child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("BoolValue")) then
            return child.Value, child.Name
        end
    end
end

local function getRarity(object)
    local value, source = metadata(object, "rarity")
    if value == nil then value, source = metadata(object, "eggrarity") end
    if value == nil then value, source = metadata(object, "raridade") end
    if value == nil then value, source = metadata(object, "tier") end
    if value == nil then return missing, "—" end
    local raw = tostring(value):match("^%s*(.-)%s*$")
    if raw == "" then return missing, "—" end
    return rarityNames[raw:lower()] or raw, source
end

local function clearList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local selectedData
local function details(row)
    selectedData = row
    if not running then collect.Text = row.prompt and "Ir e coletar" or "Sem interação de coleta" end
    local object = row.object
    local pos = row.anchor.Position
    local reportedStatus = metadata(object, "status")
    local lines = {
        object.Name, "Raridade: " .. row.rarity, "Fonte da raridade: " .. row.source,
        "Status: " .. tostring(reportedStatus == nil and "visível no mapa local" or reportedStatus),
        "Distância: " .. (row.distance < math.huge and string.format("%.0f studs", row.distance) or "—"),
        string.format("Posição: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z),
        "Detecção: " .. row.signal,
        row.prompt and ("Interação: " .. row.prompt.ActionText .. " (" .. row.prompt.HoldDuration .. " s)") or "Interação de coleta indisponível",
        "Tipo: " .. object.ClassName, "Caminho: " .. object:GetFullName(), "", "Atributos e valores",
    }
    local entries = {}
    for name, value in pairs(object:GetAttributes()) do
        table.insert(entries, name .. ": " .. tostring(value))
    end
    for _, child in ipairs(object:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("BoolValue") then
            table.insert(entries, child.Name .. ": " .. tostring(child.Value))
        end
    end
    table.sort(entries)
    for _, entry in ipairs(entries) do table.insert(lines, entry) end
    if #entries == 0 then table.insert(lines, "Nenhum valor legível neste objeto.") end
    info.Text = table.concat(lines, "\n")
end

local function refresh()
    clearList()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local rows = {}
    local raritySet, detected = {}, {}
    local descendants = workspace:GetDescendants()
    for _, object in ipairs(descendants) do
        if eggCandidate(object) then
            local anchor = anchorOf(object)
            if anchor then detected[object] = { anchor = anchor, signal = "nome, tag ou atributo" } end
        end
    end
    for _, prompt in ipairs(descendants) do
        if prompt:IsA("ProximityPrompt") and collectionPrompt(prompt) then
            local target = promptTarget(prompt)
            local cursor = target
            local owner
            local areaHasEggs = false
            while cursor and cursor ~= workspace do
                if detected[cursor] then
                    owner = cursor
                    break
                end
                areaHasEggs = areaHasEggs or (cursor:IsA("Folder") and eggText(cursor.Name))
                cursor = cursor.Parent
            end
            local explicit = eggText(prompt.ObjectText) or eggText(prompt.ActionText)
            local action = prompt.ActionText:lower()
            local collectAction = action:find("collect", 1, true) or action:find("colet", 1, true)
                or action:find("pick up", 1, true) or action:find("pegar", 1, true)
            if (explicit or (areaHasEggs and collectAction)) and not owner and target and (target:IsA("Model") or target:IsA("BasePart")) then
                local anchor = anchorOf(target)
                if anchor then
                    owner = target
                    detected[owner] = { anchor = anchor, signal = "interação identificada como ovo" }
                end
            end
            if owner and (explicit or collectAction) then
                local row = detected[owner]
                if row.prompt and row.prompt ~= prompt then
                    row.ambiguous = true
                end
                row.prompt = prompt
            end
        end
    end
    for object, row in pairs(detected) do
        local ancestor = object.Parent
        local duplicate = false
        while ancestor and ancestor ~= workspace do
            if detected[ancestor] and not row.prompt then
                duplicate = true
                break
            end
            ancestor = ancestor.Parent
        end
        if not duplicate then
            if row.ambiguous then row.prompt = nil end
            row.object = object
            row.rarity, row.source = getRarity(object)
            if row.rarity == missing and row.prompt then
                row.rarity, row.source = getRarity(row.prompt)
            end
            row.distance = root and (root.Position - row.anchor.Position).Magnitude or math.huge
            raritySet[row.rarity] = true
            if filter == "Todos" or row.rarity == filter then table.insert(rows, row) end
        end
    end
    filters = { "Todos" }
    local extras = {}
    for rarity in pairs(raritySet) do table.insert(extras, rarity) end
    table.sort(extras)
    for _, rarity in ipairs(extras) do table.insert(filters, rarity) end
    if not table.find(filters, filter) then
        filter = "Todos"
        filterButton.Text = "Filtro · Todos"
        refresh()
        return
    end
    filterIndex = table.find(filters, filter)
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    status.Text = #rows == 0 and "Nenhum ovo carregado neste filtro." or (#rows .. " ovos carregados neste filtro")
    if #rows > 100 then status.Text = #rows .. " ovos · exibindo os 100 mais próximos" end
    local keep = {}
    local selectedRow
    for index, row in ipairs(rows) do
        if row.object == selected then selectedRow = row end
        if index <= 100 then
            local caption = row.object.Name .. " · " .. row.rarity
            local reportedStatus = metadata(row.object, "status")
            if reportedStatus ~= nil then caption = caption .. " · " .. tostring(reportedStatus) end
            if row.distance < math.huge then caption = caption .. string.format(" · %.0f studs", row.distance) end
            local item = button(list, caption, UDim2.new(), UDim2.new(1, -7, 0, 36))
            item.LayoutOrder = index
            item.Activated:Connect(function()
                selected = row.object
                details(row)
                detailScroll.CanvasPosition = Vector2.zero
                list.Visible, status.Visible, filterButton.Visible = false, false, false
                detail.Visible = true
                teleport.Text = "Teleportar até o ovo"
            end)
        end
        if index <= 40 then
            local marker = activeMarks[row.object]
            if not marker then
                marker = make("BillboardGui", marks, {
                    Size = UDim2.fromOffset(160, 34), StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
                    AlwaysOnTop = true, MaxDistance = 350,
                })
                label(marker, "", UDim2.new(), UDim2.fromScale(1, 1)).TextStrokeTransparency = 0.2
            end
            marker.Adornee = row.anchor
            marker.TextLabel.Text = row.rarity
            marker.TextLabel.TextColor3 = rarityColors[row.rarity] or palette.text
            keep[row.object] = marker
        end
    end
    for object, marker in pairs(activeMarks) do
        if not keep[object] then marker:Destroy() end
    end
    activeMarks = keep
    if selectedRow then
        details(selectedRow)
    elseif selected then
        selectedData = nil
        info.Text = "O ovo selecionado saiu do mapa local ou do filtro."
    end
end

local function closeDetails()
    selected, selectedData = nil, nil
    detail.Visible = false
    list.Visible, status.Visible, filterButton.Visible = true, true, true
end

back.Activated:Connect(closeDetails)
local function moveToEgg(row, prompt)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not row or not row.object:IsDescendantOf(workspace) then return end
    local anchor = row.anchor
    local position = anchor.Position
    if prompt then
        local parent = prompt.Parent
        local target = promptTarget(prompt)
        if parent and parent:IsA("Attachment") then
            position = parent.WorldPosition
        elseif target and target:IsA("BasePart") then
            position = target.Position
        elseif target and target:IsA("Model") then
            position = target:GetPivot().Position
        end
    end
    local offset = prompt and Vector3.new(0, 1.5, 2) or Vector3.new(0, anchor.Size.Y / 2 + 4, 0)
    character:PivotTo(CFrame.new(position + offset) * character:GetPivot().Rotation)
    return character, position
end

teleport.Activated:Connect(function()
    if running then return end
    teleport.Text = moveToEgg(selectedData) and "Movimento solicitado" or "Ovo ou personagem indisponível"
end)

collect.Activated:Connect(function()
    local row = selectedData
    local prompt = row and row.prompt
    if running or not prompt or not prompt:IsDescendantOf(workspace) or not collectionPrompt(prompt) then return end

    running = true
    runId = runId + 1
    local currentRun = runId
    collect.Text = "Coleta em andamento"
    progress.Visible = true
    progress.Text = "Indo até o ovo..."
    local holding, triggeredConnection
    local ok, result = pcall(function()
        local character, position = moveToEgg(row, prompt)
        if not character then return "Personagem ou ovo indisponível." end
        task.wait(0.25)
        if currentRun ~= runId or not gui.Parent then return "" end

        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 or not prompt:IsDescendantOf(workspace)
            or not prompt.Enabled or (root.Position - position).Magnitude > prompt.MaxActivationDistance then
            return "A interação ficou fora de alcance ou indisponível."
        end

        local activated = false
        triggeredConnection = prompt.Triggered:Connect(function(who)
            if who == player or who == nil then activated = true end
        end)
        local duration = math.max(1, prompt.HoldDuration)
        progress.Text = "Segurando a interação..."
        prompt:InputHoldBegin()
        holding = true
        local deadline = os.clock() + duration + 0.15
        repeat
            task.wait(0.05)
        until activated or os.clock() >= deadline or currentRun ~= runId or not gui.Parent
            or not prompt.Parent or humanoid.Health <= 0
        prompt:InputHoldEnd()
        holding = false
        triggeredConnection:Disconnect()
        triggeredConnection = nil
        if currentRun ~= runId or not gui.Parent then return "" end
        if not activated then return "O jogo não sinalizou a interação de coleta." end

        local escapeEnd = os.clock() + 30
        while os.clock() < escapeEnd do
            if currentRun ~= runId or not gui.Parent then return "" end
            if player.Character ~= character or humanoid.Health <= 0 then
                return "Fuga interrompida: personagem derrotado."
            end
            progress.Text = string.format("Fuja do boss  ·  %ds  ·  Vida %.0f",
                math.ceil(escapeEnd - os.clock()), humanoid.Health)
            task.wait(0.2)
        end
        return "30 s concluídos. Confira o ovo no jogo."
    end)
    if triggeredConnection then triggeredConnection:Disconnect() end
    if holding then pcall(function() prompt:InputHoldEnd() end) end
    running = false
    if currentRun ~= runId or not gui.Parent then return end
    if not ok then warn(result) end
    progress.Text = ok and result or "Falha ao interagir. Veja o console."
    collect.Text = "Ir e coletar"
    task.delay(5, function()
        if gui.Parent and currentRun == runId then progress.Visible = false end
    end)
end)
toggle.Activated:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "Rastreador ligado" or "Rastreador desligado"
    toggle.BackgroundColor3 = enabled and palette.accent or palette.card
    if enabled then
        refresh()
    else
        runId = runId + 1
        progress.Visible = false
        closeDetails()
        clearList()
        marks:ClearAllChildren()
        activeMarks = {}
        status.Text = "Ative para buscar ovos no mapa."
    end
end)
filterButton.Activated:Connect(function()
    filterIndex = filterIndex % #filters + 1
    filter = filters[filterIndex]
    filterButton.Text = "Filtro · " .. filter
    list.CanvasPosition = Vector2.zero
    if enabled then refresh() end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if gui.Parent and enabled then refresh() end
    end
end)
