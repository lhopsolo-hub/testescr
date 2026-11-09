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

local function eggNameKey(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("^%s*🥚%s*", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
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

local function findEgg(character)
    for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and (eggNameKey(tool:GetAttribute("EggName")) ~= ""
                or eggNameKey(tool.Name):match("^ovo ")) then
                return tool
            end
        end
    end
end

local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("TesteDepositoOvos")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TesteDepositoOvos"
gui.ResetOnSpawn = false
local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(300, 55)
button.Position = UDim2.fromScale(.05, .65)
button.Text = "Auto Colocar ligado · toque para pausar"
button.TextWrapped = true
button.Parent = gui
gui.Parent = playerGui

local enabled = true
local function deposit()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local pen = ownPen()
    if not humanoid or not pen then return "Personagem ou cercado indisponível" end

    local function active()
        local carrying = player:GetAttribute("Carrying")
        return gui.Parent and enabled and player.Character == character
            and humanoid.Health > 0 and ownPen() == pen and carrying ~= true
            and (tonumber(carrying) or 0) == 0
    end

    local count, start = 0, os.clock()
    while active() do
        local tool = findEgg(character)
        if not tool then break end
        local before = tonumber(player:GetAttribute("PenEggs"))
        if not before then return "Contador do cercado indisponível" end

        if tool.Parent ~= character then
            humanoid:EquipTool(tool)
            local deadline = os.clock() + 1
            while active() and tool.Parent ~= character and os.clock() < deadline do
                runService.Heartbeat:Wait()
            end
        end
        if not active() then break end
        if tool.Parent ~= character then return "O jogo não equipou o ovo" end

        local original = penTimes()
        local sentAt = os.clock()
        local confirmed = false
        local function check()
            if (tonumber(player:GetAttribute("PenEggs")) or before) > before then
                confirmed = true
            elseif original then
                for timestamp, amount in pairs(penTimes() or {}) do
                    if amount > (original[timestamp] or 0) then
                        confirmed = true
                        break
                    end
                end
            end
        end

        local eggCount = player:GetAttributeChangedSignal("PenEggs"):Connect(check)
        local eggTimes = player:GetAttributeChangedSignal("PenEggTimes"):Connect(check)
        local sent, err = pcall(function() tool:Activate() end)
        while sent and not confirmed and active() and os.clock() - sentAt < 2 do
            runService.Heartbeat:Wait()
        end
        eggCount:Disconnect()
        eggTimes:Disconnect()

        if not sent then error(err) end
        if not confirmed then
            if active() then return string.format("%d colocado(s) · ativação sem confirmação", count) end
            break
        end
        count = count + 1
        print(string.format("[Teste Depósito] Ovo %d confirmado em %.0f ms", count, (os.clock() - sentAt) * 1000))
    end
    return string.format("%d colocado(s) em %.2f s", count, os.clock() - start)
end

button.Activated:Connect(function()
    enabled = not enabled
    button.Text = enabled and "Auto Colocar ligado · toque para pausar"
        or "Pausado · toque para retomar"
end)

task.spawn(function()
    while gui.Parent do
        local interval = .2
        local character = player.Character
        local carrying = player:GetAttribute("Carrying")
        if enabled and character and carrying ~= true and (tonumber(carrying) or 0) == 0
            and ownPen() and findEgg(character) then
            button.Text = "Depositando · toque para pausar"
            local ok, result = pcall(deposit)
            if not gui.Parent then break end
            if not ok then warn("[Teste Depósito] " .. tostring(result)) end
            if enabled then
                button.Text = (ok and result or "Falha · confira o console") .. "\nAuto ligado · toque para pausar"
            end
            -- Limita novas tentativas fora do cercado ou após uma recusa.
            interval = 1
        end
        task.wait(interval)
    end
end)
