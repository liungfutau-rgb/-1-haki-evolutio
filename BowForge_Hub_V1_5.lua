-- +1 Bow Forge Hub V1.5 - Continuous Lane Movement + Aim Diagnostics
-- Delta compatible UI, no assumed private remote names or server bypasses.
-- Features that need the game's exact UI are deliberately marked 'needs mapping'.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local VirtualUser=game:GetService('VirtualUser')
local TweenService=game:GetService('TweenService')
local UIS=game:GetService('UserInputService')
local P=Players.LocalPlayer
if not P then return end
if getgenv then
    local env=getgenv()
    if env.BowForgeHubStop then pcall(env.BowForgeHubStop) end
end
local alive=true
local flags={Shoot=false,Farm=false,Loot=false,Forge=false,Equip=false,Boss=false,Return=false,AntiAFK=false}
local connections={}
local savedPos=nil
local lastBoss=false
-- Direction stays fixed despite turning to face enemies.
local farmDir, farmOrigin, farmFrontier = nil, nil, 0
local farmSawMob, farmEmptySince = false, nil
local farmWaypoint, farmWaypointTime = nil, 0
local farmSteps, farmLastMove = 0, 0
local FARM_STEP = 18
local AIM_RANGE = 140
local LANE_HALF_WIDTH = 62
local farmTarget = nil
local lastAimCamera = nil
local lastMovementProgress, stuckSince = nil, nil
local movementBindName='BowForgeV15Movement'
local cameraBindName='BowForgeV15AimCamera'
local aimEnabled = true
local bodyAimEnabled = true
local farmState = "IDLE"
local farmScanCount = 0
local farmLastStatus = 0
local previousAutoRotate = nil
local lastAimStatus = 0
local function markForward()
    local c=P.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    local v=r.CFrame.LookVector
    local flat=Vector3.new(v.X,0,v.Z)
    if flat.Magnitude < 0.05 then return false end
    farmDir=flat.Unit
    farmOrigin=r.Position
    farmFrontier=0
    farmSawMob=false;farmEmptySince=nil
    farmWaypoint=nil;farmWaypointTime=0
    farmSteps=0;farmLastMove=0
    lastMovementProgress=nil;stuckSince=nil
    farmTarget=nil
    farmState='CALIBRATED'
    return true
end
local statusText
local function setStatus(s)
    if statusText and statusText.Parent then statusText.Text='STATUS: '..s end
end
local function chr() return P.Character end
local function root() local c=chr();return c and c:FindFirstChild('HumanoidRootPart') end
local function hum() local c=chr();return c and c:FindFirstChildOfClass('Humanoid') end
local function tool()
    local c=chr(); if not c then return nil end
    return c:FindFirstChildOfClass('Tool')
end
local function locateNPCs(bossOnly,forwardFarm)
    local r=root(); if not r then return nil,nil end
    local best,bestDist
    for _,m in ipairs(workspace:GetDescendants()) do
        if m:IsA('Model') and m~=chr() and not Players:GetPlayerFromCharacter(m) then
            local h=m:FindFirstChildOfClass('Humanoid')
            local mr=m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart
            if h and mr and h.Health>0 and mr:IsA('BasePart') then
                local n=m.Name:lower()
                local isBoss=n:find('boss') or n:find('worldboss') or n:find('world boss')
                if (not bossOnly or isBoss) and (bossOnly or not isBoss) then
                    local dist=(r.Position-mr.Position).Magnitude
                    local eligible=true
                    if forwardFarm and farmDir and farmOrigin then
                        local rel=mr.Position-r.Position
                        local forward=rel:Dot(farmDir)
                        local axisProgress=(mr.Position-farmOrigin):Dot(farmDir)
                        local sideways=(rel - farmDir*forward).Magnitude
                        -- Ignore stragglers behind and models far off the route.
                        eligible=forward>=-5 and axisProgress>=farmFrontier-8 and sideways<=LANE_HALF_WIDTH and dist<=AIM_RANGE
                    end
                    if eligible and (not bestDist or dist<bestDist) then best,bestDist=m,dist end
                end
            end
        end
    end
    return best,bestDist
end
local function faceTarget(model)
    local r=root();local p=model and (model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart)
    if r and p and p:IsA('BasePart') then
        local v=Vector3.new(p.Position.X,r.Position.Y,p.Position.Z)
        if (v-r.Position).Magnitude>0.1 then r.CFrame=CFrame.lookAt(r.Position,v) end
    end
