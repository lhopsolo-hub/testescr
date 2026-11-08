-- Captura local das interações do ciclo de ovos.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local prompts = game:GetService("ProximityPromptService")
local old = playerGui:FindFirstChild("MapaPrado")
if old then old:Destroy() end
local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {Name="MapaPrado", ResetOnSpawn=false, DisplayOrder=65})
local panel = make("Frame",gui,{Position=UDim2.fromOffset(12,180),Size=UDim2.new(0.88,0,0,108),
    BackgroundColor3=Color3.fromRGB(21,30,46)})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(400,108)})
make("UICorner",panel,{CornerRadius=UDim.new(0,9)})
local function text(class,value,x,y,width,height)
    return make(class,panel,{Text=value,Position=UDim2.new(x,5,0,y),Size=UDim2.new(width,-10,0,height),
        TextWrapped=true,TextSize=13,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),
        BackgroundColor3=Color3.fromRGB(47,79,125),BackgroundTransparency=class=="TextLabel" and 1 or 0})
end
local status=text("TextLabel","MAPA DO PRADO · pronto",0,5,1,37)
local record=text("TextButton","Gravar",0,59,0.31,38)
local mark=text("TextButton","Marcar etapa",0.31,59,0.38,38)
local export=text("TextButton","Exportar",0.69,59,0.31,38)

local report=make("Frame",gui,{Position=UDim2.fromScale(.05,.07),Size=UDim2.fromScale(.90,.79),
    Visible=false,BackgroundColor3=Color3.fromRGB(21,30,46)})
