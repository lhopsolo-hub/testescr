end

back.Activated:Connect(closeDetails)
local function moveToEgg(row, prompt)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not row or not row.object:IsDescendantOf(workspace) then return end
    local anchor = row.anchor
    local position = anchor.Position
    if prompt then
        local parent = prompt.Parent
        local target = promptTarget(prompt)
        if parent and parent:IsA("Attachment") then
            position = parent.WorldPosition
        elseif target and target:IsA("BasePart") then
            position = target.Position
        elseif target and target:IsA("Model") then
            position = target:GetPivot().Position
        end
    end
    local offset = prompt and Vector3.new(0, 1.5, 2) or Vector3.new(0, anchor.Size.Y / 2 + 4, 0)
    character:PivotTo(CFrame.new(position + offset) * character:GetPivot().Rotation)
    return character, position
end

teleport.Activated:Connect(function()
    if running then return end
    teleport.Text = moveToEgg(selectedData) and "Movimento solicitado" or "Ovo ou personagem indisponível"
end)

collect.Activated:Connect(function()
    local row = selectedData
    local prompt = row and row.prompt
    if running or not prompt or not prompt:IsDescendantOf(workspace) or not collectionPrompt(prompt) then return end

    running = true
    runId = runId + 1
    local currentRun = runId
    collect.Text = "Coleta em andamento"
    progress.Visible = true
    progress.Text = "Indo até o ovo..."
    local holding, triggeredConnection
    local ok, result = pcall(function()
        local character, position = moveToEgg(row, prompt)
        if not character then return "Personagem ou ovo indisponível." end
        task.wait(0.25)
        if currentRun ~= runId or not gui.Parent then return "" end

        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 or not prompt:IsDescendantOf(workspace)
            or not prompt.Enabled or (root.Position - position).Magnitude > prompt.MaxActivationDistance then
            return "A interação ficou fora de alcance ou indisponível."
        end

        local activated = false
        triggeredConnection = prompt.Triggered:Connect(function(who)
            if who == player or who == nil then activated = true end
        end)
        local duration = math.max(1, prompt.HoldDuration)
        progress.Text = "Segurando a interação..."
        prompt:InputHoldBegin()
        holding = true
        local deadline = os.clock() + duration + 0.15
        repeat
            task.wait(0.05)
        until activated or os.clock() >= deadline or currentRun ~= runId or not gui.Parent
            or not prompt.Parent or humanoid.Health <= 0
        prompt:InputHoldEnd()
        holding = false
        triggeredConnection:Disconnect()
        triggeredConnection = nil
        if currentRun ~= runId or not gui.Parent then return "" end
        if not activated then return "O jogo não sinalizou a interação de coleta." end

        local escapeEnd = os.clock() + 30
        while os.clock() < escapeEnd do
            if currentRun ~= runId or not gui.Parent then return "" end
            if player.Character ~= character or humanoid.Health <= 0 then
                return "Fuga interrompida: personagem derrotado."
            end
            progress.Text = string.format("Fuja do boss  ·  %ds  ·  Vida %.0f",
                math.ceil(escapeEnd - os.clock()), humanoid.Health)
            task.wait(0.2)
        end
        return "30 s concluídos. Confira o ovo no jogo."
    end)
    if triggeredConnection then triggeredConnection:Disconnect() end
    if holding then pcall(function() prompt:InputHoldEnd() end) end
    running = false
    if currentRun ~= runId or not gui.Parent then return end
    if not ok then warn(result) end
    progress.Text = ok and result or "Falha ao interagir. Veja o console."
    collect.Text = "Ir e coletar"
    task.delay(5, function()
        if gui.Parent and currentRun == runId then progress.Visible = false end
    end)
end)
toggle.Activated:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "Rastreador ligado" or "Rastreador desligado"
    toggle.BackgroundColor3 = enabled and palette.accent or palette.card
    if enabled then
        refresh()
    else
        runId = runId + 1
        progress.Visible = false
        closeDetails()
        clearList()
        marks:ClearAllChildren()
        activeMarks = {}
        status.Text = "Ative para buscar ovos no mapa."
    end
end)
filterButton.Activated:Connect(function()
    filterIndex = filterIndex % #filters + 1
    filter = filters[filterIndex]
    filterButton.Text = "Filtro · " .. filter
    list.CanvasPosition = Vector2.zero
    if enabled then refresh() end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(2)
        if gui.Parent and enabled then refresh() end
    end
end)
