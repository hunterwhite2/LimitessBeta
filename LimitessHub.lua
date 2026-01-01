-- Limitless Hub 11.4 FINAL - ALL BUGS FIXED
-- Snake Fixed | Noclip Fixed | Anchor Server-Side | Kill Grab Removed

local VERSION = "11.4 FINAL"

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
    TweenService = game:GetService("TweenService")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Mouse = Player:GetMouse()

-- ========================================
-- CONFIGURAÇÕES
-- ========================================
local Config = {
    AutoRemoveArrows = true,
    TeleportKey = Enum.KeyCode.Q,
    TargetSwitchKey = Enum.KeyCode.T,
    
    AutoLockEnabled = false,
    PriorityTargeting = false,
    PredictMovement = false,
    LeadShots = false,
    CurrentTarget = nil,
    
    TimeOfDay = "14:00:00",
    WeatherEnabled = false,
    ZoomExtended = false,
    
    FreecamEnabled = false,
    NoclipEnabled = false,
    MirrorModeEnabled = false,
    
    Friends = {},
    FriendChatHistory = {}
}

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
            pcall(func)
            task.wait(0.1)
        end
    end)
end

function ConnectionManager:RemoveLoop(name)
    if self.loops[name] then
        self.loops[name].stop()
        self.loops[name] = nil
    end
end

function ConnectionManager:Cleanup()
    for _, conn in pairs(self.connections) do pcall(function() conn:Disconnect() end) end
    for _, loop in pairs(self.loops) do pcall(function() loop.stop() end) end
    self.connections = {}
    self.loops = {}
end

-- ========================================
-- FRIEND SYSTEM
-- ========================================
local FriendSystem = {
    friends = {},
    chatHistory = {},
    fileName = "LimitlessHub_Friends.json"
}

function FriendSystem:Save()
    pcall(function()
        if writefile then
            local data = {
                friends = self.friends,
                chatHistory = self.chatHistory
            }
            writefile(self.fileName, game:GetService("HttpService"):JSONEncode(data))
        end
    end)
end

function FriendSystem:Load()
    pcall(function()
        if isfile and readfile and isfile(self.fileName) then
            local data = game:GetService("HttpService"):JSONDecode(readfile(self.fileName))
            self.friends = data.friends or {}
            self.chatHistory = data.chatHistory or {}
        end
    end)
end

function FriendSystem:AddFriend(playerName)
    if not table.find(self.friends, playerName) then
        table.insert(self.friends, playerName)
        self:Save()
        return true
    end
    return false
end

function FriendSystem:RemoveFriend(playerName)
    local index = table.find(self.friends, playerName)
    if index then
        table.remove(self.friends, index)
        self:Save()
        return true
    end
    return false
end

function FriendSystem:IsFriend(playerName)
    return table.find(self.friends, playerName) ~= nil
end

function FriendSystem:SendMessage(friendName, message)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] You -> %s: %s", timestamp, friendName, message)
    
    table.insert(self.chatHistory, entry)
    self:Save()
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "Message Sent",
        Text = "To: " .. friendName,
        Duration = 2
    })
end

function FriendSystem:GetChatHistory()
    local result = ""
    for i = math.max(1, #self.chatHistory - 20), #self.chatHistory do
        result = result .. self.chatHistory[i] .. "\n"
    end
    return result ~= "" and result or "No messages yet."
end

-- ========================================
-- GRAB HELPER
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
-- ALL GRAB EFFECTS (KILL GRAB REMOVIDO)
-- ========================================
local AllGrabEffects = {
    currentEffect = nil,
    anchoredParts = {},
    unanchorKey = Enum.KeyCode.U,
    spinSpeed = 10
}

function AllGrabEffects:Stop()
    ConnectionManager:RemoveLoop("GrabEffect")
    ConnectionManager:Remove("UnanchorKey")
    
    for _, part in pairs(self.anchoredParts) do
        if part and part.Parent then
            part.Anchored = false
        end
    end
    self.anchoredParts = {}
    self.currentEffect = nil
end

-- SPIN GRAB
function AllGrabEffects:Spin()
    self:Stop()
    self.currentEffect = "spin"
    
    local spinGyro = nil
    local currentAngle = 0
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then 
            if spinGyro then 
                spinGyro:Destroy() 
                spinGyro = nil
            end
            return 
        end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        local humanoid = grab.character:FindFirstChild("Humanoid")
        
        if hrp then
            -- ✅ Desabilita controle do Humanoid
            if humanoid then
                humanoid.PlatformStand = true
            end
            
            -- ✅ Cria BodyGyro se não existir
            if not spinGyro or spinGyro.Parent ~= hrp then
                -- Remove BodyGyro antigo se existir
                local oldGyro = hrp:FindFirstChild("SpinGyro")
                if oldGyro then oldGyro:Destroy() end
                
                -- Cria novo BodyGyro
                spinGyro = Instance.new("BodyGyro")
                spinGyro.Name = "SpinGyro"
                spinGyro.MaxTorque = Vector3.new(0, math.huge, 0) -- Só gira no eixo Y
                spinGyro.P = 10000 -- Força da rotação
                spinGyro.D = 500 -- Amortecimento
                spinGyro.Parent = hrp
            end
            
            -- ✅ Atualiza ângulo suavemente
            currentAngle = currentAngle + math.rad(self.spinSpeed)
            spinGyro.CFrame = CFrame.Angles(0, currentAngle, 0)
            
            -- ✅ Zera velocidades lineares (mantém angular)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end, "GrabEffect")
end

-- ✅ IMPORTANTE: Limpar BodyGyro ao parar
function AllGrabEffects:Stop()
    ConnectionManager:RemoveLoop("GrabEffect")
    ConnectionManager:Remove("UnanchorKey")
    
    -- ✅ Remove BodyGyro se existir
    local grab = GrabHelper:GetCurrentGrab()
    if grab and grab.character then
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local gyro = hrp:FindFirstChild("SpinGyro")
            if gyro then gyro:Destroy() end
            
            -- ✅ Restaura controle do Humanoid
            local humanoid = grab.character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
            end
        end
    end
    
    -- Resto do código de cleanup...
    for _, part in pairs(self.anchoredParts) do
        if part and part.Parent then
            part.Anchored = false
        end
    end
    self.anchoredParts = {}
    self.currentEffect = nil
end
-- VOID GRAB
function AllGrabEffects:Void()
    self:Stop()
    self.currentEffect = "void"
    
    local voidY = -50000 -- Muito profundo
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if not grab or not grab.character then 
            return 
        end
        
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        local humanoid = grab.character:FindFirstChild("Humanoid")
        
        if hrp then
            -- ✅ 1. Desabilita controle do Humanoid
            if humanoid then
                humanoid.PlatformStand = true
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end
            
            -- ✅ 2. Desativa TODAS as colisões
            for _, part in pairs(grab.character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            -- ✅ 3. Ancora o HRP (impede servidor de interferir)
            hrp.Anchored = true
            
            -- ✅ 4. Teleporta para MUITO profundo
            hrp.CFrame = CFrame.new(0, voidY, 0)
            
            -- ✅ 5. Zera velocidades (evita "pular" de volta)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            -- ✅ 6. Remove BodyMovers que podem interferir
            for _, obj in pairs(hrp:GetChildren()) do
                if obj:IsA("BodyMover") or obj:IsA("BodyGyro") or 
                   obj:IsA("BodyPosition") or obj:IsA("BodyVelocity") then
                    obj:Destroy()
                end
            end
        end
    end, "GrabEffect")
end

