-- Limitless Hub 12.0 ULTIMATE - XENO COMPATIBLE
-- 🔥 Otimizado para Xeno Executor
-- Game: Fling Things and People (6961824067)

local VERSION = "12.0 XENO"
local OWNER = "TheSix2b" -- ⚠️ MUDE ISSO

-- ========================================
-- XENO COMPATIBILITY CHECK
-- ========================================
local isXeno = (identifyexecutor and identifyexecutor():lower():find("xeno")) or false

if isXeno then
    print("[Limitless Hub] Xeno detected - Using optimized mode")
end

-- ========================================
-- SAFE FUNCTION WRAPPERS (XENO)
-- ========================================
local function safeRequire(module)
    local success, result = pcall(function()
        return require(module)
    end)
    return success and result or nil
end

local function safeLoadstring(url)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not success then
        warn("[Limitless Hub] Failed to load:", url)
    end
    return success and result or nil
end

-- ========================================
-- SERVICES
-- ========================================
local Services = {
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    StarterGui = game:GetService("StarterGui"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    Lighting = game:GetService("Lighting"),
    TweenService = game:GetService("TweenService"),
    HttpService = game:GetService("HttpService"),
    TeleportService = game:GetService("TeleportService")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Mouse = Player:GetMouse()

Player.CharacterAdded:Connect(function(char) Character = char end)

-- ========================================
-- CONNECTION MANAGER
-- ========================================
local ConnectionManager = {
    connections = {},
    loops = {}
}

function ConnectionManager:Add(conn, name)
    self:Remove(name)
    self.connections[name] = conn
end

function ConnectionManager:Remove(name)
    if self.connections[name] then
        pcall(function() self.connections[name]:Disconnect() end)
        self.connections[name] = nil
    end
end

function ConnectionManager:AddLoop(func, name)
    self:RemoveLoop(name)
    local running = true
    self.loops[name] = {stop = function() running = false end}
    
    task.spawn(function()
        while running do
            local success = pcall(func)
            if not success and isXeno then
                task.wait(0.2) -- Xeno fallback
            else
                task.wait(0.1)
            end
        end
    end)
end

function ConnectionManager:RemoveLoop(name)
    if self.loops[name] then
        self.loops[name].stop()
        self.loops[name] = nil
    end
end

-- ========================================
-- CONFIG SYSTEM (File Operations)
-- ========================================
local ConfigSystem = {
    fileName = "LimitlessHub_Config.json",
    currentTheme = "Default",
    keybind = Enum.KeyCode.RightControl,
    
    themes = {
        Default = {name = "Default", description = "Classic Rayfield"},
        Light = {name = "Light", description = "Clean light theme"},
        Dark = {name = "Dark", description = "Pure dark"},
        Ocean = {name = "Ocean", description = "Ocean blue"},
        Amber = {name = "Amber", description = "Warm amber"},
        DarkBlue = {name = "DarkBlue", description = "Deep blue"},
        Amethyst = {name = "Amethyst", description = "Purple amethyst"},
        Cyberpunk = {name = "Cyberpunk", description = "Neon cyberpunk"}
    }
}

function ConfigSystem:Save()
    local success = pcall(function()
        if writefile then
            local data = Services.HttpService:JSONEncode({
                theme = self.currentTheme,
                keybind = self.keybind.Name
            })
            writefile(self.fileName, data)
        end
    end)
    if not success and isXeno then
        warn("[Limitless Hub] Xeno: Config save failed (normal)")
    end
end

function ConfigSystem:Load()
    local success = pcall(function()
        if isfile and readfile and isfile(self.fileName) then
            local data = Services.HttpService:JSONDecode(readfile(self.fileName))
            self.currentTheme = data.theme or "Default"
            if data.keybind then
                self.keybind = Enum.KeyCode[data.keybind] or Enum.KeyCode.RightControl
            end
        end
    end)
    if not success and isXeno then
        print("[Limitless Hub] Xeno: Using default config")
    end
end

-- ========================================
-- ADMIN SYSTEM
-- ========================================
local AdminSystem = {
    owner = OWNER,
    friends = {},
    chatHistory = {},
    maxHistory = 50,
    fileName = "LimitlessHub_Data.json"
}

function AdminSystem:IsOwner(name)
    return name == self.owner
end

function AdminSystem:SaveData()
    pcall(function()
        if writefile then
            local data = Services.HttpService:JSONEncode({
                friends = self.friends,
                chatHistory = self.chatHistory
            })
            writefile(self.fileName, data)
        end
    end)
end

function AdminSystem:LoadData()
    pcall(function()
        if isfile and readfile and isfile(self.fileName) then
            local data = Services.HttpService:JSONDecode(readfile(self.fileName))
            self.friends = data.friends or {}
            self.chatHistory = data.chatHistory or {}
        end
    end)
end

function AdminSystem:AddFriend(name)
    if not table.find(self.friends, name) then
        table.insert(self.friends, name)
        self:SaveData()
        return true
    end
    return false
end

function AdminSystem:RemoveFriend(name)
    local index = table.find(self.friends, name)
    if index then
        table.remove(self.friends, index)
        self:SaveData()
        return true
    end
    return false
end

-- ========================================
-- GRAB HELPER (FLING THINGS SPECIFIC)
-- ========================================
local GrabHelper = {}

function GrabHelper:GetCurrentGrab()
    local grabParts = Services.Workspace:FindFirstChild("GrabParts")
    if not grabParts then return nil end
    
    local grabPart = grabParts:FindFirstChild("GrabPart")
    if not grabPart then return nil end
    
    local weld = grabPart:FindFirstChild("WeldConstraint")
    if not weld or not weld.Part1 then return nil end
    
    return {
        part = weld.Part1,
        character = weld.Part1.Parent,
        grabPart = grabPart,
        weld = weld
    }
end

-- ========================================
-- GRAB EFFECTS
-- ========================================
local AllGrabEffects = {
    currentEffect = nil,
    spinSpeed = 10
}

function AllGrabEffects:Stop()
    ConnectionManager:RemoveLoop("GrabEffect")
    self.currentEffect = nil
end

function AllGrabEffects:Spin()
    self:Stop()
    self.currentEffect = "spin"
    local angle = 0
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then return end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local humanoid = grab.character:FindFirstChild("Humanoid")
            if humanoid then humanoid.PlatformStand = true end
            
            local gyro = hrp:FindFirstChild("SpinGyro") or Instance.new("BodyGyro")
            gyro.Name = "SpinGyro"
            gyro.MaxTorque = Vector3.new(0, math.huge, 0)
            gyro.P = 10000
            gyro.Parent = hrp
            
            angle = angle + math.rad(self.spinSpeed)
            gyro.CFrame = CFrame.Angles(0, angle, 0)
        end
    end, "GrabEffect")
end

function AllGrabEffects:Void()
    self:Stop()
    self.currentEffect = "void"
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then return end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            hrp.CFrame = CFrame.new(0, -50000, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end, "GrabEffect")
end

function AllGrabEffects:Fling()
    self:Stop()
    self.currentEffect = "fling"
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if grab and grab.part then
            local bv = grab.part:FindFirstChild("FlingForce") or Instance.new("BodyVelocity")
            bv.Name = "FlingForce"
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Velocity = Vector3.new(
                math.random(-200, 200),
                math.random(100, 300),
                math.random(-200, 200)
            )
            bv.Parent = grab.part
        end
    end, "GrabEffect")
