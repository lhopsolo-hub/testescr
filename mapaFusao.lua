local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("MapaFusao")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MapaFusao"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.Parent = playerGui

local function button(text, x, width, callback)
    local item = Instance.new("TextButton")
    item.Position = UDim2.new(x, 2, .05, 0)
    item.Size = UDim2.new(width, -4, 0, 38)
    item.Text = text
    item.TextWrapped = true
    item.BackgroundColor3 = Color3.fromRGB(24, 34, 45)
    item.TextColor3 = Color3.fromRGB(175, 255, 229)
    item.Parent = gui
    item.Activated:Connect(function() callback(item) end)
end

local function visible(object)
    while object and object ~= playerGui do
        if object == gui or (object:IsA("GuiObject") and not object.Visible)
            or (object:IsA("ScreenGui") and not object.Enabled) then
            return false
        end
        object = object.Parent
    end
    return object == playerGui
end

local function describe(object)
    local detail = object:GetFullName() .. " | " .. object.ClassName
    if object:IsA("TextLabel") or object:IsA("TextButton") then
        detail = detail .. " | texto=" .. object.Text:gsub("%s+", " "):sub(1, 180)
    end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        detail = detail .. " | imagem=" .. object.Image
    end
    if object:IsA("GuiButton") then
        detail = detail .. " | ativo=" .. tostring(object.Active)
            .. " | interagível=" .. tostring(object.Interactable)
    end
    return detail
end

local started = os.clock()
local captures = {}
local parts, nextPart = nil, 1
local function describeCard(card, index)
    local fields = { "CARD " .. index .. " | ordem=" .. card.LayoutOrder }
    for _, object in ipairs(card:GetDescendants()) do
        if visible(object) then
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                fields[#fields + 1] = object.Name .. "=" .. object.Text:gsub("%s+", " ")
            elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                fields[#fields + 1] = object.Name .. "=" .. object.Image
            end
        end
    end
    for _, key in ipairs({ "PetId", "Variant", "Tier", "Count", "Selected", "Evolution" }) do
        local value = card:GetAttribute(key)
        if value ~= nil then fields[#fields + 1] = key .. "=" .. tostring(value) end
    end
    return table.concat(fields, " | ")
end

local clicks = {}
local connections = {}
local function observeButton(object)
    if not object:IsA("GuiButton") then return end
    connections[#connections + 1] = object.Activated:Connect(function()
        if visible(object) and #clicks < 30 then
            local detail = describe(object)
            if object.Parent and object.Parent.Name == "ScrollingFrame" then
                detail = detail .. " | " .. describeCard(object, object.LayoutOrder)
            end
            clicks[#clicks + 1] = string.format("+%.2fs | %s", os.clock() - started, detail)
        end
    end)
end

gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)

local function capture(index, name, item)
    local fusion = playerGui:FindFirstChild("Fusion")
    local panel = fusion and fusion:FindFirstChild("Panel")
    local body = panel and panel:FindFirstChild("Body")
    local list = body and body:FindFirstChild("ScrollingFrame")
    if not panel or not visible(panel) then
        item.Text = "Abra a máquina"
        return
    end
    if index == 1 then
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
        table.clear(clicks)
        table.clear(captures)
        connections[#connections + 1] = fusion.DescendantAdded:Connect(observeButton)
        for _, object in ipairs(fusion:GetDescendants()) do observeButton(object) end
    end

    local lines = { string.format("[FUSÃO] +%.2fs | %s", os.clock() - started, name) }
    local cardIndex = 0
    for _, card in ipairs(list and list:GetChildren() or {}) do
        if card:IsA("GuiButton") and visible(card) then
            cardIndex = cardIndex + 1
            lines[#lines + 1] = describeCard(card, cardIndex)
        end
    end
    for _, object in ipairs(panel:GetDescendants()) do
        if visible(object) and not (list and object:IsDescendantOf(list))
            and (object:IsA("GuiButton") or object:IsA("TextLabel") or object:IsA("ImageLabel")) then
            lines[#lines + 1] = describe(object):sub(#playerGui:GetFullName() + 2)
        end
    end
    if index == 3 then
        lines[#lines + 1] = "[AÇÕES NA MÁQUINA]"
        for _, click in ipairs(clicks) do lines[#lines + 1] = click end
    end

    captures[index] = table.concat(lines, "\n")
    parts, nextPart = nil, 1
    item.Text = name .. " ✓"
end

button("1 Aberta", 0, .23, function(item) capture(1, "Aberta", item) end)
button("2 Selecionado", .23, .23, function(item) capture(2, "Selecionado", item) end)
button("3 Resultado", .46, .23, function(item) capture(3, "Resultado", item) end)
button("Copiar parte", .69, .23, function(item)
    if not (captures[1] and captures[2] and captures[3]) then
        item.Text = "Capture 1–3"
        return
    end
    local copy = type(setclipboard) == "function" and setclipboard or toclipboard
    if type(copy) ~= "function" then
        item.Text = "Cópia indisponível"
        return
    end
    if not parts then
        parts = {}
        local lines, size = {}, 0
        local report = table.concat(captures, "\n\n") .. "\n[FUSÃO] FIM\n"
        for line in report:gmatch("[^\n]*\n") do
            if size + #line > 1400 and size > 0 then
                parts[#parts + 1] = table.concat(lines)
                lines, size = {}, 0
            end
            lines[#lines + 1] = line
            size = size + #line
        end
        if size > 0 then parts[#parts + 1] = table.concat(lines) end
    end
    local header = string.format("[FUSÃO] PARTE %d/%d\n", nextPart, #parts)
    local ok, result = pcall(copy, header .. parts[nextPart])
    if not ok or result == false then
        item.Text = "Falhou · tente de novo"
        return
    end
    item.Text = string.format("Copiada %d/%d", nextPart, #parts)
    nextPart = nextPart % #parts + 1
end)
button("×", .92, .08, function() gui:Destroy() end)
