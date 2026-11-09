local player = game:GetService("Players").LocalPlayer
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

local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("TesteChocarOvos")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TesteChocarOvos"
gui.ResetOnSpawn = false
local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(300, 55)
button.Position = UDim2.fromScale(.05, .77)
button.Text = "Auto Chocar ligado · toque para pausar"
button.TextWrapped = true
button.Parent = gui
gui.Parent = playerGui

local enabled, lastInput = true, nil

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
        local face = type(firesignal) == "function" and hatchFace()
        if not prompt and not face then break end

        local before = tonumber(player:GetAttribute("PenEggs"))
        local original = penTimes()
        if not before and not original then return count, "Contador indisponível" end
        local confirmed = false
        local function check()
            local current = tonumber(player:GetAttribute("PenEggs"))
            if before and current then
                confirmed = confirmed or current < before
            elseif original then
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
        local function waitConfirmation()
            local deadline = os.clock() + 1.5
            while active() and not confirmed and os.clock() < deadline do
                runService.Heartbeat:Wait()
            end
        end

        if prompt and pcall(function() prompt:InputHoldBegin() end) then
            local releaseAt = os.clock() + prompt.HoldDuration
            repeat
                runService.Heartbeat:Wait()
            until not active() or not prompt.Parent or confirmed or os.clock() >= releaseAt
            pcall(function() prompt:InputHoldEnd() end)
            waitConfirmation()
        end
        if not confirmed and active() and face and hatchFace() == face
            and pcall(firesignal, face.Activated, lastInput, 1) then
            waitConfirmation()
        end

        countChanged:Disconnect()
        timesChanged:Disconnect()
        if not confirmed then
            return count, active() and "Eclosão sem confirmação" or nil
        end
        count = count + 1
    end
    return count, nil, os.clock() - started
end

button.Activated:Connect(function(input)
    lastInput = input
    enabled = not enabled
    button.Text = enabled and "Auto Chocar ligado · toque para pausar"
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
            local count, problem, elapsed = hatchBatch(root, character, pen)
            total = total + count
            if count > 0 then
                print(string.format("[Auto Chocar] %d ovo(s) em %.2f s", count, elapsed or 0))
            end
            if enabled then
                button.Text = string.format("Auto Chocar · %d chocado(s)\n%s", total,
                    problem or "Aguardando ovos prontos ao alcance")
            end
            if problem then interval = 1 end
        end
        task.wait(interval)
    end
end)
