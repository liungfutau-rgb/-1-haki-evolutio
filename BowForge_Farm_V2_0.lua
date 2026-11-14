-- +1 Bow Forge | Farm V2.0 - wave clear + movement speed + rapid attack
-- Uses a proven MoveTo movement primitive and camera targeting.
-- IMPORTANT: NPC/gate identifiers and firing mechanism are not verified.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
if not player then return end
local playerGui=player:WaitForChild('PlayerGui')
local env=(getgenv and getgenv()) or _G
if type(env.BowFarmStop)=='function' then pcall(env.BowFarmStop) end
local prior=playerGui:FindFirstChild('BowFarmV20')
if prior then prior:Destroy() end
local gui=Instance.new('ScreenGui')
gui.Name='BowFarmV20'; gui.ResetOnSpawn=false; gui.DisplayOrder=9999; gui.IgnoreGuiInset=true; gui.Parent=playerGui
local isRunning=true
local active={farm=false,aim=true,shoot=false,shootClick=false}
local heading,origin=nil,nil
local target,enemyCount=nil,0
local tickScan,tickWalk,tickToolShoot,tickClickShoot=0,0,0,0
local boostEnabled=false
local rapidEnabled=false
local desiredWalkSpeed=48
local originalSpeed=nil
local originalHumanoid=nil
local emptySince=nil
local state='READY'
local statusNote=''
local scanRange=75
local widthRange=36
local connections={}
local function char() return player.Character end
local function root() local c=char();return c and c:FindFirstChild('HumanoidRootPart') end
local function hum() local c=char();return c and c:FindFirstChildOfClass('Humanoid') end
local function ui(kind, props, parent)
 local obj=Instance.new(kind)
 for k,v in pairs(props) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local main=ui('Frame',{Size=UDim2.fromOffset(330,530),Position=UDim2.new(.5,-165,.5,-265),BackgroundColor3=Color3.fromRGB(18,27,36),BorderSizePixel=0,Active=true},gui)
ui('UICorner',{CornerRadius=UDim.new(0,12)},main)
ui('UIStroke',{Color=Color3.fromRGB(221,170,81),Thickness=1},main)
local header=ui('TextLabel',{Size=UDim2.new(1,-57,0,40),Position=UDim2.fromOffset(9,0),BackgroundTransparency=1,Text='BOW FARM V2.0 | SPEED + RAPID',TextColor3=Color3.fromRGB(242,199,106),TextSize=15,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=true},main)
local mini=ui('TextButton',{Size=UDim2.fromOffset(33,30),Position=UDim2.new(1,-39,0,6),Text='—',TextSize=17,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(48,60,76)},main)
local bubble=ui('TextButton',{Size=UDim2.fromOffset(68,44),Position=UDim2.fromOffset(12,165),Text='BOW',TextSize=13,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(142,104,37),Visible=false},gui)
ui('UICorner',{CornerRadius=UDim.new(0,9)},bubble)
mini.MouseButton1Click:Connect(function()main.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()main.Visible=true;bubble.Visible=false end)
local function button(label,x,y,w,callback)
 local b=ui('TextButton',{Size=UDim2.fromOffset(w,35),Position=UDim2.fromOffset(x,y),Text=label,TextSize=12,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,BackgroundColor3=Color3.fromRGB(43,58,74),BorderSizePixel=0},main)
 ui('UICorner',{CornerRadius=UDim.new(0,8)},b)
 b.MouseButton1Click:Connect(function()local ok,err=pcall(callback,b);if not ok then warn('[BowFarmV20] '..tostring(err)) end end)
 return b
end
local function toggle(name,x,y,key)
 local b
 b=button(name..': '..(active[key] and 'ON' or 'OFF'),x,y,150,function()
  active[key]=not active[key]
  b.Text=name..': '..(active[key] and 'ON' or 'OFF')
  b.BackgroundColor3=active[key] and Color3.fromRGB(30,115,82) or Color3.fromRGB(43,58,74)
 end)
 b.BackgroundColor3=active[key] and Color3.fromRGB(30,115,82) or Color3.fromRGB(43,58,74)
 return b
end
toggle('AUTO FARM',9,48,'farm')
toggle('AUTO AIM',170,48,'aim')
toggle('TOOL SHOOT',9,90,'shoot')
toggle('CLICK SHOOT',170,90,'shootClick')
local function setForward()
 local r=root();if not r then state='NO CHARACTER';return false end
 local v=r.CFrame.LookVector
 v=Vector3.new(v.X,0,v.Z)
 if v.Magnitude<.1 then return false end
 heading=v.Unit;origin=r.Position;emptySince=nil;tickWalk=0
 return true
