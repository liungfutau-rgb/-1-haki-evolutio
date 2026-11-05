-- HAKI EVOLUTION HUB V1.0
-- Client-side utility. Object identification is heuristic and may require manual selection.
-- Intended for user-authorized testing. Does not bypass server-side checks.

if getgenv and getgenv().HakiEvolutionHub_Stop then
    pcall(getgenv().HakiEvolutionHub_Stop)
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
local guiParent = (gethui and gethui()) or game:GetService('CoreGui')
local state = {
    king = false, trainAfterDeath = true, autoTrain = false,
    bestTraining = true, autoRebirth = false,
    kingTarget = nil, trainingTarget = nil, trainingOptions = {},
    deadAtKing = false, mode = 'Idle', alive = true, stopped = false,
}
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn); table.insert(connections, c); return c
end
local function root()
    local c = player.Character
    return c and c:FindFirstChild('HumanoidRootPart')
end
local function humanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass('Humanoid')
end
local function posOf(obj)
    if not obj then return nil end
    if obj:IsA('BasePart') then return obj.Position end
    if obj:IsA('Model') then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart', true)
        return p and p.Position
    end
    if obj:IsA('Attachment') then return obj.WorldPosition end
    return nil
end
local function locOf(obj)
    if not obj then return nil end
    if obj:IsA('BasePart') then return obj end
    if obj:IsA('Attachment') then return obj.Parent end
    return obj:IsA('Model') and (obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart', true)) or nil
end
local function tp(obj)
    local hrp, target = root(), locOf(obj)
    if not hrp or not target then return false end
    local hum = humanoid()
    if not hum or hum.Health <= 0 then return false end
    hrp.CFrame = target.CFrame * CFrame.new(0, math.max(4, target.Size.Y / 2 + 3), 0)
    return true
end
local function nameOf(o)
    return o.Name:lower():gsub('[^%w]', '')
end
local function isKing(o)
    local n = nameOf(o)
    return n:find('kingofthehill', 1, true) or n:find('kinghill', 1, true) or n:find('koth', 1, true)
end
local function isTraining(o)
    local n = nameOf(o)
    return n:find('training', 1, true) or n:find('punchingbag', 1, true)
        or n:find('trainbag', 1, true) or n:find('punchbag', 1, true)
end
local function scoreTraining(o)
    local n = o.Name
    local num = tonumber(n:match('(%d+)%D*$')) or tonumber(n:match('(%d+)')) or 0
    for _, key in ipairs({'RequiredHaki','Requirement','Level','UnlockLevel','Cost'}) do
        local attr = o:GetAttribute(key)
        if type(attr) == 'number' then num = math.max(num, attr) end
        local v = o:FindFirstChild(key)
        if v and (v:IsA('IntValue') or v:IsA('NumberValue')) then num = math.max(num, v.Value) end
    end
    return num
end
local function scan()
    local kingCandidates, options, seen = {}, {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA('BasePart') or obj:IsA('Model') then
            if posOf(obj) then
                if isKing(obj) then table.insert(kingCandidates, obj) end
                if isTraining(obj) and not seen[obj] then
                    -- Avoid listing every part of a training model where its parent qualifies.
                    local parent = obj.Parent
                    if not (parent and parent:IsA('Model') and isTraining(parent)) then
                        table.insert(options, obj); seen[obj] = true
                    end
                end
            end
        end
    end
    table.sort(options, function(a,b)
        local sa, sb = scoreTraining(a), scoreTraining(b)
        if sa == sb then return a:GetFullName() < b:GetFullName() end
        return sa > sb
    end)
    table.sort(kingCandidates, function(a,b)
        local an, bn = nameOf(a), nameOf(b)
        local ax = an == 'kingofthehill' and 10 or 0
        local bx = bn == 'kingofthehill' and 10 or 0
        return ax > bx
    end)
    state.kingTarget = kingCandidates[1]
    state.trainingOptions = options
    if state.bestTraining or not (state.trainingTarget and state.trainingTarget.Parent) then
        state.trainingTarget = options[1]
    end
end

local gui = Instance.new('ScreenGui')
gui.Name = 'HakiEvolutionHubV1'
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent

local function corner(o, r)
    local x=Instance.new('UICorner'); x.CornerRadius=UDim.new(0,r); x.Parent=o
end
local function stroke(o, c)
    local x=Instance.new('UIStroke'); x.Color=c; x.Thickness=1; x.Transparency=.35; x.Parent=o
end
local function label(parent, text, size, color, bold)
    local x=Instance.new('TextLabel')
    x.BackgroundTransparency=1; x.Text=text; x.TextColor3=color or Color3.fromRGB(231,235,255)
    x.TextSize=size or 14; x.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    x.TextXAlignment=Enum.TextXAlignment.Left; x.Parent=parent
    return x
end
local function button(parent, text, color)
    local x=Instance.new('TextButton'); x.Text=text; x.TextColor3=Color3.new(1,1,1)
    x.TextSize=13; x.Font=Enum.Font.GothamBold
    x.BackgroundColor3=color or Color3.fromRGB(48,51,87); x.AutoButtonColor=true
    x.Parent=parent; corner(x,8); return x
end
local base=Instance.new('Frame')
base.Name='Window'; base.Size=UDim2.fromOffset(350,420); base.Position=UDim2.new(.5,-175,.5,-210)
base.BackgroundColor3=Color3.fromRGB(18,19,34); base.BorderSizePixel=0; base.Parent=gui
corner(base,14); stroke(base,Color3.fromRGB(145,93,255))
local header=Instance.new('Frame'); header.Size=UDim2.new(1,0,0,54); header.BackgroundColor3=Color3.fromRGB(34,29,62)
header.Parent=base; corner(header,14)
local title=label(header,'⚡ HAKI EVOLUTION HUB',16,Color3.fromRGB(243,231,255),true)
title.Position=UDim2.fromOffset(14,8);title.Size=UDim2.new(1,-64,0,24)
local subtitle=label(header,'V1  •  KING + TRAINING',10,Color3.fromRGB(183,171,221))
subtitle.Position=UDim2.fromOffset(15,31); subtitle.Size=UDim2.new(1,-70,0,14)
local mini=button(header,'—',Color3.fromRGB(90,60,151)); mini.Size=UDim2.fromOffset(35,32)
mini.Position=UDim2.new(1,-43,0,11)
local scroll=Instance.new('ScrollingFrame')
scroll.Size=UDim2.new(1,-20,1,-112); scroll.Position=UDim2.fromOffset(10,62)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
scroll.ScrollBarThickness=3;scroll.ScrollBarImageColor3=Color3.fromRGB(140,89,236)
scroll.CanvasSize=UDim2.new(); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.Parent=base
local layout=Instance.new('UIListLayout'); layout.Padding=UDim.new(0,7); layout.Parent=scroll
local function section(t)
    local x=label(scroll,t,13,Color3.fromRGB(168,137,255),true);x.Size=UDim2.new(1,-6,0,23); return x
end
local function toggle(t, field)
    local row=Instance.new('Frame'); row.BackgroundColor3=Color3.fromRGB(29,31,53)
    row.Size=UDim2.new(1,-5,0,41);row.Parent=scroll;corner(row,9)
    local txt=label(row,t,12);txt.Size=UDim2.new(1,-104,1,0);txt.Position=UDim2.fromOffset(12,0)
    local b=button(row,'OFF',Color3.fromRGB(95,59,84)); b.Size=UDim2.fromOffset(65,27)
    b.Position=UDim2.new(1,-75,.5,-13)
    local function update()
        b.Text=state[field] and 'ON' or 'OFF'
        b.BackgroundColor3=state[field] and Color3.fromRGB(55,145,114) or Color3.fromRGB(95,59,84)
    end
    connect(b.MouseButton1Click,function()
        state[field]=not state[field]
        if field=='king' then
            if state.king then state.mode='King';state.deadAtKing=false
            elseif state.mode=='King' then state.mode='Idle' end
        elseif field=='autoTrain' and state.autoTrain then
            state.king=false; state.mode='Training'
            if state.trainingTarget then tp(state.trainingTarget) end
        elseif field=='bestTraining' and state.bestTraining then
            scan()
        end
        update()
    end)
    update();return row
end
local function action(t, callback)
    local b=button(scroll,t,Color3.fromRGB(67,50,122));b.Size=UDim2.new(1,-5,0,34)
    connect(b.MouseButton1Click,callback);return b
end
section('👑 KING OF THE HILL')
toggle('Auto King of the Hill','king')
toggle('Training setelah mati','trainAfterDeath')
section('🥊 TRAINING')
toggle('Auto Training (prompt terdekat)','autoTrain')
toggle('Pilih training terbaik otomatis','bestTraining')
local selected=label(scroll,'Training: belum dipindai',11,Color3.fromRGB(204,208,234))
selected.Size=UDim2.new(1,-8,0,37);selected.TextWrapped=true
local status=label(base,'Status: Siap',11,Color3.fromRGB(178,205,196))
status.Position=UDim2.new(0,13,1,-46);status.Size=UDim2.new(1,-26,0,16)
local count=label(base,'Scan: 0 training',10,Color3.fromRGB(160,160,190))
count.Position=UDim2.new(0,13,1,-27);count.Size=UDim2.new(1,-26,0,15)
local function updateSelected()
    selected.Text='Training: '..(state.trainingTarget and state.trainingTarget.Name or 'tidak ditemukan')
    count.Text=string.format('Scan: %d training  |  King: %s',#state.trainingOptions,state.kingTarget and 'ada' or 'tidak ada')
end
local function rescan()
    scan(); updateSelected()
end
action('🔎 RESCAN LOKASI',rescan)
action('📍 PILIH TRAINING BERIKUTNYA',function()
    local a=state.trainingOptions
    if #a==0 then return end
    local index=table.find(a,state.trainingTarget) or 0
    state.trainingTarget=a[index % #a + 1]
    state.bestTraining=false
    updateSelected()
end)
action('🚀 TELEPORT KE TRAINING',function()
    if state.trainingTarget then
        if tp(state.trainingTarget) then state.mode='Training';state.king=false end
    end
end)
action('👑 TELEPORT KE KING',function()
    if state.kingTarget and tp(state.kingTarget) then state.mode='King' end
end)
section('ℹ️ CATATAN')
local info=label(scroll,'Scan berdasarkan nama objek. "Terbaik" adalah perkiraan dari level/angka, bukan jaminan sudah terbuka. Gunakan pilih training jika hasil keliru.',11,Color3.fromRGB(164,168,198))
info.Size=UDim2.new(1,-10,0,72);info.TextWrapped=true

local expanded=true
connect(mini.MouseButton1Click,function()
    expanded=not expanded
    base.Size=expanded and UDim2.fromOffset(350,420) or UDim2.fromOffset(350,54)
    scroll.Visible=expanded;status.Visible=expanded;count.Visible=expanded
    mini.Text=expanded and '—' or '+'
end)
local dragging,startMouse,startPos=false,nil,nil
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;startMouse=input.Position;startPos=base.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if dragging and startMouse and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-startMouse
        base.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)

local deathConnection
local function hookCharacter(character)
    local h=character:WaitForChild('Humanoid',10)
    if not h then return end
    state.alive=h.Health>0
    if deathConnection then deathConnection:Disconnect() end
    deathConnection=h.Died:Connect(function()
        state.alive=false
        if state.mode=='King' or state.king then
            state.deadAtKing=true
            state.king=false
            state.mode='WaitingRespawn'
        end
    end)
    if state.deadAtKing and state.trainAfterDeath then
        task.defer(function()
            local hrp=character:WaitForChild('HumanoidRootPart',10)
            if not hrp or state.stopped then return end
            task.wait(1.5)
            scan(); updateSelected()
            if state.trainingTarget and tp(state.trainingTarget) then
                state.mode='Training';state.autoTrain=true
            else
                state.mode='TrainingNotFound'
            end
            state.deadAtKing=false
        end)
    elseif state.deadAtKing then
        state.deadAtKing=false;state.mode='Idle'
    end
end
if player.Character then task.spawn(hookCharacter,player.Character) end
connect(player.CharacterAdded,hookCharacter)

-- Prompt-based training only (where the game exposes a client-usable ProximityPrompt).
local function interactTraining()
    if not state.trainingTarget or not fireproximityprompt then return end
    local hrp=root();if not hrp then return end
    for _, obj in ipairs(state.trainingTarget:GetDescendants()) do
        if obj:IsA('ProximityPrompt') then
            local part=obj.Parent
            local pp=(part and (part:IsA('BasePart') and part.Position or part:IsA('Attachment') and part.WorldPosition))
            if pp and (hrp.Position-pp).Magnitude <= (obj.MaxActivationDistance+2) then
                pcall(fireproximityprompt,obj)
                break
            end
        end
    end
end
local function loop()
    local nextKing=0
    while not state.stopped do
        task.wait(.65)
        local hrp=root();local h=humanoid()
        if not hrp or not h or h.Health<=0 then
            status.Text='Status: Menunggu respawn'
        else
            if state.king and state.mode~='Training' then
                state.mode='King'
                if os.clock()>=nextKing then
                    if state.kingTarget and state.kingTarget.Parent then
                        local kpos=posOf(state.kingTarget)
                        if kpos and (hrp.Position-kpos).Magnitude>13 then tp(state.kingTarget) end
                    end
                    nextKing=os.clock()+3
                end
            end
            if state.autoTrain and state.mode=='Training' then interactTraining() end
            status.Text='Status: '..state.mode
        end
    end
end
rescan()
task.spawn(loop)
local function stop()
    state.stopped=true
    if deathConnection then deathConnection:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end
if getgenv then getgenv().HakiEvolutionHub_Stop=stop end
print('[Haki Evolution Hub] Loaded. Scan: '..tostring(#state.trainingOptions)..' training locations.')
