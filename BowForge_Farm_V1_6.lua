-- +1 BOW FORGE - FARM V1.6 (experimental)
-- Uses only client-observable objects and standard character movement.
-- No arbitrary server remotes; shooting may need game-specific mapping.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local P = Players.LocalPlayer
if not P then return end
local PG = P:WaitForChild('PlayerGui',15)
if not PG then warn('[BowFarm] No PlayerGui') return end
local E = getgenv and getgenv() or _G
if type(E.BowFarmStop)=='function' then pcall(E.BowFarmStop) end
local old = PG:FindFirstChild('BowFarmV16')
if old then old:Destroy() end
local gui=Instance.new('ScreenGui')
gui.Name='BowFarmV16'; gui.ResetOnSpawn=false; gui.DisplayOrder=9999; gui.IgnoreGuiInset=true; gui.Parent=PG
local state={farm=false,shoot=false,aim=false,moveDuringWave=false}
local dir, origin, gatePos
local lastTarget, lastScan, lastShot, lastMove, emptyAt, lastProgress, progressAt = nil,0,0,0,nil,nil,0
local targetCount=0
local connections={}
local alive=true
local camera=workspace.CurrentCamera
local previousCameraType=nil
local function root()
 local c=P.Character; return c and c:FindFirstChild('HumanoidRootPart')
end
local function humanoid()
 local c=P.Character; return c and c:FindFirstChildOfClass('Humanoid')
end
local function ui(cl,props,parent)
 local o=Instance.new(cl)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent
 return o
end
local main=ui('Frame',{Size=UDim2.fromOffset(320,342),Position=UDim2.new(.5,-160,.5,-171),BackgroundColor3=Color3.fromRGB(19,27,36),BorderSizePixel=0,Active=true},gui)
ui('UICorner',{CornerRadius=UDim.new(0,10)},main)
ui('UIStroke',{Color=Color3.fromRGB(211,166,75),Thickness=1},main)
local head=ui('TextLabel',{Size=UDim2.new(1,-45,0,40),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text='BOW FORGE - FARM V1.6',Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(243,201,107),TextXAlignment=Enum.TextXAlignment.Left},main)
local mini=ui('TextButton',{Size=UDim2.fromOffset(32,30),Position=UDim2.new(1,-37,0,5),Text='-',Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(54,68,79)},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},mini)
local reopen=ui('TextButton',{Size=UDim2.fromOffset(68,42),Position=UDim2.fromOffset(10,155),Text='BOW',Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(121,86,25),Visible=false},gui)
ui('UICorner',{CornerRadius=UDim.new(0,8)},reopen)
mini.MouseButton1Click:Connect(function() main.Visible=false;reopen.Visible=true end)
reopen.MouseButton1Click:Connect(function() main.Visible=true;reopen.Visible=false end)
local function button(text,y,callback,width,x)
 local b=ui('TextButton',{Size=UDim2.fromOffset(width or 298,34),Position=UDim2.fromOffset(x or 11,y),Text=text,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(51,64,78)},main)
 ui('UICorner',{CornerRadius=UDim.new(0,7)},b)
 b.MouseButton1Click:Connect(function() local ok,err=pcall(callback,b);if not ok then warn('[BowFarm] '..tostring(err)) end end)
 return b
end
local function toggle(name,y,key)
 return button(name..': OFF',y,function(b)
  state[key]=not state[key];b.Text=name..(state[key] and ': ON' or ': OFF')
  b.BackgroundColor3=state[key] and Color3.fromRGB(34,113,83) or Color3.fromRGB(51,64,78)
  if key=='farm' then emptyAt=nil;lastTarget=nil end
 end,145, (key=='farm' or key=='aim') and 11 or 164)
end
-- Two columns, no dependence on camera rotation for navigation.
toggle('AUTO FARM',45,'farm')
toggle('AUTO SHOOT',45,'shoot')
toggle('AUTO AIM',84,'aim')
toggle('MOVE IN WAVE',84,'moveDuringWave')
local function setForward()
 local r=root();if not r then return false end
 local v=r.CFrame.LookVector;v=Vector3.new(v.X,0,v.Z)
 if v.Magnitude<.1 then return false end
 dir=v.Unit;origin=r.Position;emptyAt=nil;lastProgress=nil;progressAt=os.clock()
 return true
