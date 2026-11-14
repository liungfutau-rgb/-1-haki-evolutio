-- +1 Bow Forge | Speed + Auto Loot V2.2
-- Based on the GUI design and working WalkSpeed approach of V2.1.
-- Loot mapping is experimental: only ProximityPrompts with detectable rarity are eligible.
-- No auto farm, aim, shoot, rapid attack or gate movement.

local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild('PlayerGui')
local env = (getgenv and getgenv()) or _G
if type(env.BowFarmStop)=='function' then pcall(env.BowFarmStop) end
if type(env.BowSpeedLootStop)=='function' then pcall(env.BowSpeedLootStop) end
for _,name in ipairs({'BowFarmV20','BowFarmV21','BowSpeedLootV22'}) do
 local existing=playerGui:FindFirstChild(name)
 if existing then existing:Destroy() end
end

local running=true
local speedOn=false
local speedChoice=48
local originalSpeed, originalHumanoid=nil,nil
local lootOn=false
local allowUnknown=false -- safe default: do not pick up unidentified loot
local rarityNames={'Common','Uncommon','Rare','Epic','Legendary','Mythic','Secret'}
local raritySelected={Common=false,Uncommon=false,Rare=true,Epic=true,Legendary=true,Mythic=true,Secret=true}
local connections={}
local scanResult={seen=0,eligible=0,unknown=0,attempted=0,reason='NOT SCANNED',last='-'}
local lastAttempt=setmetatable({}, {__mode='k'})
local status='READY | select loot rarity then scan'
local function character() return player.Character end
local function humanoid() local c=character();return c and c:FindFirstChildOfClass('Humanoid') end
local function root() local c=character();return c and c:FindFirstChild('HumanoidRootPart') end
local function ui(class,properties,parent)
 local x=Instance.new(class)
 for k,v in pairs(properties) do x[k]=v end
 x.Parent=parent
 return x
end
local gui=ui('ScreenGui',{Name='BowSpeedLootV22',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=9999},playerGui)
local main=ui('Frame',{Size=UDim2.fromOffset(330,390),Position=UDim2.new(.5,-165,.5,-195),BackgroundColor3=Color3.fromRGB(18,27,36),BorderSizePixel=0,Active=true},gui)
ui('UICorner',{CornerRadius=UDim.new(0,12)},main)
ui('UIStroke',{Color=Color3.fromRGB(221,170,81),Thickness=1},main)
local scale=ui('UIScale',{Scale=1},main)
local function fitScreen()
 local cam=workspace.CurrentCamera
 if not cam then return end
 local v=cam.ViewportSize
 scale.Scale=math.min(1,math.max(.55,math.min((v.X-18)/330,(v.Y-28)/390)))
end
fitScreen()
local camChanged=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(fitScreen)
local header=ui('TextLabel',{Size=UDim2.new(1,-55,0,41),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text='BOW FORGE | SPEED + LOOT V2.2',TextColor3=Color3.fromRGB(242,199,106),TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Active=true},main)
local mini=ui('TextButton',{Size=UDim2.fromOffset(33,30),Position=UDim2.new(1,-40,0,6),Text='-',TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(48,60,76),BorderSizePixel=0},main)
ui('UICorner',{CornerRadius=UDim.new(0,7)},mini)
local bubble=ui('TextButton',{Size=UDim2.fromOffset(64,42),Position=UDim2.fromOffset(12,160),Text='BOW',TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(142,104,37),Visible=false},gui)
ui('UICorner',{CornerRadius=UDim.new(0,9)},bubble)
local content=ui('ScrollingFrame',{
 Name='ScrollArea',Size=UDim2.new(1,-12,1,-51),Position=UDim2.fromOffset(6,45),
 CanvasSize=UDim2.fromOffset(0,650),ScrollingDirection=Enum.ScrollingDirection.Y,
 ScrollBarThickness=5,ScrollBarImageColor3=Color3.fromRGB(221,170,81),
 ScrollingEnabled=true,Active=true,BackgroundTransparency=1,BorderSizePixel=0,
},main)
local function button(text,x,y,w,callback)
 local b=ui('TextButton',{Size=UDim2.fromOffset(w,36),Position=UDim2.fromOffset(x,y),Text=text,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(43,58,74),BorderSizePixel=0},content)
 ui('UICorner',{CornerRadius=UDim.new(0,8)},b)
 b.MouseButton1Click:Connect(function() local ok,err=pcall(callback,b);if not ok then warn('[BowSpeedLootV22] '..tostring(err)) end end)
 return b
end
local onColor=Color3.fromRGB(30,115,82)
local offColor=Color3.fromRGB(43,58,74)
local function paint(b,value) b.BackgroundColor3=value and onColor or offColor end
local function restoreSpeed()
 if originalHumanoid and originalHumanoid.Parent and originalSpeed then
  pcall(function() originalHumanoid.WalkSpeed=originalSpeed end)
 end