end
local function moveNear(model,dist)
    local r=root();local h=hum()
    local p=model and (model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart)
    if not (r and h and p) then return end
    if (r.Position-p.Position).Magnitude>dist then
        local away=r.Position-p.Position
        local offset=away.Magnitude>0.01 and away.Unit*dist or Vector3.new(dist,0,0)
        h:MoveTo(p.Position+offset)
    else faceTarget(model) end
end
local function clickGuiButton(btn)
    if not btn or not btn:IsA('GuiButton') or not btn.Visible then return false end
    local parent=btn.Parent
    while parent and parent~=game do
        if parent:IsA('GuiObject') and not parent.Visible then return false end
        parent=parent.Parent
    end
    if firesignal then
        local ok=pcall(function() firesignal(btn.Activated) end)
        if ok then return true end
        ok=pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then return true end
    end
    return false
end
local function matchingButtons(keys)
    local gui=P:FindFirstChild('PlayerGui')
    local found={}
    if not gui then return found end
    for _,obj in ipairs(gui:GetDescendants()) do
        if obj:IsA('GuiButton') and obj.Visible then
            local label=(obj.Name..' '..(obj:IsA('TextButton') and obj.Text or '')):lower()
            for _,word in ipairs(keys) do
                if label:find(word,1,true) then table.insert(found,obj);break end
            end
        end
    end
    return found
end
local function bestEquippable()
    local bag=P:FindFirstChildOfClass('Backpack')
    if not bag then return nil end
    local best,score=nil,-math.huge
    for _,it in ipairs(bag:GetChildren()) do
        if it:IsA('Tool') then
            local s=it:GetAttribute('Damage') or it:GetAttribute('Power') or it:GetAttribute('Attack')
            if not s then
                local nv=it:FindFirstChild('Damage') or it:FindFirstChild('Power') or it:FindFirstChild('Attack')
                s=nv and nv:IsA('NumberValue') and nv.Value or nil
            end
            if type(s)=='number' and s>score then best,score=it,s end
        end
    end
    return best
end
local sg=Instance.new('ScreenGui')
sg.Name='BowForgeHubV1_4'
sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true
sg.DisplayOrder=9999
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
-- PlayerGui confirmed working in Delta user's visibility test.
local playerGui=P:WaitForChild('PlayerGui',15)
if not playerGui then warn('[BowForge] PlayerGui tidak ditemukan');return end
local previous=playerGui:FindFirstChild(sg.Name)
if previous then previous:Destroy() end
sg.Parent=playerGui
local function ui(class,props,parent)
    local x=Instance.new(class)
    for k,v in pairs(props) do x[k]=v end
    x.Parent=parent
    return x
end
local main=ui('Frame',{Name='Main',Size=UDim2.fromOffset(286,390),Position=UDim2.new(0.5,-143,0.5,-195),BackgroundColor3=Color3.fromRGB(17,25,34),BorderSizePixel=0,Active=true},sg)
ui('UICorner',{CornerRadius=UDim.new(0,12)},main)
ui('UIStroke',{Color=Color3.fromRGB(192,148,58),Thickness=1},main)
local head=ui('Frame',{Size=UDim2.new(1,0,0,43),BackgroundColor3=Color3.fromRGB(28,37,48),BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,12)},head)
ui('TextLabel',{Size=UDim2.new(1,-85,1,0),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Text='🏹 BOW FORGE HUB V1.4',TextColor3=Color3.fromRGB(242,194,98),Font=Enum.Font.GothamBold,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left},head)
local min=ui('TextButton',{Size=UDim2.fromOffset(30,28),Position=UDim2.new(1,-69,0,7),Text='—',TextSize=18,BackgroundColor3=Color3.fromRGB(49,61,75),TextColor3=Color3.new(1,1,1),BorderSizePixel=0},head)
local close=ui('TextButton',{Size=UDim2.fromOffset(30,28),Position=UDim2.new(1,-35,0,7),Text='×',TextSize=20,BackgroundColor3=Color3.fromRGB(110,48,52),TextColor3=Color3.new(1,1,1),BorderSizePixel=0},head)
for _,b in ipairs({min,close}) do ui('UICorner',{CornerRadius=UDim.new(0,7)},b) end
local tabs=ui('Frame',{Size=UDim2.new(1,-18,0,35),Position=UDim2.fromOffset(9,49),BackgroundTransparency=1},main)
local pages=ui('Frame',{Size=UDim2.new(1,-18,1,-140),Position=UDim2.fromOffset(9,91),BackgroundTransparency=1},main)
local pageNames={'FARM','FORGE','BOSS','UTILITY'}
local tabbuttons={};local panels={}
local function activatePage(name)
    for n,p in pairs(panels) do p.Visible=n==name end
    for n,b in pairs(tabbuttons) do b.BackgroundColor3=n==name and Color3.fromRGB(139,102,35) or Color3.fromRGB(39,50,64) end
