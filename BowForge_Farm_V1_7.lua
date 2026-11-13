-- +1 Bow Forge Farm V1.7 - diagnostic forward movement
-- Client-side helper only. Gate unlock and hit registration remain controlled by the game.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
if not player then return end
local pg=player:WaitForChild('PlayerGui')
local env=(getgenv and getgenv()) or _G
if type(env.BowFarmStop)=='function' then pcall(env.BowFarmStop) end
local old=pg:FindFirstChild('BowFarmV17'); if old then old:Destroy() end
local gui=Instance.new('ScreenGui')
gui.Name='BowFarmV17';gui.ResetOnSpawn=false;gui.DisplayOrder=9999;gui.IgnoreGuiInset=true;gui.Parent=pg
local running=true
local st={farm=false,shoot=false,aim=false,walkWhileFighting=true,holdNearEnemy=false}
local facing=nil
local startPoint=nil
local target=nil
local count=0
local nextScan=0
local nextShot=0
local debugStatus='READY'
local lastMoved=nil
local stuckSince=os.clock()
local connections={}
local function character() return player.Character end
local function root() local c=character();return c and c:FindFirstChild('HumanoidRootPart') end
local function hum() local c=character();return c and c:FindFirstChildOfClass('Humanoid') end
local function element(cls,props,parent)
 local a=Instance.new(cls)
 for k,v in pairs(props) do a[k]=v end
 a.Parent=parent
 return a
end
local bg=element('Frame',{Name='Main',Size=UDim2.fromOffset(330,404),Position=UDim2.new(.5,-165,.5,-202),BackgroundColor3=Color3.fromRGB(18,27,36),BorderSizePixel=0,Active=true},gui)
element('UICorner',{CornerRadius=UDim.new(0,12)},bg)
element('UIStroke',{Color=Color3.fromRGB(210,166,79),Thickness=1},bg)
local header=element('TextLabel',{Size=UDim2.new(1,-60,0,40),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text='BOW FARM V1.7 | FIX MOVE',TextColor3=Color3.fromRGB(242,199,106),TextSize=15,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},bg)
local shrink=element('TextButton',{Size=UDim2.fromOffset(37,29),Position=UDim2.new(1,-44,0,6),Text='—',TextSize=18,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(45,58,72)},bg)
local bubble=element('TextButton',{Size=UDim2.fromOffset(62,45),Position=UDim2.fromOffset(15,160),Text='BOW',Visible=false,BackgroundColor3=Color3.fromRGB(131,95,31),TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=13},gui)
shrink.MouseButton1Click:Connect(function()bg.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()bg.Visible=true;bubble.Visible=false end)
local function btn(name,x,y,w,cb)
 local b=element('TextButton',{Size=UDim2.fromOffset(w or 150,35),Position=UDim2.fromOffset(x,y),Text=name,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(45,59,73),BorderSizePixel=0},bg)
 element('UICorner',{CornerRadius=UDim.new(0,7)},b)
 b.MouseButton1Click:Connect(function() local ok,err=pcall(cb,b);if not ok then warn('[BowFarm17] '..tostring(err)) end end)
 return b
end
local function toggle(title,x,y,key)
 return btn(title..': '..(st[key] and 'ON' or 'OFF'),x,y,150,function(b)
  st[key]=not st[key];b.Text=title..(st[key] and ': ON' or ': OFF');b.BackgroundColor3=st[key] and Color3.fromRGB(35,118,83) or Color3.fromRGB(45,59,73)
 end)
end
toggle('AUTO FARM',9,47,'farm')
toggle('AUTO SHOOT',170,47,'shoot')
toggle('AUTO AIM',9,89,'aim')
toggle('WALK IN WAVE',170,89,'walkWhileFighting')
local function setForward()
 local r=root();if not r then debugStatus='NO CHARACTER';return false end
 local v=r.CFrame.LookVector
 v=Vector3.new(v.X,0,v.Z)
 if v.Magnitude<.1 then return false end
 facing=v.Unit;startPoint=r.Position;stuckSince=os.clock();lastMoved=r.Position
 return true
end
btn('SET FORWARD',9,132,150,function(b) b.Text=setForward() and 'FORWARD SAVED' or 'CHAR NOT READY' end)
btn('STOP WALK',170,132,150,function() st.farm=false;debugStatus='STOPPED';local h=hum();if h then h:Move(Vector3.zero,false) end end)
toggle('HOLD NEAR ENEMY',9,174,'holdNearEnemy')
local refresh=btn('RESCAN TARGET',170,174,150,function() nextScan=0 end)
local debug=element('TextLabel',{Size=UDim2.fromOffset(310,130),Position=UDim2.fromOffset(10,220),BackgroundColor3=Color3.fromRGB(30,42,55),TextColor3=Color3.fromRGB(225,235,242),TextWrapped=true,TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='Press SET FORWARD',BorderSizePixel=0},bg)
element('UICorner',{CornerRadius=UDim.new(0,8)},debug)
local function findPart(m)
 return m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart or m:FindFirstChildWhichIsA('BasePart')
