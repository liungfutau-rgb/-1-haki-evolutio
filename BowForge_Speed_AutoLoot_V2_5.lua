-- +1 Bow Forge: Speed + Auto Collect GUI V2.5
-- Retains working WalkSpeed, uses identified UI_HUD CollectPrompt button.
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
for _,name in ipairs({'BowFarmV20','BowFarmV21','BowSpeedLootV22','BowSpeedLootV24','BowSpeedLootV25'}) do
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
local successes=0 -- counts attempts without Lua errors, not confirmed item pickups.
local status='READY'
local scanResult={seen=0,near=0,attempted=0,reason='-',last='-'}
local collectPath='UI_HUD.Canvas.Safe.CollectPrompt'
local lastCollect=0
local clickMethod='-'
local modeNames={'CONNECTIONS','VIRTUAL INPUT','FIRESIGNAL'}
local modeIndex=1
local listenerCount='?'
local lastError='-'
local tested=0
local collectButton=nil
local lastAttempt=setmetatable({}, {__mode='k'})
local function hum() local c=player.Character; return c and c:FindFirstChildOfClass('Humanoid') end
local function root() local c=player.Character; return c and c:FindFirstChild('HumanoidRootPart') end
local function ui(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local gui=ui('ScreenGui',{Name='BowSpeedLootV25',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9999},playerGui)
local main=ui('Frame',{Size=UDim2.fromOffset(330,360),Position=UDim2.new(.5,-165,.5,-180),BackgroundColor3=Color3.fromRGB(18,27,36),BorderSizePixel=0,Active=true},gui)
ui('UICorner',{CornerRadius=UDim.new(0,12)},main)
ui('UIStroke',{Color=Color3.fromRGB(221,170,81),Thickness=1},main)
local scale=ui('UIScale',{Scale=1},main)
local function fitScreen()
 local cam=workspace.CurrentCamera; if not cam then return end
 local v=cam.ViewportSize
 scale.Scale=math.min(1,math.max(.55,math.min((v.X-18)/330,(v.Y-28)/360)))
end
fitScreen()
local camChanged=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(fitScreen)
local header=ui('TextLabel',{Size=UDim2.new(1,-55,0,41),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text='BOW FORGE | SPEED + COLLECT',TextColor3=Color3.fromRGB(242,199,106),TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=true},main)
local mini=ui('TextButton',{Size=UDim2.fromOffset(33,30),Position=UDim2.new(1,-40,0,6),Text='-',TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(48,60,76),BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},mini)
local bubble=ui('TextButton',{Size=UDim2.fromOffset(64,42),Position=UDim2.fromOffset(12,160),Text='BOW',TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(142,104,37),Visible=false},gui)
ui('UICorner',{CornerRadius=UDim.new(0,9)},bubble)
local content=ui('ScrollingFrame',{
 Name='ScrollArea',Size=UDim2.new(1,-12,1,-51),Position=UDim2.fromOffset(6,45),CanvasSize=UDim2.fromOffset(0,525),
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
 status=lootOn and 'Watching Kumpulkan button' or 'Auto Loot paused'
end)
ui('TextLabel',{Size=UDim2.fromOffset(306,37),Position=UDim2.fromOffset(10,128),BackgroundTransparency=1,Text='Dekati loot. TEST CLICK NOW untuk menguji metode. Pilih MODE bila loot tidak terambil. Tanpa filter rarity.',TextWrapped=true,TextColor3=Color3.fromRGB(172,186,199),TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},content)

-- Game uses a TextButton, not a ProximityPrompt.
-- Path found by in-game GUI scanner: PlayerGui.UI_HUD.Canvas.Safe.CollectPrompt
local function visibleInHierarchy(obj)
 if not obj or not obj:IsA('GuiObject') then return false end
 local p=obj
 while p and p~=playerGui do
  if p:IsA('GuiObject') and not p.Visible then return false end
  p=p.Parent
 end
 if not obj:IsDescendantOf(playerGui) then return false end
 if obj.AbsoluteSize.X<2 or obj.AbsoluteSize.Y<2 then return false end
 return true
end
local function findCollectButton()
 local hud=playerGui:FindFirstChild('UI_HUD')
 local canvas=hud and hud:FindFirstChild('Canvas')
 local safe=canvas and canvas:FindFirstChild('Safe')
 local btn=safe and safe:FindFirstChild('CollectPrompt')
 if btn and btn:IsA('GuiButton') then return btn end
 return nil
end
local function connectionsFor(signal)
 if type(getconnections)~='function' then return {} end
 local ok,items=pcall(function()return getconnections(signal)end)
 if ok and type(items)=='table' then return items end
 return {}
end
local function countListeners(btn)
 if not btn then return '-' end
 if type(getconnections)~='function' then return 'API unavailable' end
 return tostring(#connectionsFor(btn.Activated))..' / '..tostring(#connectionsFor(btn.MouseButton1Click))
end
local function tryClick(btn)
 local mode=modeNames[modeIndex]
 if mode=='CONNECTIONS' then
  if type(getconnections)~='function' then return false,'getconnections unavailable' end
  local handlers=connectionsFor(btn.Activated)
  if #handlers==0 then handlers=connectionsFor(btn.MouseButton1Click) end
  if #handlers==0 then return false,'no listener exposed' end
  local called=0
  for _,conn in ipairs(handlers) do
   if conn.Enabled~=false and type(conn.Function)=='function' then
    local ok,err=pcall(conn.Function)
    if ok then called=called+1 else lastError=tostring(err):sub(1,75) end
   elseif type(conn.Fire)=='function' then
    local ok,err=pcall(function() conn:Fire() end)
    if ok then called=called+1 else lastError=tostring(err):sub(1,75) end
   end
  end
  return called>0,'callbacks invoked '..called..'/'..#handlers
 elseif mode=='VIRTUAL INPUT' then
  local ok,vim=pcall(function()return game:GetService('VirtualInputManager')end)
  if not ok or not vim then return false,'VirtualInputManager unavailable' end
  local c=btn.AbsolutePosition+btn.AbsoluteSize/2
  local sent,err=pcall(function()
   vim:SendMouseButtonEvent(c.X,c.Y,0,true,game,0)
   task.wait(.1)
   vim:SendMouseButtonEvent(c.X,c.Y,0,false,game,0)
  end)
  if not sent then lastError=tostring(err):sub(1,75) end
  return sent,'mouse event at '..math.floor(c.X)..','..math.floor(c.Y)
 else
  if type(firesignal)~='function' then return false,'firesignal unavailable' end
  local ok,err=pcall(function()firesignal(btn.Activated)end)
  if not ok then ok,err=pcall(function()firesignal(btn.MouseButton1Click)end) end
  if not ok then lastError=tostring(err):sub(1,75) end
  return ok,'firesignal invoked'
 end
end
local function scan(collect)
 local btn=findCollectButton()
 collectButton=btn
 local shown=btn and visibleInHierarchy(btn) or false
 scanResult.seen=btn and 1 or 0
 scanResult.near=shown and 1 or 0
 scanResult.attempted=0
 scanResult.last=btn and btn:GetFullName() or '-'
 scanResult.reason=btn and (shown and 'BUTTON VISIBLE' or 'BUTTON HIDDEN') or 'BUTTON NOT FOUND'
 listenerCount=countListeners(btn)
 if collect and shown and os.clock()-lastCollect>=.8 then
  lastCollect=os.clock()
  attempts=attempts+1
  local ok,method=tryClick(btn)
  clickMethod=method
  scanResult.attempted=1
  if ok then successes=successes+1 end
  status=ok and ('Click attempted: '..method) or ('Click failed: '..method)
 end
end
button('SCAN COLLECT BUTTON',9,172,310,function()
 scan(false)
 status='Scan complete: '..scanResult.reason
end)
button('MODE: CONNECTIONS',9,214,310,function(b)
 modeIndex=modeIndex % #modeNames+1
 b.Text='MODE: '..modeNames[modeIndex]
 status='Mode changed. Test with loot visible.'
end)
button('TEST CLICK NOW',9,256,310,function()
 local btn=findCollectButton()
 if not btn then status='NOT FOUND';return end
 if not visibleInHierarchy(btn) then status='BUTTON HIDDEN';return end
 tested=tested+1; attempts=attempts+1
 local ok,method=tryClick(btn)
 clickMethod=method
 if ok then successes=successes+1 end
 status=ok and 'Test sent; check whether loot disappears' or 'Test failed'
end)
local debug=ui('TextLabel',{Size=UDim2.fromOffset(308,165),Position=UDim2.fromOffset(10,303),BackgroundColor3=Color3.fromRGB(30,43,56),TextColor3=Color3.fromRGB(229,237,245),TextSize=11,Font=Enum.Font.Code,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='STATUS: READY',BorderSizePixel=0},content)
ui('UICorner',{CornerRadius=UDim.new(0,9)},debug)
local function shutdown()
 running=false;restoreSpeed()
 pcall(function()camChanged:Disconnect()end)
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
 if gui.Parent then gui:Destroy()end
 if env.BowSpeedLootStop==shutdown then env.BowSpeedLootStop=nil end
end
env.BowSpeedLootStop=shutdown
button('CLOSE',9,476,310,shutdown)
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
   debug.Text=string.format('SPEED: %s | WALK: %s\nAUTO LOOT: %s\nBUTTON FOUND: %d | VISIBLE: %d\nATTEMPTS: %d | NO LUA ERROR: %d\nLISTENERS Act/Click: %s\nMODE: %s\nMETHOD: %s\nSCAN: %s\nLAST ERR: %s\nSTATUS: %s',
    speedOn and 'ON' or 'OFF',h and tostring(h.WalkSpeed) or '-',lootOn and 'ON' or 'OFF',scanResult.seen,scanResult.near,attempts,successes,listenerCount,modeNames[modeIndex],clickMethod,scanResult.reason,lastError,status)
  end)
  if not ok then warn('[BowLootV23] '..tostring(err));status='ERROR: '..tostring(err):sub(1,85)end
  task.wait(.2)
 end
end)
print('[BowForge] V2.5 diagnostic loaded; input calls are not pickup confirmation.')