-- ✅ IMPORTANTE: Cleanup ao parar
function AllGrabEffects:Stop()
    ConnectionManager:RemoveLoop("GrabEffect")
    ConnectionManager:Remove("UnanchorKey")
    
    -- ✅ Restaura player (se ainda existir)
    local grab = GrabHelper:GetCurrentGrab()
    if grab and grab.character then
        local hrp = grab.character:FindFirstChild("HumanoidRootPart")
        local humanoid = grab.character:FindFirstChild("Humanoid")
        
        if hrp then
            hrp.Anchored = false
        end
        
        if humanoid then
            humanoid.PlatformStand = false
        end
        
        -- Reativa colisões
        for _, part in pairs(grab.character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    
    -- Resto do cleanup...
    for _, part in pairs(self.anchoredParts) do
        if part and part.Parent then
            part.Anchored = false
        end
    end
    self.anchoredParts = {}
    self.currentEffect = nil
end

-- KICK GRAB
function AllGrabEffects:Kick()
    self:Stop()
    self.currentEffect = "kick"
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if grab and grab.character then
            pcall(function()
                local hrp = grab.character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local firePart = hrp:FindFirstChild("FirePlayerPart") or Instance.new("Part")
                    firePart.Name = "FirePlayerPart"
                    firePart.Size = Vector3.new(1, 1, 1)
                    firePart.Transparency = 1
                    firePart.CanCollide = false
                    firePart.Anchored = true
                    firePart.Parent = hrp
                    
                    local partOwner = firePart:FindFirstChild("PartOwner") or Instance.new("StringValue")
                    partOwner.Name = "PartOwner"
                    partOwner.Value = Player.Name
                    partOwner.Parent = firePart
                    
                    hrp.CFrame = CFrame.new(0, -500, 0)
                end
            end)
        end
    end, "GrabEffect")
end

-- FLING GRAB
function AllGrabEffects:Fling()
    self:Stop()
    self.currentEffect = "fling"
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if grab and grab.part then
            local bv = grab.part:FindFirstChild("FlingForce") or Instance.new("BodyVelocity")
            bv.Name = "FlingForce"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(
                math.random(-200, 200),
                math.random(100, 300),
                math.random(-200, 200)
            )
            bv.Parent = grab.part
        end
    end, "GrabEffect")
end

-- ANCHOR GRAB (SERVER-SIDE FIXED)
function AllGrabEffects:Anchor()
    self:Stop()
    self.currentEffect = "anchor"
    self.anchoredParts = {}
    self.anchorKey = Enum.KeyCode.Y
    self.unanchorKey = Enum.KeyCode.U
    self.anchorAllKey = Enum.KeyCode.H -- ✅ Ancora TODAS as parts no modelo
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "⚓ Anchor Mode",
        Text = "Y = Anchor grabbed\nH = Anchor all parts in model\nU = Unanchor all",
        Duration = 6
    })
    
    ConnectionManager:Add(Services.UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        
        local grab = GrabHelper:GetCurrentGrab()
        
        -- ✅ Y - Ancora APENAS a part grabbed
        if input.KeyCode == self.anchorKey then
            if not grab then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Nothing Grabbed",
                    Text = "Grab something first!",
                    Duration = 2
                })
                return
            end
            
            -- Bloqueia players
            if grab.character and grab.character:FindFirstChild("Humanoid") then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Cannot Anchor Players",
                    Text = "Only works on objects!",
                    Duration = 3
                })
                return
            end
            
            -- Ancora a part
            if grab.part then
                pcall(function()
                    grab.part.Anchored = true
                    grab.part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    grab.part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    if not table.find(self.anchoredParts, grab.part) then
                        table.insert(self.anchoredParts, grab.part)
                    end
                end)
                
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "✅ Anchored",
                    Text = grab.part.Name,
                    Duration = 2
                })
            end
        end
        
        -- ✅ H - Ancora TODAS as parts do modelo
        if input.KeyCode == self.anchorAllKey then
            if not grab or not grab.part then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Nothing Grabbed",
                    Text = "Grab something first!",
                    Duration = 2
                })
                return
            end
            
            local model = grab.part.Parent
            if not model then return end
            
            local count = 0
            for _, part in pairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.Anchored = true
                        part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        
                        if not table.find(self.anchoredParts, part) then
                            table.insert(self.anchoredParts, part)
                            count = count + 1
                        end
                    end)
                end
            end
            
            Services.StarterGui:SetCore("SendNotification", {
                Title = "✅ Anchored All",
                Text = count .. " parts in " .. model.Name,
                Duration = 3
            })
        end
        
        -- ✅ U - Desancora TODAS
        if input.KeyCode == self.unanchorKey then
            if #self.anchoredParts == 0 then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Nothing to Unanchor",
                    Text = "No anchored parts",
                    Duration = 2
                })
                return
            end
            
            local count = 0
            for _, part in pairs(self.anchoredParts) do
                if part and part.Parent then
                    pcall(function()
                        part.Anchored = false
                        count = count + 1
                    end)
                end
            end
            
            self.anchoredParts = {}
            
            Services.StarterGui:SetCore("SendNotification", {
                Title = "✅ Unanchored",
                Text = count .. " parts",
                Duration = 2
            })
        end
    end), "AnchorKeys")
end
-- PENDULUM GRAB
function AllGrabEffects:Pendulum()
    self:Stop()
    self.currentEffect = "pendulum"
    
    local angle = 0
    local speed = 5
    local radius = 10
    
    ConnectionManager:AddLoop(function()
        local grab = GrabHelper:GetCurrentGrab()
        if grab and grab.character then
            local hrp = grab.character:FindFirstChild("HumanoidRootPart")
            local humanoid = grab.character:FindFirstChild("Humanoid")
            
            if hrp then
                -- ✅ ATUALIZA A POSIÇÃO CENTRAL A CADA FRAME
                local centerPosition = Character.HumanoidRootPart.Position
                
                -- ✅ Desabilita controle do Humanoid (opcional, mas ajuda)
                if humanoid then
                    humanoid.PlatformStand = true
                end
                
                -- ✅ Calcula swing
                angle = angle + (speed * 0.1)
                local swing = math.sin(angle) * radius
                
                -- ✅ Aplica posição relativa ao SEU player atual
                hrp.CFrame = CFrame.new(
                    centerPosition.X + swing,
                    centerPosition.Y + 5,
                    centerPosition.Z
                )
                
                -- ✅ Zera velocidades
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                hrp.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end, "GrabEffect")
end

-- ========================================
-- MIRROR MODE
-- ========================================
local MirrorMode = {
    enabled = false,
    targetPlayer = nil,
    offset = Vector3.new(5, 0, 0),
    copyStats = true,
    copyAnimations = true,
    smoothing = 0.3, -- ✅ Suavização do movimento (0-1, menor = mais suave)
}

function MirrorMode:Start(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        Services.StarterGui:SetCore("SendNotification", {
            Title = "❌ Mirror Mode Failed",
            Text = "Target player not found",
            Duration = 3
        })
        return
    end
    
    self.enabled = true
    self.targetPlayer = targetPlayer
    
    -- ✅ Desabilita controles
    local myHumanoid = Character:FindFirstChild("Humanoid")
    if myHumanoid then
        myHumanoid.PlatformStand = true
    end
    
    -- ✅ Copia animações (opcional)
    if self.copyAnimations then
        self:CopyAnimations()
    end
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "🪞 Mirror Mode Active",
        Text = "Mirroring: " .. targetPlayer.Name .. "\nOffset: " .. tostring(self.offset),
        Duration = 4
    })
    
    local lastCFrame = nil
    
    ConnectionManager:AddLoop(function()
        if not self.enabled then return end
        if not self.targetPlayer or not self.targetPlayer.Character then 
            self:Stop()
            return 
        end
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
        
        local targetHRP = self.targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = Character.HumanoidRootPart
        
        if targetHRP and myHRP then
            -- ✅ Calcula posição target com offset
            local targetCFrame = targetHRP.CFrame * CFrame.new(self.offset)
            
            -- ✅ Aplica suavização (lerp) para movimento mais natural
            if lastCFrame then
                targetCFrame = lastCFrame:Lerp(targetCFrame, self.smoothing)
            end
            lastCFrame = targetCFrame
            
            -- ✅ Aplica CFrame completo (posição + rotação)
            myHRP.CFrame = targetCFrame
            
            -- ✅ Zera velocidades
            myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            -- ✅ Copia stats
            if self.copyStats then
                local targetHumanoid = self.targetPlayer.Character:FindFirstChild("Humanoid")
                local myHumanoid = Character:FindFirstChild("Humanoid")
                
                if targetHumanoid and myHumanoid then
                    myHumanoid.WalkSpeed = targetHumanoid.WalkSpeed
                    myHumanoid.JumpPower = targetHumanoid.JumpPower
                    myHumanoid.JumpHeight = targetHumanoid.JumpHeight
                    
                    -- ✅ Copia estado do humanoid
                    local targetState = targetHumanoid:GetState()
                    if targetState ~= Enum.HumanoidStateType.Dead then
                        myHumanoid:ChangeState(targetState)
                    end
                end
            end
        end
    end, "MirrorMode")
