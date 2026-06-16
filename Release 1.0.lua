local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-----------------------------------
-- BUILT-IN PNG ICON GENERATOR
-----------------------------------
local function packI4_big(v)
    return string.char(bit32.band(bit32.rshift(v, 24), 255), bit32.band(bit32.rshift(v, 16), 255), bit32.band(bit32.rshift(v, 8), 255), bit32.band(v, 255))
end

local function packI2_little(v)
    return string.char(bit32.band(v, 255), bit32.band(bit32.rshift(v, 8), 255))
end

local function crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local b = string.byte(data, i)
        crc = bit32.bxor(crc, b)
        for j = 1, 8 do
            local mask = bit32.band(crc, 1) == 1 and 0xEDB88320 or 0
            crc = bit32.bxor(bit32.rshift(crc, 1), mask)
        end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
end

local function adler32(data)
    local s1, s2 = 1, 0
    for i = 1, #data do
        local b = string.byte(data, i)
        s1 = (s1 + b) % 65521
        s2 = (s2 + s1) % 65521
    end
    return s2 * 65536 + s1
end

local function writeChunk(ctype, data)
    local len = packI4_big(#data)
    local crc = packI4_big(crc32(ctype .. data))
    return len .. ctype .. data .. crc
end

local function createPNG(width, height, drawFunc)
    local raw_data_tbl = {}
    for y = 0, height - 1 do
        table.insert(raw_data_tbl, string.char(0))
        for x = 0, width - 1 do
            local r, g, b, a = drawFunc(x, y)
            table.insert(raw_data_tbl, string.char(r, g, b, a))
        end
    end
    local raw_data = table.concat(raw_data_tbl)
    
    local len = #raw_data
    local nlen = bit32.bxor(len, 0xFFFF)
    local deflate_data = string.char(0x01) .. packI2_little(len) .. packI2_little(nlen) .. raw_data
    local zlib_data = string.char(0x78, 0x01) .. deflate_data .. packI4_big(adler32(raw_data))
    local ihdr = packI4_big(width) .. packI4_big(height) .. string.char(8, 6, 0, 0, 0)
    
    return "\137PNG\r\n\26\n" .. writeChunk("IHDR", ihdr) .. writeChunk("IDAT", zlib_data) .. writeChunk("IEND", "")
end

local function drawSpiral(x, y)
    local cx, cy = 16, 16
    local dx, dy = x - cx, y - cy
    local dist = math.sqrt(dx^2 + dy^2)
    local angle = math.atan2(dy, dx)
    if angle < 0 then angle = angle + 2 * math.pi end
    local min_diff = 100
    for k = 0, 8 do
        local r_ideal = 0.6 * (angle + 2 * math.pi * k)
        local diff = math.abs(dist - r_ideal)
        if diff < min_diff then min_diff = diff end
    end
    if min_diff <= 1.0 and dist <= 14 then return 255, 255, 255, 255 end
    return 0, 0, 0, 0
end

local function drawInfinity(x, y)
    local d1 = math.abs(math.sqrt((x - 10)^2 + (y - 16)^2) - 5)
    local d2 = math.abs(math.sqrt((x - 22)^2 + (y - 16)^2) - 5)
    if d1 <= 1.5 or d2 <= 1.5 then return 255, 255, 255, 255 end
    return 0, 0, 0, 0
end

local function drawBoat(x, y)
    local a = 0
    if y >= 22 and y <= 26 then
        local w = (y - 22)
        local left, right = 6 + w, 26 - w
        if x >= left and x <= right then
            if math.abs(x - left) <= 1 or math.abs(x - right) <= 1 or math.abs(y - 26) <= 1 or math.abs(y - 22) <= 1 then a = 255 end
        end
    end
    if x == 16 and y >= 4 and y <= 22 then a = 255 end
    if x >= 6 and x <= 14 and y >= 6 and y <= 20 then
        local slopeX = 14 - (y - 6) * (8 / 14)
        if math.abs(x - slopeX) <= 1 or x == 14 or y == 20 then
            if x <= slopeX then a = 255 end
        end
    end
    if x >= 18 and x <= 26 and y >= 6 and y <= 20 then
        local curveX = 18 + 8 * math.sin((y - 6) / 14 * math.pi / 2)
        if math.abs(x - curveX) <= 1 or x == 18 or y == 20 then
            if x <= curveX then a = 255 end
        end
        if (y == 10 or y == 15) and x <= curveX then a = 255 end
    end
    return 255, 255, 255, a
end

local function drawGeoTag(x, y)
    local cx, cy = 16, 11
    local d = math.sqrt((x - cx)^2 + (y - cy)^2)
    
    if d <= 3 then return 255, 255, 255, 255 end
    
    if y <= 15 then
        if math.abs(d - 7) <= 1 then return 255, 255, 255, 255 end
    elseif y <= 27 then
        local dy = 27 - y
        local targetX = dy * 0.58 
        if math.abs(math.abs(x - cx) - targetX) <= 1.2 then return 255, 255, 255, 255 end
    end
    return 0, 0, 0, 0
end

local function drawGlove(x, y)
    local a = 0
    -- Glove cuff (base)
    if y >= 24 and y <= 28 then
        if x >= 6 and x <= 26 then
            if y == 24 or y == 28 or x == 6 or x == 26 then a = 255 end
        end
    end
    -- Palm
    if y >= 14 and y <= 24 then
        if x >= 7 and x <= 25 then
            if x == 7 or x == 25 or y == 14 then a = 255 end
        end
    end
    -- Thumb (left)
    if x >= 4 and x <= 8 and y >= 10 and y <= 18 then
        if x == 4 or x == 8 or y == 10 then a = 255 end
    end
    -- Index finger
    if x >= 9 and x <= 13 and y >= 4 and y <= 14 then
        if x == 9 or x == 13 or y == 4 then a = 255 end
    end
    -- Middle finger
    if x >= 14 and x <= 18 and y >= 2 and y <= 14 then
        if x == 14 or x == 18 or y == 2 then a = 255 end
    end
    -- Ring finger
    if x >= 19 and x <= 22 and y >= 4 and y <= 14 then
        if x == 19 or x == 22 or y == 4 then a = 255 end
    end
    -- Pinky
    if x >= 23 and x <= 26 and y >= 7 and y <= 14 then
        if x == 23 or x == 26 or y == 7 then a = 255 end
    end
    return 255, 255, 255, a
end

if not isfolder("CheatMenuAssets") then makefolder("CheatMenuAssets") end
local paths = { 
    spiral = "CheatMenuAssets/spiral.png", 
    infinity = "CheatMenuAssets/infinity.png", 
    boat = "CheatMenuAssets/boat.png",
    geo = "CheatMenuAssets/geo.png",
    glove = "CheatMenuAssets/glove.png"
}

if not isfile(paths.spiral) then writefile(paths.spiral, createPNG(32, 32, drawSpiral)) end
if not isfile(paths.infinity) then writefile(paths.infinity, createPNG(32, 32, drawInfinity)) end
if not isfile(paths.boat) then writefile(paths.boat, createPNG(32, 32, drawBoat)) end
if not isfile(paths.geo) then writefile(paths.geo, createPNG(32, 32, drawGeoTag)) end
if not isfile(paths.glove) then writefile(paths.glove, createPNG(32, 32, drawGlove)) end

local spiralIcon = getcustomasset(paths.spiral)
local infinityIcon = getcustomasset(paths.infinity)
local boatIcon = getcustomasset(paths.boat)
local geoIcon = getcustomasset(paths.geo)
local gloveIcon = getcustomasset(paths.glove)

-----------------------------------
-- ANTI-PHANTOM (CLEANUP ON RELOAD)
-----------------------------------
if getgenv().CheatESP_Loop then getgenv().CheatESP_Loop:Disconnect() end
if getgenv().PlayerCheats_Heartbeat then getgenv().PlayerCheats_Heartbeat:Disconnect() end
if getgenv().PlayerCheats_Stepped then getgenv().PlayerCheats_Stepped:Disconnect() end
if getgenv().PlayerCheats_InputBegan then getgenv().PlayerCheats_InputBegan:Disconnect() end
if getgenv().PlayerCheats_JumpReq then getgenv().PlayerCheats_JumpReq:Disconnect() end
if getgenv().Menu_InputChanged then getgenv().Menu_InputChanged:Disconnect() end
if getgenv().AutoClicker_Conn then getgenv().AutoClicker_Conn:Disconnect() end
if getgenv().AutoClicker_KeyConn then getgenv().AutoClicker_KeyConn:Disconnect() end
getgenv().GoldFarmRunning = false
getgenv().GoldClaimRunning = false

if getgenv().CursorScript_Conn then getgenv().CursorScript_Conn:Disconnect() end
if CoreGui:FindFirstChild("CursorXYGui") then CoreGui.CursorXYGui:Destroy() end
if getgenv().CheatMenu_Gui then pcall(function() getgenv().CheatMenu_Gui:Destroy() end); getgenv().CheatMenu_Gui = nil end

if getgenv().CheatESP_Cache then
    for _, playerCache in pairs(getgenv().CheatESP_Cache) do
        for k, obj in pairs(playerCache) do
            if typeof(obj) == "Instance" then 
                pcall(function() obj:Destroy() end)
            elseif type(obj) == "table" and obj.Remove then 
                pcall(function() obj:Remove() end) 
            end
        end
    end
end
getgenv().CheatESP_Cache = {}
local espCache = getgenv().CheatESP_Cache

local ESP = { Enabled = false, ShowTeam = true, Mode = "Cubes", ChamsTransparency = 0.5, Hue = 0.5, Shade = 0.5, Color = Color3.fromRGB(95, 205, 228), Radius = 10000 }
local PlayerMods = { SpeedEnabled = false, SpeedValue = 16, JumpEnabled = false, JumpValue = 50, FlyEnabled = false, FlySpeed = 50, NoclipEnabled = false, WallWalkEnabled = false, InfJumpEnabled = false, AntiKnockback = false }
local TEXT_COLOR = Color3.fromRGB(180, 180, 185)

local function updateColor()
    local h = ESP.Hue
    local s, v = 1, 1
    if ESP.Shade < 0.5 then
        v = ESP.Shade * 2; s = 1
    else
        v = 1; s = 1 - ((ESP.Shade - 0.5) * 2)
    end
    ESP.Color = Color3.fromHSV(h, s, v)
end

-----------------------------------
-- USER INTERFACE
-----------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CheatMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui
getgenv().CheatMenu_Gui = ScreenGui

local function isShiftLockOptionEnabled()
    local enabled = false
    pcall(function()
        local settings = UserSettings()
        if settings then
            local gameSettings = settings.GameSettings or settings:GetService("UserGameSettings")
            if gameSettings then
                enabled = (gameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch)
            end
        end
    end)
    return enabled
end

local function getMouseLockController()
    local controller = nil
    pcall(function()
        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            local playerModule = require(playerScripts:FindFirstChild("PlayerModule"))
            if playerModule then
                if type(playerModule.GetCameras) == "function" then
                    local cameras = playerModule:GetCameras()
                    controller = cameras and cameras.activeMouseLockController
                end
                if not controller and playerModule.CameraModule then
                    controller = playerModule.CameraModule.activeMouseLockController or playerModule.CameraModule.MouseLockController
                end
            end
        end
    end)
    return controller
end

local _lastMouseBehavior = UserInputService.MouseBehavior
local _lastMouseIcon = UserInputService.MouseIconEnabled
local menuIsOpen = true
local _menuToken = 0

local _rmbHeld = false
local _rmbSettleUntil = 0

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then _rmbHeld = true end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        _rmbHeld = false
        _rmbSettleUntil = tick() + 0.3
    end
end)