end
for i,name in ipairs(pageNames) do
    local b=ui('TextButton',{Size=UDim2.new(.25,-3,1,0),Position=UDim2.new((i-1)*.25,0,0,0),Text=name,TextSize=10,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(39,50,64),BorderSizePixel=0},tabs)
    ui('UICorner',{CornerRadius=UDim.new(0,6)},b)
    tabbuttons[name]=b
    local p=ui('ScrollingFrame',{Size=UDim2.fromScale(1,1),CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BackgroundTransparency=1,Visible=false,BorderSizePixel=0},pages)
    ui('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},p)
    panels[name]=p
    b.MouseButton1Click:Connect(function() activatePage(name) end)
end
local function toggle(page,label,key,description)
    local f=ui('Frame',{Size=UDim2.new(1,-5,0,53),BackgroundColor3=Color3.fromRGB(32,44,56),BorderSizePixel=0},panels[page])
    ui('UICorner',{CornerRadius=UDim.new(0,8)},f)
    ui('TextLabel',{Size=UDim2.new(1,-85,0,24),Position=UDim2.fromOffset(10,5),BackgroundTransparency=1,Text=label,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.new(1,1,1)},f)
    ui('TextLabel',{Size=UDim2.new(1,-15,0,16),Position=UDim2.fromOffset(10,29),BackgroundTransparency=1,Text=description,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(167,180,190)},f)
    local b=ui('TextButton',{Size=UDim2.fromOffset(61,26),Position=UDim2.new(1,-70,0,8),Text='OFF',Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(112,54,57),BorderSizePixel=0},f)
    ui('UICorner',{CornerRadius=UDim.new(0,7)},b)
    b.MouseButton1Click:Connect(function()
        flags[key]=not flags[key]
        b.Text=flags[key] and 'ON' or 'OFF'
        b.BackgroundColor3=flags[key] and Color3.fromRGB(36,130,87) or Color3.fromRGB(112,54,57)
        if key=='Boss' and flags[key] then local r=root();savedPos=r and r.CFrame or nil end
        if key=='Farm' then
            if flags.Farm and not farmDir then
                if markForward() then setStatus('Arah maju disimpan. Sesuaikan dengan SET FORWARD.') end
            end
            if not flags.Farm then
                farmWaypoint=nil;farmEmptySince=nil;farmTarget=nil;farmState='OFF'
                local h=hum()
                if h and previousAutoRotate~=nil then h.AutoRotate=previousAutoRotate;previousAutoRotate=nil end
            end
        end
        setStatus(label..(flags[key] and ' aktif' or ' berhenti'))
    end)
end
toggle('FARM','Auto Shoot','Shoot','Aktifkan tool/bow yang sedang dipakai')
toggle('FARM','Auto Farm Stage','Farm','Jalur lurus; lanjut ke gate saat wave kosong')
local calibration=ui('TextButton',{Size=UDim2.new(1,-5,0,37),Text='SET FORWARD (arah maju)',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(87,74,33),BorderSizePixel=0},panels.FARM)
ui('UICorner',{CornerRadius=UDim.new(0,8)},calibration)
calibration.MouseButton1Click:Connect(function()
    if markForward() then setStatus('Arah lurus disimpan. Akan lanjut hingga gate/halangan.')
    else setStatus('Gagal: karakter belum tersedia') end
end)
toggle('FARM','Auto Collect Loot','Loot','Aktifkan prompt loot dalam jangkauan')
local aimToggle=ui('TextButton',{Size=UDim2.new(1,-5,0,37),Text='AUTO AIM CAMERA: ON',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,113,78),BorderSizePixel=0},panels.FARM)
ui('UICorner',{CornerRadius=UDim.new(0,8)},aimToggle)
aimToggle.MouseButton1Click:Connect(function()
    aimEnabled=not aimEnabled
    aimToggle.Text='AUTO AIM CAMERA: '..(aimEnabled and 'ON' or 'OFF')
    aimToggle.BackgroundColor3=aimEnabled and Color3.fromRGB(30,113,78) or Color3.fromRGB(105,56,56)
    setStatus(aimEnabled and 'Auto Aim kamera aktif' or 'Auto Aim kamera mati')
end)
local bodyAimToggle=ui('TextButton',{Size=UDim2.new(1,-5,0,37),Text='AIM BODY: ON',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,113,78),BorderSizePixel=0},panels.FARM)
ui('UICorner',{CornerRadius=UDim.new(0,8)},bodyAimToggle)
bodyAimToggle.MouseButton1Click:Connect(function()
    bodyAimEnabled=not bodyAimEnabled
    bodyAimToggle.Text='AIM BODY: '..(bodyAimEnabled and 'ON' or 'OFF')
    bodyAimToggle.BackgroundColor3=bodyAimEnabled and Color3.fromRGB(30,113,78) or Color3.fromRGB(105,56,56)
    setStatus(bodyAimEnabled and 'Bidik badan + kamera aktif' or 'Bidik hanya kamera')
end)
local debugInfo=ui('TextLabel',{Size=UDim2.new(1,-5,0,50),Text='DEBUG: Farm OFF',TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Code,TextSize=11,TextColor3=Color3.fromRGB(206,220,225),BackgroundColor3=Color3.fromRGB(28,37,48),BorderSizePixel=0},panels.FARM)
ui('UICorner',{CornerRadius=UDim.new(0,7)},debugInfo)
toggle('FORGE','Auto Forge Bow','Forge','Deteksi GUI forge; mapping belum tersedia')
toggle('FORGE','Auto Equip Best','Equip','Pilih tool dari atribut Damage/Power')
toggle('BOSS','Auto World Boss','Boss','Cari NPC dengan nama mengandung Boss')
toggle('BOSS','Return After Boss','Return','Kembali ke posisi sebelum boss')
toggle('UTILITY','Anti AFK','AntiAFK','Mencegah idle dengan input virtual')
local info=ui('TextLabel',{Size=UDim2.new(1,-20,0,37),Position=UDim2.new(0,10,1,-42),BackgroundColor3=Color3.fromRGB(29,40,51),Text='STATUS: Ready',TextWrapped=true,Font=Enum.Font.Gotham,TextSize=10,TextColor3=Color3.fromRGB(219,224,232),BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},info); statusText=info
-- Opacity slider (all main GUI panels)
local opacityRow=ui('Frame',{Size=UDim2.new(1,-5,0,48),BackgroundColor3=Color3.fromRGB(32,44,56),BorderSizePixel=0},panels['UTILITY'])
ui('UICorner',{CornerRadius=UDim.new(0,8)},opacityRow)
ui('TextLabel',{Size=UDim2.new(1,-12,0,18),Position=UDim2.fromOffset(8,2),Text='GUI Opacity',TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=11,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left},opacityRow)
local track=ui('Frame',{Size=UDim2.new(1,-25,0,9),Position=UDim2.fromOffset(12,29),BackgroundColor3=Color3.fromRGB(75,83,94),BorderSizePixel=0,Active=true},opacityRow)
ui('UICorner',{CornerRadius=UDim.new(1,0)},track)
local fill=ui('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(218,174,79),BorderSizePixel=0},track)
ui('UICorner',{CornerRadius=UDim.new(1,0)},fill)
local knob=ui('Frame',{Size=UDim2.fromOffset(13,13),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,0,.5,0),BackgroundColor3=Color3.fromRGB(255,233,184),BorderSizePixel=0},track)
ui('UICorner',{CornerRadius=UDim.new(1,0)},knob)
local sliding=false
local function setOpacity(x)
    local amount=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),.35,1)
    fill.Size=UDim2.fromScale(amount,1);knob.Position=UDim2.new(amount,0,.5,0)
    local transparency=(1-amount)*.75
    main.BackgroundTransparency=transparency
    head.BackgroundTransparency=transparency
    for _,b in pairs(tabbuttons) do b.BackgroundTransparency=transparency end
    for _,panel in pairs(panels) do
        for _,v in ipairs(panel:GetChildren()) do
            if v:IsA('Frame') then v.BackgroundTransparency=transparency end
        end
    end