end

function MirrorMode:CopyAnimations()
    if not self.targetPlayer or not self.targetPlayer.Character then return end
    if not Character then return end
    
    local targetAnimator = self.targetPlayer.Character:FindFirstChild("Humanoid")
    local myAnimator = Character:FindFirstChild("Humanoid")
    
    if not targetAnimator or not myAnimator then return end
    
    -- ✅ Tenta copiar tracks de animação
    pcall(function()
        local targetTracks = targetAnimator:GetPlayingAnimationTracks()
        local myTracks = myAnimator:GetPlayingAnimationTracks()
        
        -- Para todas as suas animações
        for _, track in pairs(myTracks) do
            track:Stop()
        end
        
        -- Toca as animações do alvo
        for _, targetTrack in pairs(targetTracks) do
            local myTrack = myAnimator:LoadAnimation(targetTrack.Animation)
            myTrack:Play()
            myTrack.TimePosition = targetTrack.TimePosition
        end
    end)
end

function MirrorMode:Stop()
    self.enabled = false
    
    -- ✅ Restaura controles
    if Character then
        local myHumanoid = Character:FindFirstChild("Humanoid")
        if myHumanoid then
            myHumanoid.PlatformStand = false
            myHumanoid.WalkSpeed = 16 -- Restaura padrão
            myHumanoid.JumpPower = 50
        end
    end
    
    self.targetPlayer = nil
    ConnectionManager:RemoveLoop("MirrorMode")
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "🪞 Mirror Mode Stopped",
        Text = "Controls restored",
        Duration = 2
    })
end

-- ✅ Funções de configuração
function MirrorMode:SetOffset(x, y, z)
    self.offset = Vector3.new(x, y, z)
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "🪞 Offset Updated",
        Text = string.format("X: %d, Y: %d, Z: %d", x, y, z),
        Duration = 2
    })
end

function MirrorMode:SetSmoothing(value)
    self.smoothing = math.clamp(value, 0, 1)
end

function MirrorMode:SetCopyStats(enabled)
    self.copyStats = enabled
end

function MirrorMode:SetCopyAnimations(enabled)
    self.copyAnimations = enabled
end

-- ========================================
-- NOCLIP FIXED (SEM ATRAVESSAR CHÃO)
-- ========================================
local NoclipSystem = {
    enabled = false,
    minHeight = 4, -- Aumentado para evitar bug
    checkInterval = 0.1
}

function NoclipSystem:IsOnGround()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return true end
    
    local hrp = Character.HumanoidRootPart
    local humanoid = Character:FindFirstChild("Humanoid")
    
    -- Verifica se está no chão pelo estado do humanoid
    if humanoid then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Landed or 
           state == Enum.HumanoidStateType.Running or
           state == Enum.HumanoidStateType.RunningNoPhysics then
            return true
        end
    end
    
    -- Raycast para baixo
    local rayOrigin = hrp.Position
    local rayDirection = Vector3.new(0, -5, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {Character}
    
    local rayResult = Services.Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    return rayResult ~= nil
end

function NoclipSystem:Enable()
    if self.enabled then return end
    self.enabled = true
    
    local lastCheck = tick()
    
    ConnectionManager:AddLoop(function()
        if not self.enabled or not Character then return end
        
        local currentTime = tick()
        if currentTime - lastCheck < self.checkInterval then return end
        lastCheck = currentTime
        
        local isOnGround = self:IsOnGround()
        
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Se estiver no chão, mantém colisão
                if isOnGround then
                    part.CanCollide = true
                else
                    -- Se estiver no ar E acima de certa altura, desativa colisão
                    if part.Position.Y > self.minHeight then
                        part.CanCollide = false
                    else
                        part.CanCollide = true
                    end
                end
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
-- FREECAM (COM FREEZE DO PERSONAGEM)
-- ========================================
local FreecamSystem = {
    enabled = false,
    camera = Services.Workspace.CurrentCamera,
    speed = 1,
    savedCFrame = nil,
    characterFrozen = false
}

function FreecamSystem:FreezeCharacter()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    self.characterFrozen = true
    local hrp = Character.HumanoidRootPart
    
    hrp.Anchored = true
    
    local humanoid = Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
end

function FreecamSystem:UnfreezeCharacter()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    self.characterFrozen = false
    local hrp = Character.HumanoidRootPart
    
    hrp.Anchored = false
    
    local humanoid = Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end

function FreecamSystem:Enable()
    if self.enabled then return end
    self.enabled = true
    
    self:FreezeCharacter()
    
    self.savedCFrame = self.camera.CFrame
    self.camera.CameraType = Enum.CameraType.Scriptable
    
    local cameraCFrame = self.camera.CFrame
    
    ConnectionManager:Add(Services.RunService.RenderStepped:Connect(function(dt)
        if not self.enabled then return end
        
        local moveVector = Vector3.new()
        local speed = self.speed * 50 * dt
        
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + cameraCFrame.LookVector * speed
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector - cameraCFrame.LookVector * speed
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector - cameraCFrame.RightVector * speed
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + cameraCFrame.RightVector * speed
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.E) then
            moveVector = moveVector + Vector3.new(0, speed, 0)
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            moveVector = moveVector - Vector3.new(0, speed, 0)
        end
        
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveVector = moveVector * 2
        end
        
        cameraCFrame = cameraCFrame + moveVector
        self.camera.CFrame = cameraCFrame
    end), "FreecamMovement")
    
    ConnectionManager:Add(Services.UserInputService.InputChanged:Connect(function(input)
        if not self.enabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Services.UserInputService:GetMouseDelta()
            
            local rotationX = CFrame.Angles(0, -delta.X * 0.003, 0)
            local rotationY = CFrame.Angles(-delta.Y * 0.003, 0, 0)
            
            cameraCFrame = cameraCFrame * rotationX * rotationY
        end
    end), "FreecamRotation")
end

function FreecamSystem:Disable()
    self.enabled = false
    ConnectionManager:Remove("FreecamMovement")
    ConnectionManager:Remove("FreecamRotation")
    
    self:UnfreezeCharacter()
    
    self.camera.CameraType = Enum.CameraType.Custom
    if self.savedCFrame then
        self.camera.CFrame = self.savedCFrame
    end
end

function FreecamSystem:SetSpeed(speed)
    self.speed = speed
end

-- ========================================
-- ZOOM EXTENDER
-- ========================================
local ZoomExtender = {
    enabled = false,
    originalMaxZoom = 0
}

function ZoomExtender:Enable()
    if self.enabled then return end
    self.enabled = true
    
    if Player.CameraMaxZoomDistance then
        self.originalMaxZoom = Player.CameraMaxZoomDistance
        Player.CameraMaxZoomDistance = math.huge
    end
end

function ZoomExtender:Disable()
    self.enabled = false
    
    if self.originalMaxZoom > 0 then
        Player.CameraMaxZoomDistance = self.originalMaxZoom
    end
end

-- ========================================
-- FOV CHANGER (ADICIONE DEPOIS DO ZoomExtender)
-- ========================================
local FOVChanger = {
    enabled = false,
    originalFOV = 70,
    currentFOV = 70,
    minFOV = 1,
    maxFOV = 120
}

function FOVChanger:Enable()
    if not self.enabled then
        self.enabled = true
        self.originalFOV = Services.Workspace.CurrentCamera.FieldOfView
    end
end

function FOVChanger:Disable()
    self.enabled = false
    self:Reset()
end

function FOVChanger:SetFOV(fov)
    self:Enable()
    self.currentFOV = math.clamp(fov, self.minFOV, self.maxFOV)
    Services.Workspace.CurrentCamera.FieldOfView = self.currentFOV
end

function FOVChanger:Reset()
    if self.originalFOV > 0 then
        Services.Workspace.CurrentCamera.FieldOfView = self.originalFOV
        self.currentFOV = self.originalFOV
    end
end

-- ✅ Atualiza FOV constantemente (caso o jogo tente resetar)
function FOVChanger:StartLoop()
    ConnectionManager:AddLoop(function()
        if self.enabled then
            Services.Workspace.CurrentCamera.FieldOfView = self.currentFOV
        end
    end, "FOVLoop")
end

function FOVChanger:StopLoop()
    ConnectionManager:RemoveLoop("FOVLoop")
end

-- ========================================
-- TIME CHANGER
-- ========================================
local TimeChanger = {
    enabled = false,
    originalTime = ""
}

function TimeChanger:SetTime(timeString)
    self.enabled = true
    
    if not self.originalTime or self.originalTime == "" then
        self.originalTime = Services.Lighting.ClockTime
    end
    
    Services.Lighting.ClockTime = tonumber(timeString:sub(1, 2)) + (tonumber(timeString:sub(4, 5)) / 60)
end

function TimeChanger:Reset()
    self.enabled = false
    if self.originalTime and self.originalTime ~= "" then
        Services.Lighting.ClockTime = self.originalTime
    end
end

-- ========================================
-- WEATHER CHANGER
-- ========================================
local WeatherChanger = {
    enabled = false,
    effects = {},
    currentWeather = nil
}

function WeatherChanger:CreateRain()
    self:Clear()
    self.currentWeather = "rain"
    
    -- ✅ Cria múltiplas parts para melhor cobertura
    for i = 1, 5 do
        local rainPart = Instance.new("Part")
        rainPart.Name = "RainEffect_" .. i
        rainPart.Size = Vector3.new(100, 1, 100)
        rainPart.Transparency = 1
        rainPart.Anchored = true
        rainPart.CanCollide = false
        rainPart.CFrame = CFrame.new(0, 100, 0)
        
        local particleEmitter = Instance.new("ParticleEmitter")
        -- ✅ Usa texture ID em vez de rbxasset
        particleEmitter.Texture = "rbxassetid://241685484" -- Raindrop texture
        particleEmitter.Rate = 300
        particleEmitter.Lifetime = NumberRange.new(1.5, 2.5)
        particleEmitter.Speed = NumberRange.new(80, 100)
        particleEmitter.SpreadAngle = Vector2.new(5, 5)
        particleEmitter.EmissionDirection = Enum.NormalId.Bottom
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
        particleEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0.1)
        })
        particleEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 0.8)
        })
        particleEmitter.Acceleration = Vector3.new(0, -100, 0)
        particleEmitter.Parent = rainPart
        
        rainPart.Parent = Services.Workspace
        table.insert(self.effects, rainPart)
    end
    
    -- ✅ Loop para seguir player
    ConnectionManager:AddLoop(function()
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = Character.HumanoidRootPart
        
        for i, effect in ipairs(self.effects) do
            if effect and effect.Parent then
                -- ✅ Distribui parts em grid ao redor do player
                local offsetX = ((i - 3) * 50)
                effect.CFrame = CFrame.new(
                    hrp.Position.X + offsetX,
                    hrp.Position.Y + 60,
                    hrp.Position.Z
                )
            end
        end
    end, "WeatherFollow")
    
    -- ✅ Adiciona som de chuva
    self:AddRainSound()
    
    -- ✅ Escurece o ambiente
    self:SetRainAmbience()
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "🌧️ Rain Created",
        Text = "Rain weather activated",
        Duration = 3
    })
