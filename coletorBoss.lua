-- Diagnóstico local dos ataques. Execute no cliente com o personagem carregado.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local old = playerGui:FindFirstChild("ColetorBoss")
if old then old:Destroy() end

local function make(class, parent, props)
    local item = Instance.new(class)
    for key, value in pairs(props) do item[key] = value end
    item.Parent = parent
    return item
end

local gui = make("ScreenGui", playerGui, { Name = "ColetorBoss", ResetOnSpawn = false, DisplayOrder = 45 })
local panel = make("Frame", gui, {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -75),
    Size = UDim2.new(0.86, 0, 0, 120), BackgroundColor3 = Color3.fromRGB(19, 27, 42),
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(370, 120) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 10) })

local function control(class, text, position, size)
    return make(class, panel, {
        Text = text, Position = position, Size = size, TextSize = 14, TextWrapped = true,
        TextColor3 = Color3.fromRGB(240, 246, 255), Font = Enum.Font.GothamBold,
        BackgroundColor3 = Color3.fromRGB(44, 72, 109), BorderSizePixel = 0,
        BackgroundTransparency = class == "TextLabel" and 1 or 0,
    })
end

control("TextLabel", "COLETOR DE ATAQUES", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22))
local status = control("TextLabel", "Pronto para gravar", UDim2.fromOffset(8, 30), UDim2.new(1, -16, 0, 37))
local record = control("TextButton", "Gravar", UDim2.fromOffset(6, 78), UDim2.new(0.33, -8, 0, 34))
local mark = control("TextButton", "Marcar aviso", UDim2.new(0.33, 4, 0, 78), UDim2.new(0.34, -8, 0, 34))
local export = control("TextButton", "Exportar", UDim2.new(0.67, 4, 0, 78), UDim2.new(0.33, -10, 0, 34))

local overlay = make("Frame", gui, {
    Visible = false, Position = UDim2.new(0.05, 0, 0.06, 0), Size = UDim2.new(0.9, 0, 0.78, 0),
    BackgroundColor3 = Color3.fromRGB(19, 27, 42),
})
local close = make("TextButton", overlay, {
    Text = "Fechar relatório", TextSize = 16, Size = UDim2.new(1, 0, 0, 34),
})
local scroll = make("ScrollingFrame", overlay, {
    Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
})
local output = make("TextBox", scroll, {
    Text = "", MultiLine = true, ClearTextOnFocus = false, TextEditable = false,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Code, TextSize = 14, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(245, 245, 245),
})
close.Activated:Connect(function() overlay.Visible = false end)

local active, last
local function vector(v)
    return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end

local function add(session, kind, message)
    local rows = kind == "FX" and session.effects or session.markers
    local limit = kind == "FX" and 420 or 200
    if #rows >= limit then
        session.omitted = session.omitted + 1
        return
    end
    table.insert(rows, { time = os.clock() - session.start, kind = kind, message = message })
end

local function stop(session)
    if active ~= session then return end
    active, last = nil, session
    session.effectsConnection:Disconnect()
    session.hpConnection:Disconnect()
    record.Text = "Gravar"
    status.Text = "Gravação concluída · toque em Exportar"
end

local function start()
    local hp = player:GetAttribute("BossHP")
    local session = { start = os.clock(), effects = {}, markers = {}, omitted = 0, hits = 0 }
    active = session
    record.Text = "Parar"
    add(session, "INÍCIO", "BossHP=" .. tostring(hp))
    session.effectsConnection = workspace.DescendantAdded:Connect(function(part)
        local parent = part.Parent
        if not part:IsA("BasePart") or not parent or parent.Name ~= "BossFX" or parent.Parent ~= workspace then return end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local c = part.Color
        local message = string.format("%s | pos=%s | tam=%s | rot=%s | rgb=%d,%d,%d | tr=%.2f | jogador=%s",
            part.Name, vector(part.Position), vector(part.Size), vector(part.Orientation),
            math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255),
            part.Transparency, root and vector(root.Position) or "-")
        add(session, "FX", message)
    end)
    session.hpConnection = player:GetAttributeChangedSignal("BossHP"):Connect(function()
        local value = player:GetAttribute("BossHP")
        if type(value) == "number" and type(hp) == "number" and value < hp then
            session.hits = session.hits + 1
            add(session, "DANO", string.format("%.2f -> %.2f", hp, value))
        end
        hp = value
    end)
    task.spawn(function()
        while gui.Parent and active == session do
            local remaining = math.ceil(45 - (os.clock() - session.start))
            if remaining <= 0 then break end
            status.Text = string.format("GRAVANDO · %ds · %d efeitos · %d quedas", remaining, #session.effects, session.hits)
            task.wait(0.2)
        end
        if gui.Parent then stop(session) end
    end)
end

record.Activated:Connect(function()
    if active then stop(active) else start() end
end)
mark.Activated:Connect(function()
    if active then add(active, "MARCA", "Aviso vermelho visto pelo jogador") end
end)

export.Activated:Connect(function()
    local session = active or last
    if not session then status.Text = "Grave uma tentativa primeiro."; return end
    local rows = {}
    for _, group in ipairs({ session.effects, session.markers }) do
        for _, row in ipairs(group) do table.insert(rows, row) end
    end
    table.sort(rows, function(a, b) return a.time < b.time end)
    local lines = { "BOSSFX | " .. #session.effects .. " efeitos | " .. session.hits .. " quedas | " .. session.omitted .. " omitidos" }
    for _, row in ipairs(rows) do
        table.insert(lines, string.format("%.3fs | %s | %s", row.time, row.kind, row.message))
    end
    local text = table.concat(lines, "\n")
    output.Text = text
    overlay.Visible = true
    local copied = type(setclipboard) == "function" and pcall(setclipboard, text)
    if copied then
        close.Text = "Copiado · Fechar"
    elseif type(writefile) == "function" and pcall(writefile, "relatorioBoss.txt", text) then
        close.Text = "Salvo em relatorioBoss.txt · Fechar"
    else
        close.Text = "Relatório na tela · Fechar"
    end
end)

gui.Destroying:Connect(function()
    if active then
        active.effectsConnection:Disconnect()
        active.hpConnection:Disconnect()
        active = nil
    end
end)
