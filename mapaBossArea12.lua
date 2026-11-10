-- Arme na base. A coleta começa quando Carrying confirma o ID escolhido.
local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = assert(player:WaitForChild("PlayerGui", 8))
local prompts = game:GetService("ProximityPromptService")
local old = playerGui:FindFirstChild("MapaAreaBoss")
if old then old:Destroy() end
local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {Name="MapaAreaBoss",ResetOnSpawn=false,DisplayOrder=70})
local panel = make("Frame",gui,{Position=UDim2.new(0,10,1,-132),Size=UDim2.new(.78,0,0,76),
    BackgroundColor3=Color3.fromRGB(28,18,37),BorderSizePixel=0})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(390,76)})
make("UICorner",panel,{CornerRadius=UDim.new(0,8)})
local status=make("TextLabel",panel,{Position=UDim2.fromOffset(5,2),Size=UDim2.new(1,-10,0,37),
    Text="MAPA DE ÁREA · informe o ID e toque em Armar",TextWrapped=true,TextSize=13,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1)})
local view=make("TextButton",panel,{Position=UDim2.fromOffset(5,41),Size=UDim2.new(.5,-8,0,29),
    Text="Ver relatório",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local record=make("TextButton",panel,{Position=UDim2.new(.5,3,0,41),Size=UDim2.new(.5,-8,0,29),
    Text="Armar",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local area=make("TextBox",panel,{Position=UDim2.fromOffset(5,-34),Size=UDim2.fromOffset(116,29),
    Text="12",PlaceholderText="ID da área",ClearTextOnFocus=false,TextSize=15,
    BackgroundColor3=Color3.fromRGB(46,32,59),TextColor3=Color3.new(1,1,1)})
local overlay=make("Frame",gui,{Visible=false,Position=UDim2.fromScale(.05,.08),Size=UDim2.fromScale(.9,.77),
    BackgroundColor3=Color3.fromRGB(28,18,37)})
local close=make("TextButton",overlay,{Text="Fechar",Size=UDim2.new(1/3,0,0,33)})
local filter=make("TextButton",overlay,{Text="Só verdes",Position=UDim2.fromScale(1/3,0),Size=UDim2.new(1/3,0,0,33)})
local copyReport=make("TextButton",overlay,{
    Text="Copiar relatório",Position=UDim2.fromScale(2/3,0),Size=UDim2.new(1/3,0,0,33),
})
local scroll=make("ScrollingFrame",overlay,{Position=UDim2.fromOffset(0,35),Size=UDim2.new(1,0,1,-35),
    CanvasSize=UDim2.new(),ScrollingEnabled=true,ScrollingDirection=Enum.ScrollingDirection.Y,
    Active=true,ScrollBarThickness=8,BackgroundTransparency=1})
local output=make("TextLabel",scroll,{Text="",TextWrapped=true,
    Size=UDim2.new(1,-12,0,0),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=13,TextColor3=Color3.new(1,1,1)})
local textService=game:GetService("TextService")
local fullReport, greenReport
local onlyGreen=false
local function splitReport(report)
    local parts, chunk, size = {}, {}, 0
    for line in (report.."\n"):gmatch("[^\n]*\n") do
        if size+#line>5500 and #chunk>0 then
            table.insert(parts,table.concat(chunk))
            chunk,size={},0
        end
        table.insert(chunk,line)
        size=size+#line
    end
    if #chunk>0 then table.insert(parts,table.concat(chunk)) end
    return parts
end

local copyParts, copyIndex
copyReport.Activated:Connect(function()
    if not copyParts then return end
    local copy=type(setclipboard)=="function" and setclipboard or toclipboard
    if type(copy)~="function" then
        copyReport.Text="Cópia indisponível"
        return
    end
    local part=copyIndex
    local ok,result=pcall(copy,copyParts[part])
    if not ok or result==false then
        copyReport.Text="Falha · tente novamente"
        return
    end
    copyIndex=part % #copyParts + 1
    if #copyParts==1 then
        copyReport.Text="Relatório copiado"
    else
        copyReport.Text=string.format("Copiado %d/%d · próximo %d",part,#copyParts,copyIndex)
    end
end)
local function resizeReport()
    local width=math.floor(scroll.AbsoluteSize.X)-12
    if width<=0 then return end
    local size=textService:GetTextSize(output.Text,output.TextSize,output.Font,Vector2.new(width,100000))
    local height=math.ceil(size.Y)+16
    output.Size=UDim2.new(1,-12,0,height)
    scroll.CanvasSize=UDim2.fromOffset(0,height)
end
local function showReport()
    output.Text=onlyGreen and greenReport or fullReport
    filter.Text=onlyGreen and "Ver tudo" or "Só verdes"
    resizeReport()
    scroll.CanvasPosition=Vector2.zero
end
close.Activated:Connect(function() overlay.Visible=false end)
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeReport)
view.Activated:Connect(function()
    if not fullReport then return end
    overlay.Visible=true
    showReport()
end)
filter.Activated:Connect(function()
    if not fullReport then return end
    onlyGreen=not onlyGreen
    showReport()
end)

local started, selectedZone
local duration=120
local lines,fx,moves,connections={},{},{},{}
local dropped=0
local done=false
local carryAt, endedAt, carryZone
local floodLines, detailLines={},{}
local lastFloodContext, lastFloorContext="",""
local function vec(v) return v and string.format("%.1f,%.1f,%.1f",v.X,v.Y,v.Z) or "-" end
local function log(kind, message)
    if not started or done or (endedAt and kind~="TRANSPORTE" and kind~="FIM BOSS") then return end
    local flood=kind=="RECIFE" or kind=="APOIO" or kind=="SALTO"
    local detail=kind=="CHÃO" or kind=="SINAL"
    local rows=detail and detailLines or flood and floodLines or (kind=="FX" and fx or (kind=="MOV" and moves or lines))
    local limit=detail and 220 or flood and 48 or (kind=="FX" and 48 or (kind=="MOV" and 100 or 85))
    if #rows>=limit then dropped=dropped+1; return end
    local t=os.clock()-started
    table.insert(rows,{t=t,text=string.format("%.3fs | %s | %s",t,kind,message)})
end
local function listen(signal, callback)
    table.insert(connections,signal:Connect(callback))
end
local function root()
    local character=player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function carrying()
    local v=player:GetAttribute("Carrying")
    return v==true or (tonumber(v) or 0)>0
end
local function walls(position)
    local folder=workspace:FindFirstChild("CarryWalls")
    local seen={}
    local count=0
    for _,part in ipairs(folder and folder:GetDescendants() or {}) do
        if part:IsA("BasePart") and (part.Name=="Field" or part.Name=="Force")
            and math.abs(part.Position.Y-position.Y)<=part.Size.Y/2+3 then
            local axis=part.CFrame.RightVector
            local key
            if math.abs(axis.Z)>.98 then key=string.format("X=%.1f",part.Position.X)
            elseif math.abs(axis.X)>.98 then key=string.format("Z=%.1f",part.Position.Z)
            else key="Inclinada "..vec(part.Orientation) end
            local span=seen[key] or {min=math.huge,max=-math.huge,n=0}
            local along=math.abs(axis.Z)>.98 and part.Position.Z or part.Position.X
            span.min=math.min(span.min,along-part.Size.X/2)
            span.max=math.max(span.max,along+part.Size.X/2)
            span.n=span.n+1
            seen[key]=span
            count=count+1
        end
    end
    local rows={}
    for key,span in pairs(seen) do
        table.insert(rows,string.format("%s [%.1f,%.1f] n=%d",key,span.min,span.max,span.n))
    end
    table.sort(rows)
    log("JAULA","pos="..vec(position).." | peças="..count.." | "..table.concat(rows,"; "))
end
local watched={}
local nextId=0
local ignored={Scenery=true,Eggs=true,CarriedEggs=true,CarryWalls=true}
local function track(part)
    if not part:IsA("BasePart") or watched[part] then return end
    local path=part:GetFullName()
    local category=path:match("^Workspace%.([^%.]+)")
    if ignored[category] or path:find(".SleepModel.",1,true)
        or path:find(".ZoneWalls.",1,true) then return end
    nextId=nextId+1
    watched[part]={id=nextId,path=path}
end
local function fxFolder(object)
    local path=object:GetFullName():lower()
    return path:find(".bossfx.",1,true) or path:find(".vfx.",1,true)
        or path:find(".effects.",1,true) or path:find(".bosses.",1,true)
end
for _,part in ipairs(workspace:GetDescendants()) do
    if part:IsA("BasePart") and fxFolder(part) then track(part) end
end
listen(workspace.DescendantAdded,function(part)
    if not started or not part:IsA("BasePart") then return end
    local r=root()
    if fxFolder(part) or (r and (part.Position-r.Position).Magnitude<=200) then track(part) end
end)
listen(workspace.DescendantRemoving,function(part)
    local state=watched[part]
    if state and state.signalLogged then log("SINAL",string.format("#%d removido | %s",state.id,state.path)) end
    watched[part]=nil
end)

local holds={}
listen(prompts.PromptButtonHoldBegan,function(prompt,who)
    if (not who or who==player) and prompt.ActionText:lower():find("ovo",1,true) then
        holds[prompt]=os.clock()
        log("SEGURAR",prompt.ObjectText.." | duração pedida="..prompt.HoldDuration)
    end
end)
listen(prompts.PromptButtonHoldEnded,function(prompt,who)
    local began=holds[prompt]
    if began and (not who or who==player) then
        log("SOLTAR",string.format("%s | %.3fs",prompt.ObjectText,os.clock()-began))
        holds[prompt]=nil
    end
end)
listen(prompts.PromptTriggered,function(prompt,who)
    if (not who or who==player) and prompt.ActionText:lower():find("ovo",1,true) then
        log("COLETA",prompt.ObjectText.." | duração pedida="..prompt.HoldDuration
            .." | zona="..tostring(prompt.Parent and prompt.Parent:GetAttribute("Zone")))
    end
end)
local function motion(r)
    if not r then return "pos=-" end
    local humanoid=r.Parent and r.Parent:FindFirstChildOfClass("Humanoid")
    local velocity=r.AssemblyLinearVelocity
    return string.format("pos=%s vel=%s XZ=%.1f walk=%.1f dir=%s chão=%s",
        vec(r.Position),vec(velocity),Vector3.new(velocity.X,0,velocity.Z).Magnitude,
        humanoid and humanoid.WalkSpeed or 0,vec(humanoid and humanoid.MoveDirection),
        tostring(humanoid and humanoid.FloorMaterial~=Enum.Material.Air))
end

local lastGroups, lastGroupsAt
local hp=player:GetAttribute("BossHP")
listen(player:GetAttributeChangedSignal("BossHP"),function()
    local value=player:GetAttribute("BossHP")
    local r=root()
    if type(hp)=="number" and type(value)=="number" and hp>=0 and value>=0 and value<hp then
        local context = lastGroupsAt and os.clock()-lastGroupsAt <= 1
            and string.format(" | FX %.2fs atrás: %s",os.clock()-lastGroupsAt,lastGroups) or ""
        log("DANO",string.format("%.2f -> %.2f | %s%s",hp,value,motion(r),context..lastFloorContext..(carryZone==11 and lastFloodContext or "")))
    elseif type(value)~="number" or value<0 then
        log("FIM BOSS","BossHP="..tostring(value))
    elseif type(hp)~="number" or hp<0 then
        log("INÍCIO BOSS","BossHP="..tostring(value))
    end
    hp=value
end)
listen(player:GetAttributeChangedSignal("Carrying"),function()
    if not selectedZone or done then return end
    local value=player:GetAttribute("Carrying")
    local zone=tonumber(value)
    if not started then
        if zone~=selectedZone then
            if carrying() then
                status.Text="Ovo com ID "..tostring(value).." · aguardando ID "..selectedZone
            end
            return
        end
        started=os.clock()
        carryZone,carryAt=zone,started
        record.Text="Encerrar"
        log("INÍCIO",motion(root()).." | BossHP="..tostring(hp))
    elseif endedAt then
        return
    elseif zone~=selectedZone then
        endedAt=os.clock()
    end
    local r=root()
    log("TRANSPORTE",tostring(value).." | pos="..vec(r and r.Position))
end)
listen(gui.Destroying,function()
    done=true
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)

local function finish()
    if not started or done then return end
    done=true
    record.Text="Concluído"
    for _,connection in ipairs(connections) do connection:Disconnect() end
    for _,row in ipairs(fx) do table.insert(lines,row) end
    for _,row in ipairs(moves) do table.insert(lines,row) end
    for _,row in ipairs(detailLines) do table.insert(lines,row) end
    for _,row in ipairs(floodLines) do table.insert(lines,row) end
    table.sort(lines,function(a,b) return a.t<b.t end)
    local report={"MAPA DO BOSS · V1 | ID="..selectedZone.." | eventos excedentes="..dropped}
    for _,row in ipairs(lines) do table.insert(report,row.text) end
    table.insert(report,"=== FIM DO RELATÓRIO ===")
    local text=table.concat(report,"\n")
    fullReport=text
    copyParts,copyIndex=splitReport(text),1
    copyReport.Text=#copyParts>1 and ("Copiar parte 1/"..#copyParts) or "Copiar relatório"
    local greenRows={}
    for _,row in ipairs(fx) do
        local marker=row.text:find(" | VERDE ",1,true)
        if marker then
            greenRows[#greenRows+1]=string.format("%.3fs",row.t)..row.text:sub(marker)
        end
    end
    greenReport=#greenRows>0 and table.concat(greenRows,"\n\n")
        or "Nenhum retângulo verde registrado nesta captura."
    status.Text="Captura concluída · Ver relatório"
end
local function nearbyEggs(r)
    local folder=workspace:FindFirstChild("Eggs")
    local counts, nearest, minDistance = {}, nil, math.huge
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local zone=tostring(egg:GetAttribute("Zone") or "?")
        local prompt=egg:FindFirstChildWhichIsA("ProximityPrompt",true)
        local row=counts[zone] or {total=0,enabled=0}
        counts[zone]=row
        row.total=row.total+1
        if prompt and prompt.Enabled then row.enabled=row.enabled+1 end
        local point=egg:IsA("BasePart") and egg.Position or (egg:IsA("Model") and egg:GetPivot().Position)
        local distance=point and (point-r.Position).Magnitude
        if distance and distance<minDistance then
            minDistance=distance
            nearest=string.format("%s · ID=%s · %.1f studs · prompt=%s",
                prompt and prompt.ObjectText~="" and prompt.ObjectText or egg.Name,zone,distance,
                prompt and tostring(prompt.Enabled) or "ausente")
        end
    end
    local summary={}
    for zone,row in pairs(counts) do
        table.insert(summary,string.format("ID %s: %d/%d ativos",zone,row.enabled,row.total))
    end
    table.sort(summary)
    return #summary>0 and table.concat(summary,"; ") or "nenhum objeto em Workspace.Eggs",nearest
end

record.Activated:Connect(function()
    if done then return end
    if started then finish(); return end
    if carrying() then
        status.Text="Comece na base, antes de pegar o ovo"
        return
    end
    if selectedZone then
        selectedZone=nil
        area.TextEditable=true
        record.Text="Armar"
        status.Text="Seleção cancelada"
        return
    end
    local id=tonumber(area.Text)
    if not id or id<1 or id%1~=0 then
        status.Text="Digite o ID interno da área (ex.: 11)"
        return
    end
    selectedZone=id
    area.TextEditable=false
    record.Text="Cancelar"
    status.Text="Aguardando ovo da área ID "..id
end)

local solidRay=RaycastParams.new()
solidRay.IgnoreWater=true
solidRay.RespectCanCollide=true
local waterRay=RaycastParams.new()
local lastSupport, lastGround, nextFlood, lastFloodKey=nil,nil,0,nil

local function sampleRecife(r, now)
    local h=r.Parent:FindFirstChildOfClass("Humanoid")
    if not h then return end
    solidRay.FilterDescendantsInstances={r.Parent}
    waterRay.FilterDescendantsInstances={r.Parent}
    local down=Vector3.new(0,-20,0)
    local ground=h.FloorMaterial~=Enum.Material.Air
    local support=ground and workspace:Raycast(r.Position,down,solidRay) or nil
    local object=support and support.Instance
    if lastGround~=nil and ground~=lastGround then
        log("SALTO",(ground and "POUSO | " or "SAÍDA DO CHÃO | ")..motion(r))
    end
    if object and (object~=lastSupport or not lastGround) then
        local id=watched[object] and ("#"..watched[object].id.." ") or ""
        log("APOIO",string.format("%s%s | topoY=%.2f | pouso=%s | material=%s",
            id,object.Name,support.Position.Y,vec(r.Position),tostring(h.FloorMaterial)))
    end
    lastSupport,lastGround=object,ground
    if now<nextFlood then return end
    nextFlood=now+.42

    local water=workspace:Raycast(r.Position+Vector3.new(0,16,0),Vector3.new(0,-44,0),waterRay)
    local waterY=water and water.Material==Enum.Material.Water and water.Position.Y
    local platform, platformDistance, surface, surfaceDistance
    for part,state in pairs(watched) do
        if part.Parent and part.Transparency<.99 then
            local c,size,frame=part.Color,part.Size,part.CFrame
            local delta=part.Position-r.Position
            local distance=delta.X^2+delta.Z^2
            local orange=c.R>.8 and c.G>.55 and c.G<.76 and c.B>.26 and c.B<.44
            local platformShape=math.abs(size.X-3.2)<=.6 and math.abs(size.Y-9.5)<=1
                and math.abs(size.Z-9.5)<=1 and math.abs(frame.RightVector.Y)>=.9
            if orange and platformShape and distance<=65^2 and (not platformDistance or distance<platformDistance) then
                platform,platformDistance={part=part,id=state.id},distance
            end
            if size.Y<=6 and size.X>=28 and size.Z>=28 and math.abs(frame.UpVector.Y)>=.98
                and (part.Material==Enum.Material.Glass or part.Material==Enum.Material.Water
                    or (c.B>.35 and c.B>=c.R+.12)) then
                local localPoint=frame:PointToObjectSpace(Vector3.new(r.Position.X,part.Position.Y,r.Position.Z))
                if math.abs(localPoint.X)<=size.X/2 and math.abs(localPoint.Z)<=size.Z/2
                    and (not surfaceDistance or distance<surfaceDistance) then
                    surface,surfaceDistance={part=part,id=state.id},distance
                end
            end
        end
    end
    local waterText=waterY and string.format("água detectada Y=%.2f",waterY) or "água Terrain sem leitura"
    if surface then
        local part=surface.part
        waterText=waterText..string.format(" | superfície candidata #%d %s topoY=%.2f tam=%s",
            surface.id,part.Name,part.Position.Y+part.Size.Y/2,vec(part.Size))
    end
    local platformText="apoio candidato=-"
    if platform then
        local part=platform.part
        platformText=string.format("apoio candidato #%d %s p=%s topoY≈%.2f tam=%s dist=%.1f",
            platform.id,part.Name,vec(part.Position),part.Position.Y+part.Size.X/2,
            vec(part.Size),math.sqrt(platformDistance))
    end
    lastFloodContext=" | "..waterText.." | "..platformText
    local key=waterText.." | "..platformText
    if key~=lastFloodKey and (platform or surface or waterY or lastFloodKey) then
        log("RECIFE",key.." | jogador="..vec(r.Position))
        lastFloodKey=key
    end
end

local floorRay=RaycastParams.new()
local probes={
    {"centro",Vector3.zero},{"X+",Vector3.new(5,0,0)},{"X-",Vector3.new(-5,0,0)},
    {"Z+",Vector3.new(0,0,5)},{"Z-",Vector3.new(0,0,-5)},
}
local floorKey,nextFloor=nil,0
local function rgb(color)
    return string.format("%.0f,%.0f,%.0f",color.R*255,color.G*255,color.B*255)
end

local function floorAt(origin, params)
    local hit=workspace:Raycast(origin,Vector3.new(0,-38,0),params)
    if not hit then return "-", "-" end
    local part=hit.Instance
    local material=hit.Material.Name
    local color
    if part:IsA("Terrain") then
        color=hit.Material==Enum.Material.Water and part.WaterColor or part:GetMaterialColor(hit.Material)
    else
        color=part.Color
    end
    local key=string.format("%s rgb=%s mat=%s",part.Name,rgb(color),material)
    return key, string.format("%s y=%.2f p=%s",key,hit.Position.Y,vec(hit.Position))
end

local function sampleFloor(r, now)
    if now<nextFloor then return end
    nextFloor=now+.10
    floorRay.FilterDescendantsInstances={r.Parent}
    solidRay.FilterDescendantsInstances={r.Parent}
    local keys, details={},{}
    for _,probe in ipairs(probes) do
        local key, detail=floorAt(r.Position+probe[2]+Vector3.new(0,2,0),floorRay)
        table.insert(keys,key)
        table.insert(details,probe[1].."="..detail)
    end
    local solid, support=floorAt(r.Position+Vector3.new(0,2,0),solidRay)
    table.insert(keys,solid)
    lastFloorContext=" | CHÃO "..keys[1].." | APOIO "..solid
    local key=table.concat(keys,";")
    if key~=floorKey then
        floorKey=key
        log("CHÃO",table.concat(details," | ").." | sólido="..support)
    end
end

local function sampleSignals(r, baseline)
    local candidates={}
    for part,state in pairs(watched) do
        if part.Parent then
            local size, p=part.Size,part.Position
            local thin=math.min(size.X,size.Y,size.Z)
            local distance=Vector3.new(p.X-r.Position.X,0,p.Z-r.Position.Z).Magnitude
            local visible=part.Transparency<.98 and distance<=110+math.max(size.X,size.Z)/2
            local groundEffect=thin<=2 and math.max(size.X,size.Z)>=2 and math.abs(p.Y-r.Position.Y)<=18
            if visible and (fxFolder(part) or groundEffect) and not part:IsDescendantOf(r.Parent) then
                local color=rgb(part.Color)
                local key=string.format("%s/%s/%.1f/%s",color,part.Material.Name,part.Transparency,vec(size))
                if baseline and not fxFolder(part) then
                    state.signalKey=key
                elseif key~=state.signalKey then
                    table.insert(candidates,{part=part,state=state,key=key,color=color,distance=distance})
                end
            elseif state.signalKey then
                state.signalKey=nil
                if state.signalLogged then
                    state.signalLogged=nil
                    log("SINAL",string.format("#%d saiu da captura | %s",state.id,state.path))
                end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.distance<b.distance end)
    for index=1,math.min(#candidates,10) do
        local item=candidates[index]
        local part,state=item.part,item.state
        state.signalKey,state.signalLogged=item.key,true
        log("SINAL",string.format("#%d %s | rgb=%s mat=%s tr=%.2f | p=%s tam=%s rot=%s dist=%.1f",
            state.id,state.path,item.color,part.Material.Name,part.Transparency,
            vec(part.Position),vec(part.Size),vec(part.Orientation),item.distance))
    end
end

task.spawn(function()
    local lastWall,nextFX,nextModel=0,0,0
    local nextMove,seeded,signalsSeeded=0,false,false
    local nextGroup=0
    local lastInventory
    while gui.Parent and not started do task.wait(.12) end
    while gui.Parent and started and not done do
        local now=os.clock()
        local r=root()
        if r and not endedAt then
            sampleFloor(r, now)
            if carryZone==11 then sampleRecife(r, now) end
        end
        if r and now>=nextMove then
            nextMove=now+1.2
            local nearest
            if not carryAt then
                local summary
                summary,nearest=nearbyEggs(r)
                if summary~=lastInventory then
                    lastInventory=summary
                    log("OVOS",summary)
                end
            end
            log("MOV",motion(r)..(nearest and (" | Ovo mais próximo: "..nearest) or ""))
        end
        if r and carryAt and not endedAt then
            if not seeded then
                seeded=true
                for _,part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Position-r.Position).Magnitude<=220 then track(part) end
                end
            end
            if now-lastWall>6 then walls(r.Position); lastWall=now end
            if now>=nextModel then
                nextModel=now+6
                local folder=workspace:FindFirstChild("BossFX")
                local models={}
                for _,obj in ipairs(folder and folder:GetChildren() or {}) do
                    if obj:IsA("Model") then table.insert(models,obj.Name.."@"..vec(obj:GetPivot().Position)) end
                    if #models>=8 then break end
                end
                log("BOSSFX MODELOS",table.concat(models,"; "))
            end
            if now>=nextFX then
                nextFX=now+.08
                sampleSignals(r, not signalsSeeded)
                signalsSeeded=true
                local groups={}
                local green1,green2,dist1,dist2
                local folder=workspace:FindFirstChild("BossFX")
                for part,state in pairs(watched) do
                    if part.Parent then
                        local c,size=part.Color,part.Size
                        local thin=math.min(size.X,size.Y,size.Z)
                        local span=math.max(size.X,size.Y,size.Z)
                        local red=c.R>.45 and c.R>c.G*1.45 and c.R>c.B*1.45
                        local delta=part.Position-r.Position
                        local knownFX=fxFolder(part)
                        local near=Vector3.new(delta.X,0,delta.Z).Magnitude<=145+span/2
                        if now>=nextGroup and size.Y<=1 and math.min(size.X,size.Z)>=2
                            and math.abs(delta.Y)<=8 and part.Transparency<.98
                            and c.G>.2 and c.G>c.R+.05 and c.G>c.B+.05
                            and not state.path:find(".Boss.",1,true) then
                            local d=delta.X*delta.X+delta.Z*delta.Z
                            if d<=70*70 then
                                if not dist1 or d<dist1 then
                                    green2,dist2=green1,dist1
                                    green1,dist1=part,d
                                elseif not dist2 or d<dist2 then
                                    green2,dist2=part,d
                                end
                            end
                        end
                        if red and near and part.Transparency<.98 and span>=1
                            and (knownFX or (thin<=2 and math.abs(delta.Y)<=16))
                            and not state.path:find(".Boss.",1,true) then
                            local key=folder and part:IsDescendantOf(folder) and part.ClassName or "Outros"
                            local group=groups[key]
                            if not group then
                                group={count=0,minX=math.huge,maxX=-math.huge,minZ=math.huge,maxZ=-math.huge,
                                    distance=math.huge}
                                groups[key]=group
                            end
                            local position=part.Position
                            group.count=group.count+1
                            group.minX,group.maxX=math.min(group.minX,position.X),math.max(group.maxX,position.X)
                            group.minZ,group.maxZ=math.min(group.minZ,position.Z),math.max(group.maxZ,position.Z)
                            local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
                            if distance<group.distance then
                                group.distance,group.position,group.size,group.rotation,group.color=distance,position,size,part.Orientation,c
                            end
                        end
                    else watched[part]=nil end
                end
                local summaries={}
                for key,group in pairs(groups) do
                    table.insert(summaries,string.format("%s n=%d X[%.0f,%.0f] Z[%.0f,%.0f] prox=%.1f p=%s tam=%s rot=%s rgb=%s",
                        key,group.count,group.minX,group.maxX,group.minZ,group.maxZ,group.distance,
                        vec(group.position),vec(group.size),vec(group.rotation),
                        vec(group.color and Vector3.new(group.color.R,group.color.G,group.color.B)*255)))
                end
                if #summaries>0 then
                    table.sort(summaries)
                    lastGroups,lastGroupsAt=table.concat(summaries,"; "),now
                end
                if (#summaries>0 or green1) and now>=nextGroup then
                    local details=table.concat(summaries,"; ")
                    for _,part in ipairs({green1,green2}) do
                        local c=part.Color
                        details=details..string.format(" | VERDE #%d rgb=%.0f,%.0f,%.0f p=%s tam=%s rot=%s",
                            watched[part].id,c.R*255,c.G*255,c.B*255,vec(part.Position),
                            vec(part.Size),vec(part.Orientation))
                    end
                    log("FX",details)
                    nextGroup=now+.65
                elseif #summaries==0 and not green1 and now>=nextGroup then
                    nextGroup=0
                end
            end
        end
        if (endedAt and now-endedAt>1) or now-started>=duration then finish(); return end
        status.Text=string.format("ÁREA ID %d · %ds restantes",
            selectedZone,math.max(0,math.ceil(duration-(now-started))))
        task.wait(.08)
    end
end)