RunService.Stepped:Connect(function()
    if not menuIsOpen or _rmbHeld then return end
    local settling = tick() < _rmbSettleUntil
    local mb = UserInputService.MouseBehavior
    if mb ~= Enum.MouseBehavior.Default then
        if not settling then _lastMouseBehavior = mb end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    local mie = UserInputService.MouseIconEnabled
    if not mie then
        if not settling then _lastMouseIcon = mie end
        UserInputService.MouseIconEnabled = true
    end
end)

local function onMenuToggle(isOpening)
    _menuToken = _menuToken + 1
    local myToken = _menuToken

    if isOpening then
        _lastMouseBehavior = UserInputService.MouseBehavior
        _lastMouseIcon = UserInputService.MouseIconEnabled
        ScreenGui.Parent = CoreGui
        menuIsOpen = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    else
        menuIsOpen = false
        ScreenGui.Parent = nil
        local restoreBehavior = _lastMouseBehavior
        local restoreIcon = _lastMouseIcon
        
        if restoreBehavior == Enum.MouseBehavior.LockCenter then
            if not isShiftLockOptionEnabled() then
                restoreBehavior = Enum.MouseBehavior.Default
            else
                local controller = getMouseLockController()
                local isEnabled = false
                if controller and type(controller.enabled) == "boolean" then
                    isEnabled = controller.enabled
                end
                if not isEnabled then
                    restoreBehavior = Enum.MouseBehavior.Default
                end
            end
        end

        task.wait()
        if _menuToken ~= myToken then return end
        UserInputService.MouseBehavior = restoreBehavior
        UserInputService.MouseIconEnabled = restoreIcon
    end
end

onMenuToggle(true)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 550, 0, 420)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local SideBar = Instance.new("Frame")
SideBar.Size = UDim2.new(0, 60, 1, 0)
SideBar.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
SideBar.BorderSizePixel = 0
SideBar.Parent = MainFrame
Instance.new("UICorner", SideBar).CornerRadius = UDim.new(0, 8)

local TopTabs = Instance.new("Frame")
TopTabs.Size = UDim2.new(1, 0, 1, -60)
TopTabs.BackgroundTransparency = 1
TopTabs.Parent = SideBar

local SideList = Instance.new("UIListLayout")
SideList.Parent = TopTabs
SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideList.Padding = UDim.new(0, 10)

local Spacer = Instance.new("Frame")
Spacer.Size = UDim2.new(1, 0, 0, 2)
Spacer.BackgroundTransparency = 1
Spacer.Parent = TopTabs

local function createTabIcon(parent, iconId, isActive)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 40, 0, 40)
    bg.BackgroundTransparency = isActive and 0.8 or 1
    bg.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    bg.Parent = parent
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(0.5, -12, 0.5, -12)
    btn.BackgroundTransparency = 1
    btn.Image = iconId
    btn.ImageColor3 = isActive and Color3.fromRGB(45, 125, 246) or Color3.fromRGB(150, 150, 150)
    btn.Modal = true
    btn.Parent = bg
    return bg, btn
end

-- Tabs
local EspTabBg, EspTabBtn = createTabIcon(TopTabs, spiralIcon, true) 
local IyTabBg, IyTabBtn = createTabIcon(TopTabs, infinityIcon, false) 
local BabftTabBg, BabftTabBtn = createTabIcon(TopTabs, boatIcon, false) 
local TeleportTabBg, TeleportTabBtn = createTabIcon(TopTabs, geoIcon, false) 
local SlapTabBg, SlapTabBtn = createTabIcon(TopTabs, gloveIcon, false) 
local EtcTabBg, EtcTabBtn = createTabIcon(TopTabs, "rbxassetid://7734053495", false) 

local TerminateBtn = Instance.new("TextButton")
TerminateBtn.Size = UDim2.new(0, 30, 0, 30)
TerminateBtn.Position = UDim2.new(0.5, -15, 1, -45)
TerminateBtn.BackgroundTransparency = 1
TerminateBtn.Text = "☠"
TerminateBtn.Font = Enum.Font.Gotham
TerminateBtn.TextSize = 22
TerminateBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
TerminateBtn.Modal = true
TerminateBtn.Parent = SideBar

local function createContainer()
    local c = Instance.new("ScrollingFrame")
    c.Size = UDim2.new(1, -80, 1, -20)
    c.Position = UDim2.new(0, 70, 0, 10)
    c.BackgroundTransparency = 1
    c.ScrollBarThickness = 0
    c.BorderSizePixel = 0
    c.ScrollingEnabled = true 
    c.Visible = false
    c.Parent = MainFrame
    local l = Instance.new("UIListLayout")
    l.Parent = c
    l.Padding = UDim.new(0, 10)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    return c, l
end

local EspContainer, EspLayout = createContainer()
local IyContainer, IyLayout = createContainer()
local BabftContainer, BabftLayout = createContainer()
local TeleportContainer, TeleportLayout = createContainer()
local SlapContainer, SlapLayout = createContainer()
local EtcContainer, EtcLayout = createContainer()

-- Layout lookup for CanvasSize updates (only update visible container each frame)
local containerLayouts

EspContainer.Visible = true

local tabsInfo = {
    {Btn = EspTabBtn, Bg = EspTabBg, Container = EspContainer},
    {Btn = IyTabBtn, Bg = IyTabBg, Container = IyContainer},
    {Btn = BabftTabBtn, Bg = BabftTabBg, Container = BabftContainer},
    {Btn = TeleportTabBtn, Bg = TeleportTabBg, Container = TeleportContainer},
    {Btn = SlapTabBtn, Bg = SlapTabBg, Container = SlapContainer},
    {Btn = EtcTabBtn, Bg = EtcTabBg, Container = EtcContainer}
}

-- Map each container to its layout for fast CanvasSize updates
containerLayouts = {
    [EspContainer]      = EspLayout,
    [IyContainer]       = IyLayout,
    [BabftContainer]    = BabftLayout,
    [TeleportContainer] = TeleportLayout,
    [SlapContainer]     = SlapLayout,
    [EtcContainer]      = EtcLayout,
}

local function switchTab(targetTabBtn)
    for _, tab in pairs(tabsInfo) do
        if tab.Btn == targetTabBtn then
            if not tab.Container.Visible then
                tab.Bg.BackgroundTransparency = 0.8
                tab.Btn.ImageColor3 = Color3.fromRGB(45, 125, 246)
                tab.Container.Position = UDim2.new(0, 90, 0, 10) 
                tab.Container.Visible = true
                TweenService:Create(tab.Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(0, 70, 0, 10)}):Play()
            end
        else
            tab.Bg.BackgroundTransparency = 1
            tab.Btn.ImageColor3 = Color3.fromRGB(150, 150, 150)
            tab.Container.Visible = false
        end
    end
end

EspTabBtn.MouseButton1Click:Connect(function() switchTab(EspTabBtn) end)
IyTabBtn.MouseButton1Click:Connect(function() switchTab(IyTabBtn) end)
BabftTabBtn.MouseButton1Click:Connect(function() switchTab(BabftTabBtn) end)
TeleportTabBtn.MouseButton1Click:Connect(function() switchTab(TeleportTabBtn) end)
SlapTabBtn.MouseButton1Click:Connect(function() switchTab(SlapTabBtn) end)
EtcTabBtn.MouseButton1Click:Connect(function() switchTab(EtcTabBtn) end)

local function clearESP(player)
    if espCache[player] then
        for k, obj in pairs(espCache[player]) do
            if k ~= "Character" and k ~= "lastMode" then
                if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end)
                else pcall(function() obj:Remove() end) end
            end
        end
        espCache[player] = nil
    end
end

