-- +1 Bow Forge | Independent Hub V3 - Stage 25..30 research build
-- Not a copy of CM Hub. Does not access, modify or bypass its key system.
-- Locators are based on player-observed Workspace paths. Client game changes may break them.
-- Stage transitions / firing / UI controls need live testing; status reports attempts, not confirmed success.

local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local VirtualUser = game:GetService('VirtualUser')
local player = Players.LocalPlayer
if not player then return end
local pg = player:WaitForChild('PlayerGui')
local env = (type(getgenv)=='function' and getgenv()) or _G
if type(env.BowHubStage30Stop)=='function' then pcall(env.BowHubStage30Stop) end
local old = pg:FindFirstChild('BowHubStage30V3')
if old then old:Destroy() end

local SPEEDS={32,40,48,64,80}
local GATES={
 [25]=3091.73584,[26]=3213.18066,[27]=3334.29395,
 [28]=3455.55493,[29]=3577.51611,[30]=3698.96118
}
local X_LANE=11.182
local alive=true
local flags={Farm=false,Aim=true,Shoot=false,Speed=false,Rebirth=false,Boss=false,Gifts=false,Abilities=false,AntiAFK=false}
local chosenSpeed=48
local originalHum,originalSpeed=nil,nil
local stage=25
local status='READY - Start near Stage 25'
local detected=0
local targetName='-'
local mobSeen=false
local emptyAt=nil
local lastMove,lastAim,lastShoot,lastScan,lastUtility,lastUi=0,0,0,0,0,0
local target,stageMobs=nil,{}
local actions={click=0,rebirth=0,gifts=0,ability=0,boss=0}
local connections={}

local function character() return player.Character end
local function root() local c=character();return c and c:FindFirstChild('HumanoidRootPart') end
local function humanoid() local c=character();return c and c:FindFirstChildOfClass('Humanoid') end
local function new(kind,props,parent)
 local x=Instance.new(kind)
 for k,v in pairs(props or {}) do x[k]=v end
 x.Parent=parent
 return x
end
local function corner(parent,rad) new('UICorner',{CornerRadius=UDim.new(0,rad or 8)},parent) end
local colors={bg=Color3.fromRGB(18,26,38),card=Color3.fromRGB(31,43,58),gold=Color3.fromRGB(232,184,91),green=Color3.fromRGB(26,115,78),red=Color3.fromRGB(105,48,54),grey=Color3.fromRGB(49,65,83)}
local gui=new('ScreenGui',{Name='BowHubStage30V3',ResetOnSpawn=false,DisplayOrder=99999,IgnoreGuiInset=false},pg)
local main=new('Frame',{Size=UDim2.new(0.88,0,0.66,0),Position=UDim2.new(.06,0,.18,0),BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true},gui)
new('UISizeConstraint',{MaxSize=Vector2.new(354,440),MinSize=Vector2.new(260,260)},main)
corner(main,12)
new('UIStroke',{Color=colors.gold,Thickness=1},main)
local header=new('Frame',{Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.fromRGB(28,37,49),BorderSizePixel=0,Active=true},main)
corner(header,12)
new('TextLabel',{Size=UDim2.new(1,-92,1,0),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=14,Text='BOW FORGE HUB V3',TextColor3=colors.gold,TextXAlignment=Enum.TextXAlignment.Left},header)
local mini=new('TextButton',{Size=UDim2.fromOffset(29,28),Position=UDim2.new(1,-65,0,7),Text='-',Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Color3.new(1,1,1),BackgroundColor3=colors.grey},header)
local quit=new('TextButton',{Size=UDim2.fromOffset(29,28),Position=UDim2.new(1,-33,0,7),Text='X',Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.new(1,1,1),BackgroundColor3=colors.red},header)
corner(mini);corner(quit)
local bubble=new('TextButton',{Size=UDim2.fromOffset(62,43),Position=UDim2.fromOffset(14,150),Text='BOW V3',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=colors.gold,BackgroundColor3=colors.bg,Visible=false},gui)
corner(bubble)
mini.MouseButton1Click:Connect(function()main.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()main.Visible=true;bubble.Visible=false end)
local tabbar=new('Frame',{Size=UDim2.new(1,-16,0,34),Position=UDim2.fromOffset(8,49),BackgroundTransparency=1},main)
local pageArea=new('Frame',{Size=UDim2.new(1,-16,1,-170),Position=UDim2.fromOffset(8,89),BackgroundTransparency=1},main)
local pages,tabButtons={},{}
local function choosePage(key)
 for n,v in pairs(pages) do v.Visible=n==key end
 for n,b in pairs(tabButtons) do b.BackgroundColor3=n==key and colors.green or colors.grey end