end

function AllGrabEffects:KickUp()
    self:Stop()
    self.currentEffect = "kickup"
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then return end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("KickForce") or Instance.new("BodyVelocity")
            bv.Name = "KickForce"
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Velocity = Vector3.new(0, 10000, 0)
            bv.Parent = hrp
        end
    end, "GrabEffect")
end

function AllGrabEffects:Pendulum()
    self:Stop()
    self.currentEffect = "pendulum"
    local angle = 0
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then return end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        if hrp and Character and Character:FindFirstChild("HumanoidRootPart") then
            local centerPos = Character.HumanoidRootPart.Position
            local humanoid = grab.character:FindFirstChild("Humanoid")
            if humanoid then humanoid.PlatformStand = true end
            
            angle = angle + 0.5
            local swing = math.sin(angle) * 10
            
            hrp.CFrame = CFrame.new(
                centerPos.X + swing,
                centerPos.Y + 5,
                centerPos.Z
            )
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end, "GrabEffect")
end

-- ========================================
-- XENO-COMPATIBLE ESP
-- ========================================
local ESP = {
    enabled = false,
    boxes = {}
}

function ESP:CreateBox(player)
    if player == Player then return end
    
    local success, box = pcall(function()
        local b = Drawing.new("Square")
        b.Visible = false
        b.Color = Color3.fromRGB(255, 0, 0)
        b.Thickness = 2
        b.Transparency = 1
        b.Filled = false
        return b
    end)
    
    if not success then
        warn("[Limitless Hub] Xeno: Drawing API not supported")
        return
    end
    
    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Size = 18
    name.Center = true
    name.Outline = true
    name.Text = player.Name
    
    self.boxes[player] = {box = box, name = name}