local function createSwitch(parent, name, defaultState, order, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = order
    container.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = TEXT_COLOR
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local switchBg = Instance.new("TextButton")
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -44, 0.5, -11)
    switchBg.BackgroundColor3 = defaultState and Color3.fromRGB(45, 125, 246) or Color3.fromRGB(60, 60, 65)
    switchBg.Text = ""
    switchBg.Parent = container
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = defaultState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchKnob.Parent = switchBg
    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

    local state = defaultState
    switchBg.MouseButton1Click:Connect(function()
        state = not state
        local goalBg = state and Color3.fromRGB(45, 125, 246) or Color3.fromRGB(60, 60, 65)
        local goalPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        TweenService:Create(switchBg, TweenInfo.new(0.25), {BackgroundColor3 = goalBg}):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.25), {Position = goalPos}):Play()
        callback(state)
    end)
    return container, switchBg, switchKnob
end

local function findAncestorScrollingFrame(obj)
    local current = obj
    while current do
        if current:IsA("ScrollingFrame") then
            return current
        end
        current = current.Parent
    end
    return nil
end

-- Shared slider update: 1 RenderStepped loop for ALL sliders instead of one per slider
local _sliderRegistry = {}
local _sliderDragging = false
RunService.RenderStepped:Connect(function()
    if not _sliderDragging then return end
    _sliderDragging = false
    for _, s in ipairs(_sliderRegistry) do
        if s.dragging then
            _sliderDragging = true
            local mousePos = UserInputService:GetMouseLocation().X
            local rel = math.clamp((mousePos - s.bg.AbsolutePosition.X) / s.bg.AbsoluteSize.X, 0, 1)
            s.fill.Size = UDim2.new(rel, 0, 1, 0)
            s.marker.Position = UDim2.new(rel, -2, 0, -2)
            if s.minVal and s.maxVal then
                local val = math.floor(s.minVal + (s.maxVal - s.minVal) * rel)
                if s.vbox then s.vbox.Text = tostring(val) end
                s.cb(val)
            else
                s.cb(rel)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local wasDragging = false
    for _, s in ipairs(_sliderRegistry) do
        if s.dragging then
            wasDragging = true
            s.dragging = false
            local scroller = findAncestorScrollingFrame(s.bg)
            if scroller then
                scroller.ScrollingEnabled = true
            end
        end
    end
    if wasDragging then
        _sliderDragging = false
    end
end)

local function createSlider(parent, name, default, order, isColor, isShade, callback, minVal, maxVal)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 40)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = TEXT_COLOR
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local sliderBg = Instance.new("TextButton")
    sliderBg.Size = UDim2.new(1, (minVal and maxVal) and -60 or 0, 0, 10)
    sliderBg.Position = UDim2.new(0, 0, 0, 22)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    sliderBg.Text = ""
    sliderBg.Parent = frame
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    if isColor then
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
        })
        grad.Parent = sliderBg
        sliderBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end

    local shadeGrad
    if isShade then
        shadeGrad = Instance.new("UIGradient")
        shadeGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(ESP.Hue, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        })
        shadeGrad.Parent = sliderBg
        sliderBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end

    local fill = Instance.new("Frame")
    local startRel = default
    if minVal and maxVal then startRel = (default - minVal) / (maxVal - minVal) end
    fill.Size = UDim2.new(startRel, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    fill.BackgroundTransparency = (isColor or isShade) and 1 or 0
    fill.Parent = sliderBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 4, 1, 4)
    marker.Position = UDim2.new(startRel, -2, 0, -2)
    marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.Parent = sliderBg
    Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)

    local valueBox
    if minVal and maxVal then
        valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.new(0, 50, 0, 20)
        valueBox.Position = UDim2.new(1, -50, 0, 17)
        valueBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        valueBox.TextColor3 = TEXT_COLOR
        valueBox.Font = Enum.Font.GothamBold
        valueBox.TextSize = 12
        valueBox.Text = tostring(default)
        valueBox.Parent = frame
        Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 4)
    end

    -- Register with shared slider loop
    local s = {dragging = false, bg = sliderBg, fill = fill, marker = marker,
               minVal = minVal, maxVal = maxVal, vbox = valueBox, cb = callback}
    table.insert(_sliderRegistry, s)
    sliderBg.MouseButton1Down:Connect(function()
        s.dragging = true
        _sliderDragging = true
        local scroller = findAncestorScrollingFrame(sliderBg)
        if scroller then
            scroller.ScrollingEnabled = false
        end
    end)

    if valueBox then
        valueBox.FocusLost:Connect(function()
            local num = tonumber(string.match(valueBox.Text, "%d+"))
            if num then
                num = math.clamp(num, minVal, maxVal)
                local rel = (num - minVal) / (maxVal - minVal)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                marker.Position = UDim2.new(rel, -2, 0, -2)
                valueBox.Text = tostring(num)
                callback(num)
            end
        end)
    end

    return frame, shadeGrad
end

local function createButton(parent, name, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.LayoutOrder = order
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
end

local function createLabel(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 30)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = TEXT_COLOR
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.LayoutOrder = order
    lbl.Parent = parent
    return lbl
end

local function createSubcategoryHeader(parent, name, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 24)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = TEXT_COLOR
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 0.6
    line.BorderSizePixel = 0
    line.Parent = frame
end

local function createXYZInputs(parent, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local function mkBox(ph)
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(0.31, 0, 1, 0)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        b.TextColor3 = TEXT_COLOR
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.PlaceholderText = ph
        b.Text = ""
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Parent = frame
        return b
    end

    return mkBox("X"), mkBox("Y"), mkBox("Z")
end

-----------------------------------
-- TAB: ESP & MOVEMENT (MERGED)
-----------------------------------
createSubcategoryHeader(EspContainer, "ESP", 1)
createSwitch(EspContainer, "Toggle ESP", false, 2, function(val)
    ESP.Enabled = val
    if not val then for _, p in pairs(Players:GetPlayers()) do clearESP(p) end end
end)
createSwitch(EspContainer, "Show teammates", true, 3, function(val)
    ESP.ShowTeam = val
    if not val then
        for _, p in pairs(Players:GetPlayers()) do if p.Team == LocalPlayer.Team then clearESP(p) end end
    end
end)

local DropdownFrame = Instance.new("Frame")
DropdownFrame.Size = UDim2.new(1, -10, 0, 35)
DropdownFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
DropdownFrame.ClipsDescendants = true
DropdownFrame.LayoutOrder = 4
DropdownFrame.Parent = EspContainer
Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 6)

local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(1, 0, 0, 35)
DropdownBtn.BackgroundTransparency = 1
DropdownBtn.Text = "  Mode: Cubes"
DropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownBtn.Font = Enum.Font.Gotham
DropdownBtn.TextSize = 14
DropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
DropdownBtn.Parent = DropdownFrame

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(1, 0, 1, -35)
DropdownList.Position = UDim2.new(0, 0, 0, 35)
DropdownList.BackgroundTransparency = 1
DropdownList.Parent = DropdownFrame
Instance.new("UIListLayout", DropdownList)

local isOpen = false
local modes = {"Cubes", "Outline", "Chams", "Boxes"}
local chamsSliderFrame 

DropdownBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    local targetSize = isOpen and UDim2.new(1, -10, 0, 35 + (#modes * 30)) or UDim2.new(1, -10, 0, 35)
    TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
end)

for _, mode in pairs(modes) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.Text = "  " .. mode
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = DropdownList

    btn.MouseButton1Click:Connect(function()
        ESP.Mode = mode
        DropdownBtn.Text = "  Mode: " .. mode
        isOpen = false
        TweenService:Create(DropdownFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, -10, 0, 35)}):Play()
        if chamsSliderFrame then chamsSliderFrame.Visible = (mode == "Chams") end
    end)
end

createSlider(EspContainer, "Distance", 10000, 5, false, false, function(val) ESP.Radius = val end, 0, 10000)
chamsSliderFrame = createSlider(EspContainer, "Chams Transparency", 0.5, 6, false, false, function(val) ESP.ChamsTransparency = val end)
chamsSliderFrame.Visible = false 
local _, shadeGradient = createSlider(EspContainer, "Shade", 0.5, 8, false, true, function(val) ESP.Shade = val; updateColor() end)
local _, _ = createSlider(EspContainer, "Hue", 0.5, 7, true, false, function(val)
    ESP.Hue = val
    updateColor()
    if shadeGradient then
        shadeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(ESP.Hue, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        })
    end
end)

createSubcategoryHeader(EspContainer, "Movement", 9)
createSwitch(EspContainer, "WalkSpeed", false, 10, function(val) PlayerMods.SpeedEnabled = val end)
createSlider(EspContainer, "Speed Value", 16, 11, false, false, function(val) PlayerMods.SpeedValue = val end, 16, 250)
createSwitch(EspContainer, "JumpPower", false, 12, function(val) PlayerMods.JumpEnabled = val end)
createSlider(EspContainer, "Jump Value", 50, 13, false, false, function(val) PlayerMods.JumpValue = val end, 50, 500)

createSwitch(EspContainer, "Fly", false, 14, function(val) 
    PlayerMods.FlyEnabled = val 
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local hum = char:FindFirstChild("Humanoid")
        if not val then
            if hrp:FindFirstChild("CheatFlyMover") then hrp.CheatFlyMover:Destroy() end
            if hrp:FindFirstChild("CheatFlyGyro") then hrp.CheatFlyGyro:Destroy() end
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.Freefall)
                local rx, ry, rz = hrp.CFrame:ToOrientation()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, ry, 0)
            end
        end
    end
end)

createSlider(EspContainer, "Fly Speed", 50, 15, false, false, function(val)
    PlayerMods.FlySpeed = val
end, 10, 500)

