print("[Auto Chocar V5] Iniciando")
local player = assert(game:GetService("Players").LocalPlayer, "[Auto Chocar V5] Execute no cliente do jogo")
local runService = game:GetService("RunService")

local function ownPen()
    local map = workspace:FindFirstChild("Map")
    local base = map and map:FindFirstChild("Base")
    local plots = base and base:FindFirstChild("Plots")
    for _, plot in ipairs(plots and plots:GetChildren() or {}) do
        if tonumber(plot:GetAttribute("OwnerId")) == player.UserId then
            return plot:FindFirstChild("PenEggs")
        end
    end
end

local function penTimes()
    local raw = player:GetAttribute("PenEggTimes")
    if type(raw) ~= "string" then return end
    local ok, times = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not ok or type(times) ~= "table" then return end
    local counts = {}
    for _, timestamp in ipairs(times) do
        if type(timestamp) == "number" then counts[timestamp] = (counts[timestamp] or 0) + 1 end
    end
    return counts
end

local function promptPosition(prompt)
    local host = prompt.Parent
    if host:IsA("Attachment") then return host.WorldPosition end
    if host:IsA("BasePart") then return host.Position end
    if host:IsA("Model") then return host:GetPivot().Position end
end

local playerGui = assert(player:WaitForChild("PlayerGui", 8), "[Auto Chocar V5] PlayerGui indisponível")
local previous = playerGui:FindFirstChild("TesteChocarOvos")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TesteChocarOvos"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(1, 0)
button.Size = UDim2.new(.48, 0, 0, 60)
button.Position = UDim2.new(1, -12, 0, 16)
button.BackgroundColor3 = Color3.fromRGB(28, 38, 54)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextSize = 14
local size = Instance.new("UISizeConstraint")
size.MaxSize = Vector2.new(300, 60)
size.Parent = button
button.Text = "Auto Chocar V5 ligado · toque para pausar"
button.TextWrapped = true
button.Parent = gui
gui.Parent = playerGui
print("[Auto Chocar V5] Painel criado")

local enabled, lastInput = true, nil
local BUTTON_INTERVAL = .08

