local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("ListaOvosPantano")
if previous then previous:Destroy() end

local function make(className, parent, properties)
    local object = Instance.new(className)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", playerGui, {
    Name = "ListaOvosPantano", ResetOnSpawn = false, DisplayOrder = 95,
})
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 46), Size = UDim2.new(.65, 0, .62, 0),
    BackgroundColor3 = Color3.fromRGB(21, 28, 27), BorderSizePixel = 0,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(430, 385) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 8) })

local function label(parent, text, position, size)
    return make("TextLabel", parent, {
        Text = text, Position = position, Size = size, BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(239, 250, 245),
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    })
end

local title = label(panel, "OVOS DO PÂNTANO · ID 10", UDim2.fromOffset(10, 3), UDim2.new(1, -54, 0, 28))
title.Font = Enum.Font.GothamBold
local close = make("TextButton", panel, {
    Position = UDim2.new(1, -36, 0, 3), Size = UDim2.fromOffset(28, 28),
    Text = "×", TextSize = 19, TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(65, 78, 72),
})
close.Activated:Connect(function() gui:Destroy() end)
local status = label(panel, "Procurando ovos…", UDim2.fromOffset(10, 34), UDim2.new(1, -20, 0, 32))
local scroll = make("ScrollingFrame", panel, {
    Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 1, -79),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
})
local rowsLabel = label(scroll, "", UDim2.new(), UDim2.new(1, -8, 0, 0))
rowsLabel.AutomaticSize = Enum.AutomaticSize.Y
rowsLabel.TextYAlignment = Enum.TextYAlignment.Top

local rarities = { [1] = "Comum", [2] = "Raro", [3] = "Épico", [4] = "Lendário" }
local function update()
    local folder = workspace:FindFirstChild("Eggs")
    if not folder then
        status.Text = "Workspace.Eggs ainda não apareceu"
        rowsLabel.Text = "Vá até o Pântano e aguarde a lista atualizar."
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local rows, active = {}, 0
    for _, egg in ipairs(folder:GetChildren()) do
        if tonumber(egg:GetAttribute("Zone")) == 10 then
            local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
            local point = egg:IsA("BasePart") and egg.Position
                or (egg:IsA("Model") and egg:GetPivot().Position)
            local distance = point and root and (point - root.Position).Magnitude or math.huge
            local name = prompt and prompt.ObjectText ~= "" and prompt.ObjectText or "Ovo do Pântano"
            local rarity = rarities[tonumber(egg:GetAttribute("EggRarity") or egg:GetAttribute("Rarity"))]
            if rarity and not name:find("(", 1, true) then name = name .. " (" .. rarity .. ")" end
            if prompt and prompt.Enabled then active = active + 1 end
            local state = not prompt and "sem interação" or (prompt.Enabled and "ativo" or "inativo")
            local range = distance < math.huge and string.format("%.1f studs", distance) or "distância indisponível"
            table.insert(rows, { distance = distance, text = name .. "  ·  " .. range .. "  ·  " .. state })
        end
    end
    table.sort(rows, function(a, b) return a.distance < b.distance end)
    status.Text = string.format("%d carregados · %d ativos", #rows, active)
    local lines = {}
    for i, row in ipairs(rows) do lines[i] = row.text end
    local text = #lines > 0 and table.concat(lines, "\n\n") or "Nenhum ovo do ID 10 carregado neste ponto."
    if rowsLabel.Text ~= text then rowsLabel.Text = text end
end

task.spawn(function()
    while gui.Parent do
        update()
        task.wait(1)
    end
end)