createSwitch(EspContainer, "Noclip", false, 16, function(val) 
    PlayerMods.NoclipEnabled = val 
    if not val then
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

createSwitch(EspContainer, "Wall Walk", false, 17, function(val) 
    PlayerMods.WallWalkEnabled = val 
    if not val then
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

createSwitch(EspContainer, "Infinite Jump", false, 18, function(val) PlayerMods.InfJumpEnabled = val end)
createSwitch(EspContainer, "Anti-Knockback", false, 19, function(val) PlayerMods.AntiKnockback = val end)

-----------------------------------
-- TAB: SCRIPTS
-----------------------------------
createSubcategoryHeader(IyContainer, "Infinity Yield", 1)
createButton(IyContainer, "Launch Infinity Yield", 2, function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
end)

createButton(IyContainer, "Kill Infinity Yield", 3, function()
    if _G.IY_LOADED then _G.IY_LOADED = false end
    if getgenv().IY_LOADED then getgenv().IY_LOADED = false end
    for _, v in pairs(CoreGui:GetChildren()) do
        if v:IsA("ScreenGui") and v.Name ~= "CheatMenu" and not v.Name:match("Roblox") then
            pcall(function() v:Destroy() end)
        end
    end
end)

createSubcategoryHeader(IyContainer, "Simple Spy", 4)
createButton(IyContainer, "Simple Spy", 5, function()
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpyBeta.lua"))()
end)

createButton(IyContainer, "Terminate Simple Spy", 6, function()
    -- Remove all foreign ScreenGuis except CheatMenu, Roblox and Infinite Yield
    local iyNames = {"Infinite Yield", "InfiniteYield", "IY"}
    local function isIY(name)
        for _, n in pairs(iyNames) do
            if name == n then return true end
        end
        return false
    end
    for _, v in pairs(CoreGui:GetChildren()) do
        if v:IsA("ScreenGui")
            and v.Name ~= "CheatMenu"
            and not v.Name:match("Roblox")
            and not isIY(v.Name)
        then
            pcall(function() v:Destroy() end)
        end
    end
    -- Clear SimpleSpy global variables
    pcall(function()
        if getgenv().SS then getgenv().SS = nil end
        if getgenv().SimpleSpy then getgenv().SimpleSpy = nil end
        if _G.SimpleSpy then _G.SimpleSpy = nil end
        if _G.SS then _G.SS = nil end
        if getgenv().SimpleSpyActive then getgenv().SimpleSpyActive = false end
    end)
end)

createSubcategoryHeader(IyContainer, "Hydroxide", 7)
createButton(IyContainer, "Hydroxide", 8, function()
    local owner = "Upbolt"
    local branch = "revision"
    local function webImport(file)
        return loadstring(game:HttpGetAsync(("https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua"):format(owner, branch, file)), file .. '.lua')()
    end
    webImport("init")
    webImport("ui/main")
end)

createButton(IyContainer, "Terminate Hydroxide", 9, function()
    -- Protected: our menu, Roblox GUI, Infinity Yield, Simple Spy
    local protectedNames = {"CheatMenu", "Infinite Yield", "InfiniteYield", "IY"}
    -- Known Simple Spy GUI names
    local spyNames = {"SimpleSpy", "SimpleSpyGui", "SSpy", "Simple Spy"}
    local function isProtected(name)
        if name:match("Roblox") then return true end
        for _, n in pairs(protectedNames) do
            if name == n then return true end
        end
        for _, n in pairs(spyNames) do
            if name == n then return true end
        end
        return false
    end
    -- Remove everything that is not protected (Hydroxide etc.)
    for _, v in pairs(CoreGui:GetChildren()) do
        if v:IsA("ScreenGui") and not isProtected(v.Name) then
            pcall(function() v:Destroy() end)
        end
    end
    pcall(function()
        if getgenv().Hydroxide then getgenv().Hydroxide = nil end
        if _G.Hydroxide then _G.Hydroxide = nil end
    end)
end)


-----------------------------------
-- TAB: BABFT
-----------------------------------
createSubcategoryHeader(BabftContainer, "Autofarm", 1)

do
    local SPEED = 450
    getgenv().GoldFarmRunning = false
    getgenv().GoldClaimRunning = false

    local goldBtn = Instance.new("TextButton")
    goldBtn.Size = UDim2.new(1, -10, 0, 35)
    goldBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    goldBtn.Text = "Gold Autofarm (click to toggle)"
    goldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    goldBtn.Font = Enum.Font.Gotham
    goldBtn.TextSize = 14
    goldBtn.LayoutOrder = 2
    goldBtn.Parent = BabftContainer
    Instance.new("UICorner", goldBtn).CornerRadius = UDim.new(0, 6)

    goldBtn.MouseButton1Click:Connect(function()
        getgenv().GoldFarmRunning = not getgenv().GoldFarmRunning
        if getgenv().GoldFarmRunning then
            goldBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            goldBtn.Text = "Gold Autofarm [ON] (click to stop)"

            getgenv().GoldClaimRunning = true
            task.spawn(function()
                while getgenv().GoldClaimRunning do
                    pcall(function()
                        workspace:WaitForChild("ClaimRiverResultsGold"):FireServer()
                    end)
                    task.wait(5)
                end
            end)

            task.spawn(function()
                while getgenv().GoldFarmRunning do
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                        local hrp = char.HumanoidRootPart
                        local hum = char.Humanoid

                        hrp.CFrame = CFrame.new(-55, 75, 1000)
                        task.wait(0.3)

                        local mover = Instance.new("BodyVelocity")
                        mover.Name = "GoldFlyMover"
                        mover.MaxForce = Vector3.new(100000, 100000, 100000)
                        mover.Parent = hrp
                        local gyro = Instance.new("BodyGyro")
                        gyro.Name = "GoldFlyGyro"
                        gyro.MaxTorque = Vector3.new(100000, 100000, 100000)
                        gyro.P = 10000
                        gyro.Parent = hrp
                        hum.PlatformStand = true

                        local function isAlive()
                            return getgenv().GoldFarmRunning and hrp.Parent and hum.Health > 0
                        end

                        mover.Velocity = Vector3.new(0, 0, SPEED)
                        gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(0, 0, 1))
                        while isAlive() and hrp.Position.Z < 8700 do task.wait() end

                        if isAlive() then
                            mover.Velocity = Vector3.new(0, -SPEED, 0)
                            gyro.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(0, 0, 1))
                            while isAlive() and hrp.Position.Y > -235 do task.wait() end
                        end

                        if isAlive() then
                            mover.Velocity = Vector3.new(0, 0, SPEED)
                            while isAlive() and hrp.Position.Z < 9495 do task.wait() end
                        end

                        pcall(function() mover:Destroy() end)
                        pcall(function() gyro:Destroy() end)
                        pcall(function() hum.PlatformStand = false end)

                        while getgenv().GoldFarmRunning and char.Parent and hum.Health > 0 do task.wait() end
                    end

                    while getgenv().GoldFarmRunning do
                        local c = LocalPlayer.Character
                        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") and c.Humanoid.Health > 0 then
                            break
                        end
                        task.wait()
                    end
                    task.wait(1)
                end

                local fc = LocalPlayer.Character
                local fhrp = fc and fc:FindFirstChild("HumanoidRootPart")
                if fhrp then
                    if fhrp:FindFirstChild("GoldFlyMover") then fhrp.GoldFlyMover:Destroy() end
                    if fhrp:FindFirstChild("GoldFlyGyro") then fhrp.GoldFlyGyro:Destroy() end
                end
                local fhum = fc and fc:FindFirstChild("Humanoid")
                if fhum then fhum.PlatformStand = false end
            end)
        else
            goldBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            goldBtn.Text = "Gold Autofarm (click to toggle)"
            getgenv().GoldFarmRunning = false
            getgenv().GoldClaimRunning = false
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if hrp:FindFirstChild("GoldFlyMover") then hrp.GoldFlyMover:Destroy() end
                if hrp:FindFirstChild("GoldFlyGyro") then hrp.GoldFlyGyro:Destroy() end
            end
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end)
end

-----------------------------------
-- TAB: SLAP BATTLES
-----------------------------------
local antiRagdollActive = false
local antiRagdollThread = nil

createSubcategoryHeader(SlapContainer, "Teleport", 1)

-- Get in Elude / Teleport to the Elude game (PlaceID: 11828384869)
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get in Elude (???)", 2, function()
    game:GetService("TeleportService"):Teleport(11828384869)
end)
--------------------------------------------------------------------------------

-- Get in Frostbite / Teleport to the Frostbite game (PlaceID: 17290438723)
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get in Frostbite", 3, function()
    game:GetService("TeleportService"):Teleport(17290438723)
end)
--------------------------------------------------------------------------------

-- Teleport to Frostbite Glove / Teleport to glove spawn point in Frostbite
--------------------------------------------------------------------------------
createButton(SlapContainer, "Teleport to Frostbite Glove", 4, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(-550, 178, 58)
    end
end)
--------------------------------------------------------------------------------

createSubcategoryHeader(SlapContainer, "Get", 5)

-- Get Iceskate / FireServer IceSkate:Freeze to obtain the glove
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get Iceskate", 6, function()
    local args = { "Freeze" }
    game:GetService("ReplicatedStorage"):WaitForChild("IceSkate"):FireServer(unpack(args))
end)
--------------------------------------------------------------------------------

-- Get Elude+Counter / Run inside the maze: clicks Counter lever, waits 121s frozen in sky, then touches Elude glove and collects hidden items
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get Elude+Counter", 7, function()
    task.spawn(function()
        local root = game.Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")

        -- 1. Click the Counter lever
        if workspace:FindFirstChild("CounterLever") then
            fireclickdetector(workspace.CounterLever.ClickDetector)
        end

        -- 2. Teleport into the sky and freeze so monsters can't reach
        root.CFrame = CFrame.new(0, 100, 0)
        task.wait(0.2)
        root.Anchored = true

        -- Wait 121 seconds while the maze timer ticks
        for i = 121, 1, -1 do
            task.wait(1)
        end

        -- 3. Unfreeze
        root.Anchored = false
        task.wait(0.5)

        -- 4. Touch the Elude glove
        if workspace:FindFirstChild("Ruins") and workspace.Ruins.Elude:FindFirstChild("Glove") then
            firetouchinterest(root, workspace.Ruins.Elude.Glove, 0)
            firetouchinterest(root, workspace.Ruins.Elude.Glove, 1)
        end

        -- 5. Collect all hidden items in the maze
        if workspace:FindFirstChild("Maze") then
            for _, v in pairs(workspace.Maze:GetDescendants()) do
                if v:IsA("ClickDetector") then
                    fireclickdetector(v)
                end
            end
        end
    end)