end
button('SET FORWARD',9,132,150,function(b)b.Text=setForward() and 'FORWARD SAVED' or 'NOT READY' end)
button('STOP FARM',170,132,150,function()active.farm=false;state='STOPPED';local h=hum();if h then h:MoveTo(root().Position) end end)
button('RESCAN MONSTER',9,174,150,function()tickScan=0;emptySince=nil end)
button('RESET DIRECTION',170,174,150,function()heading=nil;origin=nil;state='SET FORWARD AGAIN' end)
local debug=ui('TextLabel',{Size=UDim2.fromOffset(310,160),Position=UDim2.fromOffset(10,310),BackgroundColor3=Color3.fromRGB(30,43,56),TextColor3=Color3.fromRGB(229,237,245),TextWrapped=true,TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='Face the next gate and press SET FORWARD.',BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,9)},debug)
-- Speed boost is a client-side movement request; game/server may override it.
local function restoreSpeed()
 if originalHumanoid and originalHumanoid.Parent and originalSpeed then
  pcall(function() originalHumanoid.WalkSpeed=originalSpeed end)
 end
end
local speedToggle
speedToggle=button('SPEED: OFF',9,216,150,function(b)
 boostEnabled=not boostEnabled
 if not boostEnabled then restoreSpeed() end
 b.Text=boostEnabled and 'SPEED: ON' or 'SPEED: OFF'
 b.BackgroundColor3=boostEnabled and Color3.fromRGB(30,115,82) or Color3.fromRGB(43,58,74)
end)
local speedValue
speedValue=button('WALK: 48',170,216,150,function(b)
 local values={32,40,48,64,80}
 local idx=1
 for i,v in ipairs(values) do if v==desiredWalkSpeed then idx=i;break end end
 desiredWalkSpeed=values[idx % #values+1]
 b.Text='WALK: '..desiredWalkSpeed
end)
local rapidToggle
rapidToggle=button('RAPID ATTACK: OFF',9,258,310,function(b)
 rapidEnabled=not rapidEnabled
 b.Text=rapidEnabled and 'RAPID ATTACK: ON' or 'RAPID ATTACK: OFF'
 b.BackgroundColor3=rapidEnabled and Color3.fromRGB(30,115,82) or Color3.fromRGB(43,58,74)
end)
local function npcPart(m)
 local p=m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart
 if not p then p=m:FindFirstChildWhichIsA('BasePart') end
 return p
end
local function scan()
 local r=root();if not r or not heading then return nil,0 end
 local closest,bestScore,num=nil,math.huge,0
 for _,m in ipairs(workspace:GetDescendants()) do
  if m:IsA('Model') and m~=char() and not Players:GetPlayerFromCharacter(m) then
   local h=m:FindFirstChildOfClass('Humanoid')
   local p=npcPart(m)
   if h and p and h.Health>0 and not m.Name:lower():find('boss',1,true) then
    local d=p.Position-r.Position
    local forward=d:Dot(heading)
    local sideways=(d-heading*forward).Magnitude
    if forward>=-12 and forward<=scanRange and sideways<=widthRange then
     num=num+1
     local score=d.Magnitude+sideways*.3
     if score<bestScore then closest=m;bestScore=score end
    end
   end
  end
 end
 return closest,num
end
local function shutdown()
 isRunning=false
 restoreSpeed()
 for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
 if gui.Parent then gui:Destroy() end
 if env.BowFarmStop==shutdown then env.BowFarmStop=nil end
end
env.BowFarmStop=shutdown
button('CLOSE',9,480,310,shutdown)
local drag=false;local dragPos,oldPos
table.insert(connections,header.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  drag=true;dragPos=input.Position;oldPos=main.Position
 end
end))
table.insert(connections,header.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if drag and dragPos and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local diff=input.Position-dragPos
  main.Position=UDim2.new(oldPos.X.Scale,oldPos.X.Offset+diff.X,oldPos.Y.Scale,oldPos.Y.Offset+diff.Y)
 end
end))
local debugAt=0
local lastPos,lastPosAt=nil,0
local movementSpeed=0
local prevChar=nil
local previousEnemyCount=0
local function tickFarm()
 local now=os.clock()
 local r,h=root(),hum()
 if not r or not h then state='WAITING CHARACTER';return end
 if char()~=prevChar then
  restoreSpeed()
  originalHumanoid=h
  originalSpeed=h.WalkSpeed
  prevChar=char();lastPos=r.Position;lastPosAt=now;heading=nil;origin=nil;state='RESPAWN: SET FORWARD'
 end
 if boostEnabled and h.WalkSpeed~=desiredWalkSpeed then
  pcall(function() h.WalkSpeed=desiredWalkSpeed end)
 end
 if not heading then state='PRESS SET FORWARD';return end
 if now>=tickScan then
  target,enemyCount=scan();tickScan=now+.35
 end
 local p=target and npcPart(target)
 if target then
  local th=target:FindFirstChildOfClass('Humanoid')
  if not p or not th or th.Health<=0 then target=nil;p=nil;tickScan=0 end
 end
 if enemyCount>0 then
  emptySince=nil
  if previousEnemyCount==0 then h:MoveTo(r.Position) end -- cancel an old next-gate MoveTo
 else
  emptySince=emptySince or now
 end
 previousEnemyCount=enemyCount
 if active.aim and p then
  local cam=workspace.CurrentCamera
  if cam then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,p.Position+Vector3.new(0,1.5,0)) end
 end
 -- Faster Activate()/click requests do not change server weapon cooldown or damage.
 local shootGap=rapidEnabled and 0.10 or 0.30
 if active.shoot and now>=tickToolShoot then
  tickToolShoot=now+shootGap
  local bow=char() and char():FindFirstChildOfClass('Tool')
  if bow then pcall(function() bow:Activate() end)
  else statusNote='NO TOOL: bow may use custom GUI' end
 end
 if active.shootClick and now>=tickClickShoot then
  tickClickShoot=now+shootGap
  if type(mouse1click)=='function' then pcall(mouse1click)
  else statusNote='mouse1click unavailable' end
 end
 if active.farm then
  if h.Health<=0 then state='DEAD'
  elseif h.Sit or h.PlatformStand or h.WalkSpeed<=0 then state='MOVEMENT DISABLED'
  elseif enemyCount>0 then
   -- Keep the player in the current wave, do not enter the next gate.
   state='FIGHT WAVE / WAIT FOR ALL KILLS'
   -- If enemy is far, approach only along the saved lane; not toward enemy's side position.
   if p and (p.Position-r.Position).Magnitude>29 and now>=tickWalk then
    local progress=(r.Position-origin):Dot(heading)
    local step=math.min(10,math.max(0,(p.Position-r.Position):Dot(heading)-25))
    if step>2 then
     local dest=origin+heading*(progress+step)
     h:MoveTo(Vector3.new(dest.X,r.Position.Y,dest.Z))
     state='APPROACH WAVE (STRAIGHT)'
    end
    tickWalk=now+.5
   end
  elseif emptySince and now-emptySince>=1.2 then
   -- MoveTo along a stored heading; advances only when no living NPC is detected.
   if now>=tickWalk then
    local progress=(r.Position-origin):Dot(heading)
    local dest=origin+heading*(math.max(0,progress)+20)
    h:MoveTo(Vector3.new(dest.X,r.Position.Y,dest.Z))
    tickWalk=now+.7
   end
   state='WAVE CLEAR -> NEXT GATE'
  else state='VERIFYING WAVE EMPTY' end
 else state='FARM OFF' end
 if now-lastPosAt>=.9 then
  movementSpeed=lastPos and (r.Position-lastPos).Magnitude/(now-lastPosAt) or 0
  lastPos=r.Position;lastPosAt=now
 end
 if now>=debugAt then
  debugAt=now+.3
  local distance=p and math.floor((p.Position-r.Position).Magnitude) or '-'
  local progress=origin and math.floor((r.Position-origin):Dot(heading)) or 0
  local bow=char() and char():FindFirstChildOfClass('Tool')
  debug.Text=string.format('STATE: %s\nTARGET: %s | WAVE COUNT: %d\nDIST: %s | FORWARD: %d studs\nSPEED: %.1f | WALKSPEED: %.0f\nTOOL: %s\nRAPID: %s | SPEED BOOST: %s\nNOTICE: %s',state,target and target.Name or '-',enemyCount,tostring(distance),progress,movementSpeed,h.WalkSpeed,bow and bow.Name or 'NOT FOUND',rapidEnabled and 'ON' or 'OFF',boostEnabled and 'ON' or 'OFF',statusNote)
 end
end
task.spawn(function()
 while isRunning and gui.Parent do
  local ok,err=pcall(tickFarm)
  if not ok then state='ERROR';debug.Text='ERROR: '..tostring(err) end
  task.wait(.1)
 end
end)
print('[BowForge] V2.0 loaded: SET FORWARD, enable FARM/AIM; TOOl SHOOT or CLICK SHOOT as applicable.')
