-- Inicie no Pântano antes de pegar o ovo. Diagnóstico somente de leitura.
local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = assert(player:WaitForChild("PlayerGui", 8))
local prompts = game:GetService("ProximityPromptService")
local old = playerGui:FindFirstChild("MapaGolpesPantano")
if old then old:Destroy() end
local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {Name="MapaGolpesPantano",ResetOnSpawn=false,DisplayOrder=70})
local panel = make("Frame",gui,{Position=UDim2.new(0,10,1,-132),Size=UDim2.new(.78,0,0,76),
    BackgroundColor3=Color3.fromRGB(28,18,37),BorderSizePixel=0})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(390,76)})
make("UICorner",panel,{CornerRadius=UDim.new(0,8)})
local status=make("TextLabel",panel,{Position=UDim2.fromOffset(5,2),Size=UDim2.new(1,-10,0,37),
    Text="MAPA DE GOLPES · PÂNTANO V1 · toque em Iniciar",TextWrapped=true,TextSize=13,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1)})
local view=make("TextButton",panel,{Position=UDim2.fromOffset(5,41),Size=UDim2.new(.5,-8,0,29),
    Text="Ver relatório",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local record=make("TextButton",panel,{Position=UDim2.new(.5,3,0,41),Size=UDim2.new(.5,-8,0,29),
    Text="Iniciar",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
local overlay=make("Frame",gui,{Visible=false,Position=UDim2.fromScale(.05,.08),Size=UDim2.fromScale(.9,.77),
    BackgroundColor3=Color3.fromRGB(28,18,37)})
local close=make("TextButton",overlay,{Text="Fechar",Size=UDim2.new(.5,0,0,33)})
local copy=make("TextButton",overlay,{Text="Selecionar texto",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,0,0,33)})
local scroll=make("ScrollingFrame",overlay,{Position=UDim2.fromOffset(0,35),Size=UDim2.new(1,0,1,-35),
    CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
local output=make("TextBox",scroll,{Text="",TextEditable=true,MultiLine=true,TextWrapped=true,ClearTextOnFocus=false,
    Size=UDim2.new(1,-10,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    Font=Enum.Font.Code,TextSize=13,TextColor3=Color3.new(1,1,1)})
close.Activated:Connect(function() overlay.Visible=false end)
view.Activated:Connect(function() if output.Text~="" then overlay.Visible=true end end)
copy.Activated:Connect(function()
    if not overlay.Visible or output.Text=="" then return end
    output:CaptureFocus()
    output.CursorPosition=#output.Text+1
    output.SelectionStart=1
    copy.Text="Use Copiar do teclado"
end)

local started
local duration=120
local lines,fx,moves,pieces,connections={},{},{},{},{}
local dropped=0
local done=false
local carryAt, endedAt
local function vec(v) return v and string.format("%.1f,%.1f,%.1f",v.X,v.Y,v.Z) or "-" end
local function log(kind, message)
    if not started or done then return end
    local rows=kind=="FX" and fx or (kind=="MOV" and moves)
        or ((kind=="PEÇA" or kind=="TRAJETO" or kind=="FIM PEÇA") and pieces) or lines
    local limit=rows==pieces and 110 or 100
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
    if not part:IsA("BasePart") then return end
    local r=root()
    if fxFolder(part) or (r and (part.Position-r.Position).Magnitude<=200) then track(part) end
end)
listen(workspace.DescendantRemoving,function(part)
    local state=watched[part]
    if state and state.logged then log("FIM PEÇA","#"..state.id) end
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
local speedHumanoid, speedConnection
local function trackSpeed(r)
    local humanoid=r and r.Parent and r.Parent:FindFirstChildOfClass("Humanoid")
    if humanoid==speedHumanoid then return end
    if speedConnection then speedConnection:Disconnect() end
    speedHumanoid=humanoid
    if not humanoid then return end
    local previous=humanoid.WalkSpeed
    log("VELOCIDADE INICIAL",motion(r))
    speedConnection=humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local current=humanoid.WalkSpeed
        log("VELOCIDADE",string.format("%.1f -> %.1f | %s",previous,current,motion(r)))
        previous=current
    end)
    table.insert(connections,speedConnection)
end
local hp=player:GetAttribute("BossHP")
listen(player:GetAttributeChangedSignal("BossHP"),function()
    local value=player:GetAttribute("BossHP")
    local r=root()
    if type(hp)=="number" and type(value)=="number" and hp>=0 and value>=0 and value<hp then
        local context = lastGroupsAt and os.clock()-lastGroupsAt <= 1
            and string.format(" | FX %.2fs atrás: %s",os.clock()-lastGroupsAt,lastGroups) or ""
        log("DANO",string.format("%.2f -> %.2f | %s%s",hp,value,motion(r),context))
    elseif type(value)~="number" or value<0 then
        log("FIM BOSS","BossHP="..tostring(value))
    elseif type(hp)~="number" or hp<0 then
        log("INÍCIO BOSS","BossHP="..tostring(value))
    end
    hp=value
end)
listen(player:GetAttributeChangedSignal("Carrying"),function()
    if not started or done then return end
    local r=root()
    log("TRANSPORTE",tostring(player:GetAttribute("Carrying")).." | pos="..vec(r and r.Position))
    if carrying() then carryAt,endedAt=os.clock(),nil
    elseif carryAt then endedAt=os.clock() end
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
    for _,row in ipairs(pieces) do table.insert(lines,row) end
    table.sort(lines,function(a,b) return a.t<b.t end)
    local report={"MAPA DE GOLPES · PÂNTANO V1 | eventos excedentes="..dropped}
    for _,row in ipairs(lines) do table.insert(report,row.text) end
    table.insert(report,"=== FIM DO RELATÓRIO ===")
    local text=table.concat(report,"\n")
    output.Text=text
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
        status.Text="Inicie antes de pegar o ovo do Pântano"
        return
    end
    started=os.clock()
    record.Text="Encerrar"
    trackSpeed(root())
    log("INÍCIO",motion(root()).." | BossHP="..tostring(hp))
end)

task.spawn(function()
    local lastWall,lastMode,nextFX,nextModel=0,nil,0,0
    local nextMove,seeded=0,false
    local nextGroup=0
    local effectStates={}
    local nextAttributes=0
    local lastInventory
    while gui.Parent and not started do task.wait(.12) end
    while gui.Parent and started and not done do
        local now=os.clock()
        local r=root()
        trackSpeed(r)
        if r and now>=nextMove then
            nextMove=now+(carryAt and .42 or 1.2)
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
        if r and carryAt and now>=nextAttributes then
            nextAttributes=now+.15
            for _,owner in ipairs({player,r.Parent,speedHumanoid}) do
                local old=effectStates[owner]
                local current={}
                for key,value in pairs(owner:GetAttributes()) do
                    local name=key:lower()
                    if name:find("slow",1,true) or name:find("speed",1,true)
                        or name:find("mud",1,true) or name:find("stun",1,true) then
                        current[key]=tostring(value)
                        if not old or old[key]~=current[key] then log("EFEITO",owner.ClassName.."."..key.."="..current[key]) end
                    end
                end
                for key in pairs(old or {}) do
                    if not current[key] then log("EFEITO",owner.ClassName.."."..key.." removido") end
                end
                effectStates[owner]=current
            end
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
            local dodge=playerGui:FindFirstChild("EsquivaFaixas")
            for _,obj in ipairs(dodge and dodge:GetDescendants() or {}) do
                if obj:IsA("TextLabel") and obj.Text:match("^HP ") then
                    local mode=obj.Text:match("\n([^·\n]+)")
                    if mode and mode~=lastMode then lastMode=mode; log("ESTADO ESQUIVA",mode) end
                    break
                end
            end
            if now>=nextFX then
                nextFX=now+.08
                local groups={}
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
                        if near and (knownFX or (red and thin<=2 and math.abs(delta.Y)<=16))
                            and span>=4 and part.Transparency<.98 and not state.logged then
                            state.logged=true
                            state.sampleAt,state.position,state.size=os.clock(),part.Position,size
                            log("PEÇA",string.format("#%d %s | p=%s tam=%s rot=%s rgb=%d,%d,%d tr=%.2f col=%s",
                                state.id,state.path,vec(part.Position),vec(size),vec(part.Orientation),
                                math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5),
                                part.Transparency,tostring(part.CanCollide)))
                        elseif near and state.logged and now-state.sampleAt>=.35
                            and ((part.Position-state.position).Magnitude>=3 or (size-state.size).Magnitude>=2) then
                            state.sampleAt,state.position,state.size=now,part.Position,size
                            log("TRAJETO",string.format("#%d p=%s tam=%s rot=%s",state.id,vec(part.Position),vec(size),vec(part.Orientation)))
                        end
                        if (red or knownFX) and near and part.Transparency<.98 and span>=1
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
                                group.distance,group.position,group.size,group.rotation=distance,position,size,part.Orientation
                            end
                        end
                    else watched[part]=nil end
                end
                local summaries={}
                for key,group in pairs(groups) do
                    table.insert(summaries,string.format("%s n=%d X[%.0f,%.0f] Z[%.0f,%.0f] prox=%.1f p=%s tam=%s rot=%s",
                        key,group.count,group.minX,group.maxX,group.minZ,group.maxZ,group.distance,
                        vec(group.position),vec(group.size),vec(group.rotation)))
                end
                if #summaries>0 then
                    table.sort(summaries)
                    lastGroups,lastGroupsAt=table.concat(summaries,"; "),now
                    if now>=nextGroup then
                        log("FX",lastGroups)
                        nextGroup=now+.65
                    end
                else
                    nextGroup=0
                end
            end
        end
        if (endedAt and now-endedAt>5) or now-started>=duration then finish(); return end
        status.Text=string.format("MAPA DE GOLPES · PÂNTANO V1 · %s · %ds",
            carryAt and "lutando" or "aguardando ovo",math.max(0,math.ceil(duration-(now-started))))
        task.wait(.08)
    end
end)