end)
--------------------------------------------------------------------------------

-- Get Lamp / Spams RemoteEvent until badge is awarded (requires ZZZZZZZ glove)
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get Lamp", 8, function()
    if game.Players.LocalPlayer.leaderstats.Glove.Value == "ZZZZZZZ" then
        task.spawn(function()
            repeat task.wait(0.1)
                game:GetService("ReplicatedStorage").nightmare:FireServer("LightBroken")
            until game:GetService("BadgeService"):UserHasBadgeAsync(game.Players.LocalPlayer.UserId, 490455814138437)
        end)
    end
end)
--------------------------------------------------------------------------------

-- Get Plank / Teleport + FortSkill + fireproximityprompt (requires Fort glove)
--------------------------------------------------------------------------------
createButton(SlapContainer, "Get Plank", 9, function()
    if game.Players.LocalPlayer.leaderstats.Glove.Value == "Fort" then
        local hrp = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(-392, 50, -42)
            task.wait(0.3)
            game:GetService("ReplicatedStorage").FortSkill:FireServer()
            task.wait(0.2)
            for _, v in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if v.ClassName == "ProximityPrompt" then
                    fireproximityprompt(v)
                end
            end
        end
    end
end)
--------------------------------------------------------------------------------

createSubcategoryHeader(SlapContainer, "Etc", 10)

-- Auto Fort / Loops FireServer on Fortlol every 3.5s, toggled by button
--------------------------------------------------------------------------------
do
    local autoFortRunning = false
    local autoFortBtn = Instance.new("TextButton")
    autoFortBtn.Size = UDim2.new(1, -10, 0, 35)
    autoFortBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    autoFortBtn.Text = "Auto Fort (again to disable)"
    autoFortBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoFortBtn.Font = Enum.Font.Gotham
    autoFortBtn.TextSize = 14
    autoFortBtn.LayoutOrder = 11
    autoFortBtn.Parent = SlapContainer
    Instance.new("UICorner", autoFortBtn).CornerRadius = UDim.new(0, 6)

    autoFortBtn.MouseButton1Click:Connect(function()
        autoFortRunning = not autoFortRunning
        if autoFortRunning then
            autoFortBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            autoFortBtn.Text = "Auto Fort [ON] (click to stop)"
            task.spawn(function()
                while autoFortRunning do
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("Fortlol"):FireServer()
                    end)
                    task.wait(3.5)
                end
            end)
        else
            autoFortBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            autoFortBtn.Text = "Auto Fort (again to disable)"
        end
    end)
end
--------------------------------------------------------------------------------

-- Autofarm Slapples / firetouchinterest on all Slapple/GoldenSlapple in the arena
--------------------------------------------------------------------------------
do
    local slappleFarmRunning = false
    local slappleBtn = Instance.new("TextButton")
    slappleBtn.Size = UDim2.new(1, -10, 0, 35)
    slappleBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    slappleBtn.Text = "Autofarm Slapples (again to disable)"
    slappleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    slappleBtn.Font = Enum.Font.Gotham
    slappleBtn.TextSize = 14
    slappleBtn.LayoutOrder = 12
    slappleBtn.Parent = SlapContainer
    Instance.new("UICorner", slappleBtn).CornerRadius = UDim.new(0, 6)

    slappleBtn.MouseButton1Click:Connect(function()
        slappleFarmRunning = not slappleFarmRunning
        if slappleFarmRunning then
            slappleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            slappleBtn.Text = "Autofarm Slapples [ON] (click to stop)"
            task.spawn(function()
                while slappleFarmRunning do
                    pcall(function()
                        local char = game.Players.LocalPlayer.Character
                        if char and char:FindFirstChild("entered") then
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            for _, v in pairs(workspace.Arena.island5.Slapples:GetChildren()) do
                                if hrp and char:FindFirstChild("entered") and
                                    (v.Name == "Slapple" or v.Name == "GoldenSlapple") and
                                    v:FindFirstChild("Glove") and
                                    v.Glove:FindFirstChildWhichIsA("TouchTransmitter")
                                then
                                    firetouchinterest(hrp, v.Glove, 0)
                                    firetouchinterest(hrp, v.Glove, 1)
                                end
                            end
                        end
                    end)
                    task.wait()
                end
            end)
        else
            slappleBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            slappleBtn.Text = "Autofarm Slapples (again to disable)"
        end
    end)
end
--------------------------------------------------------------------------------

-- Anti-Ragdoll / Anchors torso during ragdoll, prevents the character from being knocked away
--------------------------------------------------------------------------------
createSwitch(SlapContainer, "Anti-Ragdoll", false, 13, function(val)
    antiRagdollActive = val
    _G.AntiRagdoll = val
    if val then
        antiRagdollThread = task.spawn(function()
            while _G.AntiRagdoll do
                local char = game.Players.LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local ragdolled = char:FindFirstChild("Ragdolled")
                    if ragdolled and ragdolled.Value == true then
                        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                        if torso then
                            repeat task.wait()
                                torso.Anchored = true
                            until not ragdolled.Value
                            torso.Anchored = false
                        end
                    end
                end
                task.wait()
            end
        end)
    else
        -- On disable — make sure the torso is unanchored
        local char = game.Players.LocalPlayer.Character
        if char then
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if torso then torso.Anchored = false end
        end
    end
end)
--------------------------------------------------------------------------------

createSubcategoryHeader(SlapContainer, "Spoof", 14)

do
    local Workspace = game:GetService("Workspace")
    local RealCoreGui = game:GetService("CoreGui")
    local maskActive = false
    local originalTexts = {}
    local loopThread = nil

    local function maskElement(object, isOverhead)
        if not (object:IsA("TextLabel") or object:IsA("TextButton")) then return end

        local currentText = object.Text
        if currentText == "---" or currentText == "" then return end

        local shouldMask = false

        -- 1. Проверяем на никнеймы игроков
        for _, player in ipairs(Players:GetPlayers()) do
            if isOverhead then
                if string.find(currentText, player.Name) or string.find(currentText, player.DisplayName) then
                    shouldMask = true
                    break
                end
            else
                if currentText == player.Name or currentText == player.DisplayName then
                    shouldMask = true
                    break
                end
            end
        end

        -- 2. Проверяем на количество шлепок (только для Таблицы)
        if not shouldMask and not isOverhead then
            local cleanedText = currentText:gsub("[,%s]", "")
            local numericPart = cleanedText:gsub("[kMBy%+]$", "")
            if tonumber(numericPart) ~= nil then
                shouldMask = true
            end
        end

        if shouldMask then
            if not originalTexts[object] then
                originalTexts[object] = currentText
            end
            object.Text = "---"
        end
    end

    local function startMasking()
        maskActive = true

        loopThread = task.spawn(function()
            while maskActive do
                -- Scan PlayerList in CoreGui
                local playerList = RealCoreGui:FindFirstChild("PlayerList")
                if not playerList then
                    local robloxGui = RealCoreGui:FindFirstChild("RobloxGui")
                    playerList = robloxGui and robloxGui:FindFirstChild("PlayerList")
                end
                if playerList then
                    for _, descendant in ipairs(playerList:GetDescendants()) do
                        if not maskActive then break end
                        maskElement(descendant, false)
                    end
                end

                -- Scan Player Characters in Workspace
                for _, player in ipairs(Players:GetPlayers()) do
                    if not maskActive then break end
                    local char = player.Character
                    if char then
                        for _, descendant in ipairs(char:GetDescendants()) do
                            if not maskActive then break end
                            maskElement(descendant, true)
                        end
                    end
                end

                task.wait(0.5)
            end
        end)
    end

    local function stopMasking()
        maskActive = false

        if loopThread then pcall(function() task.cancel(loopThread) end); loopThread = nil end

        for obj, origText in pairs(originalTexts) do
            pcall(function()
                obj.Text = origText
            end)
        end
        originalTexts = {}
    end

    createSwitch(SlapContainer, "Hide Nicknames", false, 15, function(val)
        if val then startMasking() else stopMasking() end
    end)
end

-----------------------------------
-- TAB: TELEPORT
-----------------------------------
createSubcategoryHeader(TeleportContainer, "Teleport", 1)
local tbX, tbY, tbZ = createXYZInputs(TeleportContainer, 2)
createButton(TeleportContainer, "Teleport to:", 3, function()
    local x = tonumber(tbX.Text)
    local y = tonumber(tbY.Text)
    local z = tonumber(tbZ.Text)
    if x and y and z then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        end
    end
end)

local privatePlate = nil
createButton(TeleportContainer, "Go to Baseplate", 4, function()
    local PLATE_X, PLATE_Y, PLATE_Z = 100000, -10, 100000
    if not privatePlate or not privatePlate.Parent then
        privatePlate = Instance.new("Part")
        privatePlate.Name = "PrivateBaseplate"
        privatePlate.Size = Vector3.new(2048, 20, 2048)
        privatePlate.Position = Vector3.new(PLATE_X, PLATE_Y, PLATE_Z)
        privatePlate.Anchored = true
        privatePlate.Locked = true
        privatePlate.Material = Enum.Material.SmoothPlastic
        privatePlate.BrickColor = BrickColor.new("Medium stone grey")
        privatePlate.CastShadow = false
        privatePlate.Parent = workspace
    end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(PLATE_X, PLATE_Y + 15, PLATE_Z)
    end
end)

