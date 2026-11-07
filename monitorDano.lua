local jogador = game:GetService("Players").LocalPlayer
local personagem = jogador.Character or jogador.CharacterAdded:Wait()
local humanoid = personagem:WaitForChild("Humanoid")

local vidaAnterior = humanoid.Health
local golpes = 0
local danoTotal = 0

local conexao = humanoid.HealthChanged:Connect(function(vida)
    if vida < vidaAnterior then
        local dano = vidaAnterior - vida
        golpes = golpes + 1
        danoTotal = danoTotal + dano
        warn(string.format("[Boss] Perdeu %.1f de vida. Vida atual: %.1f", dano, vida))
    end
    vidaAnterior = vida
end)

print("[Boss] Monitor ativo por 40 segundos.")

task.delay(40, function()
    conexao:Disconnect()
    print(string.format("[Boss] Resultado: %d quedas de vida, %.1f de dano total.",
        golpes, danoTotal))
end)