end
track.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true;setOpacity(i.Position.X) end
end)
track.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end
end)
table.insert(connections,UIS.InputChanged:Connect(function(i)
    if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setOpacity(i.Position.X) end
end))
local bubble=ui('TextButton',{Size=UDim2.fromOffset(55,43),Position=UDim2.new(0,20,.45,0),Text='🏹',Font=Enum.Font.GothamBold,TextSize=22,BackgroundColor3=Color3.fromRGB(61,48,22),TextColor3=Color3.new(1,1,1),Visible=false},sg)
ui('UICorner',{CornerRadius=UDim.new(0,11)},bubble)
min.MouseButton1Click:Connect(function() main.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function() main.Visible=true;bubble.Visible=false end)
local dragging,startMouse,startPos=false,nil,nil
head.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;startMouse=input.Position;startPos=main.Position end
end)
head.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-startMouse
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end))
local function shutdown()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
    pcall(function() RunService:UnbindFromRenderStep(movementBindName) end)
    pcall(function() RunService:UnbindFromRenderStep(cameraBindName) end)
    local h=hum()
    if h and previousAutoRotate~=nil then h.AutoRotate=previousAutoRotate end
    sg:Destroy()
end
close.MouseButton1Click:Connect(shutdown)
if getgenv then getgenv().BowForgeHubStop=shutdown end
activatePage('FARM')
local lastShoot,lastLoot,lastEquip,lastForge,lastNotice=0,0,0,0,0
local previousBoss=nil
local noBossSince=0
local function tickwork()
    local now=os.clock()
    if flags.Shoot and now-lastShoot>.22 then
        lastShoot=now
        local t=tool()
        if t then pcall(function()t:Activate()end) else setStatus('Auto Shoot: equip bow dahulu') end
    end
    local target
    if flags.Boss then
        target=locateNPCs(true)
        if target then
            if not lastBoss then local r=root();savedPos=r and r.CFrame or savedPos end
            lastBoss=true;noBossSince=0
            moveNear(target,23)
            faceTarget(target)
        elseif lastBoss then
            if noBossSince==0 then noBossSince=now end
            if now-noBossSince>5 then
                lastBoss=false;noBossSince=0
                if flags.Return and savedPos then
                    local h=hum()
                    if h then h:MoveTo(savedPos.Position) end
                    setStatus('Boss selesai/hilang; kembali ke posisi')
                end
            end
        end
    end
    -- Target selection and diagnostics. Walking is controlled every frame below.
    if flags.Farm and not (flags.Boss and target) then
        if not farmDir then markForward() end
        local m=locateNPCs(false,true)
        farmTarget=m
        if m then
            farmState='AIMING / WAVE ACTIVE'
            farmSawMob=true
            farmEmptySince=nil
        else
            if not farmEmptySince then farmEmptySince=now end
            if now-farmEmptySince<0.45 then
                farmState='WAITING FOR NEXT WAVE'
            else
                farmState='WALK STRAIGHT / NEXT GATE'
            end
        end
        if now-farmLastStatus>1.5 then
            farmLastStatus=now
            local r=root()
            local progress=(r and farmOrigin and farmDir) and math.floor((r.Position-farmOrigin):Dot(farmDir)) or 0
            local targetName=m and m.Name or '-'
            debugInfo.Text='STATE: '..farmState..'\nTARGET: '..targetName:sub(1,24)..'  | FORWARD: '..tostring(progress)
        end
    else
        farmTarget=nil
        if not flags.Farm then farmState='OFF' end
    end
    if flags.Loot and now-lastLoot>1.5 then
        lastLoot=now
        local r=root();local count=0
        if r then
            for _,p in ipairs(workspace:GetDescendants()) do
                if count>=5 then break end
                if p:IsA('ProximityPrompt') and p.Enabled then
                    local text=(p.Name..' '..p.ActionText..' '..p.ObjectText):lower()
                    if text:find('loot') or text:find('collect') or text:find('pick') or text:find('drop') then
                        local pt=p.Parent
                        local part=pt and (pt:IsA('BasePart') and pt or pt:FindFirstAncestorWhichIsA('BasePart'))
                        if part and (r.Position-part.Position).Magnitude<=math.max(10,p.MaxActivationDistance) then
                            if fireproximityprompt then pcall(function()fireproximityprompt(p)end);count=count+1 end
                        end
                    end
                end
            end
        end
    end
    if flags.Equip and now-lastEquip>4 then
        lastEquip=now
        local best=bestEquippable();local h=hum()
        if best and h then pcall(function()h:EquipTool(best)end) else setStatus('Equip Best: atribut Damage/Power tidak ditemukan') end
    end
    if flags.Forge and now-lastForge>7 then
        lastForge=now
        local btns=matchingButtons({'forge','craft','tempa'})
        if #btns>0 then setStatus('Forge GUI terdeteksi ('..#btns..' tombol). Perlu mapping slot & material.')
        else setStatus('Auto Forge: buka menu forge game dahulu') end
        -- Intentionally do not click unspecified forge controls or consume materials.
    end