-----------------------------------
-- TAB: ETC
-----------------------------------
local CursorGui
local CursorLabel
local CursorConn

local function startCursorTracker()
    if CursorGui then return end
    CursorGui = Instance.new("ScreenGui")
    CursorGui.Name = "CursorXYGui"
    CursorGui.Parent = CoreGui
    
    CursorLabel = Instance.new("TextLabel")
    CursorLabel.Size = UDim2.new(0, 300, 0, 50)
    CursorLabel.Position = UDim2.new(0.5, -150, 0, 20)
    CursorLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
    CursorLabel.TextColor3 = TEXT_COLOR
    CursorLabel.Font = Enum.Font.GothamBold
    CursorLabel.TextSize = 16
    CursorLabel.Text = "Нажми экран (Терминейт в меню)"
    Instance.new("UICorner", CursorLabel).CornerRadius = UDim.new(0, 6)
    CursorLabel.Parent = CursorGui
    
    CursorConn = UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = UserInputService:GetMouseLocation()
            CursorLabel.Text = string.format("X: %d | Y: %d", mousePos.X, mousePos.Y)
        end
    end)
    getgenv().CursorScript_Conn = CursorConn
end

local function stopCursorTracker()
    if CursorConn then CursorConn:Disconnect(); CursorConn = nil end
    if CursorGui then CursorGui:Destroy(); CursorGui = nil end
    if getgenv().CursorScript_Conn then getgenv().CursorScript_Conn:Disconnect() end
end

-----------------------------------
-- POSITION SUBCATEGORY
-----------------------------------
createSubcategoryHeader(EtcContainer, "Position", 1)
createButton(EtcContainer, "Get cursor coordinates", 2, startCursorTracker)
createButton(EtcContainer, "Terminate", 3, stopCursorTracker)

local PlayerCoordsLabel = createLabel(EtcContainer, "Coordinates: None", 5)
createButton(EtcContainer, "Get player coordinates", 4, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        PlayerCoordsLabel.Text = string.format("X: %.1f | Y: %.1f | Z: %.1f", pos.X, pos.Y, pos.Z)
    else
        PlayerCoordsLabel.Text = "Character not found"
    end
end)

local placeIdDisplay = Instance.new("TextButton")
placeIdDisplay.Size = UDim2.new(1, -10, 0, 30)
placeIdDisplay.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
placeIdDisplay.Text = "Click button above to get ID"
placeIdDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
placeIdDisplay.Font = Enum.Font.Gotham
placeIdDisplay.TextSize = 13
placeIdDisplay.LayoutOrder = 7
placeIdDisplay.Parent = EtcContainer
Instance.new("UICorner", placeIdDisplay).CornerRadius = UDim.new(0, 6)

