-- Diagnóstico somente de leitura. Registre os momentos na ordem indicada.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local playerGui = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
local old = playerGui:FindFirstChild("MapaArea1")
if old then old:Destroy() end
local function make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, {Name="MapaArea1", ResetOnSpawn=false, DisplayOrder=60})
local panel = make("Frame", gui, {Position=UDim2.fromOffset(12,90), Size=UDim2.new(0.85,0,0,128),
    BackgroundColor3=Color3.fromRGB(22,30,45)})
make("UISizeConstraint", panel, {MaxSize=Vector2.new(410,128)})
make("UICorner", panel, {CornerRadius=UDim.new(0,10)})
local function control(class, text, x, y, width, height)
    return make(class,panel,{Text=text,Position=UDim2.new(x,5,0,y),Size=UDim2.new(width,-10,0,height),
        TextWrapped=true,TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),
        BackgroundColor3=Color3.fromRGB(49,76,111),BackgroundTransparency=class=="TextLabel" and 1 or 0})
end
control("TextLabel","MAPEAMENTO · ÁREA 1",0,4,1,22)
local status = control("TextLabel","Comece ao lado de um ovo, antes de pegar.",0,30,1,38)
local capture = control("TextButton","1 · Antes de pegar",0,78,0.62,41)
local export = control("TextButton","Exportar",0.62,78,0.38,41)
local overlay = make("Frame",gui,{Visible=false,Position=UDim2.fromScale(0.05,0.08),
    Size=UDim2.fromScale(0.90,0.78),BackgroundColor3=Color3.fromRGB(20,28,42)})
local close = make("TextButton",overlay,{Text="Fechar",Size=UDim2.new(0.48,0,0,36),TextSize=15})
local nextPage = make("TextButton",overlay,{Text="Copiar próxima",Position=UDim2.new(0.5,0,0,0),
    Size=UDim2.new(0.5,0,0,36),TextSize=15})
local scroll = make("ScrollingFrame",overlay,{Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,1,-39),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),BackgroundTransparency=1})
local box = make("TextBox",scroll,{Text="",TextEditable=false,MultiLine=true,TextWrapped=true,
    ClearTextOnFocus=false,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,-10,0,0),
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextColor3=Color3.new(1,1,1),Font=Enum.Font.Code,TextSize=13,BackgroundTransparency=1})
close.Activated:Connect(function() overlay.Visible=false end)

local steps = {"Antes de pegar", "Ovo na mão", "Perto da borda por dentro", "Resultado da tentativa"}
local phase, started = 1, os.clock()
local report, events, connections = {}, {}, {}
local dropped = 0
local function vec(v)
    return v and string.format("%.2f,%.2f,%.2f",v.X,v.Y,v.Z) or "-"
end
local function rootPosition()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end
local function clean(value)
    return tostring(value):gsub("[\r\n]"," "):sub(1,180)
end
local function relevant(key)
    local text=key:lower()
    for _, word in ipairs({"egg","ovo","rar","tier","boss","area","zone","carry","time","countdown",
        "image","icon","thumb","health","hp","reward","invulner","shield","safe","bound","arena"}) do
        if text:find(word,1,true) then return true end
    end
    return false
end
local function attributes(object)
    local out={}
    for key,value in pairs(object:GetAttributes()) do
        if relevant(key) then table.insert(out,key.."="..clean(value)) end
    end
    for _,child in ipairs(object:GetChildren()) do
        if child:IsA("ValueBase") and relevant(child.Name) then
            table.insert(out,child.Name.."="..clean(child.Value))
        end
    end
    table.sort(out)
    return table.concat(out,";")
end
local function event(message)
    if phase==1 or phase>#steps then return end
    if #events>=240 then dropped=dropped+1; return end
    table.insert(events,string.format("%.3fs | %s",os.clock()-started,message))
end
local function pathOf(object) return object:GetFullName() end
local function positionOf(object)
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Attachment") then return object.WorldPosition end
    if object:IsA("Model") then return object:GetPivot().Position end
end
local function geometry(part)
    return string.format("%s | pos=%s tam=%s rot=%s collide=%s query=%s touch=%s tr=%.2f | %s",
        pathOf(part),vec(part.Position),vec(part.Size),vec(part.Orientation),tostring(part.CanCollide),
        tostring(part.CanQuery),tostring(part.CanTouch),part.Transparency,attributes(part))
end
local function track(signal, callback)
    table.insert(connections,signal:Connect(callback))
end
track(player.AttributeChanged,function(key)
    if relevant(key) then event("PLAYER "..key.."="..clean(player:GetAttribute(key)).." pos="..vec(rootPosition())) end
end)
track(player.CharacterAdded,function() event("CHARACTER NOVO") end)
track(workspace.DescendantAdded,function(object)
    if object:IsA("BasePart") and pathOf(object):find("CarryWalls",1,true) then
        event("JAULA + "..geometry(object))
    end
end)
track(workspace.DescendantRemoving,function(object)
    if object:IsA("BasePart") and pathOf(object):find("CarryWalls",1,true) then
        event("JAULA - "..pathOf(object))
    end
end)
track(gui.Destroying,function()
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)

local function eggText(text)
    text=text:gsub("(%l)(%u)","%1 %2"):lower()
    return text:find("%f[%a]eggs?%f[%A]") or text:find("%f[%a]ovos?%f[%A]")