end
local function scan()
 local r=root();if not r or not facing then return nil,0 end
 local best,bestScore,num=nil,math.huge,0
 for _,m in ipairs(workspace:GetDescendants()) do
  if m:IsA('Model') and m~=character() and not Players:GetPlayerFromCharacter(m) then
   local mh=m:FindFirstChildOfClass('Humanoid')
   local mp=findPart(m)
   if mh and mp and mh.Health>0 and not m.Name:lower():find('boss',1,true) then
    local delta=mp.Position-r.Position
    local forward=delta:Dot(facing)
    local lateral=(delta-facing*forward).Magnitude
    -- Only local wave. Don't lock onto enemies beyond the next barrier.
    if forward>=-8 and forward<=75 and lateral<=36 then
     num=num+1
     local score=delta.Magnitude+lateral*.5
     if score<bestScore then best,bestScore=m,score end
    end
   end
  end
 end
 return best,num
end
local function stop()
 running=false;st.farm=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect() end) end
 local h=hum();if h then pcall(function()h:Move(Vector3.zero,false) end) end
 if gui.Parent then gui:Destroy() end
 if env.BowFarmStop==stop then env.BowFarmStop=nil end
end
env.BowFarmStop=stop
btn('CLOSE',9,359,310,stop)
local drag=false;local originInput;local oldPosition
header.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=true;originInput=input.Position;oldPosition=bg.Position end
end)
header.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=false end
end)
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if drag and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local diff=input.Position-originInput
  bg.Position=UDim2.new(oldPosition.X.Scale,oldPosition.X.Offset+diff.X,oldPosition.Y.Scale,oldPosition.Y.Offset+diff.Y)
 end
end))
local accum=0
-- Heartbeat is used instead of MoveTo (which is overridden or stops on repeated destinations).
table.insert(connections,RunService.Heartbeat:Connect(function(dt)
 if not running then return end
 local ok,err=pcall(function()
  local now=os.clock()
  local r=root();local h=hum()
  if not r or not h then debugStatus='WAITING CHARACTER';return end
  if not facing then debugStatus='PRESS SET FORWARD';return end
  if now>=nextScan then
   target,count=scan();nextScan=now+.4
  end
  local part=target and findPart(target)
  if not (part and part.Parent) then target=nil;part=nil end
  local distance=part and (part.Position-r.Position).Magnitude or math.huge
  if st.farm then
   if h.Health<=0 then debugStatus='CHARACTER DEAD'
   elseif st.holdNearEnemy and part and distance<24 then
    h:Move(Vector3.zero,false);debugStatus='HOLD FOR ATTACK'
   elseif not st.walkWhileFighting and part then
    h:Move(Vector3.zero,false);debugStatus='HOLD WAVE'
   else
    h:Move(facing,false)
    debugStatus=part and 'FORWARD + TARGET' or 'FORWARD / NEXT GATE'
   end
  else debugStatus='FARM OFF' end
  if st.aim and part then
   local cam=workspace.CurrentCamera
   if cam then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,part.Position+Vector3.new(0,1.4,0)) end
  end
  if st.shoot and now>=nextShot then
   nextShot=now+.3
   local c=character();local t=c and c:FindFirstChildOfClass('Tool')
   if t then pcall(function()t:Activate() end) end
  end
  if st.farm then
   if lastMoved and (r.Position-lastMoved).Magnitude>1.4 then lastMoved=r.Position;stuckSince=now end
   if lastMoved==nil then lastMoved=r.Position;stuckSince=now end
   if now-stuckSince>3.5 then debugStatus='BLOCKED / CHECK GATE' end
  else lastMoved=r.Position;stuckSince=now end
  accum=accum+dt
  if accum>.35 then
   accum=0
   local prog=startPoint and math.floor((r.Position-startPoint):Dot(facing)) or 0
   local equipped=character() and character():FindFirstChildOfClass('Tool')
   debug.Text=string.format('STATE: %s\nTARGET: %s | COUNT: %d\nPROGRESS: %d studs | DIR: SAVED\nBOW TOOL: %s | DIST: %s\nWALK IN WAVE: %s',debugStatus,target and target.Name or '-',count,prog,equipped and equipped.Name or 'NOT FOUND',part and tostring(math.floor(distance)) or '-',st.walkWhileFighting and 'ON' or 'OFF')
  end
 end)
 if not ok then debug.Text='ERROR: '..tostring(err):sub(1,160) end
end))
print('[BowForge] V1.7 loaded. Face next gate; SET FORWARD; AUTO FARM ON.')
