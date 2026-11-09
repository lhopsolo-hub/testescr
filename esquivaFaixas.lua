local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("MapaTreinoBase")
if previous then previous:Destroy() end

local function make(class, parent, props)
    local object = Instance.new(class)
    for name, value in pairs(props) do object[name] = value end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", playerGui, { Name = "MapaTreinoBase", ResetOnSpawn = false, DisplayOrder = 1001 })
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 74), Size = UDim2.new(.75, 0, 0, 158),
    BackgroundColor3 = Color3.fromRGB(20, 26, 38),
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(380, 158) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 10) })
local button = make("TextButton", panel, {
    Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 36),
    Text = "Medir 20 s de treino", Font = Enum.Font.GothamBold, TextSize = 14,
    BackgroundColor3 = Color3.fromRGB(53, 73, 137), TextColor3 = Color3.new(1, 1, 1),
})
local output = make("TextBox", panel, {
    Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 100),
    Text = "Comece a treinar no jogo e toque em Medir.", TextEditable = false,
    ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
    Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(12, 17, 26),
})

local running = false
local function measure()
    local stats, connections = {}, {}
    local started = os.clock()

    local function add(key, initial, signal, read)
        local first = tonumber(initial)
        if not first then return end
        local row = { first = first, last = first, gains = 0, intervals = {} }
        stats[key] = row
        table.insert(connections, signal:Connect(function()
            local value = tonumber(read())
            if not value or value == row.last then return end
            if value > row.last then
                local now = os.clock()
                if row.lastGain then
                    table.insert(row.intervals, now - row.lastGain)
                end
                row.gains, row.lastGain = row.gains + 1, now
            end
            row.last = value
        end))
    end

    local function attributes(instance, prefix)
        if not instance then return end
        for name, value in pairs(instance:GetAttributes()) do
            add(prefix .. name, value, instance:GetAttributeChangedSignal(name), function()
                return instance:GetAttribute(name)
            end)
        end
    end

    attributes(player, "Jogador.")
    attributes(player.Character, "Personagem.")
    local leaderstats = player:FindFirstChild("leaderstats")
    for _, object in ipairs(leaderstats and leaderstats:GetChildren() or {}) do
        if object:IsA("IntValue") or object:IsA("NumberValue") or object:IsA("StringValue") then
            add("Placar." .. object.Name, object.Value, object:GetPropertyChangedSignal("Value"), function()
                return object.Value
            end)
        end
    end

    while gui.Parent and os.clock() - started < 20 do
        button.Text = string.format("Medindo · %.0f s restantes", math.max(0, 20 - (os.clock() - started)))
        task.wait(.25)
    end
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if not gui.Parent then return end

    local elapsed = os.clock() - started
    local lines = {}
    for key, row in pairs(stats) do
        if row.gains > 0 or row.last ~= row.first then
            table.sort(row.intervals)
            local cadence = row.intervals[math.ceil(#row.intervals / 2)]
            local net = row.last - row.first
            table.insert(lines, string.format("%s | %+.5g/s | %+.5g em %.1fs | %d aumentos | intervalo %s",
                key, net / elapsed, net, elapsed, row.gains,
                cadence and string.format("%.3fs", cadence) or "-"))
        end
    end
    table.sort(lines)
    for _, line in ipairs(lines) do print("[Mapa Treino] " .. line) end
    output.Text = #lines == 0 and "Nenhuma mudança numérica detectada nesta medição."
        or table.concat(lines, "\n", 1, math.min(#lines, 4))
    if #lines > 4 then output.Text = output.Text .. "\nRelatório completo no console." end
end

button.Activated:Connect(function()
    if running then return end
    running = true
    local ok, problem = pcall(measure)
    running = false
    if not gui.Parent then return end
    button.Text = "Medir outros 20 s"
    if not ok then
        warn("[Mapa Treino] " .. tostring(problem))
        output.Text = "Falha na medição. Veja o console."
    end
end)