end
local function named(object)
    local name=object.Name:lower()
    for _,word in ipairs({"carrywall","noreturn","arena","zone","area","área","bound","cage","egg","ovo"}) do
        if name:find(word,1,true) then return true end
    end
    return false
end

local function snapshot(label)
    local root = rootPosition()
    table.insert(report,string.format("\n=== %s | %.3fs | pos=%s ===",label,os.clock()-started,vec(root)))
    table.insert(report,"PLAYER | "..attributes(player))
    if player.Character then table.insert(report,"CHARACTER | "..attributes(player.Character)) end
    local buckets={JAULA={}, INTERACAO={}, OVO={}, ESTRUTURA={}}
    local function add(kind, text, distance)
        table.insert(buckets[kind],{text=text,distance=distance or math.huge})
    end
    for _, object in ipairs(workspace:GetDescendants()) do
        local path = pathOf(object)
        local pos = positionOf(object)
        local distance = root and pos and (root-pos).Magnitude or nil
        if object:IsA("ProximityPrompt") then
            local host=object.Parent
            local target=positionOf(host)
            local d=root and target and (root-target).Magnitude or nil
            if eggText(path.." "..object.ActionText.." "..object.ObjectText) or (d and d<85) then
                add("INTERACAO",string.format("%s | objeto=%s ação=%s hold=%.2fs ativo=%s pos=%s | %s | pai:%s",
                    path,clean(object.ObjectText),clean(object.ActionText),object.HoldDuration,tostring(object.Enabled),
                    vec(target),attributes(object),attributes(host)),d)
            end
        elseif object:IsA("BasePart") and path:find("CarryWalls",1,true) then
            add("JAULA",geometry(object),distance)
        elseif object:IsA("Model") or object:IsA("BasePart") or object:IsA("Folder") then
            if object:GetAttribute("IsEgg")==true or object:GetAttribute("EggId")~=nil
                or ((object:IsA("Model") or object:IsA("BasePart")) and eggText(object.Name)) then
                local image=object:FindFirstChildWhichIsA("Decal",true)
                local mesh=object:IsA("MeshPart") and object or object:FindFirstChildWhichIsA("MeshPart",true)
                add("OVO",path.." | "..object.ClassName.." pos="..vec(pos).." | "..attributes(object)
                    .." | decal="..(image and clean(image.Texture) or "-")
                    .." | mesh="..(mesh and clean(mesh.MeshId) or "-")
                    .." | textura="..(mesh and clean(mesh.TextureID) or "-"),distance)
            elseif named(object) and not path:find("BossFX",1,true) then
                add("ESTRUTURA",object:IsA("BasePart") and geometry(object)
                    or (path.." | "..object.ClassName.." pos="..vec(pos).." | "..attributes(object)),distance)
            end
        end
    end
    local limits={JAULA=70,INTERACAO=35,OVO=35,ESTRUTURA=35}
    for _, kind in ipairs({"JAULA","INTERACAO","OVO","ESTRUTURA"}) do
        local rows=buckets[kind]
        table.sort(rows,function(a,b)
            if a.distance~=b.distance then return a.distance<b.distance end
            return a.text<b.text
        end)
        table.insert(report,string.format("[%s] total=%d exibidos=%d",kind,#rows,math.min(#rows,limits[kind])))
        for i=1,math.min(#rows,limits[kind]) do table.insert(report,rows[i].text) end
    end
end

local capturing=false
capture.Activated:Connect(function()
    if phase>#steps or capturing then return end
    capturing=true
    status.Text="Capturando "..steps[phase].."..."
    local ok,err=pcall(snapshot,steps[phase])
    if ok then
        phase=phase+1
        capture.Text=steps[phase] and (phase.." · "..steps[phase]) or "Concluído"
        status.Text=steps[phase] and ("Próxima captura: "..steps[phase]) or "Capturas concluídas. Toque em Exportar."
    else
        status.Text="Falha na captura. Veja o console."
        warn("[Mapa Área 1] "..tostring(err))
    end
    capturing=false
end)

local pages, index = {}, 1
local function show()
    box.Text=pages[index]
    scroll.CanvasPosition=Vector2.zero
    overlay.Visible=true
    local copied=type(setclipboard)=="function" and pcall(setclipboard,box.Text)
    close.Text=string.format("%s %d/%d · Fechar",copied and "Copiada" or "Parte",index,#pages)
end
nextPage.Activated:Connect(function()
    if #pages>0 then index=index%#pages+1; show() end
end)
export.Activated:Connect(function()
    local lines={}
    for _,line in ipairs(report) do table.insert(lines,line) end
    table.insert(lines,"\n=== EVENTOS ENTRE CAPTURAS | omitidos="..dropped.." ===")
    for _,line in ipairs(events) do table.insert(lines,line) end
    local text=table.concat(lines,"\n")
    local saved=type(writefile)=="function" and pcall(writefile,"mapaArea1.txt",text)
    if saved then status.Text="Arquivo mapaArea1.txt salvo no Delta." end
    pages={}
    local chunk, size={},0
    for _,line in ipairs(lines) do
        if size+#line+1>4700 and #chunk>0 then
            table.insert(pages,table.concat(chunk,"\n")); chunk,size={},0
        end
        table.insert(chunk,line); size=size+#line+1
    end
    table.insert(pages,table.concat(chunk,"\n"))
    for i,page in ipairs(pages) do pages[i]=string.format("MAPA ÁREA 1 | Parte %d/%d\n%s",i,#pages,page) end
    index=1
    show()
end)
