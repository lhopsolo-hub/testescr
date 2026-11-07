-- Diagnóstico local de vida e HUD. Não altera dados do jogo.
local Players = game:GetService("Players")
local player = assert(Players.LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local old = playerGui:FindFirstChild("MonitorDanoBoss")
if old then old:Destroy() end

local DURATION = 90
local LOG_LIMIT = 120
local function create(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end

local gui = create("ScreenGui", playerGui, {
    Name = "MonitorDanoBoss", ResetOnSpawn = false, DisplayOrder = 35,
})
local panel = create("Frame", gui, {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -70),
    Size = UDim2.new(0.85, 0, 0, 144), BackgroundColor3 = Color3.fromRGB(20, 28, 42),
})
create("UISizeConstraint", panel, { MaxSize = Vector2.new(320, 144) })
create("UICorner", panel, { CornerRadius = UDim.new(0, 10) })

local function control(class, text, x, y, width, height)
    local object = create(class, panel, {
        Position = UDim2.new(x, 5, 0, y), Size = UDim2.new(width, -10, 0, height),
        Text = text, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(240, 246, 255), BackgroundTransparency = 1,
    })
    if class == "TextButton" then
        object.BackgroundTransparency = 0
        object.BackgroundColor3 = Color3.fromRGB(43, 77, 124)
        create("UICorner", object, { CornerRadius = UDim.new(0, 6) })
    end
    return object
end

control("TextLabel", "DIAGNÓSTICO DO BOSS", 0, 4, 1, 19)
local state = control("TextLabel", "Pronto para gravar", 0, 25, 1, 22)
local summary = control("TextLabel", "Grave perto do boss e jogue normalmente.", 0, 50, 1, 42)
local record = control("TextButton", "Gravar", 0, 99, 0.33, 36)
local mark = control("TextButton", "Marcar golpe", 0.33, 99, 0.34, 36)
local report = control("TextButton", "Ver log", 0.67, 99, 0.33, 36)

local active
local last
local function related(name)
    local value = name:lower()
    return value:find("health", 1, true) or value:find("vida", 1, true)
        or value:find("heart", 1, true) or value:find("hitpoint", 1, true)
        or value:find("%f[%a]hp%f[%A]") or value:find("hpbar", 1, true)
        or value:find("currenthp", 1, true) or value:find("maxhp", 1, true)
end

local function add(session, message)
    if #session.log >= LOG_LIMIT then
        session.omitted = session.omitted + 1
        return
    end
    table.insert(session.log, string.format("%.1fs | %s", os.clock() - session.start, message))
end

local function snapshot(session)
    local values = {}
    local function observe(path, value)
        if value ~= nil then values[path] = tostring(value) end
    end
    local function attributes(object, prefix)
        for key, value in pairs(object:GetAttributes()) do
            if type(value) == "number" or (related(key) and type(value) == "string" and #value <= 45) then
                observe(prefix .. " @" .. key, value)
            end
        end
    end
    attributes(player, "Player")
    local character = player.Character
    if character then
        attributes(character, "Character")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            observe("Humanoid.Health", humanoid.Health)
            attributes(humanoid, "Humanoid")
        end
    end

    for _, object in ipairs(player:GetDescendants()) do
        if object:IsA("NumberValue") or object:IsA("IntValue") then
            observe(object:GetFullName(), object.Value)
        end
    end
    if character then
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("NumberValue") or object:IsA("IntValue") then
                observe(object:GetFullName(), object.Value)
            end
        end
    end
    for _, object in ipairs(playerGui:GetDescendants()) do
        if not object:IsDescendantOf(gui) then
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                local value = object.Text
                if #value <= 45 and value:find("%d") then
                    local path = object:GetFullName()
                    if related(path) or related(value) or value:match("^%s*%d+%s*/%s*%d+%s*$") then
                        observe("HUD " .. path .. " .Text", value)
                    end
                end
            elseif object:IsA("GuiObject") then
                local parent = object.Parent
                if related(object.Name) or (parent and related(parent.Name)) then
                    observe("HUD " .. object:GetFullName() .. " .Size", object.Size)
                end
            end
        end
    end

    local changed = {}
    for key, value in pairs(values) do
        local before = session.previous[key]
        if before and before ~= value then
            table.insert(changed, { key = key, before = before, value = value })
        elseif not before and (key == "Humanoid.Health" or related(key)) then
            add(session, key .. " = " .. value)
        end
    end
    table.sort(changed, function(a, b)
        local importantA = related(a.key) ~= nil
        local importantB = related(b.key) ~= nil
        if importantA ~= importantB then return importantA end
        return a.key < b.key
    end)
    for _, change in ipairs(changed) do
        add(session, change.key .. " : " .. change.before .. " -> " .. change.value)
    end
    session.changes = session.changes + #changed
    session.previous = values
    summary.Text = string.format("Humanoid %s  ·  %d mudanças\nToque em Marcar golpe se a barra cair.",
        values["Humanoid.Health"] or "—", session.changes)
end

local function stop(session)
    if active ~= session then return end
    active = nil
    last = session
    record.Text = "Gravar"
    state.Text = "Gravação concluída"
    state.TextColor3 = Color3.fromRGB(255, 203, 125)
    summary.Text = string.format("%d mudanças registradas.\nAbra Ver log e veja o console.", session.changes)
end

record.Activated:Connect(function()
    if active then stop(active); return end
    local session = { start = os.clock(), log = {}, previous = {}, changes = 0, omitted = 0 }
    active = session
    record.Text = "Parar"
    state.TextColor3 = Color3.fromRGB(117, 239, 173)
    task.spawn(function()
        while gui.Parent and active == session do
            local remaining = math.ceil(DURATION - (os.clock() - session.start))
            if remaining <= 0 then break end
            state.Text = string.format("GRAVANDO · %d s", remaining)
            snapshot(session)
            task.wait(0.25)
        end
        if gui.Parent then stop(session) end
    end)
end)

mark.Activated:Connect(function()
    if active then add(active, "MARCA MANUAL: golpe percebido no jogo") end
end)

report.Activated:Connect(function()
    local session = active or last
    if not session then
        summary.Text = "Grave uma tentativa antes de abrir o log."
        return
    end
    print("[Boss] INÍCIO DO RELATÓRIO")
    for _, line in ipairs(session.log) do print("[Boss] " .. line) end
    if session.omitted > 0 then print("[Boss] Limite do log atingido. Eventos extras: " .. session.omitted) end
    print("[Boss] FIM DO RELATÓRIO")
    if not active then summary.Text = "Relatório enviado ao console do Delta." end
end)
