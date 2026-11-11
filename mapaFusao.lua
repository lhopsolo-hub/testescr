local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local anterior = playerGui:FindFirstChild("MapaFusao")
if anterior then anterior:Destroy() end

local function criar(classe, pai, propriedades)
    local objeto = Instance.new(classe)
    for chave, valor in pairs(propriedades) do
        objeto[chave] = valor
    end
    objeto.Parent = pai
    return objeto
end

local gui = criar("ScreenGui", playerGui, {
    Name = "MapaFusao",
    ResetOnSpawn = false,
    DisplayOrder = 90,
})

local painel = criar("Frame", gui, {
    Position = UDim2.fromScale(0.04, 0.12),
    Size = UDim2.new(0.92, 0, 0, 48),
    BackgroundColor3 = Color3.fromRGB(28, 22, 40),
})
criar("UISizeConstraint", painel, {MaxSize = Vector2.new(480, 48)})

local function botao(texto, coluna)
    return criar("TextButton", painel, {
        Position = UDim2.new(coluna / 4, 3, 0, 5),
        Size = UDim2.new(0.25, -6, 0, 38),
        Text = texto,
        TextWrapped = true,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(245, 241, 250),
        BackgroundColor3 = Color3.fromRGB(68, 46, 94),
    })
end

local gravar = botao("Iniciar", 0)
local registrarTela = botao("Registrar tela", 1)
local ver = botao("Ver relatório", 2)
local copiar = botao("Copiar", 3)

local relatorio = criar("TextBox", painel, {
    Position = UDim2.fromOffset(0, 52),
    Size = UDim2.new(1, 0, 0, 280),
    Text = "",
    Visible = false,
    MultiLine = true,
    ClearTextOnFocus = false,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Code,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(245, 241, 250),
    BackgroundColor3 = Color3.fromRGB(34, 29, 47),
})

local inicio
local registros = 0
local linhas = {}

local function visivel(objeto)
    while objeto and objeto ~= playerGui do
        if objeto:IsA("GuiObject") and not objeto.Visible then return false end
        if objeto:IsA("ScreenGui") and not objeto.Enabled then return false end
        objeto = objeto.Parent
    end
    return objeto == playerGui
end

local function atualizarRelatorio()
    relatorio.Text = table.concat(linhas, "\n")
end

gravar.Activated:Connect(function()
    if inicio then
        linhas[#linhas + 1] = "=== FIM DO RELATÓRIO ==="
        inicio = nil
        gravar.Text = "Iniciar"
        atualizarRelatorio()
        relatorio.Visible = true
        return
    end

    inicio = os.clock()
    registros = 0
    linhas = {"MAPA DA MÁQUINA DE FUSÃO"}
    gravar.Text = "Encerrar"
    registrarTela.Text = "Registrar tela"
    copiar.Text = "Copiar"
    relatorio.Visible = false
end)

registrarTela.Activated:Connect(function()
    if not inicio then return end

    registros = registros + 1
    linhas[#linhas + 1] = string.format(
        "\n%.3fs | TELA %d", os.clock() - inicio, registros
    )

    local fusao = playerGui:FindFirstChild("Fusion")
    local janela = fusao and fusao:FindFirstChild("Panel")
    if janela and visivel(janela) then
        for _, objeto in ipairs(janela:GetDescendants()) do
            if (objeto:IsA("TextLabel") or objeto:IsA("TextButton"))
                and objeto.Text:match("%S") and visivel(objeto) then
                local caminho = objeto:GetFullName():match("Fusion%.(.+)$")
                linhas[#linhas + 1] = (caminho or objeto.Name) .. " | " .. objeto.Text
            end
        end
    else
        linhas[#linhas + 1] = "Máquina de Fusão fechada"
    end

    registrarTela.Text = "Telas: " .. registros
    if relatorio.Visible then atualizarRelatorio() end
end)

ver.Activated:Connect(function()
    relatorio.Visible = not relatorio.Visible
    if relatorio.Visible then atualizarRelatorio() end
end)

copiar.Activated:Connect(function()
    if #linhas == 0 then return end
    atualizarRelatorio()
    relatorio.Visible = true
    relatorio:CaptureFocus()
    relatorio.CursorPosition = #relatorio.Text + 1
    relatorio.SelectionStart = 1
    copiar.Text = "⌘ + C"
end)
