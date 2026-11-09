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
    Position = UDim2.fromOffset(8, 8), Size = UDim2.new(.62, -12, 0, 36),
    Text = "Medir 20 s de treino", Font = Enum.Font.GothamBold, TextSize = 14,
    BackgroundColor3 = Color3.fromRGB(53, 73, 137), TextColor3 = Color3.new(1, 1, 1),
})
local copy = make("TextButton", panel, {
    Position = UDim2.new(.62, 0, 0, 8), Size = UDim2.new(.38, -8, 0, 36),
    Text = "Copiar logs", Font = Enum.Font.GothamBold, TextSize = 13,
    BackgroundColor3 = Color3.fromRGB(40, 89, 75), TextColor3 = Color3.new(1, 1, 1),
})
local output = make("TextBox", panel, {
    Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 100),
    Text = "Comece a treinar no jogo e toque em Medir.", TextEditable = false,
    ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
    Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(12, 17, 26),
})

local function trackMotion(character)
    local channels = {}
    local function channel(name, minimum, read)
        table.insert(channels, { name = name, minimum = minimum, read = read, values = {} })
    end
    local function angles(name, read)
        local row = {}
        for axis, suffix in ipairs({ "X", "Y", "Z" }) do
            row[axis] = { name = name .. "." .. suffix, minimum = .1, values = {} }
            table.insert(channels, row[axis])
        end
        -- Lê a rotação uma vez por junta a cada amostra.
        row[1].read = function(index)
            local x, y, z = read():ToOrientation()
            row[2].values[index], row[3].values[index] = y, z
            return x
        end
    end

    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        channel("Raiz.altura", .08, function() return root.Position.Y end)
        angles("Raiz.rotação", function() return root.CFrame end)
    end
    for _, joint in ipairs(character and character:GetDescendants() or {}) do
        if joint:IsA("Motor6D") then
            for _, property in ipairs({ "Transform", "C0", "C1" }) do
                angles(joint.Name .. "." .. property, function() return joint[property] end)
            end
        end
    end
    return channels
end

local function summarizeMotion(channels, timestamps)
    local ranked = {}
    for _, row in ipairs(channels) do
        local low, high = math.huge, -math.huge
        for _, value in ipairs(row.values) do
            low, high = math.min(low, value), math.max(high, value)
        end
        local span = high - low
        if span >= row.minimum then
            local peaks, armed = {}, false
            for index, value in ipairs(row.values) do
                local t = timestamps[index]
                if value <= low + .35 * span then armed = true end
                if armed and value >= low + .65 * span then
                    if #peaks == 0 or t - peaks[#peaks] >= .25 then table.insert(peaks, t) end
                    armed = false
                end
            end
            table.insert(ranked, { name = row.name, span = span, score = span / row.minimum, peaks = peaks })
        end
    end
    table.sort(ranked, function(a, b)
        if #a.peaks ~= #b.peaks then return #a.peaks > #b.peaks end
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    local lines = { string.format("%d canais | %d amostras | picos candidatos, não contagem confirmada de flexões",
        #channels, #timestamps) }
    for index = 1, math.min(#ranked, 4) do
        local row = ranked[index]
        local times = {}
        for _, t in ipairs(row.peaks) do table.insert(times, string.format("%.3f", t)) end
        local period = #row.peaks > 1 and (row.peaks[#row.peaks] - row.peaks[1]) / (#row.peaks - 1)
        table.insert(lines, string.format("%s | amplitude=%.3f | picos=%d | período médio=%s | t(s)=%s",
            row.name, row.span, #row.peaks, period and string.format("%.3fs", period) or "-",
            table.concat(times, ", ")))
    end
    if #ranked == 0 then table.insert(lines, "Nenhum movimento acima do limiar nas juntas ou na raiz.") end
    return table.concat(lines, "\n")
end

local running, report = false, nil
local function measure()
    local stats, connections = {}, {}
    local started = os.clock()
    local events, omitted = {}, 0
    local function record(message)
        if #events >= 75 then
            omitted = omitted + 1
            return
        end
        table.insert(events, string.format("%.3fs | %s", os.clock() - started, message))
    end

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
            if key == "Jogador.Strength" or key == "Jogador.PoseTime" then
                record(string.format("%s | %.6g → %.6g | Δ%+.6g", key, row.last, value, value - row.last))
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

    local tracks, seen = {}, {}
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        local function watch(track)
            if seen[track] then return end
            seen[track] = true
            local animation = track.Animation
            local id = animation and animation.AnimationId or track.Name
            local row = tracks[id] or { instances = 0, loops = 0, stops = 0 }
            tracks[id] = row
            row.instances = row.instances + 1
            record(string.format("ANIMAÇÃO | %s | speed=%.3f | duração=%.3fs | loop=%s",
                id, track.Speed, track.Length, tostring(track.Looped)))
            table.insert(connections, track.DidLoop:Connect(function()
                if not track.Looped then return end
                row.loops = row.loops + 1
                record(string.format("CICLO | %s | speed=%.3f", id, track.Speed))
            end))
            table.insert(connections, track.Stopped:Connect(function()
                row.stops = row.stops + 1
                record("PAROU | " .. id)
            end))
        end
        table.insert(connections, animator.AnimationPlayed:Connect(watch))
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do watch(track) end
    end

    local motion, timestamps = trackMotion(character), {}
    while gui.Parent and os.clock() - started < 20 do
        if player.Character ~= character then
            record("PERSONAGEM TROCOU | medição encerrada")
            break
        end
        local elapsed = os.clock() - started
        table.insert(timestamps, elapsed)
        local index = #timestamps
        for _, row in ipairs(motion) do
            if row.read then row.values[index] = row.read(index) end
        end
        button.Text = string.format("Medindo · %.0f s restantes", math.max(0, 20 - elapsed))
        task.wait(.05)
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
    local animations = {}
    for id, row in pairs(tracks) do
        table.insert(animations, string.format("%s | %d faixas | %d ciclos | %d paradas",
            id, row.instances, row.loops, row.stops))
    end
    table.sort(animations)
    if #animations == 0 then
        animations[1] = animator and "Nenhuma faixa de animação detectada." or "Animator indisponível."
    end
    if #lines == 0 then lines[1] = "Nenhuma mudança numérica detectada." end
    report = table.concat({
        string.format("MAPA DO TREINO V3 | %.2fs | eventos omitidos=%d", elapsed, omitted),
        "ATRIBUTOS", table.concat(lines, "\n"),
        "ANIMAÇÕES", table.concat(animations, "\n"),
        "MOVIMENTO", summarizeMotion(motion, timestamps),
        "LINHA DO TEMPO", table.concat(events, "\n"), "=== FIM ===",
    }, "\n")
    output.Text = table.concat(lines, "\n", 1, math.min(#lines, 3)) .. "\nToque em Copiar logs."
    print("[Mapa Treino] " .. report)
end

button.Activated:Connect(function()
    if running then return end
    running, report = true, nil
    copy.Text = "Copiar logs"
    local ok, problem = pcall(measure)
    running = false
    if not gui.Parent then return end
    button.Text = "Medir outros 20 s"
    if not ok then
        warn("[Mapa Treino] " .. tostring(problem))
        output.Text = "Falha na medição. Veja o console."
    end
end)

copy.Activated:Connect(function()
    if not report or running then return end
    if type(setclipboard) == "function" and pcall(setclipboard, report) then
        copy.Text = "Copiado"
    else
        output.Text = report
        copy.Text = "Selecione o texto"
    end
end)