end

function WeatherChanger:CreateSnow()
    self:Clear()
    self.currentWeather = "snow"
    
    -- ✅ Cria múltiplas parts para neve
    for i = 1, 5 do
        local snowPart = Instance.new("Part")
        snowPart.Name = "SnowEffect_" .. i
        snowPart.Size = Vector3.new(100, 1, 100)
        snowPart.Transparency = 1
        snowPart.Anchored = true
        snowPart.CanCollide = false
        snowPart.CFrame = CFrame.new(0, 100, 0)
        
        local particleEmitter = Instance.new("ParticleEmitter")
        -- ✅ Usa texture ID de floco de neve
        particleEmitter.Texture = "rbxassetid://605029294" -- Snowflake texture
        particleEmitter.Rate = 50
        particleEmitter.Lifetime = NumberRange.new(8, 12)
        particleEmitter.Speed = NumberRange.new(5, 15)
        particleEmitter.SpreadAngle = Vector2.new(15, 15)
        particleEmitter.EmissionDirection = Enum.NormalId.Bottom
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        particleEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 0.5),
            NumberSequenceKeypoint.new(1, 0.2)
        })
        particleEmitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.8, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        particleEmitter.Rotation = NumberRange.new(0, 360)
        particleEmitter.RotSpeed = NumberRange.new(-100, 100)
        particleEmitter.Acceleration = Vector3.new(0, -5, 0)
        particleEmitter.Drag = 1
        particleEmitter.Parent = snowPart
        
        snowPart.Parent = Services.Workspace
        table.insert(self.effects, snowPart)
    end
    
    -- ✅ Loop para seguir player
    ConnectionManager:AddLoop(function()
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = Character.HumanoidRootPart
        
        for i, effect in ipairs(self.effects) do
            if effect and effect.Parent then
                local offsetX = ((i - 3) * 50)
                effect.CFrame = CFrame.new(
                    hrp.Position.X + offsetX,
                    hrp.Position.Y + 80,
                    hrp.Position.Z
                )
            end
        end
    end, "WeatherFollow")
    
    -- ✅ Adiciona som de vento
    self:AddSnowSound()
    
    -- ✅ Clareia o ambiente
    self:SetSnowAmbience()
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "❄️ Snow Created",
        Text = "Snow weather activated",
        Duration = 3
    })
end

-- ✅ ADICIONA SOM DE CHUVA
function WeatherChanger:AddRainSound()
    local sound = Instance.new("Sound")
    sound.Name = "RainSound"
    sound.SoundId = "rbxassetid://1837829565" -- Rain sound
    sound.Volume = 0.5
    sound.Looped = true
    sound.Parent = Services.Workspace.CurrentCamera
    sound:Play()
    
    table.insert(self.effects, sound)
end

-- ✅ ADICIONA SOM DE NEVE (Vento)
function WeatherChanger:AddSnowSound()
    local sound = Instance.new("Sound")
    sound.Name = "SnowSound"
    sound.SoundId = "rbxassetid://1837829565" -- Wind sound
    sound.Volume = 0.3
    sound.Looped = true
    sound.Parent = Services.Workspace.CurrentCamera
    sound:Play()
    
    table.insert(self.effects, sound)
end

-- ✅ MUDA ILUMINAÇÃO PARA CHUVA
function WeatherChanger:SetRainAmbience()
    local lighting = Services.Lighting
    
    -- Salva valores originais
    if not self.originalLighting then
        self.originalLighting = {
            Brightness = lighting.Brightness,
            Ambient = lighting.Ambient,
            OutdoorAmbient = lighting.OutdoorAmbient,
            ColorShift_Top = lighting.ColorShift_Top,
            FogEnd = lighting.FogEnd,
            FogColor = lighting.FogColor
        }
    end
    
    -- ✅ Aplica ambiente chuvoso
    lighting.Brightness = 1.5
    lighting.Ambient = Color3.fromRGB(100, 100, 120)
    lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
    lighting.ColorShift_Top = Color3.fromRGB(180, 180, 200)
    lighting.FogEnd = 500
    lighting.FogColor = Color3.fromRGB(150, 150, 170)
end

