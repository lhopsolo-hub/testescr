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

local title = label(panel, "RADAR DE OVOS  /  MAPA", UDim2.fromOffset(12, 4), UDim2.new(1, -76, 0, 36))
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
        math.clamp(initialSize.Y + delta.Y, math.min(340, maxHeight), maxHeight)
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
local mapTab = button(body, "Mapa", UDim2.fromOffset(10, 41), UDim2.new(0.5, -13, 0, 29))
local diagnosticTab = button(body, "Diagnóstico", UDim2.new(0.5, 3, 0, 41), UDim2.new(0.5, -13, 0, 29))
local filterButton = button(body, "Raridade · Todas", UDim2.fromOffset(10, 75), UDim2.new(0.64, -14, 0, 31))
local nearest = button(body, "Mais próximo", UDim2.new(0.64, 0, 0, 75), UDim2.new(0.36, -10, 0, 31))
local status = label(body, "Ative para buscar ovos no mapa.", UDim2.fromOffset(10, 108), UDim2.new(1, -20, 0, 23))
local list = scroll(body, UDim2.fromOffset(10, 135), UDim2.new(1, -20, 1, -145))
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local diagnostic = scroll(body, UDim2.fromOffset(10, 76), UDim2.new(1, -20, 1, -85))
diagnostic.Visible = false
local report = make("TextBox", diagnostic, {
    Size = UDim2.new(1, -9, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = palette.card, TextColor3 = palette.text, TextSize = 13,
    Font = Enum.Font.Code, TextWrapped = true, MultiLine = true,
    TextEditable = false, ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "Ligue o radar para iniciar o diagnóstico.",
})
local view = "map"
local nearestRow
local function showView(nextView)
    view = nextView
    mapTab.BackgroundColor3 = view == "diagnostic" and palette.card or palette.accent
    diagnosticTab.BackgroundColor3 = view == "diagnostic" and palette.accent or palette.card
    filterButton.Visible, nearest.Visible = view == "map", view == "map"
    status.Visible, list.Visible = view == "map", view == "map"
    diagnostic.Visible = view == "diagnostic"
end
showView("map")

local detail = make("Frame", body, {
    Visible = false, Position = UDim2.fromOffset(8, 75), Size = UDim2.new(1, -16, 1, -80),
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

local excludedNames = {
    base = true, bases = true, starterbase = true, initialbase = true, playerbase = true,
    starterarea = true, spawn = true, spawnarea = true, lobby = true, shop = true,
    eggshop = true, hatchery = true, loja = true, baseinicial = true,
}
local function baseAncestor(object)
    local cursor = object
    while cursor and cursor ~= workspace do
        if excludedNames[cursor.Name:lower():gsub("[%s_%-]", "")]
            or cursor:GetAttribute("IsBase") == true or cursor:GetAttribute("IsShop") == true then
            return cursor
        end
        cursor = cursor.Parent
    end
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

local function openRow(row)
    if not row or not row.object:IsDescendantOf(workspace) then return end
    selected = row.object
    details(row)
    detailScroll.CanvasPosition = Vector2.zero
    showView("details")
    detail.Visible = true
    teleport.Text = "Teleportar até o ovo"
end
nearest.Activated:Connect(function() openRow(nearestRow) end)

local function refresh()
    clearList()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local rows = {}
    local raritySet, detected = {}, {}
    local descendants = workspace:GetDescendants()
    local eligible, excluded, uncertain, promptCount = 0, 0, 0, 0
    local samples = {}
    local function sample(kind, object, description)
        if not samples[kind] then samples[kind] = {} end
        local group = samples[kind]
        if #group < 6 then table.insert(group, object:GetFullName() .. "  |  " .. description) end
    end
    for _, object in ipairs(descendants) do
        if eggCandidate(object) then
            local anchor = anchorOf(object)
            if anchor then detected[object] = { anchor = anchor, signal = "nome, tag ou atributo" } end
        end
    end
    for _, prompt in ipairs(descendants) do
        if prompt:IsA("ProximityPrompt") then promptCount = promptCount + 1 end
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
            local excludedBy = baseAncestor(object) or (row.prompt and baseAncestor(row.prompt))
            if excludedBy then
                excluded = excluded + 1
                sample("Base / loja", object, "Área " .. excludedBy.Name)
            elseif not row.prompt then
                uncertain = uncertain + 1
                sample("Sem interação confirmada", object, row.rarity)
            else
                eligible = eligible + 1
                sample("Ovos do mapa", object, row.prompt.ActionText .. " / " .. row.rarity)
                raritySet[row.rarity] = true
                if filter == "Todos" or row.rarity == filter then table.insert(rows, row) end
            end
        end
    end
    filters = { "Todos" }
    local extras = {}
    for rarity in pairs(raritySet) do table.insert(extras, rarity) end
    table.sort(extras)
    for _, rarity in ipairs(extras) do table.insert(filters, rarity) end
    if not table.find(filters, filter) then
        filter = "Todos"
        filterButton.Text = "Raridade · Todas"
        refresh()
        return
    end
    filterIndex = table.find(filters, filter)
    local lines = {
        string.format("MAPA  %d  |  BASE / LOJA  %d  |  PENDENTES  %d", eligible, excluded, uncertain),
        string.format("Objetos carregados: %d  |  Interações: %d", #descendants, promptCount),
        "A busca é automática. Os caminhos abaixo mostram como cada objeto foi classificado.",
    }
    for _, kind in ipairs({ "Ovos do mapa", "Base / loja", "Sem interação confirmada" }) do
        local group = samples[kind]
        if group then
            table.insert(lines, "")
            table.insert(lines, kind)
            for _, entry in ipairs(group) do table.insert(lines, entry) end
        end
    end
    local text = table.concat(lines, "\n")
    if not report:IsFocused() and report.Text ~= text then report.Text = text end
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    status.Text = #rows == 0 and "Nenhum ovo carregado neste filtro." or (#rows .. " ovos carregados neste filtro")
    if #rows > 100 then status.Text = #rows .. " ovos · exibindo os 100 mais próximos" end
    nearestRow = rows[1]
    nearest.Text = nearestRow and "Mais próximo" or "Nenhum alvo"
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
            item.TextXAlignment = Enum.TextXAlignment.Left
            make("UIPadding", item, { PaddingLeft = UDim.new(0, 10) })
            item.TextColor3 = rarityColors[row.rarity] or palette.text
            item.Activated:Connect(function() openRow(row) end)
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
    showView("map")
end

back.Activated:Connect(closeDetails)
mapTab.Activated:Connect(closeDetails)
diagnosticTab.Activated:Connect(function()
    selected, selectedData = nil, nil
    detail.Visible = false
    showView("diagnostic")
end)
local function moveToEgg(row, prompt)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not row or not row.object:IsDescendantOf(workspace)
        or not row.anchor:IsDescendantOf(workspace) or baseAncestor(row.object)
        or not row.prompt or not row.prompt:IsDescendantOf(workspace)
        or not collectionPrompt(row.prompt) or baseAncestor(row.prompt) then return end
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
        nearestRow = nil
        nearest.Text = "Nenhum alvo"
        report.Text = "Ligue o radar para iniciar o diagnóstico."
        status.Text = "Ative para buscar ovos no mapa."
    end
end)
filterButton.Activated:Connect(function()
    filterIndex = filterIndex % #filters + 1
    filter = filters[filterIndex]
    filterButton.Text = "Raridade · " .. (filter == "Todos" and "Todas" or filter)
    list.CanvasPosition = Vector2.zero
    if enabled then refresh() end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if gui.Parent and enabled then refresh() end
    end
end)

-- Funções do anexo para testes locais, isoladas da vida e dos ovos reais.
local teste = {}
local demoEgg, fleeToken
local demoFolder = make("Folder", workspace, { Name = "SimulacaoOvos" })
gui.Destroying:Connect(function()
    demoFolder:Destroy()
end)

local gameState = {
    unlockedAreas = {},      -- Áreas desbloqueadas
    playerHealth = 100,     -- Vida do jogador
    isFleeing = false,      -- Se o jogador está em modo de fuga
    fleeTimer = 0,          -- Temporizador de fuga (30 segundos)
    currentArea = nil,      -- Área atual
    eggSpawned = false,     -- Se o ovo já foi coletado
    bossMode = false,       -- Modo boss (não morre ao lutar)
    selectedEgg = nil,      -- Ovo selecionado para coleta
}

--[[
  Configurações do Mapa
]]

local CONFIG = {
    Areas = {
        [1] = { name = "Area_01", boss = "Boss_01", eggPosition = Vector3.new(100, 50, 200), maxDistance = 150, requiredStrength = 1, eggRarity = "Common", isUnlocked = false },
        [2] = { name = "Area_02", boss = "Boss_02", eggPosition = Vector3.new(250, 50, 400), maxDistance = 300, requiredStrength = 2, eggRarity = "Uncommon", isUnlocked = false },
        [3] = { name = "Area_03", boss = "Boss_03", eggPosition = Vector3.new(400, 50, 600), maxDistance = 450, requiredStrength = 3, eggRarity = "Rare", isUnlocked = false },
        [4] = { name = "Area_04", boss = "Boss_04", eggPosition = Vector3.new(550, 50, 800), maxDistance = 600, requiredStrength = 4, eggRarity = "Epic", isUnlocked = false },
        [5] = { name = "Area_05", boss = "Boss_05", eggPosition = Vector3.new(650, 50, 1000), maxDistance = 750, requiredStrength = 5, eggRarity = "Legendary", isUnlocked = false },
        [6] = { name = "Area_06", boss = "Boss_06", eggPosition = Vector3.new(750, 50, 1200), maxDistance = 850, requiredStrength = 6, eggRarity = "Legendary", isUnlocked = false },
        [7] = { name = "Area_07", boss = "Boss_07", eggPosition = Vector3.new(850, 50, 1400), maxDistance = 950, requiredStrength = 7, eggRarity = "Epic", isUnlocked = false },
        [8] = { name = "Area_08", boss = "Boss_08", eggPosition = Vector3.new(950, 50, 1600), maxDistance = 1050, requiredStrength = 8, eggRarity = "Rare", isUnlocked = false },
        [9] = { name = "Area_09", boss = "Boss_09", eggPosition = Vector3.new(1050, 50, 1800), maxDistance = 1150, requiredStrength = 9, eggRarity = "Common", isUnlocked = false },
        [10] = { name = "Area_10", boss = "Boss_10", eggPosition = Vector3.new(1100, 50, 2000), maxDistance = 1250, requiredStrength = 10, eggRarity = "Uncommon", isUnlocked = false },
        [11] = { name = "Area_11", boss = "Boss_11", eggPosition = Vector3.new(1150, 50, 2200), maxDistance = 1350, requiredStrength = 11, eggRarity = "Epic", isUnlocked = false }
    },
    EggData = {
        [1] = { rarity = "Common", position = Vector3.new(100, 50, 200) },
        [2] = { rarity = "Uncommon", position = Vector3.new(250, 50, 400) },
        [3] = { rarity = "Rare", position = Vector3.new(400, 50, 600) },
        [4] = { rarity = "Epic", position = Vector3.new(550, 50, 800) },
        [5] = { rarity = "Legendary", position = Vector3.new(650, 50, 1000) },
        [6] = { rarity = "Legendary", position = Vector3.new(750, 50, 1200) },
        [7] = { rarity = "Epic", position = Vector3.new(850, 50, 1400) },
        [8] = { rarity = "Rare", position = Vector3.new(950, 50, 1600) },
        [9] = { rarity = "Common", position = Vector3.new(1050, 50, 1800) },
        [10] = { rarity = "Uncommon", position = Vector3.new(1100, 50, 2000) },
        [11] = { rarity = "Epic", position = Vector3.new(1150, 50, 2200) }
    }
}

--[[
  Funções Principais - Acessíveis via executor Delta
]]

function teste.onGameStart()
    fleeToken = nil
    if demoEgg then
        demoEgg:Destroy()
        demoEgg = nil
    end
    gameState.playerHealth = 100
    gameState.eggSpawned = false
    gameState.currentArea = nil
    gameState.isFleeing = false
    gameState.fleeTimer = 0
    gameState.unlockedAreas = {}
    print("Simulação iniciada!")
    teste.syncUnlockedAreas()
end

function teste.syncUnlockedAreas()
    for areaId, area in pairs(CONFIG.Areas) do
        if area.requiredStrength <= gameState.playerHealth then
            gameState.unlockedAreas[areaId] = true
        end
    end
end

function teste.spawnEgg(areaId)
    local area = CONFIG.Areas[areaId]
    if not area then return end
    if demoEgg then demoEgg:Destroy() end
    local eggData = CONFIG.EggData[areaId]
    if not eggData then return end
    
    local egg = Instance.new("Part")
    egg.Name = "OvoDemo"
    egg.Anchored = true
    egg.CanCollide = false
    egg.Transparency = 0.5
    egg.BrickColor = BrickColor.new("Lime Green")
    egg.Position = area.eggPosition
    egg.Parent = demoFolder
    demoEgg = egg
    gameState.eggSpawned = true
    print("Ovo spawnado em " .. area.name .. " (Raridade: " .. eggData.rarity .. ")")
end

function teste.canEnterArea(areaId)
    local area = CONFIG.Areas[areaId]
    if not area then return false end
    if not gameState.unlockedAreas[areaId] then return false end
    if gameState.playerHealth < area.requiredStrength then return false end
    return true
end

function teste.bossAttack()
    local areaId = gameState.currentArea
    if not areaId then return end
    local area = CONFIG.Areas[areaId]
    local damage = math.random(10, 15)
    local minimum = gameState.bossMode and 1 or 0
    gameState.playerHealth = math.max(minimum, gameState.playerHealth - damage)
    print("Ataque simulado de " .. area.boss .. ". Vida: " .. gameState.playerHealth)
    if gameState.playerHealth == 0 then teste.die() end
    return gameState.playerHealth
end

function teste.floatAway()
    if not gameState.currentArea then return false end
    return teste.startFleeing(gameState.currentArea)
end

function teste.startFleeing(areaId)
    if not teste.canEnterArea(areaId) then return false end
    gameState.isFleeing = true
    gameState.fleeTimer = 30
    gameState.currentArea = areaId
    local token = {}
    fleeToken = token
    task.spawn(function()
        for remaining = 29, 0, -1 do
            task.wait(1)
            if fleeToken ~= token or not demoFolder.Parent then return end
            gameState.fleeTimer = remaining
        end
        gameState.isFleeing = false
    end)
    return true
end

function teste.returnToBase()
    fleeToken = nil
    gameState.isFleeing = false
    gameState.fleeTimer = 0
    gameState.currentArea = nil
    gameState.eggSpawned = false
    if demoEgg then
        demoEgg:Destroy()
        demoEgg = nil
    end
end

function teste.collectEgg(areaId)
    local area = CONFIG.Areas[areaId]
    if not area or not teste.canEnterArea(areaId) or gameState.eggSpawned then return false end
    
    teste.spawnEgg(areaId)
    gameState.eggSpawned = true
    
    -- O jogador flutua para longe do bosse após coletar
    teste.startFleeing(areaId)
    
    -- Atualiza o estado
    gameState.currentArea = areaId
    print("Ovo simulado coletado em " .. area.name)
    return true
end

function teste.die()
    gameState.playerHealth = 0
    gameState.currentArea = nil
    gameState.isFleeing = false
    
    -- Retorna ao base
    teste.returnToBase()
end

function teste.toggleBossMode()
    gameState.bossMode = not gameState.bossMode
    print("Boss Mode simulado: " .. tostring(gameState.bossMode))
    return gameState.bossMode
end

function teste.onAllAreasUnlocked()
    print("Todas as áreas desbloqueadas!")
end

--[[
  Eventos de entrada do jogador
]]

function teste.onEnterArea(areaId)
    if gameState.currentArea == areaId then return end
    if teste.canEnterArea(areaId) then
        teste.startFleeing(areaId)
    end
end

--[[
  Eventos de saída (morte)
]]

function teste.onDeath()
    teste.die()
end

--[[
  Eventos de coleta de ovos
]]

function teste.onEggCollected(areaId)
    return teste.collectEgg(areaId)
end


teste.gameStart = teste.onGameStart
teste.onFleeing = teste.startFleeing
teste.onReturnToBase = teste.returnToBase
function teste.status()
    return table.clone(gameState)
end
return teste