local function nearestPrompt(pen, root)
    local nearest, bestDistance
    for _, prompt in ipairs(pen:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Name == "HatchPrompt" and prompt.Enabled then
            local point = promptPosition(prompt)
            local distance = point and (point - root.Position).Magnitude
            if distance and distance <= prompt.MaxActivationDistance
                and (not bestDistance or distance < bestDistance) then
                nearest, bestDistance = prompt, distance
            end
        end
    end
    return nearest
end

local function hatchFace()
    local hatch = playerGui:FindFirstChild("HatchButton")
    local face = hatch and hatch:FindFirstChild("Face", true)
    if not face or not face:IsA("GuiButton") then return end
    local node = face
    while node and node ~= playerGui do
        if node:IsA("GuiObject") and not node.Visible then return end
        if node:IsA("ScreenGui") and not node.Enabled then return end
        node = node.Parent
    end
    return node == playerGui and face or nil
end

local function hatchBatch(root, character, pen)
    local function active()
        local carrying = player:GetAttribute("Carrying")
        return gui.Parent and enabled and root.Parent == character and player.Character == character
            and ownPen() == pen and carrying ~= true and (tonumber(carrying) or 0) == 0
    end

    local count, started = 0, os.clock()
    while active() do
        local prompt = nearestPrompt(pen, root)
        if not prompt then break end

        local before = tonumber(player:GetAttribute("PenEggs"))
        local original = penTimes()
        if not before and not original then return count, "Contador indisponível" end
        local confirmed = false
        local function check()
            local current = tonumber(player:GetAttribute("PenEggs"))
            if before and current then
                confirmed = confirmed or current < before
            end
            if not confirmed and original then
                local times = penTimes()
                for timestamp, amount in pairs(original) do
                    if times and (times[timestamp] or 0) < amount then
                        confirmed = true
                        break
                    end
                end
            end
        end

        local countChanged = player:GetAttributeChangedSignal("PenEggs"):Connect(check)
        local timesChanged = player:GetAttributeChangedSignal("PenEggTimes"):Connect(check)
        local function waitConfirmation(timeout)
            local deadline = os.clock() + timeout
            while active() and not confirmed and os.clock() < deadline do
                runService.Heartbeat:Wait()
            end
        end

        local sentAt = os.clock()
        if pcall(function() prompt:InputHoldBegin() end) then
            local releaseAt = sentAt + math.max(.05, prompt.HoldDuration)
            while active() and prompt.Parent and not confirmed and os.clock() < releaseAt do
                runService.Heartbeat:Wait()
            end
            pcall(function() prompt:InputHoldEnd() end)
            waitConfirmation(1.5)
        end

        countChanged:Disconnect()
        timesChanged:Disconnect()
        if not confirmed then
            return count, active() and "Sem confirmação · prompt" or nil
        end
        count = count + 1
        print(string.format("[Auto Chocar V5] Ovo %d · prompt · %.0f ms",
            count, (os.clock() - sentAt) * 1000))
    end
    return count, nil, os.clock() - started
end

local function rapidHatch(root, character, pen)
    local function active()
        local carrying = player:GetAttribute("Carrying")
        return gui.Parent and enabled and root.Parent == character and player.Character == character
            and ownPen() == pen and carrying ~= true and (tonumber(carrying) or 0) == 0
    end

    local started, total, attempts = os.clock(), 0, 0
    while active() and hatchFace() do
        local before = tonumber(player:GetAttribute("PenEggs"))
        local original = penTimes()
        local deadline = os.clock() + .8
        while active() and os.clock() < deadline do
            local face = hatchFace()
            if not face then break end
            if not pcall(firesignal, face.Activated, lastInput, 1) then break end
            attempts = attempts + 1
            task.wait(BUTTON_INTERVAL)
        end
        local current = tonumber(player:GetAttribute("PenEggs"))
        local removed = before and current and math.max(0, before - current) or 0
        local times = original and penTimes()
        if times then
            local missing = 0
            for timestamp, amount in pairs(original) do
                missing = missing + math.max(0, amount - (times[timestamp] or 0))
            end
            removed = math.max(removed, missing)
        end
        total = total + removed
        if removed == 0 then break end
    end
    if attempts > 0 then
        print(string.format("[Auto Chocar V5] Botão · %d tentativas · %d eclosões observadas · %.2f s",
            attempts, total, os.clock() - started))
    end
    return total
end

local function runHatch(root, character, pen)
    local started, rapidCount = os.clock(), 0
    if type(firesignal) == "function" then
        rapidCount = rapidHatch(root, character, pen)
    end
    local promptCount, problem = hatchBatch(root, character, pen)
    return rapidCount + promptCount, problem, os.clock() - started
end

button.Activated:Connect(function(input)
    lastInput = input
    enabled = not enabled
    button.Text = enabled and "Auto Chocar V5 ligado · toque para pausar"
        or "Pausado · toque para retomar"
end)

task.spawn(function()
    local total = 0
    while gui.Parent do
        local interval = .2
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local pen = enabled and root and ownPen()
        if pen then
            local ok, count, problem, elapsed = pcall(runHatch, root, character, pen)
            if not gui.Parent then break end
            if not ok then
                warn("[Auto Chocar V5] " .. tostring(count))
                count, problem = 0, "Falha · confira o console"
            end
            total = total + count
            if count > 0 then
                print(string.format("[Auto Chocar] %d ovo(s) em %.2f s", count, elapsed or 0))
            end
            if enabled then
                button.Text = string.format("Auto Chocar V5 · %d chocado(s)\n%s", total,
                    problem or "Aguardando ovos prontos ao alcance")
            end
            if problem then interval = .35 end
        elseif enabled then
            button.Text = root and "Auto Chocar V5 · aguardando cercado"
                or "Auto Chocar V5 · aguardando personagem"
        end
        task.wait(interval)
    end
end)