placeIdDisplay.MouseButton1Click:Connect(function()
    local id = tostring(game.PlaceId)
    if id ~= "0" then
        pcall(function() setclipboard(id) end)
        local prev = placeIdDisplay.Text
        placeIdDisplay.Text = "✔ Copied: " .. id
        placeIdDisplay.TextColor3 = Color3.fromRGB(80, 220, 120)
        task.wait(1.5)
        placeIdDisplay.Text = prev
        placeIdDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

createButton(EtcContainer, "Get PlaceID", 6, function()
    local id = tostring(game.PlaceId)
    placeIdDisplay.Text = "PlaceID: " .. id .. "  📋 click to copy"
    placeIdDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

-----------------------------------
-- PERFORMANCE SUBCATEGORY
-----------------------------------
createSubcategoryHeader(EtcContainer, "Performance", 8)

-- FPS / Ping overlay: adaptive position, mutually exclusive toggles
local _statsMode = nil
local _statsGui = nil
local _statsConn = nil
local _statsBtnFpsPing, _statsBtnFps, _statsBtnPing

local function _setStatsMode(mode)
    if _statsConn then _statsConn:Disconnect(); _statsConn = nil end
    if _statsGui  then _statsGui:Destroy();  _statsGui = nil end
    _statsMode = mode
    if not mode then return end

    _statsGui = Instance.new("ScreenGui")
    _statsGui.Name = "StatsOverlay"
    _statsGui.ResetOnSpawn = false
    _statsGui.DisplayOrder = 15
    _statsGui.IgnoreGuiInset = false
    _statsGui.Parent = CoreGui

    local vp = workspace.CurrentCamera.ViewportSize
    -- x=20px fixed, y = 73/1440 scale → adapts to any resolution
    local yPos     = 73 / 1440
    local fontSize = math.max(11, math.floor(vp.Y / 105))

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = TEXT_COLOR
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = fontSize
    lbl.Size = UDim2.new(0.25, 0, 0, fontSize + 8)
    lbl.Position = UDim2.new(0, 20, yPos, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = _statsGui

    local fpsAccum, fpsSamples, updateTimer = 0, 0, 0
    _statsConn = RunService.Heartbeat:Connect(function(dt)
        fpsAccum    = fpsAccum + dt
        fpsSamples  = fpsSamples + 1
        updateTimer = updateTimer + dt
        if updateTimer < 0.5 then return end
        updateTimer = 0
        local fps  = math.floor(fpsSamples / fpsAccum)
        fpsAccum = 0; fpsSamples = 0
        local ping = math.floor((LocalPlayer:GetNetworkPing() or 0) * 1000)
        if _statsMode == "both"  then lbl.Text = fps .. " FPS  " .. ping .. " ms"
        elseif _statsMode == "fps"  then lbl.Text = fps .. " FPS"
        elseif _statsMode == "ping" then lbl.Text = ping .. " ms"
        end
    end)
end

local function _updateStatsBtns()
    local on  = Color3.fromRGB(200, 50, 50)
    local off = Color3.fromRGB(45, 125, 246)
    -- Called after _statsMode is already updated — syncs all 3 button colors
    if _statsBtnFpsPing then _statsBtnFpsPing.BackgroundColor3 = (_statsMode == "both")  and on or off end
    if _statsBtnFps     then _statsBtnFps.BackgroundColor3     = (_statsMode == "fps")   and on or off end
    if _statsBtnPing    then _statsBtnPing.BackgroundColor3    = (_statsMode == "ping")  and on or off end
end

local function _makeStatsBtn(label, order, mode)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.LayoutOrder = order
    btn.Parent = EtcContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        -- Toggle: same mode → disable (nil), different mode → switch
        local newMode = (_statsMode == mode) and nil or mode
        _setStatsMode(newMode)   -- _statsMode updated inside here
        _updateStatsBtns()       -- now sync visuals after state change
    end)
    return btn
end

_statsBtnFpsPing = _makeStatsBtn("Show FPS+Ping (click to toggle)", 9, "both")
_statsBtnFps     = _makeStatsBtn("Show FPS (click to toggle)",      10, "fps")
_statsBtnPing    = _makeStatsBtn("Show Ping (click to toggle)",     11, "ping")

-- FPS Limiter / Uses setfpscap(); input box + Set button
do
    local fpsRow = Instance.new("Frame")
    fpsRow.Size = UDim2.new(1, -10, 0, 35)
    fpsRow.BackgroundTransparency = 1
    fpsRow.LayoutOrder = 12
    fpsRow.Parent = EtcContainer

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 6)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Parent = fpsRow

    local fpsBox = Instance.new("TextBox")
    fpsBox.Size = UDim2.new(0.45, 0, 1, 0)
    fpsBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    fpsBox.TextColor3 = TEXT_COLOR
    fpsBox.PlaceholderText = "FPS cap (e.g. 60)"
    fpsBox.Text = ""
    fpsBox.Font = Enum.Font.GothamBold
    fpsBox.TextSize = 13
    fpsBox.LayoutOrder = 1
    fpsBox.Parent = fpsRow
    Instance.new("UICorner", fpsBox).CornerRadius = UDim.new(0, 6)

    local fpsSetBtn = Instance.new("TextButton")
    fpsSetBtn.Size = UDim2.new(0.3, 0, 1, 0)
    fpsSetBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    fpsSetBtn.Text = "Set FPS"
    fpsSetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsSetBtn.Font = Enum.Font.Gotham
    fpsSetBtn.TextSize = 13
    fpsSetBtn.LayoutOrder = 2
    fpsSetBtn.Parent = fpsRow
    Instance.new("UICorner", fpsSetBtn).CornerRadius = UDim.new(0, 6)

    local fpsResetBtn = Instance.new("TextButton")
    fpsResetBtn.Size = UDim2.new(0.22, 0, 1, 0)
    fpsResetBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    fpsResetBtn.Text = "Reset"
    fpsResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    fpsResetBtn.Font = Enum.Font.Gotham
    fpsResetBtn.TextSize = 12
    fpsResetBtn.LayoutOrder = 3
    fpsResetBtn.Parent = fpsRow
    Instance.new("UICorner", fpsResetBtn).CornerRadius = UDim.new(0, 6)

    fpsSetBtn.MouseButton1Click:Connect(function()
        local cap = tonumber(fpsBox.Text)
        if cap and cap > 0 and cap <= 999 then
            pcall(setfpscap, cap)
            fpsSetBtn.Text = cap .. " FPS ✔"
            task.wait(1.2)
            fpsSetBtn.Text = "Set FPS"
        end
    end)

    fpsResetBtn.MouseButton1Click:Connect(function()
        pcall(setfpscap, 0) -- 0 = unlimited
        fpsBox.Text = ""
        fpsResetBtn.Text = "Reset ✔"
        task.wait(1)
        fpsResetBtn.Text = "Reset"
    end)
end

-- Disable 3D Rendering / Minimizes GPU work: lowest quality, no shadows, no post effects, max fog
do
    local renderingDisabled = false
    local savedState = nil
    local Lighting = game:GetService("Lighting")

    local renderBtn = Instance.new("TextButton")
    renderBtn.Size = UDim2.new(1, -10, 0, 35)
    renderBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    renderBtn.Text = "Disable 3D Rendering (click to toggle)"
    renderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    renderBtn.Font = Enum.Font.Gotham
    renderBtn.TextSize = 13
    renderBtn.LayoutOrder = 13
    renderBtn.Parent = EtcContainer
    Instance.new("UICorner", renderBtn).CornerRadius = UDim.new(0, 6)

    renderBtn.MouseButton1Click:Connect(function()
        renderingDisabled = not renderingDisabled
        if renderingDisabled then
            -- Save current state
            savedState = {
                QualityLevel   = settings().Rendering.QualityLevel,
                GlobalShadows  = Lighting.GlobalShadows,
                FogEnd         = Lighting.FogEnd,
                FogStart       = Lighting.FogStart,
                FogColor       = Lighting.FogColor,
                Brightness     = Lighting.Brightness,
                postEffects    = {},
            }
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Sky") or v:IsA("Atmosphere") then
                    table.insert(savedState.postEffects, {obj = v, enabled = v.Enabled})
                    pcall(function() v.Enabled = false end)
                end
            end
            -- Apply minimum rendering
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            Lighting.GlobalShadows = false
            Lighting.FogStart = 0
            Lighting.FogEnd = 250    -- fog cuts at 250 studs, reduces distant draw calls
            Lighting.FogColor = Color3.fromRGB(0, 0, 0)
            Lighting.Brightness = 0

            renderBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            renderBtn.Text = "3D Rendering OFF [click to restore]"
        else
            -- Restore saved state
            if savedState then
                pcall(function()
                    settings().Rendering.QualityLevel = savedState.QualityLevel
                end)
                Lighting.GlobalShadows = savedState.GlobalShadows
                Lighting.FogStart     = savedState.FogStart
                Lighting.FogEnd       = savedState.FogEnd
                Lighting.FogColor     = savedState.FogColor
                Lighting.Brightness   = savedState.Brightness
                for _, entry in pairs(savedState.postEffects) do
                    pcall(function() entry.obj.Enabled = entry.enabled end)
                end
                savedState = nil
            end
            renderBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            renderBtn.Text = "Disable 3D Rendering (click to toggle)"
        end
    end)
end

-- Anti-AFK / Phantom VirtualUser click every 2 min to silently reset idle timer
do
    local afkRunning = false
    local VirtualUser = game:GetService("VirtualUser")

    local afkBtn = Instance.new("TextButton")
    afkBtn.Size = UDim2.new(1, -10, 0, 35)
    afkBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    afkBtn.Text = "Anti-AFK (click to toggle)"
    afkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    afkBtn.Font = Enum.Font.Gotham
    afkBtn.TextSize = 14
    afkBtn.LayoutOrder = 14
    afkBtn.Parent = EtcContainer
    Instance.new("UICorner", afkBtn).CornerRadius = UDim.new(0, 6)

    afkBtn.MouseButton1Click:Connect(function()
        afkRunning = not afkRunning
        if afkRunning then
            afkBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            afkBtn.Text = "Anti-AFK [ON] (click to disable)"
            task.spawn(function()
                while afkRunning do
                    task.wait(120) -- 2 minutes
                    if not afkRunning then break end
                    -- Phantom right-click: no visible action, resets idle timer server-side
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(0.1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end
            end)
        else
            afkBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            afkBtn.Text = "Anti-AFK (click to toggle)"
        end
    end)
end

-----------------------------------
-- AUTOCLICK SUBCATEGORY
-----------------------------------
createSubcategoryHeader(EtcContainer, "Autoclick", 15)

do
    -- State
    local acXYEnabled    = false
    local acCursorEnabled = false
    local acRunning      = false
    local acKey          = nil
    local acSpeedMs      = 100
    local acLastClick    = 0
    local acXY_X         = nil
    local acXY_Y         = nil
    local acXYSwitchBg   = nil   -- refs for programmatic toggle reset
    local acXYKnob       = nil
    local acCursorSwitchBg = nil
    local acCursorKnob   = nil

    local function acResetSwitch(switchBg, knob)
        if not switchBg or not knob then return end
        TweenService:Create(switchBg, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 60, 65)}):Play()
        TweenService:Create(knob,     TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -9)}):Play()
    end

    -- Global Heartbeat: one connection for all click modes
    -- Uses exploit-native mouse functions instead of VirtualUser (which overrides camera CFrame and causes shaking)
    getgenv().AutoClicker_Conn = RunService.Heartbeat:Connect(function()
        if not acRunning then return end
        local now = tick()
        if (now - acLastClick) < (acSpeedMs / 1000) then return end
        acLastClick = now
        if acXYEnabled and acXY_X and acXY_Y then
            -- Move mouse to target XY
            pcall(function()
                mousemoveabs(acXY_X, acXY_Y)
            end)
            task.wait(0.01)
            pcall(mouse1press)
            task.delay(math.random(50, 150) / 1000, function()
                pcall(mouse1release)
            end)
        elseif acCursorEnabled then
            -- Click at current cursor position
            pcall(mouse1press)
            task.delay(math.random(50, 150) / 1000, function()
                pcall(mouse1release)
            end)
        end
    end)

    -- Key activation listener
    getgenv().AutoClicker_KeyConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if acKey and input.KeyCode == acKey then
            if acXYEnabled or acCursorEnabled then
                acRunning = not acRunning
            end
        end
    end)

    -- 1. Key binding button (LayoutOrder 16)
    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(1, -10, 0, 35)
    keyBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
    keyBtn.Text = "Key to enable/disable autoclicker"
    keyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBtn.Font = Enum.Font.Gotham
    keyBtn.TextSize = 14
    keyBtn.LayoutOrder = 16
    keyBtn.Parent = EtcContainer
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 6)
    local keyBtnWaiting = false
    keyBtn.MouseButton1Click:Connect(function()
        if keyBtnWaiting then return end
        keyBtnWaiting = true
        keyBtn.Text = "Press any key..."
        keyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        local forbidden = {
            [Enum.KeyCode.Insert] = true, [Enum.KeyCode.Delete] = true,
            [Enum.KeyCode.Escape] = true, [Enum.KeyCode.W] = true,
            [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
            [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.LeftShift] = true,
            [Enum.KeyCode.Tab] = true,
        }
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if forbidden[input.KeyCode] then return end
            acKey = input.KeyCode
            keyBtn.Text = "Key: " .. input.KeyCode.Name
            keyBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 246)
            keyBtnWaiting = false
            conn:Disconnect()
        end)
    end)

    -- 2. Cursor autoclicker toggle (LayoutOrder 17)
    local _, acCursorSwitchBgRef, acCursorKnobRef = createSwitch(EtcContainer, "Autoclicker", false, 17, function(val)
        acCursorEnabled = val
        if val then
            -- Mutually exclusive: disable XY clicker
            if acXYEnabled then
                acXYEnabled = false
                acRunning = false
                acResetSwitch(acXYSwitchBg, acXYKnob)
            end
        else
            if not acXYEnabled then acRunning = false end
        end
    end)
    acCursorSwitchBg = acCursorSwitchBgRef
    acCursorKnob     = acCursorKnobRef

    -- 3. XY autoclicker toggle (LayoutOrder 18)
    local _, acXYSwitchBgRef, acXYKnobRef = createSwitch(EtcContainer, "Auto Clicker for XY", false, 18, function(val)
        acXYEnabled = val
        if val then
            -- Mutually exclusive: disable cursor clicker
            if acCursorEnabled then
                acCursorEnabled = false
                acRunning = false
                acResetSwitch(acCursorSwitchBg, acCursorKnob)
            end
        else
            if not acCursorEnabled then acRunning = false end
        end
    end)
    acXYSwitchBg = acXYSwitchBgRef
    acXYKnob     = acXYKnobRef

    -- 4. X/Y coordinate input row (LayoutOrder 19)
    local xyRow = Instance.new("Frame")
    xyRow.Size = UDim2.new(1, -10, 0, 28)
    xyRow.BackgroundTransparency = 1
    xyRow.LayoutOrder = 19
    xyRow.Parent = EtcContainer
    local xyRowLayout = Instance.new("UIListLayout")
    xyRowLayout.FillDirection = Enum.FillDirection.Horizontal
    xyRowLayout.Padding = UDim.new(0, 6)
    xyRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    xyRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    xyRowLayout.Parent = xyRow

    local acXBox = Instance.new("TextBox")
    acXBox.Size = UDim2.new(0.48, 0, 1, 0)
    acXBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    acXBox.TextColor3 = TEXT_COLOR
    acXBox.PlaceholderText = "X"
    acXBox.Text = ""
    acXBox.Font = Enum.Font.GothamBold
    acXBox.TextSize = 13
    acXBox.LayoutOrder = 1
    acXBox.Parent = xyRow
    Instance.new("UICorner", acXBox).CornerRadius = UDim.new(0, 6)

    local acYBox = Instance.new("TextBox")
    acYBox.Size = UDim2.new(0.48, 0, 1, 0)
    acYBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    acYBox.TextColor3 = TEXT_COLOR
    acYBox.PlaceholderText = "Y"
    acYBox.Text = ""
    acYBox.Font = Enum.Font.GothamBold
    acYBox.TextSize = 13
    acYBox.LayoutOrder = 2
    acYBox.Parent = xyRow
    Instance.new("UICorner", acYBox).CornerRadius = UDim.new(0, 6)

    acXBox.FocusLost:Connect(function() acXY_X = tonumber(acXBox.Text) end)
    acYBox.FocusLost:Connect(function() acXY_Y = tonumber(acYBox.Text) end)

    -- 5. Autoclicker speed slider in ms (LayoutOrder 20)
    createSlider(EtcContainer, "Autoclicker Speed (ms)", 100, 20, false, false, function(val)
        acSpeedMs = val
    end, 10, 2000)
end

