local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = assert(player:WaitForChild("PlayerGui", 8))
local old = playerGui:FindFirstChild("MapaLancamento")
if old then old:Destroy() end
local function make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", playerGui, { Name="MapaLancamento", ResetOnSpawn=false, DisplayOrder=70 })
local panel = make("Frame", gui, {
    Position=UDim2.new(0,10,1,-145), Size=UDim2.new(.8,0,0,92),
    BackgroundColor3=Color3.fromRGB(23,32,48),
})
make("UISizeConstraint", panel, { MaxSize=Vector2.new(390,92) })
local function control(class, value, x, y, width, height)
    return make(class,panel,{
        Text=value, Position=UDim2.new(x,4,0,y), Size=UDim2.new(width,-8,0,height),
        TextSize=13, TextWrapped=true, Font=Enum.Font.GothamBold,
        TextColor3=Color3.new(1,1,1), BackgroundColor3=Color3.fromRGB(48,77,119),
        BackgroundTransparency=class=="TextLabel" and 1 or 0,
    })
end
local status = control("TextLabel","MAPA DO LANÇAMENTO · pronto",0,4,.72,42)
local probe = control("TextButton","Alvo teste",.72,5,.28,36)
local record = control("TextButton","Gravar",0,49,.33,34)
local test = control("TextButton","Testar toque",.33,49,.34,34)
local export = control("TextButton","Exportar",.67,49,.33,34)
local overlay=make("Frame",gui,{Visible=false,Position=UDim2.fromScale(.06,.09),
    Size=UDim2.fromScale(.88,.77),BackgroundColor3=Color3.fromRGB(20,28,42)})
local close=make("TextButton",overlay,{Text="Fechar",Size=UDim2.new(.5,0,0,35)})
local copy=make("TextButton",overlay,{Text="Copiar tudo",Position=UDim2.new(.5,0,0,0),Size=UDim2.new(.5,0,0,35)})
local scroll=make("ScrollingFrame",overlay,{Position=UDim2.fromOffset(0,37),Size=UDim2.new(1,0,1,-37),
    CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
local output=make("TextBox",scroll,{Text="",TextEditable=false,MultiLine=true,TextWrapped=true,
    AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,-10,0,0),ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=13,TextColor3=Color3.new(1,1,1),BackgroundTransparency=1})
close.Activated:Connect(function() overlay.Visible=false end)

local active, last, probeResult, report
local connections, watched = {}, {}
local function clean(value) return tostring(value):gsub("[\r\n]"," "):sub(1,100) end
local function log(message)
    if active and #active.lines<70 then
        table.insert(active.lines,string.format("%.3fs | %s",os.clock()-active.start,message))
    end
end
local function listen(signal, fn)
    table.insert(connections,signal:Connect(fn))
end
local function labels(container)
    local list, seen = {}, {}
    if not container then return "-" end
    for _, item in ipairs(container:GetDescendants()) do
        if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Visible
            and item.Text~="" and not seen[item.Text] then
            seen[item.Text]=true
            table.insert(list,clean(item.Text))
            if #list>=14 then break end
        end
    end
    return table.concat(list," / ")
end
local function watch(object)
    if not object:IsA("GuiButton") or watched[object] or object:IsDescendantOf(gui) then return end
    local hud=guiParent:FindFirstChild("HUD")
    if not hud or not object:IsDescendantOf(hud) then return end
    watched[object]=object.Activated:Connect(function()
        if not active then return end
        log("TOQUE "..object:GetFullName().." | xy="..tostring(object.AbsolutePosition)
            .." | tam="..tostring(object.AbsoluteSize))
        local node=object
        for _=1,4 do
            if not node or node==hud then break end
            log("UI "..node.Name.." | "..labels(node))
            node=node.Parent
        end
    end)
end
for _, object in ipairs(playerGui:GetDescendants()) do watch(object) end
listen(playerGui.DescendantAdded,watch)
listen(playerGui.DescendantRemoving,function(object)
    if watched[object] then watched[object]:Disconnect(); watched[object]=nil end
end)
local function position()
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end
local function stop(session)
    if active~=session then return end
    log("FIM DA CAPTURA | pos="..tostring(position()))
    last, active=session,nil
    record.Text="Gravar"
    status.Text="Captura concluída · Exportar"
end
record.Activated:Connect(function()
    if active then stop(active); return end
    local session={start=os.clock(),lines={}}
    active=session
    record.Text="Parar"
    local camera=workspace.CurrentCamera
    local inset=game:GetService("GuiService"):GetGuiInset()
    log("INÍCIO | viewport="..tostring(camera and camera.ViewportSize)
        .." | inset="..tostring(inset).." | pos="..tostring(position()))
    task.spawn(function()
        local prev=position()
        while gui.Parent and active==session and os.clock()-session.start<75 do
            local now=position()
            if prev and now and (now-prev).Magnitude>=10 then
                log("DESLOCAMENTO "..tostring(prev).." -> "..tostring(now))
            end
            prev=now
            status.Text=string.format("GRAVANDO · %ds · %d linhas",math.floor(os.clock()-session.start),#session.lines)
            task.wait(.12)
        end
        if gui.Parent then stop(session) end
    end)
end)
listen(player.AttributeChanged,function(key)
    if key=="PoseTime" or key=="Zone" or key=="ZoneIndex" then
        log("PLAYER "..key.."="..clean(player:GetAttribute(key)).." | pos="..tostring(position()))
    end
end)

local probeHits=0
local testing=false
probe.Activated:Connect(function() probeHits=probeHits+1 end)
test.Activated:Connect(function()
    if testing then return end
    testing=true
    local point=probe.AbsolutePosition+probe.AbsoluteSize/2
    local before=probeHits
    local hit=guiParent:GetGuiObjectsAtPosition(point.X,point.Y)[1]
    if hit~=probe then
        probeResult="Alvo do teste encoberto. Feche outros painéis."
    else
        local ok, err=pcall(function()
            local input=game:GetService("VirtualInputManager")
            input:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
            input:SendMouseButtonEvent(point.X,point.Y,0,false,game,0)
        end)
        task.wait(.25)
        probeResult=not ok and ("Erro de entrada: "..clean(err))
            or (probeHits>before and "Toque simulado confirmado no painel" or "A chamada não acionou o alvo")
    end
    if gui.Parent then status.Text=probeResult; log("TESTE DE TOQUE | "..probeResult) end
    testing=false
end)
copy.Activated:Connect(function()
    if report and type(setclipboard)=="function" and pcall(setclipboard,report) then copy.Text="Copiado" end
end)
export.Activated:Connect(function()
    local session=active or last
    if not session then status.Text="Grave o lançamento primeiro."; return end
    report="MAPA DO LANÇAMENTO\nTOQUE SIMULADO | "..(probeResult or "Não testado").."\n"
        ..table.concat(session.lines,"\n").."\n=== FIM DO RELATÓRIO ==="
    if type(writefile)=="function" then pcall(writefile,"mapaLancamento.txt",report) end
    output.Text=report
    scroll.CanvasPosition=Vector2.zero
    copy.Text="Copiar tudo"
    overlay.Visible=true
end)
listen(gui.Destroying,function()
    active=nil
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, connection in pairs(watched) do connection:Disconnect() end
end)