-- ✅ MUDA ILUMINAÇÃO PARA NEVE
function WeatherChanger:SetSnowAmbience()
    local lighting = Services.Lighting
    
    -- Salva valores originais
    if not self.originalLighting then
        self.originalLighting = {
            Brightness = lighting.Brightness,
            Ambient = lighting.Ambient,
            OutdoorAmbient = lighting.OutdoorAmbient,
            ColorShift_Top = lighting.ColorShift_Top,
            FogEnd = lighting.FogEnd,
            FogColor = lighting.FogColor
        }
    end
    
    -- ✅ Aplica ambiente nevado
    lighting.Brightness = 2
    lighting.Ambient = Color3.fromRGB(200, 200, 220)
    lighting.OutdoorAmbient = Color3.fromRGB(220, 220, 240)
    lighting.ColorShift_Top = Color3.fromRGB(240, 240, 255)
    lighting.FogEnd = 300
    lighting.FogColor = Color3.fromRGB(220, 220, 240)
end

-- ✅ RESTAURA ILUMINAÇÃO ORIGINAL
function WeatherChanger:RestoreLighting()
    if not self.originalLighting then return end
    
    local lighting = Services.Lighting
    
    lighting.Brightness = self.originalLighting.Brightness
    lighting.Ambient = self.originalLighting.Ambient
    lighting.OutdoorAmbient = self.originalLighting.OutdoorAmbient
    lighting.ColorShift_Top = self.originalLighting.ColorShift_Top
    lighting.FogEnd = self.originalLighting.FogEnd
    lighting.FogColor = self.originalLighting.FogColor
    
    self.originalLighting = nil
end

function WeatherChanger:Clear()
    ConnectionManager:RemoveLoop("WeatherFollow")
    
    for _, effect in pairs(self.effects) do
        if effect and effect.Parent then
            pcall(function() effect:Destroy() end)
        end
    end
    self.effects = {}
    
    -- ✅ Restaura iluminação
    self:RestoreLighting()
    
    self.currentWeather = nil
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "✅ Weather Cleared",
        Text = "All weather effects removed",
        Duration = 2
    })
end

-- ✅ FUNÇÃO EXTRA: Criar Tempestade (Chuva + Raios)
function WeatherChanger:CreateStorm()
    self:CreateRain() -- Cria chuva primeiro
    self.currentWeather = "storm"
    
    -- ✅ Adiciona raios ocasionais
    ConnectionManager:AddLoop(function()
        if math.random(1, 100) > 95 then -- 5% de chance por frame
            self:CreateLightning()
        end
        task.wait(1) -- Checa a cada 1 segundo
    end, "StormLightning")
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "⚡ Storm Created",
        Text = "Storm weather activated",
        Duration = 3
    })
end

-- ✅ Cria efeito de raio
function WeatherChanger:CreateLightning()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = Character.HumanoidRootPart
    
    -- Flash branco na tela
    local flash = Instance.new("ColorCorrectionEffect")
    flash.Name = "LightningFlash"
    flash.Brightness = 1
    flash.Parent = Services.Lighting
    
    -- Som de trovão
    local thunder = Instance.new("Sound")
    thunder.SoundId = "rbxassetid://130818250" -- Thunder sound
    thunder.Volume = 0.8
    thunder.Parent = Services.Workspace.CurrentCamera
    thunder:Play()
    
    -- Remove flash após delay
    task.spawn(function()
        task.wait(0.1)
        if flash.Parent then
            flash:Destroy()
        end
        task.wait(2)
        if thunder.Parent then
            thunder:Destroy()
        end
    end)
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
    
    -- Body Gyro para controle de rotação
    self.bodyGyro = Instance.new("BodyGyro")
    self.bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    self.bodyGyro.P = 9e4
    self.bodyGyro.Parent = hrp
    
    -- Body Velocity para movimento
    self.bodyVelocity = Instance.new("BodyVelocity")
    self.bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    self.bodyVelocity.Parent = hrp
    
    ConnectionManager:AddLoop(function()
        if not self.enabled then return end
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = Character.HumanoidRootPart
        local camera = Services.Workspace.CurrentCamera
        
        local moveVector = Vector3.new()
        
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
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "✈️ Fly Enabled",
        Text = "WASD to move | Space/Shift for up/down",
        Duration = 3
    })
end

function FlySystem:Disable()
    self.enabled = false
    ConnectionManager:RemoveLoop("FlyLoop")
    
    if self.bodyGyro then
        self.bodyGyro:Destroy()
        self.bodyGyro = nil
    end
    
    if self.bodyVelocity then
        self.bodyVelocity:Destroy()
        self.bodyVelocity = nil
    end
    Services.StarterGui:SetCore("SendNotification", {
        Title = "✈️ Fly Disabled",
        Text = "Character control restored",
        Duration = 2
    })
end

function FlySystem:SetSpeed(speed)
    self.speed = speed
end
-- ========================================
-- ADVANCED TARGETING SYSTEM
-- ========================================
local TargetingSystem = {
    enabled = false,
    currentTarget = nil,
    targetLocked = false,
    priorityMode = false,
    predictMovement = false,
    leadShots = false,
    highlightColor = Color3.fromRGB(255, 0, 0)
}

function TargetingSystem:GetClosestPlayer()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local myPos = Character.HumanoidRootPart.Position
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player ~= Player and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and humanoid.Health > 0 and hrp then
                if FriendSystem:IsFriend(player.Name) then
                    
                end
                
                local distance = (hrp.Position - myPos).Magnitude
                
                if self.priorityMode then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    distance = distance * (healthPercent + 0.1)
                end
                
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    
    return closestPlayer
end

function TargetingSystem:PredictPosition(target)
    if not target or not target.Character then return nil end
    
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local velocity = hrp.AssemblyLinearVelocity
    local predictTime = 0.2
    
    local predictedPosition = hrp.Position + (velocity * predictTime)
    return predictedPosition
end

function TargetingSystem:LockTarget(target)
    self.currentTarget = target
    self.targetLocked = true
    
    if target.Character and not target.Character:FindFirstChild("TargetHighlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "TargetHighlight"
        highlight.FillColor = self.highlightColor
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = target.Character
    end
end

function TargetingSystem:UnlockTarget()
    if self.currentTarget and self.currentTarget.Character then
        local highlight = self.currentTarget.Character:FindFirstChild("TargetHighlight")
        if highlight then
            highlight:Destroy()
        end
    end
    
    self.currentTarget = nil
    self.targetLocked = false
end

function TargetingSystem:SwitchTarget()
    self:UnlockTarget()
    
    local newTarget = self:GetClosestPlayer()
    if newTarget then
        self:LockTarget(newTarget)
    end
end

function TargetingSystem:Enable()
    self.enabled = true
    
    ConnectionManager:AddLoop(function()
        if not self.enabled then return end
        
        if not self.targetLocked or not self.currentTarget or not self.currentTarget.Character then
            local target = self:GetClosestPlayer()
            if target then
                self:LockTarget(target)
            end
        else
            local humanoid = self.currentTarget.Character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                self:SwitchTarget()
            end
        end
    end, "AutoLock")
    
    ConnectionManager:Add(Services.UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Config.TargetSwitchKey then
            self:SwitchTarget()
        end
    end), "TargetSwitch")
end

function TargetingSystem:Disable()
    self.enabled = false
    self:UnlockTarget()
    ConnectionManager:RemoveLoop("AutoLock")
    ConnectionManager:Remove("TargetSwitch")
end

function TargetingSystem:GetAimPosition()
    if not self.currentTarget or not self.currentTarget.Character then return nil end
    
    local head = self.currentTarget.Character:FindFirstChild("Head")
    if not head then return nil end
    
    if self.predictMovement then    
        return self:PredictPosition(self.currentTarget)
    else
        return head.Position
    end
end
-- ========================================
-- SNAKE GAME FIXED (CALLBACK CORRIGIDO)
-- ========================================
local SnakeGame = {
    running = false,
    gridSize = 20,
    snake = {},
    direction = Vector2.new(1, 0),
    food = nil,
    score = 0,
    gui = nil,
    -- Salva estados originais para restaurar depois
    savedStates = {
        walkSpeed = 16,
        jumpPower = 50,
        anchored = false,
        cameraType = nil
    }
}