-----------------------------------
-- TERMINATE ALL SCRIPTS
-----------------------------------
TerminateBtn.MouseButton1Click:Connect(function()
    ESP.Enabled = false
    for _, p in pairs(Players:GetPlayers()) do clearESP(p) end
    
    if getgenv().CheatESP_Loop then getgenv().CheatESP_Loop:Disconnect() end
    if getgenv().PlayerCheats_Heartbeat then getgenv().PlayerCheats_Heartbeat:Disconnect() end
    if getgenv().PlayerCheats_Stepped then getgenv().PlayerCheats_Stepped:Disconnect() end
    if getgenv().PlayerCheats_InputBegan then getgenv().PlayerCheats_InputBegan:Disconnect() end
    if getgenv().PlayerCheats_JumpReq then getgenv().PlayerCheats_JumpReq:Disconnect() end
    if getgenv().Menu_InputChanged then getgenv().Menu_InputChanged:Disconnect() end
    getgenv().GoldFarmRunning = false
    getgenv().GoldClaimRunning = false
    
    stopCursorTracker()
    
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        if hrp:FindFirstChild("CheatFlyMover") then hrp.CheatFlyMover:Destroy() end
        if hrp:FindFirstChild("CheatFlyGyro") then hrp.CheatFlyGyro:Destroy() end
        if hrp:FindFirstChild("GoldFlyMover") then hrp.GoldFlyMover:Destroy() end
        if hrp:FindFirstChild("GoldFlyGyro") then hrp.GoldFlyGyro:Destroy() end
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false; hum:ChangeState(Enum.HumanoidStateType.Freefall) end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
    
    onMenuToggle(false)
    if ScreenGui then ScreenGui:Destroy(); getgenv().CheatMenu_Gui = nil end
    -- Cleanup stats overlay
    if _statsConn then _statsConn:Disconnect(); _statsConn = nil end
    if _statsGui  then _statsGui:Destroy();  _statsGui = nil end
    -- Cleanup autoclicker
    if getgenv().AutoClicker_Conn then getgenv().AutoClicker_Conn:Disconnect() end
    if getgenv().AutoClicker_KeyConn then getgenv().AutoClicker_KeyConn:Disconnect() end
end)

-----------------------------------
-- ESP LOGIC
-----------------------------------
RunService.RenderStepped:Connect(function()
    if not menuIsOpen and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        pcall(function()
            local dist = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
            if dist > 2 and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                if not isShiftLockOptionEnabled() then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                else
                    local controller = getMouseLockController()
                    if controller then
                        local isShiftLockActive = false
                        if type(controller.GetIsMouseLocked) == "function" then
                            isShiftLockActive = controller:GetIsMouseLocked()
                        elseif type(controller.isMouseLocked) == "boolean" then
                            isShiftLockActive = controller.isMouseLocked
                        end
                        if not isShiftLockActive then
                            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                        end
                    end
                end
            end
        end)
    end

    if containerLayouts then
        for container, layout in pairs(containerLayouts) do
            if container.Visible then
                container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
                break
            end
        end
    end
end)

local _cachedPlayers = {}
local _playersLastUpdate = 0
getgenv().CheatESP_Loop = RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then return end
    local now = tick()
    if now - _playersLastUpdate > 0.5 then
        _cachedPlayers = Players:GetPlayers()
        _playersLastUpdate = now
    end
    for _, player in ipairs(_cachedPlayers) do
        if player == LocalPlayer then continue end
        if not ESP.ShowTeam and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then clearESP(player); continue end
        
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hum or hum.Health <= 0 or not hrp then clearESP(player); continue end

        local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
        local inRange = (ESP.Radius >= 10000) or (dist <= ESP.Radius)

        if not espCache[player] then espCache[player] = {} end
        local cache = espCache[player]

        if cache.Character ~= char or cache.lastMode ~= ESP.Mode then
            clearESP(player)
            espCache[player] = {Character = char, lastMode = ESP.Mode}
            cache = espCache[player]
        end

        if not inRange then
            if cache.Highlight then cache.Highlight.Enabled = false end
            if cache.Box then cache.Box.Visible = false end
            for k, v in pairs(cache) do if string.sub(k, 1, 5) == "Cube_" then v.Visible = false end end
            continue
        end

        if ESP.Mode == "Cubes" then
            local activeParts = {}
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
                    local id = "Cube_" .. part.Name
                    activeParts[id] = true
                    if not cache[id] then
                        local box = Instance.new("BoxHandleAdornment")
                        box.Size = part.Size + Vector3.new(0.05, 0.05, 0.05)
                        box.AlwaysOnTop = true
                        box.ZIndex = 5
                        box.Transparency = 0.6
                        box.Parent = CoreGui
                        box.Adornee = part
                        cache[id] = box
                    end
                    cache[id].Visible = true
                    -- Only write properties when they actually changed (avoids per-frame GPU overhead)
                    if cache[id].Color3 ~= ESP.Color then
                        cache[id].Color3 = ESP.Color
                    end
                    local newSize = part.Size + Vector3.new(0.05, 0.05, 0.05)
                    if cache[id].Size ~= newSize then
                        cache[id].Size = newSize
                    end
                end
            end
            for k, obj in pairs(cache) do
                if string.sub(k, 1, 5) == "Cube_" and not activeParts[k] then
                    if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
                    cache[k] = nil
                end
            end

        elseif ESP.Mode == "Outline" or ESP.Mode == "Chams" then
            if not cache.Highlight then
                local hl = Instance.new("Highlight")
                hl.Adornee = char
                hl.Parent = CoreGui
                cache.Highlight = hl
            end
            local hl = cache.Highlight
            hl.Enabled = true
            hl.FillColor = ESP.Color
            hl.OutlineColor = ESP.Color
            if ESP.Mode == "Chams" then
                hl.FillTransparency = ESP.ChamsTransparency
                hl.OutlineTransparency = 1
            else
                hl.FillTransparency = 1
                hl.OutlineTransparency = 0
            end

        elseif ESP.Mode == "Boxes" and Drawing then
            if not cache.Box then
                cache.Box = Drawing.new("Square")
                cache.Box.Thickness = 2
                cache.Box.Filled = false
            end
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and pos.Z > 0.1 then
                local width = math.clamp(1000 / pos.Z, 5, 2000)
                local height = math.clamp(1500 / pos.Z, 5, 3000)
                local size = Vector2.new(width, height)
                cache.Box.Size = size
                cache.Box.Position = Vector2.new(pos.X - size.X / 2, pos.Y - size.Y / 2)
                cache.Box.Color = ESP.Color
                cache.Box.Visible = true
            else
                cache.Box.Visible = false
            end
        end
    end
end)

Players.PlayerRemoving:Connect(clearESP)

-----------------------------------
-- PLAYER LOGIC
-----------------------------------
local CtrlHeld = false
local SpaceHeld = false

getgenv().PlayerCheats_Heartbeat = RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hum and hrp and hum.Health > 0 then
        if PlayerMods.SpeedEnabled and PlayerMods.SpeedValue > 16 then
            if hum.MoveDirection.Magnitude > 0 then
                local extraSpeed = PlayerMods.SpeedValue - 16
                hrp.CFrame = hrp.CFrame + (hum.MoveDirection * extraSpeed * dt)
            end
        end

        if PlayerMods.FlyEnabled then
            local mover = hrp:FindFirstChild("CheatFlyMover")
            local gyro = hrp:FindFirstChild("CheatFlyGyro")
            
            if not mover then
                mover = Instance.new("BodyVelocity")
                mover.Name = "CheatFlyMover"
                mover.MaxForce = Vector3.new(100000, 100000, 100000)
                mover.Parent = hrp
                
                gyro = Instance.new("BodyGyro")
                gyro.Name = "CheatFlyGyro"
                gyro.MaxTorque = Vector3.new(100000, 100000, 100000)
                gyro.P = 10000
                gyro.Parent = hrp
            end

            local moveDir = hum.MoveDirection
            local flySpeed = PlayerMods.FlySpeed or 50
            local yVelocity = 0

            if SpaceHeld then yVelocity = flySpeed end
            if CtrlHeld then yVelocity = -flySpeed end

            mover.Velocity = (moveDir * flySpeed) + Vector3.new(0, yVelocity, 0)
            gyro.CFrame = Camera.CFrame
            hum.PlatformStand = true
        end

        if PlayerMods.AntiKnockback and not PlayerMods.FlyEnabled then
            if hum.MoveDirection.Magnitude == 0 then
                hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
                hrp.RotVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

getgenv().PlayerCheats_Stepped = RunService.Stepped:Connect(function()
    -- Skip entirely when neither mode needs per-frame CanCollide override
    if not PlayerMods.NoclipEnabled and not PlayerMods.WallWalkEnabled then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if PlayerMods.NoclipEnabled then
                    part.CanCollide = false
                elseif PlayerMods.WallWalkEnabled then
                    local n = part.Name
                    if not string.find(n, "Leg") and not string.find(n, "Foot") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end)

getgenv().PlayerCheats_InputBegan = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then
        SpaceHeld = true
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hum and hrp and PlayerMods.JumpEnabled and not PlayerMods.FlyEnabled then
            if hum.FloorMaterial ~= Enum.Material.Air or PlayerMods.InfJumpEnabled then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, PlayerMods.JumpValue, hrp.Velocity.Z)
            end
        end
    elseif input.KeyCode == Enum.KeyCode.LeftControl then
        CtrlHeld = true
    elseif input.KeyCode == Enum.KeyCode.Delete then
        onMenuToggle(not menuIsOpen)
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space then SpaceHeld = false
    elseif input.KeyCode == Enum.KeyCode.LeftControl then CtrlHeld = false end
end)

getgenv().PlayerCheats_JumpReq = UserInputService.JumpRequest:Connect(function()
    if PlayerMods.InfJumpEnabled then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
