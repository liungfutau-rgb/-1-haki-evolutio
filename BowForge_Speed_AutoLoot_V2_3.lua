-- +1 Bow Forge: Speed + Collect All V2.3
-- Uses confirmed V2.2 WalkSpeed approach. Loot prompt detection remains experimental.
-- No rarity restrictions, no farm/aim/shoot features.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild('PlayerGui')
local env = (getgenv and getgenv()) or _G
for _,key in ipairs({'BowFarmStop','BowSpeedLootStop'}) do
 if type(env[key])=='function' then pcall(env[key]) end
end
for _,name in ipairs({'BowFarmV20','BowFarmV21','BowSpeedLootV22','BowSpeedLootV23'}) do
 local old=playerGui:FindFirstChild(name)
 if old then old:Destroy() end
end
local running=true
local speedOn=false
local speedChoice=48
local originalSpeed, originalHumanoid=nil,nil
local lootOn=false
local connections={}
local attempts=0
local successes=0 -- Count successful API calls only, not verified pickups.
local status='READY'
local scanResult={seen=0,near=0,attempted=0,reason='-',last='-'}
local lastAttempt=setmetatable({}, {__mode='k'})
local function hum() local c=player.Character; return c and c:FindFirstChildOfClass('Humanoid') end
local function root() local c=player.Character; return c and c:FindFirstChild('HumanoidRootPart') end
local function ui(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local gui=ui('ScreenGui',{Name='BowSpeedLootV23',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9999},playerGui)
local main=ui('Frame',{Size=UDim2.fromOffset(330,335),Position=UDim2.new(.5,-165,.5,-167),BackgroundColor3=Color3.fromRGB(18,27,36),BorderSizePixel=0,Active=true},gui)
ui('UICorner',{CornerRadius=UDim.new(0,12)},main)
ui('UIStroke',{Color=Color3.fromRGB(221,170,81),Thickness=1},main)
local scale=ui('UIScale',{Scale=1},main)
local function fitScreen()
 local cam=workspace.CurrentCamera; if not cam then return end
 local v=cam.ViewportSize
 scale.Scale=math.min(1,math.max(.55,math.min((v.X-18)/330,(v.Y-28)/335)))
end
fitScreen()
local camChanged=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(fitScreen)
local header=ui('TextLabel',{Size=UDim2.new(1,-55,0,41),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text='BOW FORGE | SPEED + ALL LOOT',TextColor3=Color3.fromRGB(242,199,106),TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=true},main)
local mini=ui('TextButton',{Size=UDim2.fromOffset(33,30),Position=UDim2.new(1,-40,0,6),Text='-',TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(48,60,76),BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},mini)
local bubble=ui('TextButton',{Size=UDim2.fromOffset(64,42),Position=UDim2.fromOffset(12,160),Text='BOW',TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(142,104,37),Visible=false},gui)
ui('UICorner',{CornerRadius=UDim.new(0,9)},bubble)
local content=ui('ScrollingFrame',{
 Name='ScrollArea',Size=UDim2.new(1,-12,1,-51),Position=UDim2.fromOffset(6,45),CanvasSize=UDim2.fromOffset(0,430),
 ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=5,ScrollBarImageColor3=Color3.fromRGB(221,170,81),
 ScrollingEnabled=true,Active=true,BackgroundTransparency=1,BorderSizePixel=0
},main)
local function button(text,x,y,w,callback)
 local b=ui('TextButton',{Size=UDim2.fromOffset(w,36),Position=UDim2.fromOffset(x,y),Text=text,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(43,58,74),BorderSizePixel=0},content)
 ui('UICorner',{CornerRadius=UDim.new(0,8)},b)
 b.MouseButton1Click:Connect(function() local ok,err=pcall(callback,b); if not ok then warn('[BowLootV23] '..tostring(err)) end end)
 return b
end
local onColor=Color3.fromRGB(30,115,82)
local offColor=Color3.fromRGB(43,58,74)
local function paint(btn,on) btn.BackgroundColor3=on and onColor or offColor end
local function restoreSpeed()
 if originalHumanoid and originalHumanoid.Parent and originalSpeed then
  pcall(function() originalHumanoid.WalkSpeed=originalSpeed end)
 end
end
button('SPEED: OFF',9,5,150,function(b)
 speedOn=not speedOn
 if not speedOn then restoreSpeed() end
 b.Text=speedOn and 'SPEED: ON' or 'SPEED: OFF'
 paint(b,speedOn)
end)
button('WALK: 48',170,5,150,function(b)
 local values={32,40,48,64,80};local index=1
 for i,v in ipairs(values) do if v==speedChoice then index=i;break end end
 speedChoice=values[index % #values+1]
 b.Text='WALK: '..speedChoice
end)
ui('TextLabel',{Size=UDim2.fromOffset(305,25),Position=UDim2.fromOffset(10,53),BackgroundTransparency=1,Text='AUTO COLLECT | ALL RARITIES',Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(242,199,106),TextXAlignment=Enum.TextXAlignment.Left},content)
button('AUTO LOOT ALL: OFF',9,83,310,function(b)
 lootOn=not lootOn
 b.Text=lootOn and 'AUTO LOOT ALL: ON' or 'AUTO LOOT ALL: OFF'
 paint(b,lootOn)
 status=lootOn and 'Trying nearby collectible prompts' or 'Auto Loot paused'
end)
ui('TextLabel',{Size=UDim2.fromOffset(306,37),Position=UDim2.fromOffset(10,128),BackgroundTransparency=1,Text='Ambil semua loot terdeteksi di sekitar. Tidak memilah rarity dan tidak mengaktifkan pintu / toko.',TextWrapped=true,TextColor3=Color3.fromRGB(172,186,199),TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},content)

-- Match collectible prompts only, so unrelated doors, purchases and teleports are ignored.
local function isLoot(prompt)
 local s=(prompt.Name..' '..(prompt.ActionText or '')..' '..(prompt.ObjectText or '')):lower()
 local keywords={'loot','collect','pickup','pick up','drop','grab','take item','gather','ore','chest','reward'}
 for _,k in ipairs(keywords) do if s:find(k,1,true) then return true end end
 local p=prompt.Parent
 for _=1,4 do
  if not p then break end
  local n=p.Name:lower()
  for _,k in ipairs({'loot','drop','chest','ore','collectible'}) do
   if n:find(k,1,true) then return true end
  end
  p=p.Parent
 end
 return false
end
local function promptPosition(prompt)
 local obj=prompt.Parent
 if obj and obj:IsA('Attachment') then return obj.WorldPosition end
 if obj and obj:IsA('BasePart') then return obj.Position end
 if obj and obj:IsA('Model') then return obj:GetPivot().Position end
 local ancestor=prompt:FindFirstAncestorOfClass('Model')
 return ancestor and ancestor:GetPivot().Position or nil
end
local function scan(collect)
 local r=root()
 if not r then scanResult.reason='NO CHARACTER';return end
 local fire=type(fireproximityprompt)=='function' and fireproximityprompt or nil
 local seen,near,attempted=0,0,0
 local last='-'
 for _,prompt in ipairs(workspace:GetDescendants()) do
  if prompt:IsA('ProximityPrompt') and prompt.Enabled and isLoot(prompt) then
   seen=seen+1
   local pos=promptPosition(prompt)
   if pos and (r.Position-pos).Magnitude<=math.max(5,prompt.MaxActivationDistance) then
    near=near+1
    last=(prompt.ObjectText~='' and prompt.ObjectText or prompt.Parent.Name)
    if collect and fire and os.clock()-(lastAttempt[prompt] or -100)>2.5 then
     lastAttempt[prompt]=os.clock()
     attempts=attempts+1
     local ok=pcall(fire,prompt)
     if ok then attempted=attempted+1;successes=successes+1 end
    end
   end
  end
 end
 scanResult={seen=seen,near=near,attempted=attempted,reason=fire and 'PROMPT SCAN' or 'NO fireproximityprompt',last=last}
end
button('SCAN LOOT NOW',9,172,310,function()
 scan(false)
 status='Scan complete - view counts below'
end)
local debug=ui('TextLabel',{Size=UDim2.fromOffset(308,137),Position=UDim2.fromOffset(10,219),BackgroundColor3=Color3.fromRGB(30,43,56),TextColor3=Color3.fromRGB(229,237,245),TextSize=11,Font=Enum.Font.Code,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='STATUS: READY',BorderSizePixel=0},content)
ui('UICorner',{CornerRadius=UDim.new(0,9)},debug)
local function shutdown()
 running=false;restoreSpeed()
 pcall(function()camChanged:Disconnect()end)
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
 if gui.Parent then gui:Destroy()end
 if env.BowSpeedLootStop==shutdown then env.BowSpeedLootStop=nil end
end
env.BowSpeedLootStop=shutdown
button('CLOSE',9,371,310,shutdown)
mini.MouseButton1Click:Connect(function() main.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function() main.Visible=true;bubble.Visible=false end)
local dragging,startMouse,startPos=false,nil,nil
table.insert(connections,header.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true;startMouse=input.Position;startPos=main.Position end
end))
table.insert(connections,header.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if dragging and startMouse and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local delta=input.Position-startMouse
  main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
 end
end))
task.spawn(function()
 local nextScan=0
 while running and gui.Parent do
  local ok,err=pcall(function()
   local h=hum()
   if h~=originalHumanoid then
    restoreSpeed()
    originalHumanoid=h
    originalSpeed=h and h.WalkSpeed or nil
   end
   if speedOn and h and h.WalkSpeed~=speedChoice then h.WalkSpeed=speedChoice end
   if os.clock()>=nextScan then scan(lootOn);nextScan=os.clock()+1.25 end
   debug.Text=string.format('SPEED: %s | WALK: %s\nAUTO LOOT ALL: %s\nLOOT FOUND: %d | IN RANGE: %d\nATTEMPTS (TOTAL): %d\nFIRED WITHOUT ERROR: %d\nLAST NEAR: %s\nSCAN: %s\nSTATUS: %s',
    speedOn and 'ON' or 'OFF',h and tostring(h.WalkSpeed) or '-',lootOn and 'ON' or 'OFF',scanResult.seen,scanResult.near,attempts,successes,scanResult.last,scanResult.reason,status)
  end)
  if not ok then warn('[BowLootV23] '..tostring(err));status='ERROR: '..tostring(err):sub(1,85)end
  task.wait(.2)
 end
end)
print('[BowForge] V2.3 loaded: Speed + Auto Loot All (ProximityPrompt-based).')