end

function ESP:Update()
    for player, drawings in pairs(self.boxes) do
        pcall(function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                local head = player.Character:FindFirstChild("Head")
                
                local camera = Services.Workspace.CurrentCamera
                local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                
                if onScreen then
                    local headPos = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                    local legPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2
                    
                    drawings.box.Size = Vector2.new(width, height)
                    drawings.box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                    drawings.box.Visible = true
                    
                    drawings.name.Position = Vector2.new(screenPos.X, headPos.Y - 20)
                    drawings.name.Visible = true
                else
                    drawings.box.Visible = false
                    drawings.name.Visible = false
                end
            else
                drawings.box.Visible = false
                drawings.name.Visible = false
            end
        end)
    end
end

function ESP:Enable()
    self.enabled = true
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        self:CreateBox(player)
    end
    
    ConnectionManager:Add(Services.Players.PlayerAdded:Connect(function(player)
        self:CreateBox(player)
    end), "ESPPlayerAdded")
    
    ConnectionManager:AddLoop(function()
        if self.enabled then
            self:Update()
        end
    end, "ESPUpdate")
end

function ESP:Disable()
    self.enabled = false
    ConnectionManager:RemoveLoop("ESPUpdate")
    ConnectionManager:Remove("ESPPlayerAdded")
    
    for _, drawings in pairs(self.boxes) do
        pcall(function()
            drawings.box:Remove()
            drawings.name:Remove()
        end)
    end
    self.boxes = {}
end

-- ========================================
-- XENO-COMPATIBLE SILENT AIM
-- ========================================
local SilentAim = {
    enabled = false,
    fov = 200,
    showFOV = true,
    predictMovement = false,
    predictionStrength = 0.15,
    targetPart = "Head",
    fovCircle = nil,
    currentTarget = nil
}

function SilentAim:CreateFOVCircle()
    if self.fovCircle then return end
    
    local success, circle = pcall(function()
        local c = Drawing.new("Circle")
        c.Thickness = 2
        c.NumSides = 50
        c.Radius = self.fov
        c.Color = Color3.fromRGB(255, 255, 0)
        c.Transparency = 1
        c.Visible = self.showFOV
        c.Filled = false
        return c
    end)
    
    if not success then
        warn("[Limitless Hub] Xeno: FOV Circle not supported")
        return
    end
    
    self.fovCircle = circle
    
    ConnectionManager:AddLoop(function()
        if self.fovCircle then
            local camera = Services.Workspace.CurrentCamera
            self.fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            self.fovCircle.Radius = self.fov
            self.fovCircle.Visible = self.showFOV and self.enabled
        end
    end, "SilentAimFOV")
end

function SilentAim:GetClosestPlayer()
    local camera = Services.Workspace.CurrentCamera
    local closestPlayer = nil
    local shortestDistance = self.fov
    local centerScreen = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player ~= Player and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local targetPart = player.Character:FindFirstChild(self.targetPart)
            
            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
                    
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

function SilentAim:GetPredictedPosition(targetPart)
    if not self.predictMovement then
        return targetPart.Position
    end
    
    local velocity = targetPart.AssemblyLinearVelocity
    local prediction = targetPart.Position + (velocity * self.predictionStrength)
    
    return prediction
end

function SilentAim:Enable()
    if self.enabled then return end
    self.enabled = true
    
    self:CreateFOVCircle()
    
    -- Xeno-compatible hook
    local hookSuccess = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if SilentAim.enabled and method == "FireServer" then
                if self.Name:lower():find("grab") or 
                   self.Name:lower():find("throw") or 
                   self.Name:lower():find("fling") then
                    
                    local target = SilentAim:GetClosestPlayer()
                    if target and target.Character then
                        local targetPart = target.Character:FindFirstChild(SilentAim.targetPart)
                        if targetPart then
                            local predictedPos = SilentAim:GetPredictedPosition(targetPart)
                            
                            for i, arg in pairs(args) do
                                if typeof(arg) == "Vector3" then
                                    args[i] = predictedPos
                                elseif typeof(arg) == "CFrame" then
                                    args[i] = CFrame.new(predictedPos)
                                end
                            end
                        end
                    end
                end
            end
            
            return oldNamecall(self, unpack(args))
        end)
    end)
    
    if not hookSuccess and isXeno then
        warn("[Limitless Hub] Xeno: Silent Aim hook failed (may not work)")
    end
    
    ConnectionManager:AddLoop(function()
        if not self.enabled then return end
        self.currentTarget = self:GetClosestPlayer()
    end, "SilentAimTarget")
