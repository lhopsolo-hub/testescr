-- Inicie na arena. A captura começa imediatamente, com identificação automática.
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
    Text="MAPA DO BOSS · entre na arena e toque em Iniciar",TextWrapped=true,TextSize=13,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1)})
local view=make("TextButton",panel,{Position=UDim2.fromOffset(5,41),Size=UDim2.new(.5,-8,0,29),
    Text="Ver relatório",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local record=make("TextButton",panel,{Position=UDim2.new(.5,3,0,41),Size=UDim2.new(.5,-8,0,29),
    Text="Iniciar",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local overlay=make("Frame",gui,{Visible=false,Position=UDim2.fromScale(.05,.08),Size=UDim2.fromScale(.9,.77),
    BackgroundColor3=Color3.fromRGB(28,18,37)})
local close=make("TextButton",overlay,{Text="Fechar",Size=UDim2.new(.5,0,0,33)})
local copyReport=make("TextButton",overlay,{
    Text="Copiar relatório",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,0,0,33),
})
local scroll=make("ScrollingFrame",overlay,{Position=UDim2.fromOffset(0,35),Size=UDim2.new(1,0,1,-35),
    CanvasSize=UDim2.new(),ScrollingEnabled=true,ScrollingDirection=Enum.ScrollingDirection.Y,
    Active=true,ScrollBarThickness=8,BackgroundTransparency=1})
local output=make("TextLabel",scroll,{Text="",TextWrapped=true,
    Size=UDim2.new(1,-12,0,0),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=13,TextColor3=Color3.new(1,1,1)})
local textService=game:GetService("TextService")
local fullReport
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
    output.Text=fullReport
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
local started, detectedZone, nearestZone
local duration=120
local lines,moves,connections={},{},{}
local dropped=0
local done=false
local endedAt, hadCarry
local floorLines, detailLines={},{}
local lastSignalContext, lastFloorContext="",""
local function vec(v) return v and string.format("%.1f,%.1f,%.1f",v.X,v.Y,v.Z) or "-" end
local function log(kind, message)
    if not started or done or (endedAt and kind~="TRANSPORTE" and kind~="FIM BOSS") then return end
    local floor=kind=="CHÃO"
    local detail=kind=="SINAL"
    local rows=floor and floorLines or (detail and detailLines or (kind=="MOV" and moves or lines))
    local limit=floor and 85 or (detail and 220 or (kind=="MOV" and 100 or 85))
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

local function promptZone(prompt)
    local node=prompt.Parent
    while node and node~=workspace do
        local id=tonumber(node:GetAttribute("Zone"))
        if id and id>0 then return id end
        node=node.Parent
    end
end

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
        local id=promptZone(prompt)
        if started and id then detectedZone=id end
        log("COLETA",prompt.ObjectText.." | duração pedida="..prompt.HoldDuration
            .." | ID do ovo="..tostring(id))
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

local hp=player:GetAttribute("BossHP")
listen(player:GetAttributeChangedSignal("BossHP"),function()
    local value=player:GetAttribute("BossHP")
    local r=root()
    if type(hp)=="number" and type(value)=="number" and hp>=0 and value>=0 and value<hp then
        log("DANO",string.format("%.2f -> %.2f | %s%s",hp,value,motion(r),lastFloorContext..lastSignalContext))
    elseif type(value)~="number" or value<0 then
        log("FIM BOSS","BossHP="..tostring(value))
    elseif type(hp)~="number" or hp<0 then
        log("INÍCIO BOSS","BossHP="..tostring(value))
    end
    hp=value
end)
listen(player:GetAttributeChangedSignal("Carrying"),function()
    if not started or done or endedAt then return end
    local value=player:GetAttribute("Carrying")
    if carrying() then
        hadCarry=true
        local id=tonumber(value)
        if not detectedZone and id and id>0 then detectedZone=id end
    elseif hadCarry then
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
    for _,row in ipairs(moves) do table.insert(lines,row) end
    for _,row in ipairs(detailLines) do table.insert(lines,row) end
    for _,row in ipairs(floorLines) do table.insert(lines,row) end
    table.sort(lines,function(a,b) return a.t<b.t end)
    local report={"MAPA DO BOSS · AUTO V2 | ID="..(detectedZone and tostring(detectedZone) or "não confirmado")..(nearestZone and (" | ovo próximo ID="..nearestZone) or "").." | eventos excedentes="..dropped}
    for _,row in ipairs(lines) do table.insert(report,row.text) end
    table.insert(report,"=== FIM DO RELATÓRIO ===")
    local text=table.concat(report,"\n")
    fullReport=text
    copyParts,copyIndex=splitReport(text),1
    copyReport.Text=#copyParts>1 and ("Copiar parte 1/"..#copyParts) or "Copiar relatório"
    status.Text="Captura concluída · Ver relatório"
end
local function nearbyEggs(r)
    local folder=workspace:FindFirstChild("Eggs")
    local counts, nearest, minDistance, nearestId = {}, nil, math.huge, nil
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
            minDistance,nearestId=distance,tonumber(zone)
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
    return #summary>0 and table.concat(summary,"; ") or "nenhum objeto em Workspace.Eggs",nearest,nearestId
end

record.Activated:Connect(function()
    if done then return end
    if started then finish(); return end
    local r=root()
    if not r then
        status.Text="Aguardando personagem"
        return
    end
    started=os.clock()
    hp=player:GetAttribute("BossHP")
    hadCarry=carrying()
    if hadCarry then detectedZone=tonumber(player:GetAttribute("Carrying")) end
    record.Text="Encerrar"
    local summary, nearest, id=nearbyEggs(r)
    nearestZone=id
    log("INÍCIO",motion(r).." | BossHP="..tostring(hp))
    log("OVOS",summary.." | próximo="..tostring(nearest))
end)

local solidRay=RaycastParams.new()
solidRay.IgnoreWater=true
solidRay.RespectCanCollide=true
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
                local knownFX=fxFolder(part)
                local position=knownFX and string.format("/%.0f/%.0f/%.0f",p.X/3,p.Y/3,p.Z/3) or ""
                local key=string.format("%s/%s/%.1f/%s%s",color,part.Material.Name,part.Transparency,vec(size),position)
                if baseline and not knownFX then
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
    for index=1,math.min(#candidates,8) do
        local item=candidates[index]
        local part,state=item.part,item.state
        state.signalKey,state.signalLogged=item.key,true
        if index==1 then
            lastSignalContext=string.format(" | último sinal #%d rgb=%s p=%s",state.id,item.color,vec(part.Position))
        end
        log("SINAL",string.format("#%d %s | rgb=%s mat=%s tr=%.2f | p=%s tam=%s rot=%s dist=%.1f",
            state.id,state.path,item.color,part.Material.Name,part.Transparency,
            vec(part.Position),vec(part.Size),vec(part.Orientation),item.distance))
    end
end

task.spawn(function()
    local nextWall,nextFX,nextMove=0,0,0
    local seeded=false
    while gui.Parent and not started do task.wait(.08) end
    while gui.Parent and started and not done do
        local now=os.clock()
        local r=root()
        if r and not endedAt then
            sampleFloor(r, now)
            if now>=nextMove then
                nextMove=now+.65
                log("MOV",motion(r))
            end
            if now>=nextWall then
                nextWall=now+6
                walls(r.Position)
            end
            if not seeded then
                for _,part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Position-r.Position).Magnitude<=220 then track(part) end
                end
            end
            if now>=nextFX then
                nextFX=now+.08
                sampleSignals(r,not seeded)
                seeded=true
            end
        end
        if (endedAt and now-endedAt>1) or now-started>=duration then finish(); return end
        status.Text=string.format("CAPTURANDO · ID %s · %ds restantes",
            detectedZone or (nearestZone and ("~"..nearestZone)) or "?",
            math.max(0,math.ceil(duration-(now-started))))
        task.wait(.08)
    end
end)
