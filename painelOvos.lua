-- Painel local. No Studio, coloque em um LocalScript em StarterPlayerScripts.
local player = game:GetService("Players").LocalPlayer
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
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0.78, 0),
    BackgroundColor3 = palette.bg,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(480, 460) })
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

local toggle = button(panel, "Rastreador desligado", UDim2.fromOffset(10, 9), UDim2.new(1, -20, 0, 36))
local filterButton = button(panel, "Filtro · Todos", UDim2.fromOffset(10, 51), UDim2.new(1, -20, 0, 34))
local status = label(panel, "Ative para buscar ovos no mapa.", UDim2.fromOffset(10, 89), UDim2.new(1, -20, 0, 25))
local list = scroll(panel, UDim2.fromOffset(10, 118), UDim2.new(1, -20, 1, -128))
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local detail = make("Frame", panel, {
    Visible = false, Position = UDim2.fromOffset(8, 49), Size = UDim2.new(1, -16, 1, -56),
    BackgroundColor3 = palette.bg, BorderSizePixel = 0,
})
local back = button(detail, "Voltar à lista", UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 34))
local detailScroll = scroll(detail, UDim2.fromOffset(4, 42), UDim2.new(1, -8, 1, -88))
local info = label(detailScroll, "", UDim2.new(), UDim2.new(1, -8, 0, 0))
info.AutomaticSize = Enum.AutomaticSize.Y
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
local teleport = button(detail, "Teleportar até o ovo", UDim2.new(0, 2, 1, -39), UDim2.new(1, -4, 0, 36))

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
local filters = { "Todos", "Comum", "Incomum", "Raro", "Épico", "Lendário", "Mítico", missing }
local filterIndex = 1
local activeMarks = {}

local function eggCandidate(object)
    if not (object:IsA("Model") or object:IsA("BasePart")) then return false end
    if tags:HasTag(object, "Egg") or object:GetAttribute("IsEgg") == true then return true end
    local name = object.Name:gsub("(%l)(%u)", "%1 %2"):lower()
    return name:match("%f[%a]egg%f[%A]") ~= nil or name:match("%f[%a]ovo%f[%A]") ~= nil
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
    if value == nil then value, source = metadata(object, "raridade") end
    if value == nil then value, source = metadata(object, "tier") end
    if value == nil then return missing, "—" end
    local raw = tostring(value)
    return rarityNames[raw:lower()] or raw, source
end

local function clearList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function details(row)
    local object = row.object
    local pos = row.anchor.Position
    local reportedStatus = metadata(object, "status")
    local lines = {
        object.Name, "Raridade: " .. row.rarity, "Fonte da raridade: " .. row.source,
        "Status: " .. tostring(reportedStatus == nil and "visível no mapa local" or reportedStatus),
        "Distância: " .. (row.distance < math.huge and string.format("%.0f studs", row.distance) or "—"),
        string.format("Posição: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z),
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
    local raritySet = {}
    for _, object in ipairs(workspace:GetDescendants()) do
        if eggCandidate(object) then
            local anchor = anchorOf(object)
            local ancestor = object.Parent
            while ancestor and ancestor ~= workspace and not eggCandidate(ancestor) do
                ancestor = ancestor.Parent
            end
            if anchor and ancestor == workspace then
                local rarity, source = getRarity(object)
                raritySet[rarity] = true
                if filter == "Todos" or rarity == filter then
                    table.insert(rows, {
                        object = object, anchor = anchor, rarity = rarity, source = source,
                        distance = root and (root.Position - anchor.Position).Magnitude or math.huge,
                    })
                end
            end
        end
    end
    filters = { "Todos", "Comum", "Incomum", "Raro", "Épico", "Lendário", "Mítico", missing }
    local extras = {}
    for rarity in pairs(raritySet) do
        if not table.find(filters, rarity) then table.insert(extras, rarity) end
    end
    table.sort(extras)
    for _, rarity in ipairs(extras) do table.insert(filters, rarity) end
    if not table.find(filters, filter) then table.insert(filters, filter) end
    filterIndex = table.find(filters, filter)
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    status.Text = #rows == 0 and "Nenhum ovo encontrado neste filtro." or (#rows .. " ovos no filtro")
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
        info.Text = "O ovo selecionado saiu do mapa local ou do filtro."
    end
end

local function closeDetails()
    selected = nil
    detail.Visible = false
    list.Visible, status.Visible, filterButton.Visible = true, true, true
end

back.Activated:Connect(closeDetails)
teleport.Activated:Connect(function()
    local character = player.Character
    local anchor = selected and selected:IsDescendantOf(workspace) and anchorOf(selected)
    if not anchor or not character or not character:FindFirstChild("HumanoidRootPart") then
        teleport.Text = "Ovo ou personagem indisponível"
        return
    end
    local target = anchor.Position + Vector3.new(0, anchor.Size.Y / 2 + 4, 0)
    character:PivotTo(CFrame.new(target) * character:GetPivot().Rotation)
    teleport.Text = "Movimento solicitado"
end)
toggle.Activated:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "Rastreador ligado" or "Rastreador desligado"
    toggle.BackgroundColor3 = enabled and palette.accent or palette.card
    if enabled then
        refresh()
    else
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