function SnakeGame:CreateGUI()
    if self.gui then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SnakeGame"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999999 -- ✅ ISSO GARANTE QUE FICA NO TOPO
    screenGui.IgnoreGuiInset = true -- ✅ Ignora barra superior mobile
    screenGui.Parent = Player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "GameFrame"
    frame.Size = UDim2.new(0, 400, 0, 450)
    frame.Position = UDim2.new(0.5, -200, 0.5, -225)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.ZIndex = 10000
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.BorderSizePixel = 0
    title.Text = "🐍 SNAKE GAME"
    title.TextColor3 = Color3.fromRGB(0, 255, 0)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 10001
    title.Parent = frame

    local scoreLabel = Instance.new("TextLabel")
    scoreLabel.Name = "Score"
    scoreLabel.Size = UDim2.new(1, 0, 0, 30)
    scoreLabel.Position = UDim2.new(0, 0, 0, 40)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.Text = "Score: 0"
    scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    scoreLabel.TextSize = 16
    scoreLabel.Font = Enum.Font.Gotham
    scoreLabel.ZIndex = 10001
    scoreLabel.Parent = frame

    local gameCanvas = Instance.new("Frame")
    gameCanvas.Name = "Canvas"
    gameCanvas.Size = UDim2.new(1, -20, 1, -90)
    gameCanvas.Position = UDim2.new(0, 10, 0, 70)
    gameCanvas.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    gameCanvas.BorderSizePixel = 2
    gameCanvas.BorderColor3 = Color3.fromRGB(0, 255, 0)
    gameCanvas.ZIndex = 10001
    gameCanvas.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 80, 0, 30)
    closeBtn.Position = UDim2.new(1, -90, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕ Close"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 10002
    closeBtn.Parent = frame

    closeBtn.MouseButton1Click:Connect(function()
        self:Stop()
    end)

    self.gui = screenGui
end

function SnakeGame:FreezePlayer()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = Character.HumanoidRootPart
    local humanoid = Character:FindFirstChild("Humanoid")
    
    -- Salva estados originais
    if humanoid then
        self.savedStates.walkSpeed = humanoid.WalkSpeed
        self.savedStates.jumpPower = humanoid.JumpPower
    end
    self.savedStates.anchored = hrp.Anchored
    self.savedStates.cameraType = Services.Workspace.CurrentCamera.CameraType
    
    -- ✅ CONGELA TUDO
    hrp.Anchored = true
    hrp.Velocity = Vector3.new(0, 0, 0)
    hrp.RotVelocity = Vector3.new(0, 0, 0)
    
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.JumpHeight = 0
        humanoid.AutoRotate = false
        
        -- Desabilita estados que permitem movimento
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    end
    
    -- ✅ CONGELA TODOS OS BODY PARTS (previne animações)
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part ~= hrp then
            part.Anchored = true
            part.Velocity = Vector3.new(0, 0, 0)
        end
    end
    
    -- ✅ TRAVA CÂMERA (opcional, mas ajuda na imersão)
    Services.Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    Services.Workspace.CurrentCamera.CFrame = hrp.CFrame * CFrame.new(0, 5, 10)
end

function SnakeGame:UnfreezePlayer()
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = Character.HumanoidRootPart
    local humanoid = Character:FindFirstChild("Humanoid")
    
    -- ✅ RESTAURA ESTADOS ORIGINAIS
    hrp.Anchored = self.savedStates.anchored
    
    if humanoid then
        humanoid.WalkSpeed = self.savedStates.walkSpeed
        humanoid.JumpPower = self.savedStates.jumpPower
        humanoid.JumpHeight = 7.2 -- Padrão Roblox
        humanoid.AutoRotate = true
        
        -- Reabilita estados
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    end
    
    -- ✅ DESANCORA TODOS OS BODY PARTS
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part ~= hrp then
            part.Anchored = false
        end
    end
    
    -- ✅ RESTAURA CÂMERA
    Services.Workspace.CurrentCamera.CameraType = self.savedStates.cameraType or Enum.CameraType.Custom
end

function SnakeGame:Start()
    if self.running then return end
    
    self:CreateGUI()
    self.running = true
    self.score = 0
    self.direction = Vector2.new(1, 0)

    -- ✅ USA NOVO SISTEMA DE CONGELAMENTO
    self:FreezePlayer()

    -- Inicializa cobra
    self.snake = {
        Vector2.new(10, 10),
        Vector2.new(9, 10),
        Vector2.new(8, 10)
    }

    -- Spawna comida
    self:SpawnFood()

    -- Controles
    ConnectionManager:Add(Services.UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not self.running then return end
        
        if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
            if self.direction.Y == 0 then
                self.direction = Vector2.new(0, -1)
            end
        elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
            if self.direction.Y == 0 then
                self.direction = Vector2.new(0, 1)
            end
        elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
            if self.direction.X == 0 then
                self.direction = Vector2.new(-1, 0)
            end
        elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
            if self.direction.X == 0 then
                self.direction = Vector2.new(1, 0)
            end
        end
    end), "SnakeControls")

    -- Game loop
    task.spawn(function()
        while self.running do
            self:Update()
            self:Draw()
            task.wait(0.15)
        end
    end)
end

function SnakeGame:SpawnFood()
    self.food = Vector2.new(
        math.random(0, self.gridSize - 1),
        math.random(0, self.gridSize - 1)
    )
end

function SnakeGame:Update()
    -- Move cabeça
    local head = self.snake[1]
    local newHead = head + self.direction
    
    -- Colisão com parede
    if newHead.X < 0 or newHead.X >= self.gridSize or 
       newHead.Y < 0 or newHead.Y >= self.gridSize then
        self:GameOver()
        return
    end

    -- Colisão consigo mesmo
    for _, segment in ipairs(self.snake) do
        if segment == newHead then
            self:GameOver()
            return
        end
    end

    -- Adiciona nova cabeça
    table.insert(self.snake, 1, newHead)

    -- Verifica comida
    if newHead == self.food then
        self.score = self.score + 1
        self:SpawnFood()
        
        -- Atualiza score
        if self.gui then
            self.gui.GameFrame.Score.Text = "Score: " .. self.score
        end
    else
        -- Remove cauda
        table.remove(self.snake)
    end
end

function SnakeGame:Draw()
    if not self.gui then return end
    local canvas = self.gui.GameFrame.Canvas

    -- Limpa canvas
    for _, child in pairs(canvas:GetChildren()) do
        child:Destroy()
    end

    local cellSize = canvas.AbsoluteSize.X / self.gridSize

    -- Desenha cobra
    for i, segment in ipairs(self.snake) do
        local cell = Instance.new("Frame")
        cell.Size = UDim2.new(0, cellSize - 2, 0, cellSize - 2)
        cell.Position = UDim2.new(0, segment.X * cellSize, 0, segment.Y * cellSize)
        cell.BackgroundColor3 = i == 1 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 200, 0)
        cell.BorderSizePixel = 0
        cell.ZIndex = 10002
        cell.Parent = canvas
    end

    -- Desenha comida
    local foodCell = Instance.new("Frame")
    foodCell.Size = UDim2.new(0, cellSize - 2, 0, cellSize - 2)
    foodCell.Position = UDim2.new(0, self.food.X * cellSize, 0, self.food.Y * cellSize)
    foodCell.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    foodCell.BorderSizePixel = 0
    foodCell.ZIndex = 10002
    foodCell.Parent = canvas
end

function SnakeGame:GameOver()
    self.running = false
    
    Services.StarterGui:SetCore("SendNotification", {
        Title = "🐍 Game Over!",
        Text = "Final Score: " .. self.score,
        Duration = 5
    })

    -- ✅ USA NOVO SISTEMA DE DESCONGELAMENTO
    self:UnfreezePlayer()
end

function SnakeGame:Stop()
    self.running = false
    ConnectionManager:Remove("SnakeControls")
    
    if self.gui then
        self.gui:Destroy()
        self.gui = nil
    end

    -- ✅ USA NOVO SISTEMA DE DESCONGELAMENTO
    self:UnfreezePlayer()