end
button('SET FORWARD (arah gate)',123,function(b)
 b.Text=setForward() and 'ARAH MAJU TERSIMPAN' or 'CHARACTER NOT READY'
end)
button('SET GATE (berdiri di gate)',162,function(b)
 local r=root(); if not r then return end
 gatePos=r.Position;b.Text='GATE TERSIMPAN'
end,145,11)
button('CLEAR GATE',162,function(b)
 gatePos=nil;b.Text='GATE DIHAPUS'
end,145,164)
local debug=ui('TextLabel',{Size=UDim2.new(1,-20,0,87),Position=UDim2.fromOffset(10,203),BackgroundColor3=Color3.fromRGB(32,44,56),TextColor3=Color3.fromRGB(226,234,238),Font=Enum.Font.Code,TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='READY | Arah belum disetel',BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},debug)
button('STOP / CLOSE',298,function() if E.BowFarmStop then E.BowFarmStop() end end)
local dragging,dragStart,posStart=false,nil,nil
head.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;dragStart=i.Position;posStart=main.Position end
end)
head.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
table.insert(connections,UIS.InputChanged:Connect(function(i)
 if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
  local d=i.Position-dragStart;main.Position=UDim2.new(posStart.X.Scale,posStart.X.Offset+d.X,posStart.Y.Scale,posStart.Y.Offset+d.Y)
 end
end))
local function targetPart(model)
 return model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart
end
local function findTargets()
 local r=root();if not r then return nil,0 end
 local best,bestScore,count=nil,math.huge,0
 for _,m in ipairs(workspace:GetDescendants()) do
  if m:IsA('Model') and m~=P.Character and not Players:GetPlayerFromCharacter(m) then
   local h=m:FindFirstChildOfClass('Humanoid');local part=targetPart(m)
   if h and part and part:IsA('BasePart') and h.Health>0 then
    local name=m.Name:lower()
    if not name:find('boss',1,true) then
     local rel=part.Position-r.Position
     local ahead=dir and rel:Dot(dir) or 0
     local lateral=dir and (rel-dir*ahead).Magnitude or rel.Magnitude
     -- Existing V1.3 idea: reject enemies behind, keep only the stage corridor.
     if dir and ahead>=-6 and ahead<=170 and lateral<=55 then
      count=count+1
      local score=rel.Magnitude + lateral*.6
      if score<bestScore then best=m;bestScore=score end
     end
    end
   end
  end
 end
 return best,count
end
local function doAim(m)
 local part=m and targetPart(m)
 camera=workspace.CurrentCamera
 if not (part and camera) then return end
 local point=part.Position+Vector3.new(0,1.4,0)
 -- This is visual aim only; Bow Forge may use a different firing ray.
 camera.CFrame=CFrame.lookAt(camera.CFrame.Position,point)
end
local function doShoot()
 local c=P.Character;local t=c and c:FindFirstChildOfClass('Tool')
 if t then pcall(function() t:Activate() end);return true end
 return false
end
local function moveStraight(r,h)
 if not (r and h and dir) then return 'NO DIRECTION' end
 local step=dir*16
 if gatePos then
  local toGate=gatePos-r.Position;local distance=toGate:Dot(dir)
  if distance>2 and distance<22 then step=dir*distance end
 end
 if os.clock()-lastMove>.55 then
  lastMove=os.clock()
  h:MoveTo(r.Position+step)
 end
 local progress=origin and (r.Position-origin):Dot(dir) or 0
 if lastProgress==nil or math.abs(progress-lastProgress)>1.5 then
  lastProgress=progress;progressAt=os.clock()
 end
 if os.clock()-progressAt>4 then return 'STUCK / CHECK GATE' end
 return 'STRAIGHT TO NEXT GATE'
end
local function stop()
 alive=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
 local h=hum();if h then pcall(function()h:Move(Vector3.zero,false) end) end
 gui:Destroy();E.BowFarmStop=nil
end
E.BowFarmStop=stop
local mode='READY'
task.spawn(function()
 while alive and gui.Parent do
  local ok,err=pcall(function()
   local now=os.clock();local r=root();local h=hum()
   if not dir and r then mode='SET FORWARD FIRST' end
   if dir and now-lastScan>.45 then
    lastScan=now;lastTarget,targetCount=findTargets()
   end
   if state.aim and lastTarget then doAim(lastTarget) end
   if state.shoot and now-lastShot>.25 then lastShot=now;doShoot() end
   if state.farm and r and h and dir then
    if lastTarget then
     emptyAt=nil
     if state.moveDuringWave then mode=moveStraight(r,h)
     else mode='WAVE ACTIVE / HOLD POSITION' end
    else
     if not emptyAt then emptyAt=now end
     if now-emptyAt>=1.1 then mode=moveStraight(r,h)
     else mode='WAIT WAVE CONFIRM' end
    end
   elseif not state.farm and dir then mode='FARM OFF' end
   local progress=dir and origin and r and math.floor((r.Position-origin):Dot(dir)) or 0
   local tname=lastTarget and lastTarget.Name or '-'
   debug.Text=string.format('STATE: %s\nTARGET: %s | COUNT: %d\nFORWARD: %s | PROGRESS: %s\nGATE: %s | SHOOT TOOL: %s',mode,tname,targetCount,dir and 'SET' or 'NO',tostring(progress),gatePos and 'SET' or 'NO',(P.Character and P.Character:FindFirstChildOfClass('Tool')) and 'YES' or 'NO')
  end)
  if not ok then debug.Text='ERROR: '..tostring(err):sub(1,170) end
  task.wait(.15)
 end
end)
print('[BowForge V1.6] loaded. Set Forward before Auto Farm.')
