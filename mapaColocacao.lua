-- Observa somente a etapa de colocar um ovo no cercado.
local player = assert(game:GetService("Players").LocalPlayer)
local playerGui = assert(player:WaitForChild("PlayerGui", 8))
local input = game:GetService("UserInputService")
local old = playerGui:FindFirstChild("MapaColocacao")
if old then old:Destroy() end

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", playerGui, { Name="MapaColocacao", ResetOnSpawn=false, DisplayOrder=70 })
local panel = make("Frame", gui, {
    Position=UDim2.new(0,12,1,-142), Size=UDim2.new(.79,0,0,72),
    BackgroundColor3=Color3.fromRGB(31,13,18), BorderSizePixel=0,
})
make("UISizeConstraint", panel, {MaxSize=Vector2.new(370,72)})
make("UICorner", panel, {CornerRadius=UDim.new(0,8)})
local status = make("TextLabel", panel, {
    Position=UDim2.fromOffset(5,4), Size=UDim2.new(1,-10,0,30),
    Text="MAPA DA COLOCAÇÃO · iniciando", TextSize=13, TextWrapped=true,
    TextColor3=Color3.new(1,1,1), BackgroundTransparency=1, Font=Enum.Font.GothamBold,
})
local view = make("TextButton", panel, {
    Position=UDim2.fromOffset(5,36), Size=UDim2.new(1,-10,0,29),
    Text="Ver log", TextSize=13, TextColor3=Color3.new(1,1,1), BackgroundColor3=Color3.fromRGB(137,29,44),
})
local overlay = make("Frame", gui, {
    Visible=false, Position=UDim2.fromScale(.05,.09), Size=UDim2.fromScale(.90,.77),
    BackgroundColor3=Color3.fromRGB(31,13,18),
})
local close = make("TextButton", overlay, {Text="Fechar",Size=UDim2.new(.5,0,0,33)})
local copy = make("TextButton", overlay, {Text="Copiar tudo",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,0,0,33)})
local scroll = make("ScrollingFrame", overlay, {
    Position=UDim2.fromOffset(0,35),Size=UDim2.new(1,0,1,-35),CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,
})
local output = make("TextBox", scroll, {
    Text="", TextEditable=false, MultiLine=true, TextWrapped=true, ClearTextOnFocus=false,
    AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,-10,0,0), Font=Enum.Font.Code,TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextColor3=Color3.new(1,1,1),BackgroundTransparency=1,
})
close.Activated:Connect(function() overlay.Visible=false end)
view.Activated:Connect(function() overlay.Visible=true end)
copy.Activated:Connect(function()
    if output.Text~="" and type(setclipboard)=="function" and pcall(setclipboard,output.Text) then
        copy.Text="Copiado"
    end
end)

local started = os.clock()
local before = tonumber(player:GetAttribute("PenEggs"))
local lines, connections = {}, {}
local finished, placedAt = false, nil
local function clean(value) return tostring(value):gsub("[\r\n]"," "):sub(1,100) end
local function add(message)
    if not finished and #lines < 95 then
        table.insert(lines, string.format("%.3fs | %s", os.clock()-started, message))
    end
end
local function listen(signal, callback)
    table.insert(connections,signal:Connect(callback))
end
local function root()
    local character=player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function relevant(key)
    local k=key:lower()
    return k:find("egg",1,true) or k:find("item",1,true) or k:find("select",1,true)
        or k:find("slot",1,true) or k:find("equip",1,true) or k=="count" or k=="amount"
end
local function attrs(object)
    local values={}
    for key,value in pairs(object:GetAttributes()) do
        if relevant(key) then table.insert(values,key.."="..clean(value)) end
    end
    table.sort(values)
    return table.concat(values,",")