end

function SilentAim:Disable()
    self.enabled = false
    self.currentTarget = nil
    ConnectionManager:RemoveLoop("SilentAimFOV")
    ConnectionManager:RemoveLoop("SilentAimTarget")
    
    if self.fovCircle then
        pcall(function() self.fovCircle:Remove() end)
        self.fovCircle = nil
    end
end

-- ========================================
-- FLY SYSTEM
-- ========================================
local FlySystem = {
    enabled = false,
    speed = 50,
    bodyGyro = nil,
    bodyVelocity = nil
}

function FlySystem:Enable()
    if self.enabled then return end
    self.enabled = true
    
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = Character.HumanoidRootPart
    
    self.bodyGyro = Instance.new("BodyGyro")
    self.bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    self.bodyGyro.P = 9e4
    self.bodyGyro.Parent = hrp
    
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    self.bodyVelocity.Velocity = Vector3.zero
    self.bodyVelocity.Parent = hrp
    
    ConnectionManager:AddLoop(function()
        if not self.enabled or not Character then return end
        local hrp = Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local camera = Services.Workspace.CurrentCamera
        local moveVector = Vector3.zero
        
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + camera.CFrame.LookVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - camera.CFrame.LookVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - camera.CFrame.RightVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + camera.CFrame.RightVector
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector - Vector3.new(0, 1, 0)
        end
        
        if self.bodyVelocity then
            self.bodyVelocity.Velocity = moveVector * self.speed
        end
        if self.bodyGyro then
            self.bodyGyro.CFrame = camera.CFrame
        end
    end, "FlyLoop")
end

function FlySystem:Disable()
    self.enabled = false
    ConnectionManager:RemoveLoop("FlyLoop")
    
    if self.bodyGyro then self.bodyGyro:Destroy() self.bodyGyro = nil end
    if self.bodyVelocity then self.bodyVelocity:Destroy() self.bodyVelocity = nil end
end

-- ========================================
-- NOCLIP
-- ========================================
local NoclipSystem = {enabled = false}

function NoclipSystem:Enable()
    self.enabled = true
    ConnectionManager:AddLoop(function()
        if not self.enabled or not Character then return end
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end, "Noclip")
end

function NoclipSystem:Disable()
    self.enabled = false
    ConnectionManager:RemoveLoop("Noclip")
    if Character then
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ========================================
-- ANTI-AFK
-- ========================================
local AntiAFK = {enabled = false}

function AntiAFK:Enable()
    self.enabled = true
    ConnectionManager:AddLoop(function()
        if not self.enabled then return end
        Services.VirtualInputManager:SendMouseMoveEvent(
            math.random(100, 500),
            math.random(100, 500),
            Services.Workspace
        )
        task.wait(math.random(10, 30))
    end, "AntiAFK")
end

function AntiAFK:Disable()
    self.enabled = false
    ConnectionManager:RemoveLoop("AntiAFK")
end

-- ========================================
-- UI INITIALIZATION (XENO-OPTIMIZED)
-- ========================================
local RayfieldWindow = nil