end
for i,n in ipairs({'FARM','COMBAT','UTILITY'}) do
 local b=new('TextButton',{Size=UDim2.new(1/3,-4,1,0),Position=UDim2.new((i-1)/3,0,0,0),Text=n,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.new(1,1,1),BackgroundColor3=colors.grey},tabbar)
 corner(b,6);tabButtons[n]=b
 local p=new('ScrollingFrame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false},pageArea)
 new('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},p)
 pages[n]=p
 b.MouseButton1Click:Connect(function()choosePage(n)end)
end
local function row(page,name,desc,cb)
 local frame=new('Frame',{Size=UDim2.new(1,-6,0,54),BackgroundColor3=colors.card,BorderSizePixel=0},pages[page]);corner(frame,7)
 new('TextLabel',{Size=UDim2.new(1,-92,0,23),Position=UDim2.fromOffset(9,3),Text=name,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},frame)
 new('TextLabel',{Size=UDim2.new(1,-15,0,21),Position=UDim2.fromOffset(9,28),Text=desc,BackgroundTransparency=1,TextColor3=Color3.fromRGB(174,188,205),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},frame)
 local b=new('TextButton',{Size=UDim2.fromOffset(70,29),Position=UDim2.new(1,-78,0,9),Text='OFF',BackgroundColor3=colors.red,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=11},frame)
 corner(b,7)
 b.MouseButton1Click:Connect(function()cb(b)end)
 return b
end
local function toggle(page,name,desc,key,initial)
 flags[key]=initial or false
 local b
 b=row(page,name,desc,function(button)
  flags[key]=not flags[key]
  button.Text=flags[key] and 'ON' or 'OFF'
  button.BackgroundColor3=flags[key] and colors.green or colors.red
  status=name..' '..button.Text
  if key=='Farm' then mobSeen=false;emptyAt=nil;lastMove=0 end
 end)
 b.Text=flags[key] and 'ON' or 'OFF';b.BackgroundColor3=flags[key] and colors.green or colors.red
 return b
end
local function action(page,name,desc,onClick)
 local b=row(page,name,desc,function(button)
  local ok,err=pcall(onClick,button)
  if not ok then status='ERROR: '..tostring(err):sub(1,80) end
 end)
 b.Text='RUN';b.BackgroundColor3=colors.grey
 return b
end

toggle('FARM','AUTO FARM 25-30','Stage-local monster scan + movement','Farm',false)
toggle('FARM','AUTO AIM','Camera follows active local mobs','Aim',true)
toggle('FARM','AUTO SHOOT (TEST)','Tool Activate / mouse1click, may not fire bow','Shoot',false)
action('FARM','START AT STAGE 25','Reset local stage tracking',function()
 stage=25;mobSeen=false;emptyAt=nil;status='TRACKING STAGE 25'
end)
action('FARM','RESCAN CURRENT STAGE','Refresh active NPC scan',function()lastScan=0;status='RESCANNING MOB MODELS' end)
toggle('COMBAT','AUTO WORLD BOSS (TEST)','Look for boss model, aim and activate attack','Boss',false)
toggle('COMBAT','AUTO CAST ABILITIES (TEST)','Try visible weapon ability GUI buttons','Abilities',false)
toggle('COMBAT','SPEED HACK','WalkSpeed boost based on working V2.1','Speed',false)
action('COMBAT','CHANGE SPEED','32 / 40 / 48 / 64 / 80',function(b)
 local idx=1
 for i,v in ipairs(SPEEDS) do if v==chosenSpeed then idx=i;break end end
 chosenSpeed=SPEEDS[(idx % #SPEEDS)+1];b.Text=tostring(chosenSpeed);status='SPEED SET '..chosenSpeed
end)
toggle('UTILITY','AUTO REBIRTH (TEST)','Tries visible Rebirth button when ready','Rebirth',false)
toggle('UTILITY','AUTO FREE GIFTS (TEST)','Tries visible Claim/Gift buttons','Gifts',false)
toggle('UTILITY','ANTI AFK','Uses idle virtual input','AntiAFK',false)
action('UTILITY','RESET HUD POSITION','Center the GUI panel',function()main.Position=UDim2.new(.06,0,.18,0)end)
local debug=new('TextLabel',{Size=UDim2.new(1,-16,0,68),Position=UDim2.new(0,8,1,-77),BackgroundColor3=colors.card,TextColor3=Color3.fromRGB(231,237,242),TextSize=10,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,Text='Loading...',BorderSizePixel=0},main)
corner(debug,7)
choosePage('FARM')

local drag,startInput,startPosition=false,nil,nil
header.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true;startInput=i.Position;startPosition=main.Position end
end)
header.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
end)
table.insert(connections,UIS.InputChanged:Connect(function(i)
 if drag and startInput and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
  local d=i.Position-startInput;main.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
 end
end))

local function restoreSpeed()
 if originalHum and originalHum.Parent and originalSpeed then pcall(function()originalHum.WalkSpeed=originalSpeed end)end
 originalHum=nil;originalSpeed=nil
end
local function stop()
 alive=false;restoreSpeed()
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
 if gui and gui.Parent then gui:Destroy() end
 if env.BowHubStage30Stop==stop then env.BowHubStage30Stop=nil end
end
env.BowHubStage30Stop=stop
quit.MouseButton1Click:Connect(stop)
local function mobRoot(m)
 local part=m:FindFirstChild('HumanoidRootPart') or m.PrimaryPart or m:FindFirstChildWhichIsA('BasePart',true)
 return (part and part:IsA('BasePart')) and part or nil
end
local function getMobs()
 local f=workspace:FindFirstChild('FxLocal')
 return f and f:FindFirstChild('Mobs')
end
local function refreshMobs()
 local folder=getMobs();local result={}
 if not folder then return result end
 local beginZ=GATES[stage]+10
 local endZ=(GATES[stage+1] or (GATES[30]+122))-10
 for _,m in ipairs(folder:GetChildren()) do
  if m:IsA('Model') then
   local p=mobRoot(m)
   local h=m:FindFirstChildOfClass('Humanoid')
   if p and h and h.Health>0 and p.Position.Z>beginZ and p.Position.Z<endZ and math.abs(p.Position.X-X_LANE)<65 and p.Position.Y>575 then
    result[#result+1]={model=m,part=p,z=p.Position.Z}
   end
  end
 end
 table.sort(result,function(a,b)return a.z<b.z end)
 return result
end
local function clickVisible(words)
 local count=0
 for _,v in ipairs(pg:GetDescendants()) do
  if v:IsA('GuiButton') and v.Visible then
   local label=(v.Name..' '..(v:IsA('TextButton') and v.Text or '')):lower()
   local match=false
   for _,word in ipairs(words) do if label:find(word,1,true) then match=true;break end end
   if match then
    local allowed=true;local parent=v.Parent
    while parent and parent~=pg do
     if parent:IsA('GuiObject') and not parent.Visible then allowed=false;break end
     parent=parent.Parent
    end
    if allowed then
     if type(firesignal)=='function' then
      local ok=pcall(function()firesignal(v.Activated)end)
      if ok then count=count+1 end
     end
    end
   end
  end
 end
 return count
end
local function fireBow()
 local c=character();local t=c and c:FindFirstChildOfClass('Tool')
 if t then pcall(function()t:Activate()end);return 'TOOL' end
 if type(mouse1click)=='function' then pcall(mouse1click);return 'CLICK' end
 return 'NO BOW INPUT'
end
local function aimAt(pos)
 local cam=workspace.CurrentCamera
 if cam then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,pos+Vector3.new(0,1.4,0)) end
end
local function moveOnLane(h,r,z)
 local dz=z-r.Position.Z
 local nextZ=r.Position.Z+math.clamp(dz,0,19)
 if dz>2 then h:MoveTo(Vector3.new(X_LANE,r.Position.Y,nextZ)) end
end
local function findBoss()
 local folder=getMobs()
 if not folder then return nil end
 for _,m in ipairs(folder:GetChildren()) do
  if m:IsA('Model') and m.Name:lower():find('boss',1,true) then
   local h=m:FindFirstChildOfClass('Humanoid');local p=mobRoot(m)
   if p and h and h.Health>0 and p.Position.Z>1000 then return p end
  end
 end
 return nil
end

table.insert(connections,player.Idled:Connect(function()
 if flags.AntiAFK then pcall(function()VirtualUser:CaptureController();VirtualUser:ClickButton2(Vector2.new(0,0))end) end
end))

local function step()
 local now=os.clock();local r=root();local h=hum()
 if not r or not h then status='WAIT CHARACTER';return end
 if flags.Speed then
  if originalHum~=h then restoreSpeed();originalHum=h;originalSpeed=h.WalkSpeed end
  if h.WalkSpeed~=chosenSpeed then h.WalkSpeed=chosenSpeed end
 elseif originalHum then restoreSpeed() end
 if flags.Farm then
  if r.Position.Z>GATES[30]+103 then
   flags.Farm=false;status='STAGE 30 FINISH AREA REACHED (UNVERIFIED CLEAR)'
  else
   -- Root position establishes stage progress, not a UI label.
   while stage<30 and r.Position.Z>=GATES[stage+1]+8 do
    stage=stage+1;mobSeen=false;emptyAt=nil;lastScan=0
   end
   if now-lastScan>.4 then
    stageMobs=refreshMobs();detected=#stageMobs;lastScan=now
   end
   if detected>0 then
    mobSeen=true;emptyAt=nil
    local chosen=nil;local score=math.huge
    for _,entry in ipairs(stageMobs) do
     local d=(entry.part.Position-r.Position).Magnitude
     if d<score then chosen=entry;score=d end
    end
    target=chosen;targetName=chosen and chosen.model.Name or '-'
    status='FIGHT STAGE '..stage..' | MOBS '..detected
    if chosen then
     if flags.Aim and now-lastAim>.07 then aimAt(chosen.part.Position);lastAim=now end
     if now-lastMove>.6 then
      -- Move only forward along X=11.182. Do not chase side or old stages.
      moveOnLane(h,r,math.max(r.Position.Z,chosen.part.Position.Z-24))
      lastMove=now
     end
    end
   else
    target=nil;targetName='-';emptyAt=emptyAt or now
    if now-emptyAt<2 then status='VERIFY EMPTY STAGE '..stage
    else
     -- Some waves spawn after a delay. Never claim an actual server gate unlock.
     local goal=(GATES[stage+1] or (GATES[30]+105))+10
     if now-lastMove>.65 then moveOnLane(h,r,goal);lastMove=now end
     status=(mobSeen and 'WAVE CLEAR' or 'NO MOB FOUND')..' -> STAGE '..math.min(stage+1,30)
    end
   end
  end
 end
 if flags.Boss and now-lastShoot>.2 then
  local b=findBoss()
  if b then
   if flags.Aim then aimAt(b.Position)end
   fireBow();actions.boss=actions.boss+1;lastShoot=now;status='WORLD BOSS: ATTACK ATTEMPT'
  end
 end
 if flags.Shoot and flags.Farm and detected>0 and now-lastShoot>.25 then
  fireBow();actions.click=actions.click+1;lastShoot=now
 end
 if now-lastUtility>3 then
  lastUtility=now
  if flags.Rebirth then actions.rebirth=actions.rebirth+clickVisible({'rebirth'}) end
  if flags.Gifts then actions.gifts=actions.gifts+clickVisible({'claim','free gift','collect gift'}) end
  if flags.Abilities then actions.ability=actions.ability+clickVisible({'ability','skill','cast'}) end
 end
 if now-lastUi>.25 then
  debug.Text=string.format('STAGE: %d/30 | MOBS: %d | Z: %.1f\nTARGET: %s\nSTATUS: %s\nSPEED: %.0f | ATTACK TRY: %d',stage,detected,r.Position.Z,targetName,status,h.WalkSpeed,actions.click)
  lastUi=now
 end
end

task.spawn(function()
 while alive and gui.Parent do
  local ok,err=pcall(step)
  if not ok then status='LUA ERROR: '..tostring(err):sub(1,90) end
  task.wait(.12)
 end
end)
print('[BowForge V3] Standalone research build loaded. Stage 25..30 detection based on client mob positions; no guarantee of kills or stage completion.')
