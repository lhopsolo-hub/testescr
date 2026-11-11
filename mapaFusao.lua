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
local function capture(index, name, item)
    local lines = { string.format("[FUSÃO] +%.2fs | %s", os.clock() - started, name) }
    local seen = {}
    local function record(object)
        if #lines >= 140 or seen[object] or not visible(object) then return end
        seen[object] = true
        lines[#lines + 1] = describe(object)
    end

    for _, object in ipairs(playerGui:GetDescendants()) do
        if #lines >= 140 then break end
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            local value = object.Text:lower()
            local count = value:match("^%s*%d+%s*[x×]%s*$")
                or value:match("^%s*x%s*%d+%s*$") or value:match("%d+%s*/%s*%d+")
            if (count or value:find("clon", 1, true) or value:find("fus", 1, true)
                or value:find("invent", 1, true) or value:find("confirm", 1, true)
                or value:find("sucesso", 1, true)) and visible(object) then
                record(object)
                local card = object:IsA("GuiButton") and object
                    or object:FindFirstAncestorWhichIsA("GuiButton") or object.Parent
                if card then
                    record(card)
                    local children = card:GetChildren()
                    for i = 1, math.min(#children, 10) do
                        local child = children[i]
                        if child:IsA("GuiButton") or child:IsA("ImageLabel") or child:IsA("TextLabel") then
                            record(child)
                        end
                    end
                end
            end
        end
    end

    captures[index] = table.concat(lines, "\n")
    item.Text = name .. " ✓"
end

button("1 Aberta", 0, .23, function(item) capture(1, "Aberta", item) end)
button("2 Selecionado", .23, .23, function(item) capture(2, "Selecionado", item) end)
button("3 Resultado", .46, .23, function(item) capture(3, "Resultado", item) end)
button("Copiar", .69, .23, function(item)
    if not (captures[1] and captures[2] and captures[3]) then
        item.Text = "Capture 1–3"
        return
    end
    local text = table.concat(captures, "\n\n") .. "\n[FUSÃO] FIM"
    local copy = setclipboard or toclipboard
    local copied = type(copy) == "function" and pcall(copy, text)
    local saved = type(writefile) == "function" and pcall(writefile, "mapa_fusao.txt", text)
    item.Text = copied and "Copiado ✓" or (saved and "TXT salvo ✓" or "Falha ao exportar")
end)
button("×", .92, .08, function() gui:Destroy() end)
