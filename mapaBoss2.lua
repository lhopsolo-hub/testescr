-- Execute na Área 2, antes de pegar o ovo. O coletor não move o personagem.
local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = assert(player:WaitForChild("PlayerGui", 8))
local prompts = game:GetService("ProximityPromptService")
local old = playerGui:FindFirstChild("MapaBoss2")
if old then old:Destroy() end
local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {Name="MapaBoss2",ResetOnSpawn=false,DisplayOrder=70})
local panel = make("Frame",gui,{Position=UDim2.new(0,10,1,-132),Size=UDim2.new(.78,0,0,76),
    BackgroundColor3=Color3.fromRGB(28,18,37),BorderSizePixel=0})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(390,76)})
make("UICorner",panel,{CornerRadius=UDim.new(0,8)})
local status=make("TextLabel",panel,{Position=UDim2.fromOffset(5,2),Size=UDim2.new(1,-10,0,37),
    Text="MAPA DO BOSS · V2 manual · iniciando",TextWrapped=true,TextSize=13,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1)})
local view=make("TextButton",panel,{Position=UDim2.fromOffset(5,41),Size=UDim2.new(1,-10,0,29),
    Text="Ver relatório",BackgroundColor3=Color3.fromRGB(88,49,132),TextColor3=Color3.new(1,1,1)})
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

local started=os.clock()
local lines,fx,connections={},{},{}
local dropped=0
local done=false
local carryAt, endedAt
local function vec(v) return v and string.format("%.1f,%.1f,%.1f",v.X,v.Y,v.Z) or "-" end
local function log(kind, message)
    local rows=kind=="FX" and fx or lines
    if #rows>=(kind=="FX" and 44 or 85) then dropped=dropped+1; return end
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
local function track(part)
    if part:IsA("BasePart") then watched[part]=true end
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
listen(workspace.DescendantRemoving,function(part) watched[part]=nil end)

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
local hp=player:GetAttribute("BossHP")
listen(player:GetAttributeChangedSignal("BossHP"),function()
    local value=player:GetAttribute("BossHP")
    local r=root()
    if type(hp)=="number" and type(value)=="number" and hp>=0 and value>=0 and value<hp then
        log("DANO",string.format("%.2f -> %.2f | pos=%s",hp,value,vec(r and r.Position)))
    elseif type(value)~="number" or value<0 then
        log("FIM BOSS","BossHP="..tostring(value))
    end
    hp=value
end)
listen(player:GetAttributeChangedSignal("Carrying"),function()
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
    done=true
    for _,connection in ipairs(connections) do connection:Disconnect() end
    for _,row in ipairs(fx) do table.insert(lines,row) end
    table.sort(lines,function(a,b) return a.t<b.t end)
    local report={"MAPA DO BOSS · V2 manual | eventos excedentes="..dropped}
    for _,row in ipairs(lines) do table.insert(report,row.text) end
    table.insert(report,"=== FIM DO RELATÓRIO ===")
    local text=table.concat(report,"\n")
    output.Text=text
    local saved=type(writefile)=="function" and pcall(writefile,"mapaBoss2.txt",text)
    status.Text=saved and "mapaBoss2.txt salvo · Ver relatório" or "Captura concluída · Ver relatório"
end
log("INÍCIO","BossHP="..tostring(hp))
if carrying() then carryAt=os.clock() end
task.spawn(function()
    local lastWall,lastMode,nextFX,nextModel=0,nil,0,0
    local seen={}
    while gui.Parent and not done do
        local now=os.clock()
        local r=root()
        if r and carryAt and not endedAt then
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
                nextFX=now+.18
                for part in pairs(watched) do
                    if part.Parent then
                        local c,size=part.Color,part.Size
                        local thin=math.min(size.X,size.Y,size.Z)
                        local span=math.max(size.X,size.Y,size.Z)
                        local red=c.R>.45 and c.R>c.G*1.35 and c.R>c.B*1.35
                        if red and part.Transparency<.99 and span>=3 and (part.Position-r.Position).Magnitude<160+span/2 then
                            local prior=seen[part]
                            if not prior or (part.Position-prior.pos).Magnitude>=5 or (size-prior.size).Magnitude>=5 then
                                seen[part]={pos=part.Position,size=size}
                                log("FX",string.format("%s | pos=%s tam=%s rot=%s tr=%.2f rgb=%d,%d,%d fino=%.1f",
                                    part:GetFullName(),vec(part.Position),vec(size),vec(part.Orientation),part.Transparency,
                                    math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5),thin))
                            end
                        end
                    else watched[part]=nil; seen[part]=nil end
                end
            end
        end
        if (endedAt and now-endedAt>1) or now-started>=85 then finish(); return end
        status.Text=string.format("MAPA DO BOSS · V2 manual · %s · %ds",
            carryAt and "lutando" or "aguardando ovo",math.max(0,math.ceil(85-(now-started))))
        task.wait(.12)
    end
end)