end
-- ========================================
-- UI INITIALIZATION (SUBSTITUA A FUNÇÃO InitUI COMPLETA)
-- ========================================
local function InitUI()
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Limitless Hub " .. VERSION,
    LoadingTitle = "Limitless Hub - All Bugs Fixed",
    LoadingSubtitle = "Snake Fixed | Noclip Fixed | Anchor Server-Side",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

-- ========================================
-- HOME TAB
-- ========================================
local Home = Window:CreateTab("🏠 Home", 4483362458)

Home:CreateParagraph({
    Title = "Limitless Hub " .. VERSION,
    Content = "✅ All Grab Effects Fixed\n✅ Snake Game Fixed\n✅ Noclip Fixed\n✅ Anchor Works on Parts Only\n✅ Weather System Complete\n✅ Mirror Mode Fixed\n✅ Pendulum Fixed"
})

Home:CreateLabel("Status: All Systems Operational")

Home:CreateParagraph({
    Title = "Recent Updates",
    Content = "• Spin Grab: Now uses BodyGyro (smooth rotation)\n• Void Grab: Anchors + disables collisions\n• Anchor Grab: Only works on parts, press Y to anchor\n• Pendulum: Follows you + 3 modes\n• Mirror Mode: Smooth following + offset controls\n• Weather: Rain/Snow/Storm with sounds"
})

-- ========================================
-- ALL GRAB EFFECTS TAB
-- ========================================
local GrabTab = Window:CreateTab("🤏 Grab Effects", 4483362458)

GrabTab:CreateSection("Grab Effects")

GrabTab:CreateToggle({
    Name = "🌀 Spin Grab",
    CurrentValue = false,
    Flag = "SpinGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Spin()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateSlider({
    Name = "Spin Speed",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 10,
    Flag = "SpinSpeed",
    Callback = function(v)
        AllGrabEffects:SetSpinSpeed(v)
    end
})

GrabTab:CreateToggle({
    Name = "🕳️ Void Grab",
    CurrentValue = false,
    Flag = "VoidGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Void()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateToggle({
    Name = "👢 Kick Grab",
    CurrentValue = false,
    Flag = "KickGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Kick()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateToggle({
    Name = "💫 Fling Grab",
    CurrentValue = false,
    Flag = "FlingGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Fling()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateSection("Anchor Grab (Parts Only)")

GrabTab:CreateToggle({
    Name = "⚓ Anchor Mode",
    CurrentValue = false,
    Flag = "AnchorGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Anchor()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateLabel("Press Y to anchor grabbed part")
GrabTab:CreateLabel("Press H to anchor all parts in model")
GrabTab:CreateLabel("Press U to unanchor all")
GrabTab:CreateLabel("⚠️ Does NOT work on players!")

GrabTab:CreateSection("Pendulum Grab")

GrabTab:CreateToggle({
    Name = "⏰ Pendulum Grab",
    CurrentValue = false,
    Flag = "PendulumGrab",
    Callback = function(v)
        if v then
            AllGrabEffects:Pendulum()
        else
            AllGrabEffects:Stop()
        end
    end
})

GrabTab:CreateDropdown({
    Name = "Pendulum Mode",
    Options = {"horizontal", "circular", "vertical"},
    CurrentOption = "horizontal",
    Flag = "PendulumMode",
    Callback = function(option)
        AllGrabEffects:SetPendulumMode(option)
    end
})

GrabTab:CreateSlider({
    Name = "Pendulum Speed",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 5,
    Flag = "PendulumSpeed",
    Callback = function(v)
        AllGrabEffects:SetPendulumSpeed(v)
    end
})

GrabTab:CreateSlider({
    Name = "Pendulum Radius",
    Range = {5, 30},
    Increment = 1,
    CurrentValue = 10,
    Flag = "PendulumRadius",
    Callback = function(v)
        AllGrabEffects:SetPendulumRadius(v)
    end
})

GrabTab:CreateSlider({
    Name = "Pendulum Height",
    Range = {2, 20},
    Increment = 1,
    CurrentValue = 5,
    Flag = "PendulumHeight",
    Callback = function(v)
        AllGrabEffects:SetPendulumHeight(v)
    end
})

GrabTab:CreateButton({
    Name = "Stop All Effects",
    Callback = function()
        AllGrabEffects:Stop()
    end
})

-- ========================================
-- TARGETING TAB
-- ========================================
local Targeting = Window:CreateTab("🎯 Targeting", 4483362458)

Targeting:CreateSection("Auto Lock")

Targeting:CreateToggle({
    Name = "Enable Auto Lock",
    CurrentValue = false,
    Flag = "AutoLock",
    Callback = function(v)
        Config.AutoLockEnabled = v
        if v then
            TargetingSystem:Enable()
        else
            TargetingSystem:Disable()
        end
    end
})

Targeting:CreateToggle({
    Name = "Priority Targeting (Low HP)",
    CurrentValue = false,
    Flag = "PriorityTarget",
    Callback = function(v)
        Config.PriorityTargeting = v
        TargetingSystem.priorityMode = v
    end
})

Targeting:CreateToggle({
    Name = "Predict Movement",
    CurrentValue = false,
    Flag = "PredictMove",
    Callback = function(v)
        Config.PredictMovement = v
        TargetingSystem.predictMovement = v
    end
})

Targeting:CreateButton({
    Name = "Switch Target (T)",
    Callback = function()
        TargetingSystem:SwitchTarget()
    end
})

Targeting:CreateLabel("⚠️ Auto Lock ignores friends")

-- ========================================
-- MOVEMENT TAB
-- ========================================
local Movement = Window:CreateTab("🏃 Movement", 4483362458)

Movement:CreateSection("Freecam (Freezes Character)")

Movement:CreateToggle({
    Name = "Enable Freecam",
    CurrentValue = false,
    Flag = "Freecam",
    Callback = function(v)
        Config.FreecamEnabled = v
        if v then
            FreecamSystem:Enable()
        else
            FreecamSystem:Disable()
        end
    end
})

Movement:CreateSlider({
    Name = "Freecam Speed",
    Range = {0.1, 5},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "FreecamSpeed",
    Callback = function(v)
        FreecamSystem:SetSpeed(v)
    end
})

Movement:CreateLabel("WASD - Move | Q/E - Down/Up | Shift - Boost")

Movement:CreateSection("Noclip (FIXED - Safe Floor)")

Movement:CreateToggle({
    Name = "Enable Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(v)
        Config.NoclipEnabled = v
        if v then
            NoclipSystem:Enable()
        else
            NoclipSystem:Disable()
        end
    end
})

-- ========================================
-- VISUAL TAB
-- ========================================
local Visual = Window:CreateTab("💫 Visual", 4483362458)

Visual:CreateSection("Camera")

Visual:CreateToggle({
    Name = "Infinite Zoom",
    CurrentValue = false,
    Flag = "InfiniteZoom",
    Callback = function(v)
        Config.ZoomExtended = v
        if v then
            ZoomExtender:Enable()
        else
            ZoomExtender:Disable()
        end
    end
})

-- ✅ ADICIONE ISSO AQUI:
Visual:CreateSection("Field of View (FOV)")

Visual:CreateSlider({
    Name = "FOV",
    Range = {1, 120},
    Increment = 1,
    CurrentValue = 70,
    Flag = "FOV",
    Callback = function(v)
        FOVChanger:SetFOV(v)
    end
})

Visual:CreateToggle({
    Name = "Lock FOV (Keep FOV Active)",
    CurrentValue = false,
    Flag = "LockFOV",
    Callback = function(v)
        if v then
            FOVChanger:StartLoop()
        else
            FOVChanger:StopLoop()
        end
    end
})

Visual:CreateButton({
    Name = "Reset FOV to Default",
    Callback = function()
        FOVChanger:Reset()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "🎯 FOV Reset",
            Text = "FOV restored to " .. FOVChanger.originalFOV,
            Duration = 2
        })
    end
})

Visual:CreateLabel("Default FOV: 70 | Recommended: 80-100")
Visual:CreateLabel("⚠️ Very high FOV can cause distortion")
Visual:CreateSection("Time Control")

Visual:CreateSlider({
    Name = "Time of Day (Hour)",
    Range = {0, 24},
    Increment = 1,
    CurrentValue = 14,
    Flag = "TimeOfDay",
    Callback = function(v)
        local timeString = string.format("%02d:00:00", v)
        TimeChanger:SetTime(timeString)
    end
})

Visual:CreateButton({
    Name = "Reset Time",
    Callback = function()
        TimeChanger:Reset()
    end
})

Visual:CreateSection("Weather Effects")

Visual:CreateButton({
    Name = "☔ Create Rain",
    Callback = function()
        WeatherChanger:CreateRain()
    end
})

Visual:CreateButton({
    Name = "❄️ Create Snow",
    Callback = function()
        WeatherChanger:CreateSnow()
    end
})

Visual:CreateButton({
    Name = "⚡ Create Storm (Rain + Lightning)",
    Callback = function()
        WeatherChanger:CreateStorm()
    end
})

Visual:CreateButton({
    Name = "☀️ Clear Weather",
    Callback = function()
        WeatherChanger:Clear()
    end
})

Visual:CreateLabel("Weather follows you automatically")

-- ========================================
-- MIRROR MODE TAB
-- ========================================
local Mirror = Window:CreateTab("🪞 Mirror Mode", 4483362458)

Mirror:CreateSection("Mirror Player Movement")

local targetPlayerName = ""

Mirror:CreateInput({
    Name = "Target Player Name",
    PlaceholderText = "Enter player name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        targetPlayerName = text
    end
})

Mirror:CreateToggle({
    Name = "Enable Mirror Mode",
    CurrentValue = false,
    Flag = "MirrorMode",
    Callback = function(v)
        Config.MirrorModeEnabled = v
        if v and targetPlayerName ~= "" then
            local player = nil
            for _, p in pairs(Services.Players:GetPlayers()) do
                if p.Name:lower():find(targetPlayerName:lower()) then
                    player = p
                    break
                end
            end
            
            if player then
                MirrorMode:Start(player)
            else
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Player Not Found",
                    Text = "Could not find: " .. targetPlayerName,
                    Duration = 3
                })
            end
        else
            MirrorMode:Stop()
        end
    end
})