local close=make("TextButton",report,{Text="Fechar",Size=UDim2.new(.5,0,0,35)})
local copyAll=make("TextButton",report,{Text="Copiar tudo",Position=UDim2.new(.5,0,0,0),Size=UDim2.new(.5,0,0,35)})
local scroll=make("ScrollingFrame",report,{Position=UDim2.fromOffset(0,37),Size=UDim2.new(1,0,1,-37),
    CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
local output=make("TextBox",scroll,{Text="",TextEditable=false,ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Code,TextSize=13,
    Size=UDim2.new(1,-10,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
    TextColor3=Color3.new(1,1,1)})
close.Activated:Connect(function() report.Visible=false end)

local tracked, watched, active, last = {}, {}, nil, nil
local stages = {"Antes de lançar","Pousei no Prado"}
local probeActive = false
local probeTriggered = false
local keys = {Carrying=true,CarryEnd=true,PenEggs=true,PenEggTimes=true,Zone=true,ZoneIndex=true,PoseTime=true}
local function clean(value)
    return tostring(value):gsub("[\r\n]"," "):sub(1,120)
end
local function rootPos()
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end
local function pos(v)
    return v and string.format("%.1f,%.1f,%.1f",v.X,v.Y,v.Z) or "-"
end
local function line(message)
    if not active then return end
    if #active.lines>=180 then active.omitted=active.omitted+1; return end
    table.insert(active.lines,string.format("%.3fs | %s",os.clock()-active.start,message))
end
local function connect(signal, callback)
    table.insert(tracked,signal:Connect(callback))
end
local function button(obj)
    if not obj:IsA("GuiButton") or watched[obj] or obj:IsDescendantOf(gui) then return end
    watched[obj]=obj.Activated:Connect(function(input)
        line("BOTÃO "..obj:GetFullName().." | texto="..(obj:IsA("TextButton") and clean(obj.Text) or "-")
            .." | pos="..pos(rootPos()))
        if not active then return end
        local hud=playerGui:FindFirstChild("HUD")
        if not hud or not obj:IsDescendantOf(hud) then return end
        local ok, err=pcall(function()
            line("ENTRADA "..tostring(input and input.UserInputType).." | toque="..tostring(input and input.Position)
                .." | botão="..tostring(obj.AbsolutePosition).." tam="..tostring(obj.AbsoluteSize))
            local node=obj
            for _=1,4 do
                if not node or node==hud then break end
                local labels={}
                for _,child in ipairs(node:GetDescendants()) do
                    if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Visible and child.Text~="" then
                        table.insert(labels,child.Name.."="..clean(child.Text))
                        if #labels>=10 then break end
                    end
                end
                if #labels>0 then line("CONTEXTO "..node:GetFullName().." | "..table.concat(labels," / ")) end
                node=node.Parent
            end
        end)
        if not ok then line("ERRO CONTEXTO "..clean(err)) end
    end)
end
for _,obj in ipairs(playerGui:GetDescendants()) do button(obj) end
connect(playerGui.DescendantAdded,button)
connect(playerGui.DescendantRemoving,function(obj)
    if watched[obj] then watched[obj]:Disconnect(); watched[obj]=nil end
end)
connect(prompts.PromptTriggered,function(prompt,who)
    if who and who~=player then return end
    line("INTERAÇÃO "..prompt:GetFullName().." | ação="..clean(prompt.ActionText)
        .." | objeto="..clean(prompt.ObjectText).." | hold="..prompt.HoldDuration.." | pos="..pos(rootPos()))
end)
connect(player.AttributeChanged,function(key)
    if keys[key] then line("PLAYER "..key.."="..clean(player:GetAttribute(key)).." | pos="..pos(rootPos())) end
end)

local function snapshot()
    local root=rootPos()
    line("ESTADO pos="..pos(root).." Carrying="..clean(player:GetAttribute("Carrying"))
        .." CarryEnd="..clean(player:GetAttribute("CarryEnd")).." PenEggs="..clean(player:GetAttribute("PenEggs")))
    local camera=workspace.CurrentCamera
    local inset=game:GetService("GuiService"):GetGuiInset()
    line("TELA "..tostring(camera and camera.ViewportSize).." | inset="..tostring(inset))
end

local function stop(session)
    if active~=session then return end
    snapshot()
    active,last=nil,session
    record.Text="Gravar"
    status.Text="Gravação concluída · Exportar"
end
record.Activated:Connect(function()
    if active then stop(active); return end
    local session={start=os.clock(),lines={},omitted=0,stage=0}
    active=session
    record.Text="Parar"
    snapshot()
    task.spawn(function()
        if type(firesignal) ~= "function" then
            line("TESTE DE SINAL | firesignal indisponível")
            return
        end
        probeActive,probeTriggered=true,false
        local ok,err=pcall(firesignal,mark.Activated)
        task.wait(0.25)
        probeActive=false
        if active==session then
            line("TESTE DE SINAL | "..(not ok and clean(err) or (probeTriggered and "acionou botão do coletor" or "não acionou botão do coletor")))
        end
    end)
    task.spawn(function()
        local previous=rootPos()
        while gui.Parent and active==session and os.clock()-session.start<90 do
            local current=rootPos()
            if current and previous and (current-previous).Magnitude>=12 then
                line("DESLOCAMENTO "..pos(previous).." -> "..pos(current))
            end
            previous=current
            status.Text=string.format("GRAVANDO · %ds · %d linhas",math.floor(os.clock()-session.start),#session.lines)
            task.wait(.12)
        end
        if gui.Parent then stop(session) end
    end)
end)
mark.Activated:Connect(function()
    if probeActive then probeTriggered=true; return end
    if not active then return end
    active.stage=active.stage+1
    line("MARCA "..(stages[active.stage] or ("Etapa "..active.stage)))
    snapshot()
    mark.Text=stages[active.stage+1] or "Marcar etapa"
end)

local fullReport = ""
copyAll.Activated:Connect(function()
    if fullReport == "" then return end
    if type(setclipboard) == "function" and pcall(setclipboard, fullReport) then
        copyAll.Text = "Copiado"
    else
        copyAll.Text = "Cópia indisponível"
    end
end)
export.Activated:Connect(function()
    local session = active or last
    if not session then
        status.Text = "Grave uma rodada antes de exportar."
        return
    end
    local header = string.format("MAPA DO PRADO | %d linhas | omitidas=%d", #session.lines, session.omitted)
    fullReport = header .. "\n" .. table.concat(session.lines, "\n") .. "\n=== FIM DO RELATÓRIO ==="
    local saved = type(writefile) == "function" and pcall(writefile, "mapaPrado.txt", fullReport)
    status.Text = saved and "Arquivo mapaPrado.txt salvo." or "Relatório aberto. Toque em Copiar tudo."
    close.Text = saved and "Fechar · TXT salvo" or "Fechar"
    copyAll.Text = "Copiar tudo"
    output.Text = fullReport
    scroll.CanvasPosition = Vector2.zero
    report.Visible = true
end)
connect(gui.Destroying,function()
    active=nil
    for _,connection in ipairs(tracked) do connection:Disconnect() end
    for _,connection in pairs(watched) do connection:Disconnect() end
end)