end
local function snapshot(label)
    local inv=playerGui:FindFirstChild("Inventory")
    local bar=inv and inv:FindFirstChild("Hotbar")
    local character=player.Character
    local r=root()
    add(label.." | PenEggs="..clean(player:GetAttribute("PenEggs")).." | pos="..clean(r and r.Position)
        .." | atributos="..attrs(player))
    for _,tool in ipairs(character and character:GetChildren() or {}) do
        if tool:IsA("Tool") then add("EQUIPADO "..tool.Name.." | "..attrs(tool)) end
    end
    for _,slot in ipairs(bar and bar:GetDescendants() or {}) do
        if slot.Name=="BarSlot" and slot:IsA("GuiObject") and slot.Visible then
            local details={}
            for _,node in ipairs(slot:GetDescendants()) do
                if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Visible and node.Text~="" then
                    table.insert(details,node.Name.."="..clean(node.Text))
                elseif (node:IsA("ImageLabel") or node:IsA("ImageButton")) and node.Visible and node.Image~="" then
                    table.insert(details,node.Name.."="..clean(node.Image))
                end
                local state=attrs(node)
                if state~="" then table.insert(details,node.Name.."["..state.."]") end
                if #details>=10 then break end
            end
            add("SLOT ordem="..slot.LayoutOrder.." x="..math.floor(slot.AbsolutePosition.X)
                .." | "..attrs(slot).." | "..table.concat(details," / "))
        end
    end
end
local function watch(object)
    if object:IsA("GuiButton") and object.Name=="BarSlot"
        and object:GetFullName():find(".Inventory.Hotbar.",1,true) then
        listen(object.Activated,function(touch)
            add("SELEÇÃO "..object:GetFullName().." | ordem="..object.LayoutOrder
                .." | entrada="..clean(touch and touch.UserInputType).." | "..attrs(object))
            task.delay(.16,function() if gui.Parent and not finished then snapshot("APÓS SELEÇÃO") end end)
        end)
    elseif object:IsA("Tool") and player.Character and object:IsDescendantOf(player.Character) then
        add("TOOL EQUIPADO "..object.Name.." | "..attrs(object))
        listen(object.Activated,function() add("TOOL ACTIVATED "..object.Name) end)
    end
end
for _,object in ipairs(playerGui:GetDescendants()) do watch(object) end
for _,object in ipairs(player.Character and player.Character:GetChildren() or {}) do watch(object) end
listen(playerGui.DescendantAdded,watch)
if player.Character then listen(player.Character.ChildAdded,watch) end
listen(input.TouchTapInWorld,function(point,processed)
    add("TOQUE NO MUNDO "..clean(point).." | processado="..clean(processed))
end)
listen(input.TouchTap,function(points,processed)
    add("TOUCH TAP "..clean(points[1]).." | processado="..clean(processed))
end)
listen(player:GetMouse().Button1Down,function() add("MOUSE BUTTON1DOWN") end)
listen(input.InputBegan,function(event,processed)
    if event.UserInputType==Enum.UserInputType.Touch or event.UserInputType==Enum.UserInputType.MouseButton1 then
        add("INPUT BEGAN "..event.UserInputType.Name.." "..clean(event.Position).." | processado="..clean(processed))
    end
end)
listen(player:GetAttributeChangedSignal("PenEggs"),function()
    local after=tonumber(player:GetAttribute("PenEggs"))
    add("PENEGGS "..clean(before).." -> "..clean(after))
    if before and after and after>before and not placedAt then placedAt=os.clock() end
end)
listen(gui.Destroying,function()
    finished=true
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)

snapshot("ANTES")
task.spawn(function()
    while gui.Parent and not finished do
        local elapsed=os.clock()-started
        if (placedAt and os.clock()-placedAt>.55) or elapsed>=65 then
            snapshot(placedAt and "COLOCAÇÃO CONFIRMADA" or "SEM CONFIRMAÇÃO")
            finished=true
            for _,connection in ipairs(connections) do connection:Disconnect() end
            local report="MAPA DA COLOCAÇÃO\n"..table.concat(lines,"\n").."\n=== FIM DO RELATÓRIO ==="
            output.Text=report
            local copied=type(setclipboard)=="function" and pcall(setclipboard,report)
            local saved=type(writefile)=="function" and pcall(writefile,"mapaColocacao.txt",report)
            status.Text=copied and "Relatório copiado. Cole no chat."
                or (saved and "mapaColocacao.txt salvo." or "Captura concluída · Ver log")
            print(report)
            return
        end
        status.Text=string.format("MAPA DA COLOCAÇÃO · GRAVANDO %ds",math.ceil(65-elapsed))
        task.wait(.15)
    end
end)