end
local speedBtn
speedBtn=button('SPEED: OFF',9,5,150,function(b)
 speedOn=not speedOn
 if not speedOn then restoreSpeed() end
 b.Text=speedOn and 'SPEED: ON' or 'SPEED: OFF'
 paint(b,speedOn)
end)
local speedValue
speedValue=button('WALK: 48',170,5,150,function(b)
 local values={32,40,48,64,80}
 local pos=1
 for i,v in ipairs(values) do if v==speedChoice then pos=i;break end end
 speedChoice=values[pos % #values+1]
 b.Text='WALK: '..speedChoice
end)
ui('TextLabel',{Size=UDim2.fromOffset(305,25),Position=UDim2.fromOffset(10,51),BackgroundTransparency=1,Text='AUTO LOOT | SELECT RARITY',Font=Enum.Font.GothamBold,TextSize=13,TextColor3=Color3.fromRGB(242,199,106),TextXAlignment=Enum.TextXAlignment.Left},content)
local lootBtn
lootBtn=button('AUTO LOOT: OFF',9,81,310,function(b)
 lootOn=not lootOn
 b.Text=lootOn and 'AUTO LOOT: ON' or 'AUTO LOOT: OFF'
 paint(b,lootOn)
 status=lootOn and 'Auto Loot enabled (proximity prompts only)' or 'Auto Loot disabled'
end)
local rarityButtons={}
for i,name in ipairs(rarityNames) do
 local col=(i-1)%2
 local row=math.floor((i-1)/2)
 local b
 b=button(name..': '..(raritySelected[name] and 'ON' or 'OFF'),9+161*col,128+row*43,150,function(btn)
  raritySelected[name]=not raritySelected[name]
  btn.Text=name..': '..(raritySelected[name] and 'ON' or 'OFF')
  paint(btn,raritySelected[name])
 end)
 paint(b,raritySelected[name]);rarityButtons[name]=b
end
local unknownBtn
unknownBtn=button('UNKNOWN RARITY: OFF',9,306,310,function(b)
 allowUnknown=not allowUnknown
 b.Text=allowUnknown and 'UNKNOWN RARITY: ON' or 'UNKNOWN RARITY: OFF'
 paint(b,allowUnknown)
end)
ui('TextLabel',{Size=UDim2.fromOffset(308,30),Position=UDim2.fromOffset(10,347),BackgroundTransparency=1,Text='Unknown OFF = skip loot with unreadable rarity',TextColor3=Color3.fromRGB(172,186,199),TextSize=10,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},content)

local function textFrom(obj)
 local out={obj.Name}
 if obj:IsA('ProximityPrompt') then
  table.insert(out,obj.ActionText or '')
  table.insert(out,obj.ObjectText or '')
 end
 for _,attr in ipairs({'Rarity','Tier','Quality','ItemRarity','LootRarity'}) do
  local val=obj:GetAttribute(attr)
  if val~=nil then table.insert(out,tostring(val)) end
  local child=obj:FindFirstChild(attr)
  if child and child:IsA('ValueBase') then table.insert(out,tostring(child.Value)) end
 end
 return table.concat(out,' ')
end
local function rarityOf(prompt)
 -- Prefer explicitly named rarity metadata over arbitrary ancestor names.
 local obj=prompt
 for _=1,5 do
  if not obj then break end
  for _,key in ipairs({'Rarity','ItemRarity','LootRarity','Tier','Quality'}) do
   local val=obj:GetAttribute(key)
   local child=obj:FindFirstChild(key)
   if val==nil and child and child:IsA('ValueBase') then val=child.Value end
   if val~=nil then
    local raw=tostring(val):lower()
    for _,rarity in ipairs({'Uncommon','Legendary','Mythic','Secret','Common','Rare','Epic'}) do
     if raw:find(rarity:lower(),1,true) then return rarity end
    end
   end
  end
  obj=obj.Parent
 end
 obj=prompt
 for _=1,5 do
  if not obj then break end
  local raw=textFrom(obj):lower()
  -- Uncommon first, otherwise it may be misread as Common.
  for _,rarity in ipairs({'Uncommon','Legendary','Mythic','Secret','Common','Rare','Epic'}) do
   if raw:find(rarity:lower(),1,true) then return rarity end
  end
  obj=obj.Parent
 end
 return nil
end
local function promptPosition(prompt)
 local obj=prompt.Parent
 if obj and obj:IsA('Attachment') then return obj.WorldPosition end
 if obj and obj:IsA('BasePart') then return obj.Position end
 if obj and obj:IsA('Model') then return obj:GetPivot().Position end
 local model=prompt:FindFirstAncestorOfClass('Model')
 if model then return model:GetPivot().Position end
 return nil
end
local function lootPrompt(prompt)
 -- Avoid arbitrary game prompts such as doors and shops.
 local s=(prompt.Name..' '..(prompt.ActionText or '')..' '..(prompt.ObjectText or '')):lower()
 if s:find('loot',1,true) or s:find('collect',1,true) or s:find('pickup',1,true) or s:find('pick up',1,true) or s:find('drop',1,true) or s:find('claim',1,true) then return true end
 local p=prompt.Parent
 for _=1,3 do
  if not p then break end
  local n=p.Name:lower()
  if n:find('loot',1,true) or n:find('drop',1,true) then return true end
  p=p.Parent
 end
 return false
end
local lastPrinted=''
local function scan(tryCollect)
 local r=root()
 local seen,eligible,unknown,attempted=0,0,0,0
 local last='-'
 if not r then scanResult.reason='NO CHARACTER';return end
 local fire=type(fireproximityprompt)=='function' and fireproximityprompt or nil
 for _,prompt in ipairs(workspace:GetDescendants()) do
  if prompt:IsA('ProximityPrompt') and prompt.Enabled and lootPrompt(prompt) then
   seen=seen+1
   local rarity=rarityOf(prompt)
   if not rarity then unknown=unknown+1 end
   if (rarity and raritySelected[rarity]) or (not rarity and allowUnknown) then
    eligible=eligible+1
    last=(rarity or 'Unknown')..' / '..prompt.ObjectText
    if tryCollect and fire then
     local pos=promptPosition(prompt)
     if pos and (r.Position-pos).Magnitude<=math.max(5,prompt.MaxActivationDistance) then
      local now=os.clock()
      if now-(lastAttempt[prompt] or 0)>=2 then
       lastAttempt[prompt]=now
       local ok=pcall(fire,prompt)
       if ok then attempted=attempted+1 end
      end
     end
    end
   end
  end
 end
 scanResult={seen=seen,eligible=eligible,unknown=unknown,attempted=attempted,last=last,
  reason=not fire and 'fireproximityprompt unavailable' or 'ProximityPrompt scan only'}
end
button('SCAN LOOT NOW',9,385,150,function()
 scan(false)
 status='Scan complete; inspect DEBUG below'
end)
button('SELECT ALL / NONE',170,385,150,function()
 local all=true
 for _,name in ipairs(rarityNames) do if not raritySelected[name] then all=false;break end end
 for _,name in ipairs(rarityNames) do
  raritySelected[name]=not all
  local b=rarityButtons[name]
  b.Text=name..': '..(raritySelected[name] and 'ON' or 'OFF');paint(b,raritySelected[name])
 end
end)
local debug=ui('TextLabel',{Size=UDim2.fromOffset(308,147),Position=UDim2.fromOffset(10,432),BackgroundColor3=Color3.fromRGB(30,43,56),TextColor3=Color3.fromRGB(229,237,245),TextSize=11,Font=Enum.Font.Code,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text='STATUS: READY',BorderSizePixel=0},content)
ui('UICorner',{CornerRadius=UDim.new(0,9)},debug)
local function shutdown()
 running=false
 restoreSpeed()
 pcall(function() camChanged:Disconnect() end)
 for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
 if gui.Parent then gui:Destroy() end
 if env.BowSpeedLootStop==shutdown then env.BowSpeedLootStop=nil end
end
env.BowSpeedLootStop=shutdown
button('CLOSE',9,594,310,shutdown)
mini.MouseButton1Click:Connect(function() main.Visible=false;bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function()main.Visible=true;bubble.Visible=false end)
local dragging,startMouse,startPos=false,nil,nil
table.insert(connections,header.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;startMouse=input.Position;startPos=main.Position
 end
end))
table.insert(connections,header.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if dragging and startMouse and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local d=input.Position-startMouse
  main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
 end
end))
task.spawn(function()
 local priorChar=nil
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
   if os.clock()>=nextScan then
    scan(lootOn)
    nextScan=os.clock()+1.5
   end
   debug.Text=string.format('SPEED: %s | WALK: %s\nAUTO LOOT: %s | UNKNOWN: %s\nLOOT PROMPTS: %d | MATCHED: %d\nRARITY UNKNOWN: %d | ATTEMPTS: %d\nLAST MATCH: %s\nSCAN: %s\nSTATUS: %s',
    speedOn and 'ON' or 'OFF',h and tostring(h.WalkSpeed) or '-',lootOn and 'ON' or 'OFF',allowUnknown and 'ON' or 'OFF',
    scanResult.seen,scanResult.eligible,scanResult.unknown,scanResult.attempted,scanResult.last,
    scanResult.reason,status)
  end)
  if not ok then warn('[BowSpeedLootV22] '..tostring(err));status='ERROR: '..tostring(err):sub(1,80) end
  task.wait(.2)
 end
end)
print('[BowForge] V2.2 Speed + Auto Loot loaded. Loot requires detectable ProximityPrompt/rarity.')