end
-- Use input-priority movement each frame instead of repeated MoveTo commands.
-- Movement never uses enemy position as destination; lateral correction anchors the lane.
local function farmMovement()
    if not alive or not flags.Farm or (flags.Boss and lastBoss) then return end
    local r=root();local h=hum()
    if not (r and h and farmDir and farmOrigin) or h.Health<=0 then return end
    if previousAutoRotate==nil then previousAutoRotate=h.AutoRotate end
    h.AutoRotate=false
    local target=farmTarget
    if target and target.Parent then
        local part=target:FindFirstChild('Head') or target:FindFirstChild('HumanoidRootPart') or target.PrimaryPart
        if part and part:IsA('BasePart') then
            h:Move(Vector3.zero,false)
            if bodyAimEnabled then
                local horizontal=Vector3.new(part.Position.X,r.Position.Y,part.Position.Z)
                if (horizontal-r.Position).Magnitude>0.2 then
                    r.CFrame=CFrame.lookAt(r.Position,horizontal)
                end
            end
            return
        end
    end
    if not farmEmptySince or os.clock()-farmEmptySince<0.45 then
        h:Move(Vector3.zero,false)
        return
    end
    local offset=r.Position-farmOrigin
    local progress=offset:Dot(farmDir)
    local sideways=offset-farmDir*progress
    local correction=Vector3.new(sideways.X,0,sideways.Z)
    local direction=farmDir
    if correction.Magnitude>1.5 then
        direction=(farmDir*12-correction*0.7).Unit
    end
    h:Move(direction,false)
    local look=r.Position+farmDir
    r.CFrame=CFrame.lookAt(r.Position,Vector3.new(look.X,r.Position.Y,look.Z))
