local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("IdentificarOvosArea7")
if previous then previous:Destroy() end

local function make(class, parent, props)
    local item = Instance.new(class)
    for key, value in pairs(props) do item[key] = value end
    item.Parent = parent
    return item
end

local gui = make("ScreenGui", playerGui, { Name = "IdentificarOvosArea7", ResetOnSpawn = false, DisplayOrder = 70 })
local panel = make("Frame", gui, {
    Position = UDim2.new(0, 10, 1, -120), Size = UDim2.fromOffset(260, 42),
    BackgroundColor3 = Color3.fromRGB(28, 18, 37),
})
local function button(parent, text, position, size)
    return make("TextButton", parent, {
        Text = text, Position = position, Size = size, TextSize = 14,
        TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(88, 49, 132),
    })
end
local capture = button(panel, "Inspecionar ovos próximos", UDim2.new(), UDim2.fromScale(1, 1))
local overlay = make("Frame", gui, {
    Visible = false, Position = UDim2.fromScale(.05, .1), Size = UDim2.fromScale(.9, .7),
    BackgroundColor3 = Color3.fromRGB(28, 18, 37),
})
local close = button(overlay, "Fechar", UDim2.new(), UDim2.new(.5, 0, 0, 34))
local copy = button(overlay, "Selecionar texto", UDim2.fromScale(.5, 0), UDim2.new(.5, 0, 0, 34))
local scroll = make("ScrollingFrame", overlay, {
    Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
})
local output = make("TextBox", scroll, {
    Text = "", MultiLine = true, TextWrapped = true, ClearTextOnFocus = false,
    AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -12, 0, 0),
    BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextSize = 13,
    Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
})
close.Activated:Connect(function() overlay.Visible = false end)
copy.Activated:Connect(function()
    output:CaptureFocus()
    output.CursorPosition = #output.Text + 1
    output.SelectionStart = 1
end)

local function positionOf(item)
    if item:IsA("Attachment") then return item.WorldPosition end
    if item:IsA("BasePart") then return item.Position end
    if item:IsA("Model") then return item:GetPivot().Position end
end

local function describe(item)
    local attrs = {}
    for key, value in pairs(item:GetAttributes()) do
        local name = key:lower()
        if name:find("zone", 1, true) or name:find("area", 1, true)
            or name:find("egg", 1, true) or name:find("rarity", 1, true) then
            table.insert(attrs, key .. "=" .. tostring(value))
        end
    end
    table.sort(attrs)
    return item.Name .. "[" .. item.ClassName .. "]" .. (#attrs > 0 and "{" .. table.concat(attrs, ",") .. "}" or "")
end

capture.Activated:Connect(function()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local origin = root.Position
    local eggs = workspace:FindFirstChild("Eggs")
    local lines = {
        "OVOS DA ÁREA 7 · DIAGNÓSTICO V1",
        string.format("JOGADOR | %.1f, %.1f, %.1f | Carrying=%s", origin.X, origin.Y, origin.Z,
            tostring(player:GetAttribute("Carrying"))),
        eggs and ("WORKSPACE.EGGS | filhos diretos=" .. #eggs:GetChildren()) or "WORKSPACE.EGGS | ausente",
    }
    local candidates, totalNear = {}, 0
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Parent then
            local host, point = item.Parent, nil
            local node = host
            while node and node ~= workspace and not point do
                point = positionOf(node)
                node = node.Parent
            end
            local distance = point and (point - origin).Magnitude
            if distance and distance <= 180 then
                totalNear = totalNear + 1
                local label = (item.ObjectText .. " " .. item.ActionText):lower()
                local isEgg = label:find("ovo", 1, true) or label:find("egg", 1, true)
                    or (eggs and item:IsDescendantOf(eggs))
                table.insert(candidates, { item = item, point = point, distance = distance, isEgg = not not isEgg })
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.isEgg ~= b.isEgg then return a.isEgg end
        return a.distance < b.distance
    end)
    table.insert(lines, string.format("INTERAÇÕES | próximas=%d | exibidas=%d", totalNear, math.min(12, #candidates)))
    for i = 1, math.min(12, #candidates) do
        local row = candidates[i]
        local item, point = row.item, row.point
        local ancestors = {}
        local node = item
        for _ = 1, 7 do
            if not node or node == workspace then break end
            table.insert(ancestors, describe(node))
            node = node.Parent
        end
        table.insert(lines, string.format("%s | %.1f studs | %s / %s | ativo=%s | alcance=%.1f | pos=%.1f,%.1f,%.1f",
            row.isEgg and "OVO" or "OUTRA", row.distance, item.ActionText, item.ObjectText, tostring(item.Enabled),
            item.MaxActivationDistance, point.X, point.Y, point.Z))
        table.insert(lines, "  " .. item:GetFullName())
        table.insert(lines, "  " .. table.concat(ancestors, " <- "))
    end
    if eggs then
        local counts, nearby = {}, {}
        for _, egg in ipairs(eggs:GetChildren()) do
            local zone = tostring(egg:GetAttribute("Zone") or "ausente")
            counts[zone] = (counts[zone] or 0) + 1
            local point = positionOf(egg)
            local distance = point and (point - origin).Magnitude
            if distance and distance <= 180 then
                table.insert(nearby, { egg = egg, distance = distance })
            end
        end
        local summary = {}
        for zone, count in pairs(counts) do table.insert(summary, zone .. "=" .. count) end
        table.sort(summary)
        table.insert(lines, "ZONAS DOS FILHOS DIRETOS | " .. table.concat(summary, ", "))
        table.sort(nearby, function(a, b) return a.distance < b.distance end)
        for i = 1, math.min(6, #nearby) do
            local row = nearby[i]
            local prompt = row.egg:FindFirstChildWhichIsA("ProximityPrompt", true)
            table.insert(lines, string.format("FILHO DIRETO | %.1f studs | %s | prompt=%s",
                row.distance, describe(row.egg), prompt and (prompt.Enabled and "ativo" or "inativo") or "ausente"))
        end
    end
    table.insert(lines, "=== FIM ===")
    output.Text = table.concat(lines, "\n")
    scroll.CanvasPosition = Vector2.zero
    overlay.Visible = true
end)
