local DURACAO = 40
local jogador = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local playerGui = assert(jogador:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local anterior = playerGui:FindFirstChild("MonitorDanoBoss")
if anterior then anterior:Destroy() end

local function criar(classe, pai, propriedades)
    local objeto = Instance.new(classe)
    for nome, valor in pairs(propriedades) do objeto[nome] = valor end
    objeto.Parent = pai
    return objeto
end

local gui = criar("ScreenGui", playerGui, {
    Name = "MonitorDanoBoss", ResetOnSpawn = false, DisplayOrder = 35,
})
local painel = criar("Frame", gui, {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -90),
    Size = UDim2.new(0.45, 0, 0, 120), BackgroundColor3 = Color3.fromRGB(20, 28, 42),
    BorderSizePixel = 0,
})
criar("UISizeConstraint", painel, { MaxSize = Vector2.new(272, 120) })
criar("UICorner", painel, { CornerRadius = UDim.new(0, 10) })

local function texto(classe, valor, topo, altura)
    return criar(classe, painel, {
        Position = UDim2.fromOffset(8, topo), Size = UDim2.new(1, -16, 0, altura),
        Text = valor, TextSize = 13, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(242, 247, 255), BackgroundTransparency = 1,
        TextWrapped = true,
    })
end

local titulo = texto("TextLabel", "MONITOR DE DANO", 4, 19)
local estado = texto("TextLabel", "Aguardando personagem", 24, 23)
local leitura = texto("TextLabel", "", 48, 29)
local reiniciar = texto("TextButton", "Reiniciar teste", 81, 31)
reiniciar.BackgroundColor3 = Color3.fromRGB(47, 96, 175)
reiniciar.BackgroundTransparency = 0
reiniciar.BorderSizePixel = 0
criar("UICorner", reiniciar, { CornerRadius = UDim.new(0, 6) })

local sessao
local function atualizar(atual)
    leitura.Text = string.format("Vida %.0f  ·  %d quedas\nDano total %.1f",
        atual.vida, atual.quedas, atual.dano)
end

local function encerrar(atual, mensagem)
    if sessao ~= atual then return end
    sessao = nil
    atual.conexao:Disconnect()
    estado.Text = mensagem
    estado.TextColor3 = Color3.fromRGB(255, 199, 111)
    atualizar(atual)
    print(string.format("[Boss] %s | %d quedas de vida | %.1f de dano total",
        mensagem, atual.quedas, atual.dano))
end

local function iniciar()
    if sessao then encerrar(sessao, "Teste reiniciado") end

    local personagem = jogador.Character
    local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        estado.Text = "Aguarde o personagem"
        leitura.Text = "Depois toque em Reiniciar teste."
        return
    end

    local atual = { vida = humanoid.Health, quedas = 0, dano = 0 }
    local fim = os.clock() + DURACAO
    sessao = atual
    estado.Text = "ATIVO · 40 s"
    estado.TextColor3 = Color3.fromRGB(117, 239, 173)
    atualizar(atual)
    atual.conexao = humanoid.HealthChanged:Connect(function(vida)
        if sessao ~= atual then return end
        if vida < atual.vida then
            local dano = atual.vida - vida
            atual.quedas = atual.quedas + 1
            atual.dano = atual.dano + dano
            warn(string.format("[Boss] Perdeu %.1f de vida. Vida atual %.1f.", dano, vida))
        end
        atual.vida = vida
        atualizar(atual)
        if vida <= 0 then encerrar(atual, "Personagem derrotado") end
    end)

    task.spawn(function()
        while gui.Parent and sessao == atual do
            if jogador.Character ~= personagem then
                encerrar(atual, "Personagem mudou")
                return
            end
            local restante = math.ceil(fim - os.clock())
            if restante <= 0 then
                encerrar(atual, "Teste concluído")
                return
            end
            estado.Text = string.format("ATIVO · %d s", restante)
            task.wait(0.2)
        end
    end)
end

reiniciar.Activated:Connect(iniciar)
gui.Destroying:Connect(function()
    if sessao then
        sessao.conexao:Disconnect()
        sessao = nil
    end
end)
iniciar()