end
local function aimCamera()
    if not alive or not aimEnabled or not flags.Farm or (flags.Boss and lastBoss) then return end
    local target=farmTarget
    local camera=workspace.CurrentCamera
    if not camera or not target or not target.Parent then return end
    local part=target:FindFirstChild('Head') or target:FindFirstChild('HumanoidRootPart') or target.PrimaryPart
    local r=root()
    if not part or not part:IsA('BasePart') or not r then return end
    if (part.Position-r.Position).Magnitude>AIM_RANGE then return end
    local cameraPos=camera.CFrame.Position
    if (part.Position-cameraPos).Magnitude>0.2 then
        camera.CFrame=CFrame.lookAt(cameraPos,part.Position)
    end
end
RunService:BindToRenderStep(movementBindName,Enum.RenderPriority.Character.Value+1,farmMovement)
RunService:BindToRenderStep(cameraBindName,Enum.RenderPriority.Camera.Value+1,aimCamera)
table.insert(connections,P.Idled:Connect(function()
    if flags.AntiAFK then
        pcall(function()VirtualUser:CaptureController();VirtualUser:ClickButton2(Vector2.new(0,0))end)
    end
end))
task.spawn(function()
    while alive and sg.Parent do
        local ok,err=pcall(tickwork)
        if not ok then setStatus('Error: '..tostring(err):sub(1,90)) end
        task.wait(.15)
    end
end)
setStatus('V1.5: SET FORWARD, Farm ON, Shoot ON. Cek DEBUG di tab FARM.')