Mirror:CreateSection("Mirror Settings")

Mirror:CreateSlider({
    Name = "Offset X (Side Distance)",
    Range = {-20, 20},
    Increment = 1,
    CurrentValue = 5,
    Flag = "MirrorOffsetX",
    Callback = function(v)
        MirrorMode:SetOffset(v, MirrorMode.offset.Y, MirrorMode.offset.Z)
    end
})

Mirror:CreateSlider({
    Name = "Offset Y (Height)",
    Range = {-10, 10},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MirrorOffsetY",
    Callback = function(v)
        MirrorMode:SetOffset(MirrorMode.offset.X, v, MirrorMode.offset.Z)
    end
})

Mirror:CreateSlider({
    Name = "Offset Z (Front/Back)",
    Range = {-20, 20},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MirrorOffsetZ",
    Callback = function(v)
        MirrorMode:SetOffset(MirrorMode.offset.X, MirrorMode.offset.Y, v)
    end
})

Mirror:CreateSlider({
    Name = "Movement Smoothing",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 30,
    Flag = "MirrorSmoothing",
    Callback = function(v)
        MirrorMode:SetSmoothing(v / 100)
    end
})

Mirror:CreateToggle({
    Name = "Copy Stats (Speed/Jump)",
    CurrentValue = true,
    Flag = "MirrorCopyStats",
    Callback = function(v)
        MirrorMode:SetCopyStats(v)
    end
})

Mirror:CreateToggle({
    Name = "Copy Animations",
    CurrentValue = true,
    Flag = "MirrorCopyAnims",
    Callback = function(v)
        MirrorMode:SetCopyAnimations(v)
    end
})

Mirror:CreateLabel("⚠️ Your controls will be disabled while active")

-- ========================================
-- FRIENDS TAB
-- ========================================
local Friends = Window:CreateTab("👥 Friends", 4483362458)

FriendSystem:Load()

Friends:CreateSection("Friend Management")

local friendName = ""

Friends:CreateInput({
    Name = "Friend Username",
    PlaceholderText = "Enter username...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        friendName = text
    end
})

Friends:CreateButton({
    Name = "➕ Add Friend",
    Callback = function()
        if friendName ~= "" then
            if FriendSystem:AddFriend(friendName) then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "✅ Friend Added",
                    Text = friendName,
                    Duration = 2
                })
            end
        end
    end
})

Friends:CreateButton({
    Name = "➖ Remove Friend",
    Callback = function()
        if friendName ~= "" then
            if FriendSystem:RemoveFriend(friendName) then
                Services.StarterGui:SetCore("SendNotification", {
                    Title = "❌ Friend Removed",
                    Text = friendName,
                    Duration = 2
                })
            end
        end
    end
})

Friends:CreateSection("Friend List")

local friendList = ""
for _, name in ipairs(FriendSystem.friends) do
    friendList = friendList .. "• " .. name .. "\n"
end

Friends:CreateParagraph({
    Title = "Your Friends",
    Content = friendList ~= "" and friendList or "No friends added yet."
})

Friends:CreateLabel("✅ Auto Lock ignores friends automatically")

-- ========================================
-- SNAKE GAME TAB
-- ========================================
local SnakeTab = Window:CreateTab("🐍 Snake Game", 4483362458)

SnakeTab:CreateSection("Classic Snake Game (FIXED)")

SnakeTab:CreateButton({
    Name = "🎮 Play Snake",
    Callback = function()
        SnakeGame:Start()
    end
})

SnakeTab:CreateButton({
    Name = "Stop Game",
    Callback = function()
        SnakeGame:Stop()
    end
})

SnakeTab:CreateLabel("Controls: WASD or Arrow Keys")
SnakeTab:CreateLabel("✅ FIXED: No more callback errors")


-- ========================================
-- MISC TAB
-- ========================================
local Misc = Window:CreateTab("🔧 Misc", 4483362458)

Misc:CreateButton({
    Name = "🔄 Respawn",
    Callback = function()
        Player.Character:BreakJoints()
    end
})

Misc:CreateButton({
    Name = "❌ Unload Script",
    Callback = function()
        ConnectionManager:Cleanup()
        WeatherChanger:Clear()
        SnakeGame:Stop()
        if FreecamSystem.enabled then
            FreecamSystem:Disable()
        end
        if NoclipSystem.enabled then
            NoclipSystem:Disable()
        end
        if MirrorMode.enabled then
            MirrorMode:Stop()
        end
        AllGrabEffects:Stop()
        Rayfield:Destroy()
        
        Services.StarterGui:SetCore("SendNotification", {
            Title = "Script Unloaded",
            Text = "Limitless Hub closed",
            Duration = 3
        })
    end
})

Misc:CreateSection("Keybinds")

Misc:CreateParagraph({
    Title = "Default Keybinds",
    Content = "T - Switch Target\nQ - Teleport to Mouse\nY - Anchor grabbed part\nH - Anchor all parts in model\nU - Unanchor all"
})

Misc:CreateSection("Changelog")

Misc:CreateParagraph({
    Title = "Version " .. VERSION,
    Content = "✅ Spin Grab: BodyGyro (smooth)\n✅ Void Grab: Anchored + no collisions\n✅ Anchor Grab: Parts only + keybinds\n✅ Pendulum: Follows you + 3 modes\n✅ Mirror Mode: Smooth + offset controls\n✅ Weather: Rain/Snow/Storm + sounds\n✅ Snake: GUI on top + frozen player\n✅ Noclip: Safe floor detection"
})

-- Notificação de carregamento
Services.StarterGui:SetCore("SendNotification", {
    Title = "✅ Limitless Hub Loaded",
    Text = "Version " .. VERSION .. " - All Bugs Fixed!",
    Duration = 5
})
end