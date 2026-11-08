-- Diagnóstico local dos ataques. Execute no cliente com o personagem carregado.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local old = playerGui:FindFirstChild("MecanicaBoss")
if old then old:Destroy() end

local function make(class, parent, props)
    local item = Instance.new(class)
    for key, value in pairs(props) do item[key] = value end
    item.Parent = parent
    return item
end

local gui = make("ScreenGui", playerGui, { Name = "MecanicaBoss", ResetOnSpawn = false, DisplayOrder = 45 })
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

control("TextLabel", "MECÂNICA DO BOSS", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22))
local status = control("TextLabel", "Pronto para gravar", UDim2.fromOffset(8, 30), UDim2.new(1, -16, 0, 37))
local record = control("TextButton", "Gravar", UDim2.fromOffset(6, 78), UDim2.new(0.33, -8, 0, 34))
local mark = control("TextButton", "Marcar aviso", UDim2.new(0.33, 4, 0, 78), UDim2.new(0.34, -8, 0, 34))
local export = control("TextButton", "Exportar", UDim2.new(0.67, 4, 0, 78), UDim2.new(0.33, -10, 0, 34))

local overlay = make("Frame", gui, {
    Visible = false, Position = UDim2.new(0.05, 0, 0.06, 0), Size = UDim2.new(0.9, 0, 0.78, 0),
    BackgroundColor3 = Color3.fromRGB(19, 27, 42),
})
local nextPage = make("TextButton", overlay, {
    Text = "Copiar parte", TextSize = 14, Position = UDim2.new(0.52, 0, 0, 0),
    Size = UDim2.new(0.48, 0, 0, 34),
})
local close = make("TextButton", overlay, {
    Text = "Fechar relatório", TextSize = 14, Size = UDim2.new(0.52, 0, 0, 34),
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
local pages, pageIndex = {}, 0

local function position()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end
local function vector(v)
    return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end

local function add(session, kind, message)
    local isEffect = kind == "FX" or kind == "FIM FX"
    local rows = isEffect and session.effects or session.markers
    local limit = isEffect and 350 or 200
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
    session.removedConnection:Disconnect()
    record.Text = "Gravar"
    status.Text = "Gravação concluída · toque em Exportar"
end

local function start()
    local hp = player:GetAttribute("BossHP")
    local session = { start = os.clock(), effects = {}, markers = {}, omitted = 0, hits = 0, patterns = {}, ignored = 0, group = 0 }
    active = session
    record.Text = "Parar"
    add(session, "INÍCIO", "BossHP=" .. tostring(hp) .. " | jogador=" .. (position() and vector(position()) or "-"))
    session.effectsConnection = workspace.DescendantAdded:Connect(function(part)
        local parent = part.Parent
        if not part:IsA("BasePart") or not parent or parent.Name ~= "BossFX" or parent.Parent ~= workspace then return end
        local c, size = part.Color, part.Size
        local red = c.R > 0.65 and c.R > c.G * 1.6 and c.R > c.B * 1.6
        local flat = size.Y <= 1 and math.max(size.X, size.Z) >= 3
        if not red and not flat then
            session.ignored = session.ignored + 1
            return
        end
        local now = os.clock()
        if not session.lastFx or now - session.lastFx > 0.09 then
            session.group = session.group + 1
            session.groupStart = now
        end
        session.lastFx = now
        local pos = position()
        local inside = false
        if pos then
            local localPos = part.CFrame:PointToObjectSpace(Vector3.new(pos.X, part.Position.Y, pos.Z))
            inside = math.abs(localPos.X) <= size.X / 2 and math.abs(localPos.Z) <= size.Z / 2
        end
        session.patterns[part] = { group = session.group, start = now }
        add(session, "FX", string.format(
            "#%d %s pos=%s tam=%s rot=%s rgb=%d,%d,%d tr=%.2f dentroXZ=%s jogador=%s",
            session.group, part.Name, vector(part.Position), vector(size), vector(part.Orientation),
            math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255),
            part.Transparency, tostring(inside), pos and vector(pos) or "-"))
    end)
    session.removedConnection = workspace.DescendantRemoving:Connect(function(part)
        local info = session.patterns[part]
        if not info then return end
        session.patterns[part] = nil
        add(session, "FIM FX", string.format("#%d durou %.3fs", info.group, os.clock() - info.start))
    end)
    session.hpConnection = player:GetAttributeChangedSignal("BossHP"):Connect(function()
        local value = player:GetAttribute("BossHP")
        if type(value) == "number" and type(hp) == "number" and value < hp then
            session.hits = session.hits + 1
            local pos = position()
            local delta = session.groupStart and string.format("%.3fs", os.clock() - session.groupStart) or "-"
            add(session, "DANO", string.format("%.2f -> %.2f | último grupo #%d há %s | jogador=%s",
                hp, value, session.group, delta, pos and vector(pos) or "-"))
        end
        hp = value
    end)
    task.spawn(function()
        while gui.Parent and active == session do
            local remaining = math.ceil(60 - (os.clock() - session.start))
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

local function showPage()
    local text = pages[pageIndex]
    output.Text = text
    scroll.CanvasPosition = Vector2.zero
    overlay.Visible = true
    local copied = type(setclipboard) == "function" and pcall(setclipboard, text)
    close.Text = string.format("%s %d/%d · Fechar", copied and "Copiada" or "Parte", pageIndex, #pages)
    nextPage.Text = pageIndex == #pages and "Copiar parte 1" or "Copiar próxima"
end

nextPage.Activated:Connect(function()
    if #pages == 0 then return end
    pageIndex = pageIndex % #pages + 1
    showPage()
end)

export.Activated:Connect(function()
    local session = active or last
    if not session then status.Text = "Grave uma tentativa primeiro."; return end
    local rows = {}
    for _, group in ipairs({ session.effects, session.markers }) do
        for _, row in ipairs(group) do table.insert(rows, row) end
    end
    table.sort(rows, function(a, b) return a.time < b.time end)
    local header = string.format("BOSS | %d grupos | %d quedas | %d FX ignorados | %d omitidos",
        session.group, session.hits, session.ignored, session.omitted)
    local chunk, bytes = {}, 0
    pages = {}
    for _, row in ipairs(rows) do
        local line = string.format("%.3fs | %s | %s", row.time, row.kind, row.message)
        if bytes + #line + 1 > 6500 and #chunk > 0 then
            table.insert(pages, table.concat(chunk, "\n"))
            chunk, bytes = {}, 0
        end
        table.insert(chunk, line)
        bytes = bytes + #line + 1
    end
    if #chunk > 0 then table.insert(pages, table.concat(chunk, "\n")) end
    if #pages == 0 then table.insert(pages, "Sem eventos") end
    for i, body in ipairs(pages) do
        pages[i] = string.format("%s | Parte %d/%d\n%s", header, i, #pages, body)
    end
    if type(writefile) == "function" then
        pcall(writefile, "mecanicaBoss.txt", table.concat(pages, "\n\n"))
    end
    pageIndex = 1
    showPage()
end)

gui.Destroying:Connect(function()
    if active then
        active.effectsConnection:Disconnect()
        active.hpConnection:Disconnect()
        active.removedConnection:Disconnect()
        active = nil
    end
end)
