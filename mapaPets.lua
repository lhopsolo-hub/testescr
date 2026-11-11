local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local existing = playerGui:FindFirstChild("MapaPets")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MapaPets"
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

local report
local parts, nextPart = nil, 1
button("Capturar menu Pets", 0, .55, function(item)
    local lines = { "[PETS] INVENTÁRIO" }
    for _, list in ipairs(playerGui:GetDescendants()) do
        if list:IsA("ScrollingFrame") and visible(list) then
            lines[#lines + 1] = "LISTA | " .. list:GetFullName()
            local shown = 0
            for _, card in ipairs(list:GetChildren()) do
                if shown >= 12 then break end
                if card:IsA("GuiObject") and visible(card) then
                    local fields = {}
                    local nodes = card:GetDescendants()
                    table.insert(nodes, 1, card)
                    for _, node in ipairs(nodes) do
                        if #fields >= 12 then break end
                        if visible(node) then
                            for _, key in ipairs({ "PetId", "PetName", "Variant", "Tier", "Quantity", "Count", "Evolution" }) do
                                local value = node:GetAttribute(key)
                                if value ~= nil then fields[#fields + 1] = key .. "=" .. tostring(value) end
                            end
                            if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text ~= "" then
                                fields[#fields + 1] = node.Name .. "=" .. node.Text:gsub("%s+", " "):sub(1, 100)
                            elseif (node:IsA("ImageLabel") or node:IsA("ImageButton")) and node.Image ~= "" then
                                fields[#fields + 1] = node.Name .. "=" .. node.Image
                            end
                        end
                    end
                    if #fields > 0 then
                        shown = shown + 1
                        lines[#lines + 1] = "CARD " .. shown .. " | " .. card.Name .. " | " .. table.concat(fields, " | ")
                    end
                end
            end
        end
    end
    report = table.concat(lines, "\n") .. "\n[PETS] FIM\n"
    parts, nextPart = nil, 1
    item.Text = #lines > 1 and "Capturado ✓" or "Sem lista visível"
end)

button("Copiar parte", .55, .37, function(item)
    if not report then
        item.Text = "Capture Pets primeiro"
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
    local header = string.format("[PETS] PARTE %d/%d\n", nextPart, #parts)
    local ok, result = pcall(copy, header .. parts[nextPart])
    if not ok or result == false then
        item.Text = "Falhou · tente de novo"
        return
    end
    item.Text = string.format("Copiada %d/%d", nextPart, #parts)
    nextPart = nextPart % #parts + 1
end)
button("×", .92, .08, function() gui:Destroy() end)