local function InitUI()
    ConfigSystem:Load()
    AdminSystem:LoadData()
    
    local Rayfield = safeLoadstring('https://sirius.menu/rayfield')
    
    if not Rayfield then
        warn("[Limitless Hub] Failed to load Rayfield UI")
        return
    end
    
    RayfieldWindow = Rayfield:CreateWindow({
        Name = "Limitless Hub " .. VERSION,
        LoadingTitle = "Limitless Hub - Xeno",
        LoadingSubtitle = "Optimized for Xeno Executor",
        Theme = ConfigSystem.currentTheme,
        DisableRayfieldPrompts = true,
        ConfigurationSaving = {Enabled = false},
        KeySystem = false
    })
    
    -- HOME
    local Home = RayfieldWindow:CreateTab("🏠 Home", 4483362458)
    Home:CreateParagraph({
        Title = "Limitless Hub " .. VERSION,
        Content = "✅ Xeno Compatible\n✅ Silent Aim for FTAP\n✅ 8 Themes\n✅ Keybind: " .. ConfigSystem.keybind.Name
    })
    
    if isXeno then
        Home:CreateLabel("🟢 Xeno Executor Detected")
    else
        Home:CreateLabel("⚠️ Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
    end
    
    -- SILENT AIM
    local AimTab = RayfieldWindow:CreateTab("🎯 Silent Aim", 4483362458)
    
    AimTab:CreateToggle({
        Name = "Enable Silent Aim",
        CurrentValue = false,
        Callback = function(v)
            if v then SilentAim:Enable() else SilentAim:Disable() end
        end
    })
    
    AimTab:CreateSlider({
        Name = "FOV Size",
        Range = {50, 500},
        Increment = 10,
        CurrentValue = 200,
        Callback = function(v) SilentAim.fov = v end
    })
    
    AimTab:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = true,
        Callback = function(v) SilentAim.showFOV = v end
    })
    
    AimTab:CreateToggle({
        Name = "Movement Prediction",
        CurrentValue = false,
        Callback = function(v) SilentAim.predictMovement = v end
    })
    
    AimTab:CreateDropdown({
        Name = "Target Part",
        Options = {"Head", "HumanoidRootPart", "UpperTorso"},
        CurrentOption = "Head",
        Callback = function(v) SilentAim.targetPart = v end
    })
    
    -- ESP
    local ESPTab = RayfieldWindow:CreateTab("👁️ ESP", 4483362458)
    
    ESPTab:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = false,
        Callback = function(v)
            if v then ESP:Enable() else ESP:Disable() end
        end
    })
    
    -- MOVEMENT
    local Movement = RayfieldWindow:CreateTab("🏃 Movement", 4483362458)
    
    Movement:CreateToggle({
        Name = "Enable Fly",
        CurrentValue = false,
        Callback = function(v)
            if v then FlySystem:Enable() else FlySystem:Disable() end
        end
    })
    
    Movement:CreateSlider({
        Name = "Fly Speed",
        Range = {10, 300},
        Increment = 5,
        CurrentValue = 50,
        Callback = function(v) FlySystem.speed = v end
    })
    
    Movement:CreateToggle({
        Name = "Enable Noclip",
        CurrentValue = false,
        Callback = function(v)
            if v then NoclipSystem:Enable() else NoclipSystem:Disable() end
        end
    })
    
    -- GRAB EFFECTS
    local GrabTab = RayfieldWindow:CreateTab("🤏 Grab", 4483362458)
    
    GrabTab:CreateToggle({
        Name = "🌀 Spin Grab",
        CurrentValue = false,
        Callback = function(v)
            if v then AllGrabEffects:Spin() else AllGrabEffects:Stop() end
        end
    })
    
    GrabTab:CreateSlider({
        Name = "Spin Speed",
        Range = {1, 50},
        Increment = 1,
        CurrentValue = 10,
        Callback = function(v) AllGrabEffects.spinSpeed = v end
    })
    
    GrabTab:CreateToggle({
        Name = "🕳️ Void Grab",
        CurrentValue = false,
        Callback = function(v)
            if v then AllGrabEffects:Void() else AllGrabEffects:Stop() end
        end
    })
    
    GrabTab:CreateToggle({
        Name = "💫 Fling Grab",
        CurrentValue = false,
        Callback = function(v)
            if v then AllGrabEffects:Fling() else AllGrabEffects:Stop() end
        end
    })
    
    GrabTab:CreateToggle({
        Name = "👢 Kick Up",
        CurrentValue = false,
        Callback = function(v)
            if v then AllGrabEffects:KickUp() else AllGrabEffects:Stop() end
        end
    })
    
    GrabTab:CreateToggle({
        Name = "⏰ Pendulum",
        CurrentValue = false,
        Callback = function(v)
            if v then AllGrabEffects:Pendulum() else AllGrabEffects:Stop() end
        end
    })
    
    -- FRIENDS
    local Friends = RayfieldWindow:CreateTab("👥 Friends", 4483362458)
    
    local friendInput = ""
    
    Friends:CreateInput({
        Name = "Username",
        PlaceholderText = "Enter username",
        RemoveTextAfterFocusLost = false,
        Callback = function(text) friendInput = text end
    })
    
    Friends:CreateButton({
        Name = "Add Friend",
        Callback = function()
            if friendInput ~= "" and AdminSystem:AddFriend(friendInput) then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "✅ Friend Added",
                    Text = friendInput,
                    Duration = 2
                })
            end
        end
    })
    
    Friends:CreateButton({
        Name = "Remove Friend",
        Callback = function()
            if friendInput ~= "" and AdminSystem:RemoveFriend(friendInput) then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "✅ Friend Removed",
                    Text = friendInput,
                    Duration = 2
                })
            end
        end
    })
    
    -- SETTINGS
    local Settings = RayfieldWindow:CreateTab("⚙️ Settings", 4483362458)
    
    Settings:CreateSection("Theme Selector")
    
    local themeOptions = {}
    for themeName, _ in pairs(ConfigSystem.themes) do
        table.insert(themeOptions, themeName)
    end
    
    Settings:CreateDropdown({
        Name = "UI Theme",
        Options = themeOptions,
        CurrentOption = ConfigSystem.currentTheme,
        Callback = function(option)
            ConfigSystem.currentTheme = option
            ConfigSystem:Save()
            Services.StarterGui:SetCore("SendNotification", {
                Title = "🎨 Theme Changed",
                Text = "Reload UI to apply",
                Duration = 3
            })
        end
    })
    
    Settings:CreateButton({
        Name = "🔄 Reload UI",
        Callback = function()
            pcall(function()
                for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
                    if v.Name:find("Rayfield") then v:Destroy() end
                end
            end)
            task.wait(0.5)
            InitUI()
        end
    })
    
    Settings:CreateSection("Keybind")
    
    Settings:CreateLabel("Current: " .. ConfigSystem.keybind.Name)
    
    Settings:CreateButton({
        Name = "Change Keybind",
        Callback = function()
            Services.StarterGui:SetCore("SendNotification", {
                Title = "⌨️ Press Any Key",
                Text = "Press the key you want",
                Duration = 3
            })
            
            local conn
            conn = Services.UserInputService.InputBegan:Connect(function(input, gp)
                if not gp and input.KeyCode ~= Enum.KeyCode.Unknown then
                    ConfigSystem.keybind = input.KeyCode
                    ConfigSystem:Save()
                    Services.StarterGui:SetCore("SendNotification", {
                        Title = "✅ Keybind Changed",
                        Text = "New: " .. input.KeyCode.Name,
                        Duration = 3
                    })
                    conn:Disconnect()
                end
            end)
        end
    })
    
    -- UTILS
    local Utils = RayfieldWindow:CreateTab("🔧 Utils", 4483362458)
    
    Utils:CreateToggle({
        Name = "Anti-AFK",
        CurrentValue = false,
        Callback = function(v)
            if v then AntiAFK:Enable() else AntiAFK:Disable() end
        end
    })
    
    Utils:CreateSlider({
        Name = "FOV",
        Range = {1, 120},
        Increment = 1,
        CurrentValue = 70,
        Callback = function(v)
            Services.Workspace.CurrentCamera.FieldOfView = v
        end
    })
    
    Utils:CreateButton({
        Name = "Reset Character",
        Callback = function()
            if Character then Character:BreakJoints() end
        end
    })
    
    Utils:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            Services.TeleportService:Teleport(game.PlaceId, Player)
        end
    })
    
    -- CREDITS
    local Credits = RayfieldWindow:CreateTab("ℹ️ Info", 4483362458)
    
    Credits:CreateParagraph({
        Title = "Limitless Hub " .. VERSION,
        Content = "Game: Fling Things and People\nExecutor: " .. (isXeno and "Xeno" or "Other") .. "\n\nFeatures:\n• Silent Aim\n• ESP\n• Grab Effects\n• 8 Themes\n• Keybinds"
    })
    
    Credits:CreateLabel("Place ID: 6961824067")
    Credits:CreateLabel("Created by: " .. OWNER)
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "✅ Limitless Hub Loaded",
        Text = VERSION .. " | Press " .. ConfigSystem.keybind.Name,
        Duration = 5
    })
end

-- ========================================
-- KEYBIND TOGGLE (XENO-SAFE)
-- ========================================
Services.UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    pcall(function()
        if input.KeyCode == ConfigSystem.keybind and RayfieldWindow then
            Rayfield:Toggle()
        end
    end)
end)

-- ========================================
-- START SCRIPT
-- ========================================
task.spawn(function()
    local success, err = pcall(InitUI)
    if not success then
        warn("[Limitless Hub] Error:", err)
        Services.StarterGui:SetCore("SendNotification", {
            Title = "❌ Limitless Hub Error",
            Text = "Failed to load UI. Check console (F9)",
            Duration = 10
        })
    end
end)


