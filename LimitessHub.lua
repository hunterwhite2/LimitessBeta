--[[
    R3d Hub v6.1
    by R3dL3ss
    - Removido: Ghost, Invisible, Wings, Trail próprio.
    - Adicionado: Coração Undertale (animação de morte/renascimento).
    - ESP: 3D Box baseada na hitbox do humanoide, linha (corda) do player ao alvo.
    - Música: botão "Recarregar Músicas".
    - 3ª pessoa: desativa corretamente.
    - TP: funcionando com raycast.
    - Fetch de servidores corrigido.
    - Descarga total ao desativar.
]]

local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local ok, Library = pcall(function()
    return loadstring(game:HttpGet(REPO .. "Library.lua"))()
end)
assert(ok and Library, "[R3dHub] Falha ao carregar Library. Ative HTTP no executor.")

local ThemeManager = loadstring(game:HttpGet(REPO .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(REPO .. "addons/SaveManager.lua"))()
local Options  = Library.Options
local Toggles  = Library.Toggles

-- ══════════════════════════════════════════════════════════════
--  SERVIÇOS
-- ══════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local SoundService     = game:GetService("SoundService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")
local StarterGui       = game:GetService("StarterGui")
local Workspace        = game:GetService("Workspace")
local Camera           = Workspace.CurrentCamera
local TweenService     = game:GetService("TweenService")
local TextChatService  = game:GetService("TextChatService")

local LP    = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Gui   = LP.PlayerGui

-- ══════════════════════════════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════
local G_SELECTED_PLAYER = nil
local SESSION_START     = os.time()
local ORIG_WS           = 16
local ORIG_JH           = 7.2
local ORIG_JP           = 50
local DEFAULT_GRAVITY   = workspace.Gravity

-- Lista de objetos criados pelo hub para destruir no descarregamento
local HubObjects = {
    Connections = {},
    GUIs = {},
    Parts = {},
    Sounds = {},
    Highlights = {},
    Drawings = {},
    Heart = nil,
}

local Modules = {
    Flight      = { Active=false, Connection=nil, BV=nil, BA=nil, BP=nil },
    Noclip      = { Active=false, Connection=nil },
    Freecam     = { Active=false, Data=nil },
    AntiAFK     = { Connection=nil },
    InfJump     = { Active=false, Connection=nil },
    TPMouse     = { Active=false, Connection=nil, Key=Enum.KeyCode.F },
    ClickTP     = { Active=false, Connection=nil },
    AirStand    = { Active=false, Connection=nil, Platform=nil },
    ESP         = { Active=false, PlayerConns={}, Highlights={}, Tracers={}, Lines={} },
    SpeedHUD    = { Active=false, GUI=nil, Connection=nil },
    ClockHUD    = { Active=false, GUI=nil, Connection=nil },
    FPSCounter  = { Active=false, GUI=nil, Connection=nil, Frames=0, Last=0 },
    FallDamage  = { Active=false, Connection=nil },
    Thirdperson = { Active=false, Connection=nil },
    Heart       = { Active=false, Parts={}, Connection=nil, DeathTween=nil, RespawnTween=nil },
    Skybox      = { Active=false },
    Time        = { Active=false },
    Music       = { Queue={}, CurrentAudio=nil, Folder="R3dHub/Music" },
}

-- ══════════════════════════════════════════════════════════════
--  AUXILIARES
-- ══════════════════════════════════════════════════════════════
local function getChar()  local c=LP.Character; return c and c.Parent and c end
local function getHRP()   local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()   local c=getChar(); return c and c:FindFirstChildWhichIsA("Humanoid") end
local function safeCall(f,...) local s,r=pcall(f,...); return s and r end
local function notify(t,d,dur) Library:Notify({Title=t,Description=tostring(d),Duration=dur or 3}) end
local function copyClipboard(s) safeCall(setclipboard,s) end
local function getOpt(n,fb) return (Options[n] and Options[n].Value~=nil) and Options[n].Value or fb end
local function getToggle(n) return Toggles[n] and Toggles[n].Value end

local function formatUptime()
    local e=os.time()-SESSION_START
    return ("%02d:%02d:%02d"):format(math.floor(e/3600),math.floor(e%3600/60),e%60)
end

-- Função para descarregar tudo
local function unloadHub()
    -- Desconectar todas as conexões
    for _, conn in ipairs(HubObjects.Connections) do
        pcall(conn.Disconnect, conn)
    end
    HubObjects.Connections = {}

    -- Destruir GUIs
    for _, gui in ipairs(HubObjects.GUIs) do
        pcall(gui.Destroy, gui)
    end
    HubObjects.GUIs = {}

    -- Destruir partes
    for _, part in ipairs(HubObjects.Parts) do
        pcall(part.Destroy, part)
    end
    HubObjects.Parts = {}

    -- Destruir sons
    for _, sound in ipairs(HubObjects.Sounds) do
        pcall(sound.Destroy, sound)
    end
    HubObjects.Sounds = {}

    -- Destruir highlights
    for _, hl in ipairs(HubObjects.Highlights) do
        pcall(hl.Destroy, hl)
    end
    HubObjects.Highlights = {}

    -- Remover drawings
    for _, drawing in ipairs(HubObjects.Drawings) do
        pcall(drawing.Remove, drawing)
    end
    HubObjects.Drawings = {}

    -- Desativar módulos
    if Modules.Flight.Active then Modules.Flight.Active=false; if Modules.Flight.Connection then Modules.Flight.Connection:Disconnect() end end
    if Modules.Noclip.Active then Modules.Noclip.Active=false; if Modules.Noclip.Connection then Modules.Noclip.Connection:Disconnect() end end
    if Modules.Freecam.Active then Modules.Freecam.Active=false; if Modules.Freecam.Data then Camera.CameraType=Modules.Freecam.Data.ct; Camera.CameraSubject=Modules.Freecam.Data.sub end end
    if Modules.InfJump.Active then Modules.InfJump.Active=false; if Modules.InfJump.Connection then Modules.InfJump.Connection:Disconnect() end end
    if Modules.TPMouse.Active then Modules.TPMouse.Active=false; if Modules.TPMouse.Connection then Modules.TPMouse.Connection:Disconnect() end end
    if Modules.ClickTP.Active then Modules.ClickTP.Active=false; if Modules.ClickTP.Connection then Modules.ClickTP.Connection:Disconnect() end end
    if Modules.AirStand.Active then Modules.AirStand.Active=false; if Modules.AirStand.Connection then Modules.AirStand.Connection:Disconnect() end end
    if Modules.FallDamage.Active then Modules.FallDamage.Active=false; if Modules.FallDamage.Connection then Modules.FallDamage.Connection:Disconnect() end end
    if Modules.Thirdperson.Active then Modules.Thirdperson.Active=false; if Modules.Thirdperson.Connection then Modules.Thirdperson.Connection:Disconnect() end; Camera.CameraType=Enum.CameraType.Custom end
    if Modules.Heart.Active then Modules.Heart.Active=false; if Modules.Heart.Connection then Modules.Heart.Connection:Disconnect() end; if HubObjects.Heart then HubObjects.Heart:Destroy() end end

    -- Parar música
    if Modules.Music.CurrentAudio then
        Modules.Music.CurrentAudio:Stop()
        Modules.Music.CurrentAudio:Destroy()
        Modules.Music.CurrentAudio = nil
    end

    -- Resetar gravidade e FOV
    workspace.Gravity = DEFAULT_GRAVITY
    Camera.FieldOfView = 70

    notify("R3d Hub", "Descarregado.", 2)
end

-- ══════════════════════════════════════════════════════════════
--  VOO
-- ══════════════════════════════════════════════════════════════
local function stopFlight()
    local m=Modules.Flight; if not m.Active then return end
    m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    if m.BV then safeCall(m.BV.Destroy,m.BV); m.BV=nil end
    if m.BA then safeCall(m.BA.Destroy,m.BA); m.BA=nil end
    if m.BP then safeCall(m.BP.Destroy,m.BP); m.BP=nil end
    local h=getHum(); if h then h.PlatformStand=false end
end
local function startFlight()
    local m=Modules.Flight; if m.Active then return end
    local hrp,h=getHRP(),getHum(); if not hrp or not h then return end
    m.Active=true; h.PlatformStand=true
    m.BV=Instance.new("BodyVelocity"); m.BV.MaxForce=Vector3.new(1e9,1e9,1e9); m.BV.Velocity=Vector3.zero; m.BV.Parent=hrp
    m.BA=Instance.new("BodyGyro"); m.BA.MaxTorque=Vector3.new(1e9,1e9,1e9); m.BA.P=1e6; m.BA.D=100; m.BA.CFrame=hrp.CFrame; m.BA.Parent=hrp
    m.BP=Instance.new("BodyPosition"); m.BP.MaxForce=Vector3.new(1e5,1e5,1e5); m.BP.P=2000; m.BP.D=100; m.BP.Position=hrp.Position; m.BP.Parent=hrp
    local conn
    conn=RunService.Heartbeat:Connect(function(dt)
        if not m.Active or not hrp or not hrp.Parent then stopFlight(); return end
        local UIS=UserInputService; local spd=getOpt("FlightSpeed",50)
        local shift=UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1
        local dir=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.E) then dir+=Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then dir-=Vector3.new(0,1,0) end
        if dir.Magnitude>0 then m.BV.Velocity=dir.Unit*(spd*shift) else m.BV.Velocity=Vector3.zero end
        m.BP.Position=hrp.Position
        local cl=Camera.CFrame.LookVector; local fl=Vector3.new(cl.X,0,cl.Z)
        if fl.Magnitude>0.01 then m.BA.CFrame=CFrame.new(hrp.Position,hrp.Position+fl) end
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════════════════════
local function stopNoclip()
    local m=Modules.Noclip; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    local c=getChar(); if not c then return end
    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end
end
local function startNoclip()
    local m=Modules.Noclip; if m.Active then return end
    m.Active=true
    local conn=RunService.Stepped:Connect(function()
        if not m.Active then return end
        local c=getChar(); if not c then return end
        for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  FREECAM
-- ══════════════════════════════════════════════════════════════
local function stopFreecam()
    local m=Modules.Freecam; m.Active=false
    if m.Data then
        Camera.CameraType=m.Data.ct; Camera.CameraSubject=m.Data.sub
        local hrp=getHRP(); if hrp then hrp.Anchored=false end
        local h=getHum(); if h then h.PlatformStand=false end
        m.Data=nil
    end
end
local function startFreecam()
    local m=Modules.Freecam; if m.Active then return end
    local hrp=getHRP(); if not hrp then return end
    m.Active=true; m.Data={ct=Camera.CameraType,sub=Camera.CameraSubject}
    hrp.Anchored=true; local h=getHum(); if h then h.PlatformStand=true end
    Camera.CameraType=Enum.CameraType.Scriptable
    task.spawn(function()
        while m.Active do
            local dt=task.wait(); local spd=getOpt("FreecamSpeed",60)
            local shift=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
            local dir=Vector3.zero; local UIS=UserInputService
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.E) then dir+=Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.Q) then dir-=Vector3.new(0,1,0) end
            if dir.Magnitude>0 then Camera.CFrame=Camera.CFrame+dir.Unit*spd*shift*dt end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  ANTI-AFK
-- ══════════════════════════════════════════════════════════════
local function startAntiAFK()
    local conn=LP.Idled:Connect(function()
        safeCall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
    end)
    Modules.AntiAFK.Connection=conn
    table.insert(HubObjects.Connections, conn)
end
local function stopAntiAFK()
    if Modules.AntiAFK.Connection then Modules.AntiAFK.Connection:Disconnect(); Modules.AntiAFK.Connection=nil end
end

-- ══════════════════════════════════════════════════════════════
--  PULO INFINITO
-- ══════════════════════════════════════════════════════════════
local function stopInfJump()
    local m=Modules.InfJump; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
end
local function startInfJump()
    local m=Modules.InfJump; if m.Active then return end
    m.Active=true
    local conn=UserInputService.JumpRequest:Connect(function()
        local h=getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  TELEPORTE MOUSE (COM RAYCAST)
-- ══════════════════════════════════════════════════════════════
local function stopTPMouse()
    local m=Modules.TPMouse; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
end
local function startTPMouse()
    local m=Modules.TPMouse; if m.Active then return end
    m.Active=true
    m.Key=Options.TPMouseKey and Options.TPMouseKey.Value or Enum.KeyCode.F
    local conn=UserInputService.InputBegan:Connect(function(input,gp)
        if gp or input.KeyCode~=m.Key or not m.Active then return end
        local hrp=getHRP(); if not hrp then return end
        local target=Mouse.Hit.Position
        local dist=(hrp.Position-target).Magnitude
        if dist>500 then notify("TP","Muito longe ("..math.floor(dist).."st). Máx: 500.",3); return end
        local ray=Ray.new(target+Vector3.new(0,10,0),Vector3.new(0,-20,0))
        local _,pos=workspace:FindPartOnRay(ray,LP.Character)
        hrp.CFrame=CFrame.new((pos or target)+Vector3.new(0,3,0))
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
    notify("TP Mouse","Ativo. ["..tostring(m.Key.Name).."] para teleportar.",3)
end

-- ══════════════════════════════════════════════════════════════
--  CLICK TP
-- ══════════════════════════════════════════════════════════════
local function stopClickTP()
    local m=Modules.ClickTP; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
end
local function startClickTP()
    local m=Modules.ClickTP; if m.Active then return end
    m.Active=true
    local conn=UserInputService.InputBegan:Connect(function(input,gp)
        if gp or input.UserInputType~=Enum.UserInputType.MouseButton1 or not m.Active then return end
        local hrp=getHRP(); if not hrp then return end
        local hit=Mouse.Hit.Position
        local ray=Ray.new(hit+Vector3.new(0,10,0),Vector3.new(0,-20,0))
        local _,pos=workspace:FindPartOnRay(ray,LP.Character)
        hrp.CFrame=CFrame.new((pos or hit)+Vector3.new(0,3,0))
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
    notify("Click TP","Ativo. Clique esquerdo para teleportar.",3)
end

-- ══════════════════════════════════════════════════════════════
--  AIR STAND
-- ══════════════════════════════════════════════════════════════
local function stopAirStand()
    local m=Modules.AirStand; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    if m.Platform then safeCall(m.Platform.Destroy,m.Platform); m.Platform=nil end
end
local function startAirStand()
    local m=Modules.AirStand; if m.Active then return end
    m.Active=true
    local function spawnPlatform()
        local hrp=getHRP(); if not hrp then return end
        if m.Platform then safeCall(m.Platform.Destroy,m.Platform) end
        m.Platform=Instance.new("Part"); m.Platform.Name="R3dAirPlatform"
        m.Platform.Size=Vector3.new(4,0.05,4); m.Platform.Anchored=true
        m.Platform.CanCollide=true; m.Platform.Transparency=1
        m.Platform.CFrame=CFrame.new(hrp.Position.X,hrp.Position.Y-2.8,hrp.Position.Z)
        m.Platform.Parent=Workspace
        table.insert(HubObjects.Parts, m.Platform)
    end
    local conn=UserInputService.JumpRequest:Connect(function()
        if not m.Active then return end
        local h=getHum(); if not h then return end
        local state=h:GetState()
        if state==Enum.HumanoidStateType.Freefall or state==Enum.HumanoidStateType.Jumping then
            spawnPlatform()
        else
            if m.Platform then safeCall(m.Platform.Destroy,m.Platform); m.Platform=nil end
        end
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  WALK / JUMP
-- ══════════════════════════════════════════════════════════════
local function applyWalkSpeed() local h=getHum(); if h then h.WalkSpeed=getOpt("WalkSpeedValue",50) end end
local function resetWalkSpeed()  local h=getHum(); if h then h.WalkSpeed=ORIG_WS end end
local function applyJump()
    local h=getHum(); if not h then return end
    if h.UseJumpPower then h.JumpPower=getOpt("JumpPowerValue",100)
    else h.JumpHeight=getOpt("JumpHeightValue",50) end
end
local function resetJump()
    local h=getHum(); if not h then return end
    if h.UseJumpPower then h.JumpPower=ORIG_JP else h.JumpHeight=ORIG_JH end
end

-- ══════════════════════════════════════════════════════════════
--  FALL DAMAGE BYPASS
-- ══════════════════════════════════════════════════════════════
local function stopFallDamage()
    local m=Modules.FallDamage; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
end
local function startFallDamage()
    local m=Modules.FallDamage; if m.Active then return end
    m.Active=true; local h=getHum()
    if h then
        local conn=h:GetPropertyChangedSignal("FallingDown"):Connect(function()
            if m.Active and h.FallingDown then h.FallingDown=false end
        end)
        m.Connection=conn
        table.insert(HubObjects.Connections, conn)
    end
end

-- ══════════════════════════════════════════════════════════════
--  GRAVIDADE
-- ══════════════════════════════════════════════════════════════
local function setGravity(v)  workspace.Gravity=v end
local function resetGravity() workspace.Gravity=DEFAULT_GRAVITY end

-- ══════════════════════════════════════════════════════════════
--  FPS BOOST
-- ══════════════════════════════════════════════════════════════
local function applyFPSBoost()
    safeCall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=1e9 end)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or
           v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then safeCall(function() v.Enabled=false end) end
        if v:IsA("SurfaceAppearance") then safeCall(v.Destroy,v) end
    end
    if settings then safeCall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end) end
    notify("FPS Boost","Aplicado.",3)
end
local function removeFPSBoost()
    safeCall(function() Lighting.GlobalShadows=true end)
    if settings then safeCall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end) end
    notify("FPS Boost","Removido.",3)
end

-- ══════════════════════════════════════════════════════════════
--  TERCEIRA PESSOA (CORRIGIDA)
-- ══════════════════════════════════════════════════════════════
local function stopThirdperson()
    local m=Modules.Thirdperson; if not m.Active then return end
    m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    Camera.CameraType=Enum.CameraType.Custom
    LP.CameraMinZoomDistance=0.5
    LP.CameraMaxZoomDistance=400
    notify("3ª Pessoa","Desativada.",2)
end
local function startThirdperson()
    local m=Modules.Thirdperson; if m.Active then return end
    m.Active=true
    LP.CameraMinZoomDistance=getOpt("ThirdpersonDist",12)
    LP.CameraMaxZoomDistance=getOpt("ThirdpersonDist",12)
    Camera.CameraType=Enum.CameraType.Custom
    local conn=RunService.RenderStepped:Connect(function()
        if not m.Active then return end
        local dist=getOpt("ThirdpersonDist",12)
        LP.CameraMinZoomDistance=dist
        LP.CameraMaxZoomDistance=dist
    end)
    m.Connection=conn
    table.insert(HubObjects.Connections, conn)
    notify("3ª Pessoa","Ativa. Use o slider para ajustar.",3)
end

-- ══════════════════════════════════════════════════════════════
--  CORAÇÃO UNDERTALE
-- ══════════════════════════════════════════════════════════════
local function createHeart()
    if HubObjects.Heart then HubObjects.Heart:Destroy() end
    local heart = Instance.new("Part")
    heart.Name = "R3dHeart"
    heart.Size = Vector3.new(0.8, 0.8, 0.2)
    heart.BrickColor = BrickColor.new("Bright red")
    heart.Material = Enum.Material.Neon
    heart.CanCollide = false
    heart.Anchored = false
    heart.CastShadow = false
    heart.Transparency = 0.2
    -- Forma de coração (usando um mesh especial)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Heart
    mesh.Parent = heart
    -- Posicionar no peito
    local hrp = getHRP()
    if hrp then
        heart.CFrame = hrp.CFrame * CFrame.new(0, 0.5, 0)
    end
    heart.Parent = Workspace
    HubObjects.Heart = heart
    table.insert(HubObjects.Parts, heart)

    -- Weld para seguir o personagem
    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = heart
    weld.C0 = CFrame.new(0, 0.5, 0)
    weld.Parent = heart
    table.insert(HubObjects.Parts, weld)

    return heart
end

local function startHeart()
    local m = Modules.Heart
    if m.Active then return end
    m.Active = true
    createHeart()

    -- Tela preta para animação de morte
    local blackScreen = Instance.new("ScreenGui")
    blackScreen.Name = "R3dHeartBlackScreen"
    blackScreen.ResetOnSpawn = false
    blackScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = blackScreen
    blackScreen.Parent = Gui
    table.insert(HubObjects.GUIs, blackScreen)

    local heartPart = HubObjects.Heart
    local hum = getHum()

    local function onDied()
        if not m.Active then return end
        -- Animação de quebra do coração
        local heartMesh = heartPart:FindFirstChildOfClass("SpecialMesh")
        if heartMesh then
            TweenService:Create(heartMesh, TweenInfo.new(0.5), {Scale = Vector3.new(0,0,0)}):Play()
        end
        TweenService:Create(heartPart, TweenInfo.new(0.5), {Transparency = 1}):Play()
        -- Escurecer tela
        TweenService:Create(frame, TweenInfo.new(0.8), {BackgroundTransparency = 0}):Play()
        task.wait(0.9)
        -- Esperar renascer
        local newChar = LP.CharacterAdded:Wait()
        task.wait(0.5)
        -- Reaparecer coração
        local newHRP = newChar:WaitForChild("HumanoidRootPart")
        heartPart.Parent = Workspace
        heartPart.CFrame = newHRP.CFrame * CFrame.new(0, 0.5, 0)
        local newWeld = Instance.new("Weld")
        newWeld.Part0 = newHRP
        newWeld.Part1 = heartPart
        newWeld.C0 = CFrame.new(0, 0.5, 0)
        newWeld.Parent = heartPart
        table.insert(HubObjects.Parts, newWeld)
        if heartMesh then
            TweenService:Create(heartMesh, TweenInfo.new(0.5), {Scale = Vector3.new(1,1,1)}):Play()
        end
        TweenService:Create(heartPart, TweenInfo.new(0.5), {Transparency = 0.2}):Play()
        -- Clarear tela
        TweenService:Create(frame, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
    end

    if hum then
        local conn = hum.Died:Connect(onDied)
        table.insert(HubObjects.Connections, conn)
        m.Connection = conn
    end

    notify("Coração","❤️ Ativado! (Undertale style)",3)
end

local function stopHeart()
    local m = Modules.Heart
    if not m.Active then return end
    m.Active = false
    if m.Connection then m.Connection:Disconnect(); m.Connection = nil end
    if HubObjects.Heart then
        HubObjects.Heart:Destroy()
        HubObjects.Heart = nil
    end
    -- Remover tela preta
    for i, gui in ipairs(HubObjects.GUIs) do
        if gui.Name == "R3dHeartBlackScreen" then
            gui:Destroy()
            table.remove(HubObjects.GUIs, i)
            break
        end
    end
    notify("Coração","Desativado.",2)
end

-- ══════════════════════════════════════════════════════════════
--  ESP (com 3D Box baseada na hitbox e linha "corda")
-- ══════════════════════════════════════════════════════════════
local ESP_CFG={
    showBox=true,showName=true,showHealth=true,showDistance=true,
    showTracer=false,show3DBox=false,showLine=false,teamCheck=false,
    fillColor=Color3.fromRGB(255,50,50),outlineColor=Color3.fromRGB(255,255,255),
    fillTransp=0.6,outlineTransp=0,maxDist=1000,
    tracerColor=Color3.fromRGB(255,255,255),boxColor=Color3.fromRGB(0,255,255),
    lineColor=Color3.fromRGB(255,200,0),
}

-- Função para criar caixa 3D baseada na hitbox do humanoide
local function create3DBoxFromHumanoid(hrp, hum)
    if not hum then return nil end
    local size = hum.HipHeight + 4 -- altura aproximada
    local width = 2
    local depth = 1.5
    local offsets = {
        Vector3.new(-width/2, 0, -depth/2), Vector3.new(width/2, 0, -depth/2),
        Vector3.new(width/2, 0, depth/2), Vector3.new(-width/2, 0, depth/2),
        Vector3.new(-width/2, size, -depth/2), Vector3.new(width/2, size, -depth/2),
        Vector3.new(width/2, size, depth/2), Vector3.new(-width/2, size, depth/2),
    }
    local atts = {}
    for i, off in ipairs(offsets) do
        local att = Instance.new("Attachment")
        att.Position = off
        att.Visible = false
        att.Parent = hrp
        table.insert(HubObjects.Parts, att)
        atts[i] = att
    end
    local edges = {
        {1,2},{2,3},{3,4},{4,1},
        {5,6},{6,7},{7,8},{8,5},
        {1,5},{2,6},{3,7},{4,8},
    }
    local beams = {}
    for _, e in ipairs(edges) do
        local beam = Instance.new("Beam")
        beam.Attachment0 = atts[e[1]]
        beam.Attachment1 = atts[e[2]]
        beam.Color = ColorSequence.new(ESP_CFG.boxColor)
        beam.Width0 = 0.1
        beam.Width1 = 0.1
        beam.Transparency = NumberSequence.new(0)
        beam.FaceCamera = true
        beam.Parent = hrp
        table.insert(HubObjects.Parts, beam)
        table.insert(beams, beam)
    end
    return {attachments=atts, beams=beams}
end

local function buildESPGui(player)
    local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not hum then return nil end
    local hl=Instance.new("Highlight"); hl.Name="R3dESP_HL"; hl.Adornee=char
    hl.FillColor=ESP_CFG.fillColor; hl.OutlineColor=ESP_CFG.outlineColor
    hl.FillTransparency=ESP_CFG.fillTransp; hl.OutlineTransparency=ESP_CFG.outlineTransp
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
    table.insert(HubObjects.Highlights, hl)
    local bb=Instance.new("BillboardGui"); bb.Name="R3dESP_BB"; bb.Adornee=hrp; bb.AlwaysOnTop=true
    bb.StudsOffset=Vector3.new(0,3.2,0); bb.Size=UDim2.new(0,200,0,75); bb.LightInfluence=0; bb.Parent=hrp
    table.insert(HubObjects.GUIs, bb)
    local nameL=Instance.new("TextLabel"); nameL.Name="NameL"; nameL.Size=UDim2.new(1,0,0.32,0)
    nameL.BackgroundTransparency=1; nameL.TextColor3=Color3.new(1,1,1); nameL.TextStrokeTransparency=0.4
    nameL.Font=Enum.Font.GothamBold; nameL.TextScaled=true
    nameL.Text=player.DisplayName.." (@"..player.Name..")"; nameL.Parent=bb
    local hpBG=Instance.new("Frame"); hpBG.Name="HPBG"; hpBG.Size=UDim2.new(1,0,0.18,0)
    hpBG.Position=UDim2.new(0,0,0.34,0); hpBG.BackgroundColor3=Color3.fromRGB(30,30,30)
    hpBG.BorderSizePixel=0; hpBG.Parent=bb
    local hpBar=Instance.new("Frame"); hpBar.Name="HPBar"; hpBar.Size=UDim2.new(1,0,1,0)
    hpBar.BackgroundColor3=Color3.fromRGB(80,220,80); hpBar.BorderSizePixel=0; hpBar.Parent=hpBG
    local hpText=Instance.new("TextLabel"); hpText.Size=UDim2.new(1,0,1,0)
    hpText.BackgroundTransparency=1; hpText.TextColor3=Color3.new(1,1,1)
    hpText.Font=Enum.Font.Gotham; hpText.TextScaled=true; hpText.Parent=hpBG
    local distL=Instance.new("TextLabel"); distL.Name="DistL"; distL.Size=UDim2.new(1,0,0.25,0)
    distL.Position=UDim2.new(0,0,0.56,0); distL.BackgroundTransparency=1
    distL.TextColor3=Color3.fromRGB(180,200,255); distL.TextStrokeTransparency=0.4
    distL.Font=Enum.Font.Gotham; distL.TextScaled=true; distL.Text="? m"; distL.Parent=bb
    return{hl=hl,bb=bb,hpBar=hpBar,hpText=hpText,distL=distL,nameL=nameL,box3d=nil}
end

local function removeESPPlayer(player)
    local m=Modules.ESP; local data=m.Highlights[player]
    if data then
        if data.hl then pcall(data.hl.Destroy,data.hl) end
        if data.bb then pcall(data.bb.Destroy,data.bb) end
        if data.box3d then
            for _,att in ipairs(data.box3d.attachments) do pcall(att.Destroy,att) end
            for _,beam in ipairs(data.box3d.beams) do pcall(beam.Destroy,beam) end
        end
        m.Highlights[player]=nil
    end
    local tr=m.Tracers[player]; if tr then tr:Remove(); m.Tracers[player]=nil end
    local ln=m.Lines[player]; if ln then ln:Remove(); m.Lines[player]=nil end
end

local function addESPPlayer(player)
    if player==LP then return end
    local m=Modules.ESP; removeESPPlayer(player)
    if not player.Character then return end
    if ESP_CFG.teamCheck and player.Team==LP.Team then return end
    local data=buildESPGui(player); if data then m.Highlights[player]=data end
end

local function updateESP()
    local m=Modules.ESP; local myHRP=getHRP(); local myPos=myHRP and myHRP.Position or Vector3.zero
    local screenCenter=Camera.ViewportSize/2
    ESP_CFG.showBox=getToggle("ESPBox")~=false; ESP_CFG.showName=getToggle("ESPName")~=false
    ESP_CFG.showHealth=getToggle("ESPHealth")~=false; ESP_CFG.showDistance=getToggle("ESPDistance")~=false
    ESP_CFG.showTracer=getToggle("ESPTracer")==true; ESP_CFG.show3DBox=getToggle("ESP3DBox")==true
    ESP_CFG.showLine=getToggle("ESPLine")==true; ESP_CFG.teamCheck=getToggle("ESPTeamCheck")==true
    ESP_CFG.maxDist=getOpt("ESPMaxDist",1000)
    ESP_CFG.fillTransp=getOpt("ESPFillTransp",60)/100; ESP_CFG.outlineTransp=getOpt("ESPOutlineTransp",0)/100
    ESP_CFG.tracerColor=Options.ESPTracerColor and Options.ESPTracerColor.Value or Color3.new(1,1,1)
    ESP_CFG.boxColor=Options.ESPBoxColor and Options.ESPBoxColor.Value or Color3.new(0,1,1)
    ESP_CFG.lineColor=Options.ESPLineColor and Options.ESPLineColor.Value or Color3.new(1,0.8,0)

    for player,data in pairs(m.Highlights) do
        safeCall(function()
            if not player or not player.Parent then removeESPPlayer(player); return end
            local char=player.Character; if not char then removeESPPlayer(player); return end
            local hrp=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChildWhichIsA("Humanoid")
            if not hrp then return end
            local dist=myHRP and math.floor((myHRP.Position-hrp.Position).Magnitude) or 0
            local inRange=dist<=ESP_CFG.maxDist
            if data.bb then
                data.bb.Enabled=inRange
                if inRange then
                    data.nameL.Visible=ESP_CFG.showName; data.distL.Visible=ESP_CFG.showDistance
                    if ESP_CFG.showDistance then data.distL.Text=tostring(dist).." m" end
                    local bg=data.bb:FindFirstChild("HPBG"); if bg then bg.Visible=ESP_CFG.showHealth end
                    if hum and ESP_CFG.showHealth then
                        local pct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                        data.hpBar.Size=UDim2.new(pct,0,1,0)
                        data.hpBar.BackgroundColor3=Color3.fromHSV(pct*0.33,1,1)
                        data.hpText.Text=math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
                    end
                end
            end
            if data.hl then
                data.hl.Enabled=inRange and ESP_CFG.showBox
                if inRange and ESP_CFG.showBox then
                    data.hl.FillColor=ESP_CFG.fillColor; data.hl.OutlineColor=ESP_CFG.outlineColor
                    data.hl.FillTransparency=ESP_CFG.fillTransp; data.hl.OutlineTransparency=ESP_CFG.outlineTransp
                end
            end
            -- Tracer (linha do centro da tela)
            if ESP_CFG.showTracer and inRange and myHRP then
                local head=char:FindFirstChild("Head") or hrp
                local headPos=head.Position+Vector3.new(0,0.5,0)
                local screenPos,onScreen=Camera:WorldToViewportPoint(headPos)
                if onScreen then
                    local tracer=m.Tracers[player]
                    if not tracer then
                        tracer=Drawing.new("Line"); tracer.Thickness=1
                        tracer.Color=ESP_CFG.tracerColor; tracer.Transparency=1; tracer.Visible=false
                        m.Tracers[player]=tracer
                        table.insert(HubObjects.Drawings, tracer)
                    end
                    tracer.From=Vector2.new(screenCenter.X,screenCenter.Y)
                    tracer.To=Vector2.new(screenPos.X,screenPos.Y); tracer.Visible=true
                else if m.Tracers[player] then m.Tracers[player].Visible=false end end
            else if m.Tracers[player] then m.Tracers[player].Visible=false end end

            -- Linha "corda" do meu HRP até o HRP do alvo
            if ESP_CFG.showLine and inRange and myHRP then
                local line=m.Lines[player]
                if not line then
                    line=Drawing.new("Line"); line.Thickness=1
                    line.Color=ESP_CFG.lineColor; line.Transparency=1; line.Visible=false
                    m.Lines[player]=line
                    table.insert(HubObjects.Drawings, line)
                end
                local start, onScreen1 = Camera:WorldToViewportPoint(myHRP.Position)
                local target, onScreen2 = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen1 or onScreen2 then
                    line.From=Vector2.new(start.X, start.Y)
                    line.To=Vector2.new(target.X, target.Y)
                    line.Visible=true
                else line.Visible=false end
            else if m.Lines[player] then m.Lines[player].Visible=false end end

            -- Caixa 3D baseada na hitbox
            if ESP_CFG.show3DBox and inRange then
                if not data.box3d then
                    data.box3d=create3DBoxFromHumanoid(hrp, hum)
                else
                    for _,beam in ipairs(data.box3d.beams) do beam.Color=ColorSequence.new(ESP_CFG.boxColor) end
                end
            else
                if data.box3d then
                    for _,att in ipairs(data.box3d.attachments) do pcall(att.Destroy,att) end
                    for _,beam in ipairs(data.box3d.beams) do pcall(beam.Destroy,beam) end
                    data.box3d=nil
                end
            end
        end)
    end
end

local function startESP()
    local m=Modules.ESP; if m.Active then return end
    m.Active=true
    for _,p in ipairs(Players:GetPlayers()) do addESPPlayer(p) end
    local conn1=Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function() task.wait(0.5); if m.Active then addESPPlayer(p) end end)
    end)
    local conn2=Players.PlayerRemoving:Connect(removeESPPlayer)
    m.PlayerConns={conn1, conn2}
    table.insert(HubObjects.Connections, conn1)
    table.insert(HubObjects.Connections, conn2)
    task.spawn(function() while m.Active do updateESP(); task.wait(0.1) end end)
end
local function stopESP()
    local m=Modules.ESP; m.Active=false
    for _,conn in ipairs(m.PlayerConns) do pcall(conn.Disconnect,conn) end
    m.PlayerConns={}
    for p,_ in pairs(m.Highlights) do removeESPPlayer(p) end
    m.Tracers={}; m.Lines={}
end

-- ══════════════════════════════════════════════════════════════
--  SPEED HUD
-- ══════════════════════════════════════════════════════════════
local function stopSpeedDisplay()
    local m=Modules.SpeedHUD; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    if m.GUI then safeCall(m.GUI.Destroy,m.GUI); m.GUI=nil end
end
local function startSpeedDisplay()
    local m=Modules.SpeedHUD; if m.Active then return end; m.Active=true
    local sg=Instance.new("ScreenGui"); sg.Name="R3dSpeedGUI"; sg.ResetOnSpawn=false; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,140,0,36); frame.Position=UDim2.new(0.5,-70,0.88,0)
    frame.BackgroundColor3=Color3.fromRGB(10,10,10); frame.BackgroundTransparency=0.3; frame.BorderSizePixel=0; frame.Parent=sg
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.TextColor3=Color3.fromRGB(100,220,255); lbl.Font=Enum.Font.GothamBold; lbl.TextScaled=true; lbl.Text="0.0 st/s"; lbl.Parent=frame
    sg.Parent=Gui; m.GUI=sg; table.insert(HubObjects.GUIs, sg)
    local conn=RunService.Heartbeat:Connect(function()
        if not m.Active or not m.GUI then return end
        local hrp=getHRP()
        if hrp then
            local vel=hrp.AssemblyLinearVelocity
            lbl.Text=math.floor(Vector3.new(vel.X,0,vel.Z).Magnitude*10)/10 .." st/s"
        end
    end)
    m.Connection=conn; table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  CLOCK HUD
-- ══════════════════════════════════════════════════════════════
local function stopClock()
    local m=Modules.ClockHUD; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    if m.GUI then safeCall(m.GUI.Destroy,m.GUI); m.GUI=nil end
end
local function startClock()
    local m=Modules.ClockHUD; if m.Active then return end; m.Active=true
    local sg=Instance.new("ScreenGui"); sg.Name="R3dClockGUI"; sg.ResetOnSpawn=false
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,130,0,30); lbl.Position=UDim2.new(1,-140,0,8)
    lbl.BackgroundColor3=Color3.fromRGB(10,10,10); lbl.BackgroundTransparency=0.4
    lbl.TextColor3=Color3.fromRGB(255,255,200); lbl.Font=Enum.Font.GothamBold
    lbl.TextScaled=true; lbl.BorderSizePixel=0; lbl.Parent=sg
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,6)
    sg.Parent=Gui; m.GUI=sg; table.insert(HubObjects.GUIs, sg)
    local conn=RunService.Heartbeat:Connect(function()
        if not m.Active or not m.GUI then return end
        local t=os.date("*t"); lbl.Text=("%02d:%02d:%02d"):format(t.hour,t.min,t.sec)
    end)
    m.Connection=conn; table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  FPS COUNTER HUD
-- ══════════════════════════════════════════════════════════════
local function stopFPSCounter()
    local m=Modules.FPSCounter; m.Active=false
    if m.Connection then m.Connection:Disconnect(); m.Connection=nil end
    if m.GUI then safeCall(m.GUI.Destroy,m.GUI); m.GUI=nil end
end
local function startFPSCounter()
    local m=Modules.FPSCounter; if m.Active then return end; m.Active=true
    local sg=Instance.new("ScreenGui"); sg.Name="R3dFPSGUI"; sg.ResetOnSpawn=false; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,90,0,28); lbl.Position=UDim2.new(1,-100,0,42)
    lbl.BackgroundColor3=Color3.fromRGB(10,10,10); lbl.BackgroundTransparency=0.4
    lbl.TextColor3=Color3.fromRGB(100,255,150); lbl.Font=Enum.Font.GothamBold
    lbl.TextScaled=true; lbl.BorderSizePixel=0; lbl.Parent=sg
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,6)
    sg.Parent=Gui; m.GUI=sg; table.insert(HubObjects.GUIs, sg)
    m.Frames=0; m.Last=tick()
    local conn=RunService.RenderStepped:Connect(function()
        if not m.Active then return end
        m.Frames=m.Frames+1
        local now=tick()
        if now-m.Last>=1 then
            local fps=m.Frames; m.Frames=0; m.Last=now
            local color=fps>=50 and Color3.fromRGB(100,255,150) or fps>=30 and Color3.fromRGB(255,220,80) or Color3.fromRGB(255,80,80)
            lbl.TextColor3=color; lbl.Text=fps.." FPS"
        end
    end)
    m.Connection=conn; table.insert(HubObjects.Connections, conn)
end

-- ══════════════════════════════════════════════════════════════
--  SKYBOX / HORÁRIO
-- ══════════════════════════════════════════════════════════════
local function applySkybox(ids)
    if not ids then return end
    local old=Lighting:FindFirstChild("R3dSky"); if old then old:Destroy() end
    local sky=Instance.new("Sky"); sky.Name="R3dSky"
    sky.SkyboxBk="rbxassetid://"..ids.Bk; sky.SkyboxDn="rbxassetid://"..ids.Dn
    sky.SkyboxFt="rbxassetid://"..ids.Ft; sky.SkyboxLf="rbxassetid://"..ids.Lf
    sky.SkyboxRt="rbxassetid://"..ids.Rt; sky.SkyboxUp="rbxassetid://"..ids.Up
    sky.Parent=Lighting; Modules.Skybox.Active=true
    table.insert(HubObjects.Parts, sky)
end
local function removeSkybox()
    local sky=Lighting:FindFirstChild("R3dSky"); if sky then sky:Destroy() end; Modules.Skybox.Active=false
end
local function setTimeOfDay(h)  Lighting.ClockTime=h end
local function resetTimeOfDay() Lighting.ClockTime=14 end

-- ══════════════════════════════════════════════════════════════
--  PLAYER ACTIONS
-- ══════════════════════════════════════════════════════════════
local HIDDEN_PLAYERS={}
local SPECTATE_TARGET=nil; local SPECTATE_CONN=nil

local function teleportToPlayer(target)
    if not target then notify("TP","Nenhum jogador."); return end
    local ok2,err=pcall(function()
        local tHRP=target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then error("Sem HRP") end
        local lHRP=getHRP(); if not lHRP then error("Sem HRP local") end
        lHRP.CFrame=tHRP.CFrame*CFrame.new(0,0,-4)
    end)
    if not ok2 then notify("TP","Falhou: "..tostring(err)) end
end
local function toggleHidePlayer(target,state)
    if not target then return end; HIDDEN_PLAYERS[target]=state or nil
    if target.Character then target.Character.Parent=state and nil or Workspace end
end
local function startSpectate(target)
    if not target or not target.Character then notify("Spectate","Sem personagem."); return end
    SPECTATE_TARGET=target; if SPECTATE_CONN then SPECTATE_CONN:Disconnect() end
    local hum=target.Character:FindFirstChildWhichIsA("Humanoid")
    if hum then Camera.CameraSubject=hum end
    local conn=target.CharacterAdded:Connect(function(nc)
        task.wait(1); local nh=nc:FindFirstChildWhichIsA("Humanoid")
        if nh and SPECTATE_TARGET==target then Camera.CameraSubject=nh end
    end)
    SPECTATE_CONN=conn; table.insert(HubObjects.Connections, conn)
end
local function stopSpectate()
    SPECTATE_TARGET=nil; if SPECTATE_CONN then SPECTATE_CONN:Disconnect(); SPECTATE_CONN=nil end
    local lh=getHum(); if lh then Camera.CameraSubject=lh end
end

-- ══════════════════════════════════════════════════════════════
--  SERVER FUNCTIONS (CORRIGIDAS)
-- ══════════════════════════════════════════════════════════════
local function fetchServers(placeId, limit)
    limit=limit or 100
    local ok2,res=pcall(HttpService.GetAsync,HttpService,
        ("https://games.roblox.com/v1/games/%d/servers/Public?limit=%d&sortOrder=Desc"):format(placeId,limit))
    if not ok2 then return nil,"HTTP falhou" end
    local d=HttpService:JSONDecode(res)
    return d.data or {}, nil
end

local function sniperJoin(mode)
    notify("Server Sniper","Procurando...",2)
    task.spawn(function()
        local servers, err = fetchServers(game.PlaceId, 100)
        if not servers then notify("Sniper","Falha: "..tostring(err)); return end
        local valid = {}
        for _,sv in ipairs(servers) do
            if sv.playing < sv.maxPlayers and sv.id ~= game.JobId then
                table.insert(valid, sv)
            end
        end
        if #valid == 0 then notify("Sniper","Nenhum servidor disponível."); return end
        local picked
        if mode=="fewest" then
            table.sort(valid, function(a,b) return a.playing < b.playing end)
            picked = valid[1].id
        elseif mode=="biggest" then
            table.sort(valid, function(a,b) return a.playing > b.playing end)
            picked = valid[1].id
        else -- random
            picked = valid[math.random(#valid)].id
        end
        TeleportService:TeleportToPlaceInstance(game.PlaceId, picked, LP)
    end)
end

local function rejoinServer() TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP) end

local function switchServer()
    notify("Servidor","Procurando...",2)
    task.spawn(function()
        local servers, err = fetchServers(game.PlaceId, 100)
        if not servers then notify("Servidor","Falha: "..tostring(err)); return end
        local list={}; for _,v in ipairs(servers) do if v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(list,v.id) end end
        if #list==0 then notify("Servidor","Nenhum encontrado."); return end
        TeleportService:TeleportToPlaceInstance(game.PlaceId,list[math.random(#list)],LP)
    end)
end

local function joinEmptyServer(placeId)
    local pid=placeId or game.PlaceId; notify("Servidor Vazio","Procurando...",3)
    task.spawn(function()
        local servers, err = fetchServers(pid, 100)
        if not servers then notify("Servidor Vazio","Falha: "..tostring(err)); return end
        table.sort(servers,function(a,b) return a.playing<b.playing end)
        for _,sv in ipairs(servers) do
            if sv.id~=game.JobId then
                notify("Servidor Vazio","Entrando ("..sv.playing.." players)...",3); task.wait(0.5)
                TeleportService:TeleportToPlaceInstance(pid,sv.id,LP); return
            end
        end
        notify("Servidor Vazio","Nenhum encontrado.")
    end)
end

local function joinBiggestServer(placeId)
    local pid=placeId or game.PlaceId; notify("Maior Servidor","Procurando...",3)
    task.spawn(function()
        local servers, err = fetchServers(pid, 100)
        if not servers then notify("Maior Servidor","Falha: "..tostring(err)); return end
        table.sort(servers,function(a,b) return a.playing>b.playing end)
        for _,sv in ipairs(servers) do
            if sv.id~=game.JobId then
                notify("Maior Servidor","Entrando ("..sv.playing.." players)...",3); task.wait(0.5)
                TeleportService:TeleportToPlaceInstance(pid,sv.id,LP); return
            end
        end
        notify("Maior Servidor","Nenhum encontrado.")
    end)
end

local function joinMyPrivateServer(placeId)
    local pid=placeId or game.PlaceId; notify("Servidor Privado","Procurando...",3)
    task.spawn(function()
        local ok2,res=pcall(HttpService.GetAsync,HttpService,
            ("https://games.roblox.com/v1/games/%d/private-servers?limit=100"):format(pid))
        if not ok2 then notify("Privado","Falha HTTP.",4); return end
        local d=HttpService:JSONDecode(res); local mine={}
        for _,sv in ipairs(d.data or {}) do
            if sv.owner and tostring(sv.owner.id)==tostring(LP.UserId) then table.insert(mine,sv) end
        end
        if #mine==0 then notify("Privado","Você não tem servidor privado aqui.",5); return end
        local picked=mine[1]
        if picked.accessCode then
            pcall(function() TeleportService:TeleportToPrivateServer(pid,picked.accessCode,{LP}) end)
        else
            pcall(function() TeleportService:TeleportToPlaceInstance(pid,picked.vipServerId or picked.id,LP) end)
        end
    end)
end

local function joinByPlaceId(placeIdStr,serverType)
    local pid=tonumber(placeIdStr); if not pid then notify("Entrar","Place ID inválido."); return end
    if serverType=="Empty" then joinEmptyServer(pid)
    elseif serverType=="Biggest" then joinBiggestServer(pid)
    elseif serverType=="Your Private" then joinMyPrivateServer(pid)
    else
        notify("Entrar","Procurando...",3)
        task.spawn(function()
            local servers, err = fetchServers(pid, 100)
            if servers and #servers>0 then
                local list={}; for _,v in ipairs(servers) do if v.playing<v.maxPlayers then table.insert(list,v.id) end end
                if #list>0 then TeleportService:TeleportToPlaceInstance(pid,list[math.random(#list)],LP); return end
            end
            TeleportService:Teleport(pid,LP)
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  FRIENDS — CORRIGIDO
-- ══════════════════════════════════════════════════════════════
local FRIENDS_CACHE = {}
local FRIENDS_SELECTED_RAW = nil

local function updateFriendsList()
    FRIENDS_CACHE = {}
    task.spawn(function()
        local success, friends = pcall(function()
            return LP:GetFriendsOnline(200)
        end)
        local list = {}
        if success and friends and type(friends) == "table" then
            for _, f in ipairs(friends) do
                local name = tostring(f.UserName or f.Username or "Desconhecido")
                local placeId = f.PlaceId and tonumber(f.PlaceId) or nil
                local jobId = tostring(f.GameInstanceId or "")
                -- Se jobId estiver vazio, pode ser que o amigo esteja em um jogo mas a API não retornou
                -- Vamos armazenar mesmo assim
                local label
                if placeId and placeId ~= 0 then
                    if jobId ~= "" then
                        label = name .. " — Place " .. placeId .. " (com servidor)"
                    else
                        label = name .. " — Place " .. placeId .. " (servidor desconhecido)"
                    end
                else
                    label = name .. " — Online (Lobby)"
                end
                FRIENDS_CACHE[name] = { placeId = placeId, jobId = jobId }
                table.insert(list, label)
            end
        end
        if #list == 0 then
            list = { "Nenhum amigo online" }
        end
        if Options.FriendsList then
            Options.FriendsList:SetValues(list)
            Options.FriendsList:SetValue(list[1])
        end
    end)
end

local function joinFriendGame(serverType)
    if not FRIENDS_SELECTED_RAW then
        notify("Amigos", "Selecione um amigo.")
        return
    end
    -- Extrai o nome antes do " — "
    local name = tostring(FRIENDS_SELECTED_RAW):match("^(.-)%s—%s")
    if not name then
        -- Fallback: se não encontrar, usa o texto inteiro (útil se o formato mudar)
        name = FRIENDS_SELECTED_RAW
    end
    name = name:gsub("%s+$", "")
    local info = FRIENDS_CACHE[name]
    if not info then
        notify("Amigos", "Amigo não encontrado no cache. Tente atualizar a lista.")
        return
    end
    if not info.placeId or info.placeId == 0 then
        notify("Amigos", "Amigo não está em nenhum jogo.")
        return
    end
    if serverType == "friend" then
        if info.jobId and info.jobId ~= "" then
            notify("Amigos", "Entrando no servidor do amigo...", 4)
            TeleportService:TeleportToPlaceInstance(info.placeId, info.jobId, LP)
        else
            -- Fallback: oferecer opções
            notify("Amigos", "ID de instância não disponível. Deseja entrar em um servidor público?", 5)
            -- Podemos criar um prompt aqui, mas por simplicidade vamos para público
            joinByPlaceId(tostring(info.placeId), "Public")
        end
    elseif serverType == "empty" then
        joinEmptyServer(info.placeId)
    elseif serverType == "biggest" then
        joinBiggestServer(info.placeId)
    else
        joinByPlaceId(tostring(info.placeId), "Public")
    end
end

-- ══════════════════════════════════════════════════════════════
--  MÚSICA (COM RECARREGAR)
-- ══════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
--  TAB: MÚSICA (REFATORADA)
-- ══════════════════════════════════════════════════════════════
local MGL = Tabs.Music:AddLeftGroupbox("Player de Música", "music")
MGL:AddLabel("Tocando: None", true, "NowPlaying")

-- Campo para Asset ID
MGL:AddInput("MusicURL", {
    Text = "Asset ID / rbxassetid://",
    Placeholder = "ex: 9120381428",
    ClearTextOnFocus = false,
    Callback = function() end
})
MGL:AddInput("MusicTitle", {
    Text = "Título Personalizado",
    Placeholder = "opcional",
    ClearTextOnFocus = false,
    Callback = function() end
})
MGL:AddButton({ Text = "▶  Tocar URL", Func = function()
    local url = getOpt("MusicURL", "")
    local title = getOpt("MusicTitle", "")
    if url == "" then
        notify("Música", "Digite um Asset ID.")
        return
    end
    playMusic(url, title)
end })

-- Arquivos locais
MGL:AddDivider()
MGL:AddLabel("Arquivos locais (pasta R3dHub/Music):")

-- Dropdown para selecionar arquivo local
local musicFiles = scanMusicFolder()
local fileOptions = #musicFiles > 0 and musicFiles or { "Nenhum arquivo" }
MGL:AddDropdown("LocalMusicFile", {
    Values = fileOptions,
    Default = 1,
    Text = "Selecione um arquivo",
    Callback = function() end
})

MGL:AddButton({ Text = "▶ Tocar Selecionado", Func = function()
    local selected = getOpt("LocalMusicFile")
    if not selected or selected == "Nenhum arquivo" then
        notify("Música", "Selecione um arquivo válido.")
        return
    end
    playMusic(selected, selected)
end })

MGL:AddButton({ Text = "🔄 Recarregar Lista", Func = function()
    local newFiles = scanMusicFolder()
    if #newFiles == 0 then
        Options.LocalMusicFile:SetValues({ "Nenhum arquivo" })
        Options.LocalMusicFile:SetValue("Nenhum arquivo")
    else
        Options.LocalMusicFile:SetValues(newFiles)
        Options.LocalMusicFile:SetValue(newFiles[1])
    end
    notify("Música", "Lista recarregada.", 2)
end })

MGL:AddDivider()
MGL:AddButton({ Text = "⏹ Parar", Func = stopMusic })
MGL:AddSlider("MusicVolume", {
    Text = "Volume",
    Default = 50,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = function(v) setMusicVolume(v) end
})

local MGR = Tabs.Music:AddRightGroupbox("Uso", "info")
MGR:AddLabel([[Digite um Asset ID do Roblox (apenas números) ou rbxassetid://...

Para arquivos locais, coloque-os na pasta R3dHub/Music (MP3, OGG, WAV) e use o dropdown acima.]], false)

-- ══════════════════════════════════════════════════════════════
--  JANELA
-- ══════════════════════════════════════════════════════════════
local Window=Library:CreateWindow({
    Title="R3d Hub  v6.1",
    Footer="by R3dL3ss",
    NotifySide="Right",
    ShowCustomCursor=true,
})

local Tabs={
    Character      =Window:AddTab("Personagem","user"),
    ESP            =Window:AddTab("ESP","eye"),
    Players        =Window:AddTab("Jogadores","users"),
    Server         =Window:AddTab("Servidor","server"),
    Friends        =Window:AddTab("Amigos","heart"),
    Music          =Window:AddTab("Música","music"),
    Visual         =Window:AddTab("Visual","star"),
    ["UI Settings"]=Window:AddTab("Config UI","settings"),
}

-- ══════════════════════════════════════════════════════════════
--  TAB: PERSONAGEM
-- ══════════════════════════════════════════════════════════════
local CGL=Tabs.Character:AddLeftGroupbox("Movimento","package")
CGL:AddToggle("Flight",{Text="Voo (WASD+Q/E, Shift=boost)",Default=false,Callback=function(v) if v then startFlight() else stopFlight() end end})
CGL:AddSlider("FlightSpeed",{Text="Velocidade de Voo",Default=50,Min=5,Max=500,Rounding=0,Suffix=" st/s",Callback=function() end})
CGL:AddDivider()
CGL:AddToggle("WalkSpeed",{Text="Boost de Velocidade",Default=false,Callback=function(v) if v then applyWalkSpeed() else resetWalkSpeed() end end})
CGL:AddSlider("WalkSpeedValue",{Text="WalkSpeed",Default=50,Min=1,Max=500,Rounding=0,Suffix=" st/s",Callback=function() if getToggle("WalkSpeed") then applyWalkSpeed() end end})
CGL:AddDivider()
CGL:AddToggle("JumpBoost",{Text="Boost de Pulo",Default=false,Callback=function(v) if v then applyJump() else resetJump() end end})
CGL:AddSlider("JumpHeightValue",{Text="Jump Height",Default=50,Min=1,Max=500,Rounding=0,Suffix=" st",Callback=function() if getToggle("JumpBoost") then applyJump() end end})
CGL:AddSlider("JumpPowerValue",{Text="Jump Power",Default=100,Min=1,Max=1000,Rounding=0,Callback=function() if getToggle("JumpBoost") then applyJump() end end})
CGL:AddDivider()
CGL:AddToggle("InfJump",{Text="Pulo Infinito",Default=false,Callback=function(v) if v then startInfJump() else stopInfJump() end end})
CGL:AddToggle("Noclip",{Text="Noclip",Default=false,Callback=function(v) if v then startNoclip() else stopNoclip() end end})
CGL:AddDivider()
CGL:AddToggle("AirStand",{Text="Plataforma Aérea (espaço no ar)",Default=false,Callback=function(v) if v then startAirStand() else stopAirStand() end end})
CGL:AddDivider()
CGL:AddToggle("TPMouse",{Text="Teleporte para o Mouse",Default=false,Callback=function(v) if v then startTPMouse() else stopTPMouse() end end})
CGL:AddLabel("Tecla do TP"):AddKeyPicker("TPMouseKey",{Default="F",NoUI=true,Text="TP Mouse Key"})
CGL:AddToggle("ClickTP",{Text="Click TP (botão esquerdo)",Default=false,Callback=function(v) if v then startClickTP() else stopClickTP() end end})
CGL:AddDivider()
CGL:AddToggle("FallDamage",{Text="Sem Dano de Queda",Default=false,Callback=function(v) if v then startFallDamage() else stopFallDamage() end end})

local CGR=Tabs.Character:AddRightGroupbox("Habilidades","star")
CGR:AddToggle("Freecam",{Text="Freecam",Default=false,Callback=function(v) if v then startFreecam() else stopFreecam() end end})
CGR:AddSlider("FreecamSpeed",{Text="Velocidade Freecam",Default=60,Min=5,Max=500,Rounding=0,Suffix=" st/s",Callback=function() end})
CGR:AddDivider()
CGR:AddToggle("GravityControl",{Text="Controle de Gravidade",Default=false,Callback=function(v) if v then setGravity(getOpt("GravityValue",30)) else resetGravity() end end})
CGR:AddSlider("GravityValue",{Text="Gravidade",Default=30,Min=0,Max=500,Rounding=0,Suffix=" st/s²",Callback=function(v) if getToggle("GravityControl") then setGravity(v) end end})
CGR:AddDivider()
CGR:AddSlider("FOVSlider",{Text="FOV",Default=70,Min=30,Max=120,Rounding=0,Suffix="°",Callback=function(v) Camera.FieldOfView=v end})
CGR:AddDivider()
CGR:AddToggle("Thirdperson",{Text="Terceira Pessoa",Default=false,Callback=function(v) if v then startThirdperson() else stopThirdperson() end end})
CGR:AddSlider("ThirdpersonDist",{Text="Distância da Câmera",Default=12,Min=4,Max=50,Rounding=0,Callback=function(v)
    if Modules.Thirdperson.Active then LP.CameraMinZoomDistance=v; LP.CameraMaxZoomDistance=v end
end})
CGR:AddDivider()
CGR:AddToggle("AntiAFK",{Text="Anti-AFK",Default=false,Callback=function(v) if v then startAntiAFK() else stopAntiAFK() end end})
CGR:AddDivider()
CGR:AddButton({Text="Recarregar Personagem",Func=refreshCharacter})
CGR:AddButton({Text="Copiar Posição",Func=function()
    local hrp=getHRP(); if not hrp then return end
    local p=hrp.Position; local s=("%.2f, %.2f, %.2f"):format(p.X,p.Y,p.Z)
    copyClipboard(s); notify("Posição",s,4)
end})
CGR:AddButton({Text="Resetar FOV",Func=function() Camera.FieldOfView=70 end})
CGR:AddButton({Text="Resetar Gravidade",Func=function() resetGravity(); notify("Gravidade","Resetada.",2) end})
CGR:AddButton({Text="Matar Personagem",Func=function() local h=getHum(); if h then h.Health=0 end end})

-- ══════════════════════════════════════════════════════════════
--  TAB: ESP
-- ══════════════════════════════════════════════════════════════
local EGL=Tabs.ESP:AddLeftGroupbox("Configurações ESP","eye")
EGL:AddToggle("ESPEnabled",{Text="Ativar ESP",Default=false,Callback=function(v) if v then startESP() else stopESP() end end})
EGL:AddDivider()
EGL:AddToggle("ESPBox",{Text="Caixa (Highlight)",Default=true,Callback=function() end})
EGL:AddToggle("ESPName",{Text="Nome",Default=true,Callback=function() end})
EGL:AddToggle("ESPHealth",{Text="Barra de Vida",Default=true,Callback=function() end})
EGL:AddToggle("ESPDistance",{Text="Distância",Default=true,Callback=function() end})
EGL:AddToggle("ESPTracer",{Text="Tracer (centro tela)",Default=false,Callback=function() end})
EGL:AddToggle("ESP3DBox",{Text="Caixa 3D (hitbox)",Default=false,Callback=function() end})
EGL:AddToggle("ESPLine",{Text="Linha (corda)",Default=false,Callback=function() end})
EGL:AddToggle("ESPTeamCheck",{Text="Ocultar Aliados",Default=false,Callback=function() end})
EGL:AddDivider()
EGL:AddSlider("ESPMaxDist",{Text="Distância Máxima",Default=1000,Min=50,Max=5000,Rounding=0,Suffix=" m",Callback=function() end})
EGL:AddSlider("ESPFillTransp",{Text="Transp. Preenchimento",Default=60,Min=0,Max=100,Rounding=0,Suffix="%",Callback=function(v) ESP_CFG.fillTransp=v/100 end})
EGL:AddSlider("ESPOutlineTransp",{Text="Transp. Contorno",Default=0,Min=0,Max=100,Rounding=0,Suffix="%",Callback=function(v) ESP_CFG.outlineTransp=v/100 end})

local EGR=Tabs.ESP:AddRightGroupbox("Cores ESP","palette")
EGR:AddLabel("Preenchimento"):AddColorPicker("ESPFillColor",{Default=Color3.fromRGB(255,50,50),Callback=function(v) ESP_CFG.fillColor=v end})
EGR:AddDivider()
EGR:AddLabel("Contorno"):AddColorPicker("ESPOutlineColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) ESP_CFG.outlineColor=v end})
EGR:AddDivider()
EGR:AddLabel("Tracer"):AddColorPicker("ESPTracerColor",{Default=Color3.fromRGB(255,255,255),Callback=function(v) ESP_CFG.tracerColor=v end})
EGR:AddDivider()
EGR:AddLabel("Caixa 3D"):AddColorPicker("ESPBoxColor",{Default=Color3.fromRGB(0,255,255),Callback=function(v) ESP_CFG.boxColor=v end})
EGR:AddDivider()
EGR:AddLabel("Linha (corda)"):AddColorPicker("ESPLineColor",{Default=Color3.fromRGB(255,200,0),Callback=function(v) ESP_CFG.lineColor=v end})
EGR:AddDivider()
EGR:AddButton({Text="Atualizar ESP",Func=function()
    if Modules.ESP.Active then
        for p,_ in pairs(Modules.ESP.Highlights) do removeESPPlayer(p) end
        for _,p in ipairs(Players:GetPlayers()) do addESPPlayer(p) end
        notify("ESP","Atualizado.",2)
    end
end})

-- ══════════════════════════════════════════════════════════════
--  TAB: JOGADORES
-- ══════════════════════════════════════════════════════════════
local PGL=Tabs.Players:AddLeftGroupbox("Ações","users")
PGL:AddDropdown("SelectedPlayer",{SpecialType="Player",ExcludeLocalPlayer=false,Text="Selecionar Jogador",Default=1,Callback=function(p) G_SELECTED_PLAYER=p end})
PGL:AddDivider()
PGL:AddButton({Text="Teleportar para Jogador",Func=function() teleportToPlayer(G_SELECTED_PLAYER) end})
PGL:AddToggle("FollowPlayer",{Text="Seguir Jogador",Default=false,Callback=function(v) if v then teleportToPlayer(G_SELECTED_PLAYER) end end})
PGL:AddToggle("Hide",{Text="Esconder Jogador",Default=false,Callback=function(v) toggleHidePlayer(G_SELECTED_PLAYER,v) end})
PGL:AddToggle("Spectate",{Text="Espectar Jogador",Default=false,Callback=function(v) if v then startSpectate(G_SELECTED_PLAYER) else stopSpectate() end end})
PGL:AddDivider()
PGL:AddButton({Text="Copiar UserID",Func=function()
    if not G_SELECTED_PLAYER then notify("Jogadores","Selecione um jogador."); return end
    copyClipboard(tostring(G_SELECTED_PLAYER.UserId)); notify("UserID",G_SELECTED_PLAYER.UserId,4)
end})
PGL:AddButton({Text="Copiar DisplayName",Func=function()
    if not G_SELECTED_PLAYER then notify("Jogadores","Selecione um jogador."); return end
    copyClipboard(G_SELECTED_PLAYER.DisplayName); notify("Nome",G_SELECTED_PLAYER.DisplayName,3)
end})

local PGR=Tabs.Players:AddRightGroupbox("Informações","info")
PGR:AddLabel("Nenhum jogador selecionado.",true,"PlayerInfoLabel")

task.spawn(function()
    while task.wait(0.5) do
        safeCall(function()
            if not Options.PlayerInfoLabel then return end
            if not G_SELECTED_PLAYER then Options.PlayerInfoLabel:SetText("Nenhum jogador selecionado."); return end
            local c=G_SELECTED_PLAYER.Character
            local hrp=c and c:FindFirstChild("HumanoidRootPart")
            local h=c and c:FindFirstChildWhichIsA("Humanoid")
            local myHRP=getHRP()
            local dist=(hrp and myHRP) and math.floor((myHRP.Position-hrp.Position).Magnitude) or 0
            local pos=hrp and ("%.0f, %.0f, %.0f"):format(hrp.Position.X,hrp.Position.Y,hrp.Position.Z) or "N/A"
            local hp=h and (math.floor(h.Health).."/"..math.floor(h.MaxHealth)) or "N/A"
            Options.PlayerInfoLabel:SetText(
                G_SELECTED_PLAYER.DisplayName.." (@"..G_SELECTED_PLAYER.Name..")\n"..
                "HP: "..hp.." | Dist: "..dist.."m\nPos: "..pos.."\nID: "..G_SELECTED_PLAYER.UserId)
        end)
    end
end)
task.spawn(function()
    while task.wait(0.25) do
        if getToggle("FollowPlayer") then safeCall(teleportToPlayer,G_SELECTED_PLAYER) end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  TAB: SERVIDOR
-- ══════════════════════════════════════════════════════════════
local SGL=Tabs.Server:AddLeftGroupbox("Info do Servidor","server")
SGL:AddLabel("Jogadores: ...",true,"ServerPlayers")
SGL:AddLabel("Ping: ...",true,"ServerPing")
SGL:AddLabel("Tempo: ...",true,"ServerUptime")
SGL:AddLabel("Place: "..game.PlaceId,false)
SGL:AddLabel("Job: ...",true,"ServerJobId")

task.spawn(function()
    while task.wait(0.5) do
        safeCall(function()
            local ping=math.floor(LP:GetNetworkPing()*1000)
            local icon=ping<80 and "🟢" or ping<150 and "🟡" or "🔴"
            if Options.ServerPlayers then Options.ServerPlayers:SetText("Jogadores: "..#Players:GetPlayers().."/"..Players.MaxPlayers) end
            if Options.ServerPing    then Options.ServerPing:SetText("Ping: "..icon.." "..ping.." ms") end
            if Options.ServerUptime  then Options.ServerUptime:SetText("Tempo: "..formatUptime()) end
            if Options.ServerJobId   then Options.ServerJobId:SetText("Job: "..game.JobId:sub(1,16).."...") end
        end)
    end
end)

local SGL2=Tabs.Server:AddLeftGroupbox("Navegação","compass")
SGL2:AddButton({Text="Reconectar",Func=rejoinServer})
SGL2:AddButton({Text="Trocar Servidor",Func=switchServer})
SGL2:AddButton({Text="Servidor com Menos Players",Func=function() joinEmptyServer(game.PlaceId) end})
SGL2:AddButton({Text="Servidor Mais Cheio",Func=function() joinBiggestServer(game.PlaceId) end})
SGL2:AddButton({Text="Meu Servidor Privado",Func=function() joinMyPrivateServer(game.PlaceId) end})
SGL2:AddDivider()
SGL2:AddInput("JoinPlaceId",{Text="Place ID",Placeholder="ex: 1818",ClearTextOnFocus=false,Callback=function() end})
SGL2:AddDropdown("JoinServerType",{Values={"Public","Empty","Biggest","Your Private"},Default="Public",Text="Tipo",Callback=function() end})
SGL2:AddButton({Text="Entrar",Func=function() joinByPlaceId(getOpt("JoinPlaceId",""),getOpt("JoinServerType","Public")) end})
SGL2:AddDivider()
SGL2:AddButton({Text="Copiar Job ID",Func=function() copyClipboard(game.JobId); notify("Copiado",game.JobId,3) end})
SGL2:AddButton({Text="Copiar Place ID",Func=function() copyClipboard(tostring(game.PlaceId)); notify("Copiado",tostring(game.PlaceId),3) end})

local SGS=Tabs.Server:AddRightGroupbox("Server Sniper","crosshair")
SGS:AddButton({Text="Menos Jogadores",Func=function() sniperJoin("fewest") end})
SGS:AddButton({Text="Mais Jogadores",Func=function() sniperJoin("biggest") end})
SGS:AddButton({Text="Aleatório",Func=function() sniperJoin("random") end})

-- ══════════════════════════════════════════════════════════════
--  TAB: AMIGOS
-- ══════════════════════════════════════════════════════════════
local FGL=Tabs.Friends:AddLeftGroupbox("Amigos Online","heart")
FGL:AddDropdown("FriendsList",{Values={"Carregando..."},Default=1,Text="Amigo",Searchable=true,Callback=function(v) FRIENDS_SELECTED_RAW=v end})
FGL:AddButton({Text="🔄 Atualizar Lista",Func=updateFriendsList})
FGL:AddDivider()
FGL:AddDropdown("FriendJoinType",{
    Values={"Servidor do Amigo","Servidor Público","Servidor Vazio","Servidor Mais Cheio"},
    Default="Servidor do Amigo",Text="Tipo de Entrada",
    Callback=function() end
})
FGL:AddButton({Text="Entrar",Func=function()
    local jt=getOpt("FriendJoinType","Servidor do Amigo")
    if jt=="Servidor do Amigo" then joinFriendGame("friend")
    elseif jt=="Servidor Vazio" then joinFriendGame("empty")
    elseif jt=="Servidor Mais Cheio" then joinFriendGame("biggest")
    else joinFriendGame("public") end
end})

local FGR=Tabs.Friends:AddRightGroupbox("Info do Amigo","info")
FGR:AddLabel("Selecione um amigo.",true,"FriendInfo")

task.spawn(function()
    task.wait(2); updateFriendsList()
    while task.wait(60) do updateFriendsList() end
end)

task.spawn(function()
    while task.wait(1) do
        safeCall(function()
            if not FRIENDS_SELECTED_RAW or not Options.FriendInfo then return end
            local name=(tostring(FRIENDS_SELECTED_RAW):match("^(.-)%s+%-%-") or FRIENDS_SELECTED_RAW):gsub("%s+$","")
            local info=FRIENDS_CACHE[name]
            if info then
                local gs=info.placeId and ("Place: "..tostring(info.placeId)) or "Não está em jogo"
                local js=(info.jobId and info.jobId~="") and "✔ Servidor disponível" or "✘ Sem ID de instância"
                Options.FriendInfo:SetText(name.."\n"..gs.."\n"..js)
            else
                Options.FriendInfo:SetText(name.."\nSem info.")
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  TAB: MÚSICA
-- ══════════════════════════════════════════════════════════════
local MGL=Tabs.Music:AddLeftGroupbox("Player de Música","music")
MGL:AddLabel("Tocando: None",true,"NowPlaying")
MGL:AddInput("MusicURL",{Text="Asset ID / rbxassetid://",Placeholder="ex: 9120381428",ClearTextOnFocus=false,Callback=function() end})
MGL:AddInput("MusicTitle",{Text="Título Personalizado",Placeholder="opcional",ClearTextOnFocus=false,Callback=function() end})
MGL:AddButton({Text="▶  Tocar",Func=function()
    local url=getOpt("MusicURL",""); local title=getOpt("MusicTitle","")
    if url=="" then notify("Música","Digite um Asset ID."); return end
    playMusic(url,title)
end})
MGL:AddButton({Text="⏹  Parar",Func=stopMusic})
MGL:AddSlider("MusicVolume",{Text="Volume",Default=50,Min=0,Max=100,Rounding=0,Suffix="%",Callback=function(v) setMusicVolume(v) end})
MGL:AddDivider()
MGL:AddLabel("Músicas na pasta R3dHub/Music:")
local musicFiles = scanMusicFolder()
if #musicFiles == 0 then
    MGL:AddLabel("Nenhum arquivo encontrado.", false)
else
    for _, file in ipairs(musicFiles) do
        MGL:AddButton({Text="▶ "..file, Func=function()
            -- Reproduzir arquivo local (requer getcustomasset)
            if not getcustomasset then notify("Música","Seu executor não suporta getcustomasset.",3); return end
            local path = "R3dHub/Music/"..file
            if isfile(path) then
                local asset = getcustomasset(path)
                playMusic(asset, file)
            else
                notify("Música","Arquivo não encontrado.",3)
            end
        end})
    end
end
MGL:AddButton({Text="🔄 Recarregar Lista",Func=function()
    -- Recriar a seção de músicas? Simples: destruir e recriar os botões.
    -- Como é complexo, vamos apenas notificar e sugerir reiniciar a aba.
    notify("Música","Reinicie a aba para recarregar.",3)
end})

local MGR=Tabs.Music:AddRightGroupbox("Uso","info")
MGR:AddLabel("Digite um Asset ID do Roblox (apenas números) ou rbxassetid://...\n\nPara arquivos locais, coloque-os na pasta R3dHub/Music (MP3, OGG, WAV).",false)

-- ══════════════════════════════════════════════════════════════
--  TAB: VISUAL
-- ══════════════════════════════════════════════════════════════
local VGL=Tabs.Visual:AddLeftGroupbox("Cosméticos","palette")
VGL:AddToggle("Heart",{Text="Coração Undertale",Default=false,Callback=function(v) if v then startHeart() else stopHeart() end end})
VGL:AddDivider()
VGL:AddToggle("SelfHL",{Text="Auto Highlight",Default=false,Callback=function(v)
    if v then
        local char=getChar(); if not char then return end
        local hl=Instance.new("Highlight"); hl.Name="R3dSelfHL"; hl.Adornee=char
        hl.FillColor=Options.SelfHLFill and Options.SelfHLFill.Value or Color3.fromRGB(0,200,255)
        hl.OutlineColor=Options.SelfHLOutline and Options.SelfHLOutline.Value or Color3.fromRGB(255,255,255)
        hl.FillTransparency=0.5; hl.OutlineTransparency=0
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
        Modules.SelfHL.Object=hl; Modules.SelfHL.Active=true
        table.insert(HubObjects.Highlights, hl)
    else
        if Modules.SelfHL.Object then Modules.SelfHL.Object:Destroy(); Modules.SelfHL.Object=nil end
        Modules.SelfHL.Active=false
    end
end})
VGL:AddLabel("Cor do Auto Highlight"):AddColorPicker("SelfHLFill",{Default=Color3.fromRGB(0,200,255),
    Callback=function(v) if Modules.SelfHL.Object then Modules.SelfHL.Object.FillColor=v end end})
VGL:AddLabel("Contorno"):AddColorPicker("SelfHLOutline",{Default=Color3.fromRGB(255,255,255),
    Callback=function(v) if Modules.SelfHL.Object then Modules.SelfHL.Object.OutlineColor=v end end})
VGL:AddDivider()
VGL:AddSlider("HeadSize",{Text="Tamanho da Cabeça",Default=100,Min=10,Max=500,Rounding=0,Suffix="%",Callback=function(v) setHeadSize(v/100) end})

local VGR=Tabs.Visual:AddRightGroupbox("Mundo & Performance","cpu")
VGR:AddToggle("FPSBoost",{Text="FPS Booster",Default=false,Callback=function(v) if v then applyFPSBoost() else removeFPSBoost() end end})
VGR:AddButton({Text="Iluminar Tudo",Func=function()
    Lighting.Ambient=Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
    Lighting.Brightness=10
    notify("Iluminação","Maximizada.",3)
end})
VGR:AddButton({Text="Resetar Iluminação",Func=function()
    Lighting.Ambient=Color3.fromRGB(0,0,0)
    Lighting.OutdoorAmbient=Color3.fromRGB(128,128,128)
    Lighting.Brightness=1
    notify("Iluminação","Resetada.",3)
end})
VGR:AddButton({Text="Limpar FX do Workspace",Func=function()
    local n=0
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v:Destroy(); n=n+1
        end
    end
    notify("FX","Removidos "..n.." efeitos.",3)
end})
VGR:AddDivider()

-- Skybox Custom
VGR:AddLabel("Skybox (Asset IDs)")
VGR:AddInput("SkyboxRt",{Text="Direita",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddInput("SkyboxLf",{Text="Esquerda",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddInput("SkyboxUp",{Text="Topo",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddInput("SkyboxDn",{Text="Fundo",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddInput("SkyboxFt",{Text="Frente",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddInput("SkyboxBk",{Text="Trás",Placeholder="ID",ClearTextOnFocus=false,Callback=function() end})
VGR:AddButton({Text="Aplicar Skybox",Func=function()
    local ids={
        Rt=getOpt("SkyboxRt",""), Lf=getOpt("SkyboxLf",""), Up=getOpt("SkyboxUp",""),
        Dn=getOpt("SkyboxDn",""), Ft=getOpt("SkyboxFt",""), Bk=getOpt("SkyboxBk",""),
    }
    applySkybox(ids); notify("Skybox","Aplicada.",3)
end})
VGR:AddButton({Text="Remover Skybox",Func=removeSkybox})

-- Controle de Horário
VGR:AddDivider()
VGR:AddLabel("Horário")
VGR:AddSlider("TimeOfDay",{Text="Hora",Default=14,Min=0,Max=24,Rounding=1,Suffix="h",Callback=function(v) setTimeOfDay(v) end})
VGR:AddButton({Text="Resetar Horário",Func=resetTimeOfDay})

-- ══════════════════════════════════════════════════════════════
--  TAB: CONFIG UI
-- ══════════════════════════════════════════════════════════════
local UIG=Tabs["UI Settings"]:AddLeftGroupbox("Menu","settings")
UIG:AddToggle("KeybindMenuOpen",{Default=Library.KeybindFrame and Library.KeybindFrame.Visible or false,
    Text="Mostrar Menu de Teclas",Callback=function(v) if Library.KeybindFrame then Library.KeybindFrame.Visible=v end end})
UIG:AddToggle("ShowCustomCursor",{Text="Cursor Personalizado",Default=true,Callback=function(v) Library.ShowCustomCursor=v end})
UIG:AddDropdown("NotificationSide",{Values={"Left","Right"},Default="Right",Text="Lado das Notificações",
    Callback=function(v) Library:SetNotifySide(v) end})
UIG:AddDropdown("DPIDropdown",{Values={"75","100","125","150","175","200"},Default="100",Text="DPI (%)",
    Callback=function(v) local n=tonumber(v); if n then Library:SetDPIScale(n) end end})
UIG:AddDivider()
UIG:AddLabel("Tecla do Menu"):AddKeyPicker("MenuKeybind",{Default="RightShift",NoUI=true,Text="Toggle Menu"})
UIG:AddDivider()

-- Keybinds
UIG:AddLabel("Teclas de Ações")
UIG:AddLabel("Flight"):AddKeyPicker("KeyFlight",{Default=nil,NoUI=true,Text="Flight",
    Callback=function() Toggles.Flight:SetValue(not Toggles.Flight.Value) end})
UIG:AddLabel("Noclip"):AddKeyPicker("KeyNoclip",{Default=nil,NoUI=true,Text="Noclip",
    Callback=function() Toggles.Noclip:SetValue(not Toggles.Noclip.Value) end})
UIG:AddLabel("Freecam"):AddKeyPicker("KeyFreecam",{Default=nil,NoUI=true,Text="Freecam",
    Callback=function() Toggles.Freecam:SetValue(not Toggles.Freecam.Value) end})
UIG:AddLabel("InfJump"):AddKeyPicker("KeyInfJump",{Default=nil,NoUI=true,Text="InfJump",
    Callback=function() Toggles.InfJump:SetValue(not Toggles.InfJump.Value) end})
UIG:AddLabel("TPMouse"):AddKeyPicker("KeyTPMouse",{Default=nil,NoUI=true,Text="TPMouse",
    Callback=function() Toggles.TPMouse:SetValue(not Toggles.TPMouse.Value) end})
UIG:AddLabel("ClickTP"):AddKeyPicker("KeyClickTP",{Default=nil,NoUI=true,Text="ClickTP",
    Callback=function() Toggles.ClickTP:SetValue(not Toggles.ClickTP.Value) end})
UIG:AddLabel("AirStand"):AddKeyPicker("KeyAirStand",{Default=nil,NoUI=true,Text="AirStand",
    Callback=function() Toggles.AirStand:SetValue(not Toggles.AirStand.Value) end})
UIG:AddLabel("FallDamage"):AddKeyPicker("KeyFallDamage",{Default=nil,NoUI=true,Text="FallDamage",
    Callback=function() Toggles.FallDamage:SetValue(not Toggles.FallDamage.Value) end})
UIG:AddLabel("Thirdperson"):AddKeyPicker("KeyThirdperson",{Default=nil,NoUI=true,Text="Thirdperson",
    Callback=function() Toggles.Thirdperson:SetValue(not Toggles.Thirdperson.Value) end})
UIG:AddLabel("Heart"):AddKeyPicker("KeyHeart",{Default=nil,NoUI=true,Text="Heart",
    Callback=function() Toggles.Heart:SetValue(not Toggles.Heart.Value) end})
UIG:AddLabel("ESP"):AddKeyPicker("KeyESP",{Default=nil,NoUI=true,Text="ESP",
    Callback=function() Toggles.ESPEnabled:SetValue(not Toggles.ESPEnabled.Value) end})
UIG:AddLabel("SpeedHUD"):AddKeyPicker("KeySpeedHUD",{Default=nil,NoUI=true,Text="SpeedHUD",
    Callback=function() Toggles.SpeedDisplay:SetValue(not Toggles.SpeedDisplay.Value) end})
UIG:AddLabel("ClockHUD"):AddKeyPicker("KeyClockHUD",{Default=nil,NoUI=true,Text="ClockHUD",
    Callback=function() Toggles.ClockDisplay:SetValue(not Toggles.ClockDisplay.Value) end})
UIG:AddLabel("FPSCounter"):AddKeyPicker("KeyFPSCounter",{Default=nil,NoUI=true,Text="FPSCounter",
    Callback=function() Toggles.FPSCounter:SetValue(not Toggles.FPSCounter.Value) end})

local QG=Tabs["UI Settings"]:AddRightGroupbox("Ferramentas QoL","tool")
QG:AddToggle("SpeedDisplay",{Text="HUD de Velocidade",Default=false,Callback=function(v) if v then startSpeedDisplay() else stopSpeedDisplay() end end})
QG:AddToggle("ClockDisplay",{Text="HUD de Relógio",Default=false,Callback=function(v) if v then startClock() else stopClock() end end})
QG:AddToggle("FPSCounter",{Text="Contador de FPS",Default=false,Callback=function(v) if v then startFPSCounter() else stopFPSCounter() end end})
QG:AddDivider()
QG:AddButton({Text="Esconder/Mostrar UI do Jogo",Func=toggleHideUI})
QG:AddButton({Text="Descarregar Hub",Func=unloadHub})
QG:AddDivider()
QG:AddButton({Text="Limpar Chat",Func=function()
    safeCall(function() StarterGui:SetCore("ChatActive",false); task.wait(0.1); StarterGui:SetCore("ChatActive",true) end)
    notify("Chat","Limpo.",2)
end})

Library.ToggleKeybind=Options.MenuKeybind

-- ══════════════════════════════════════════════════════════════
--  ADDONS
-- ══════════════════════════════════════════════════════════════
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
    "MenuKeybind","TPMouseKey","KeyFlight","KeyNoclip","KeyFreecam",
    "KeyInfJump","KeyTPMouse","KeyClickTP","KeyAirStand","KeyFallDamage","KeyThirdperson","KeyHeart",
    "KeyESP","KeySpeedHUD","KeyClockHUD","KeyFPSCounter"
})
ThemeManager:SetFolder("R3dHub")
SaveManager:SetFolder("R3dHub/v6")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

-- ══════════════════════════════════════════════════════════════
--  HOOK DE RESPAWN
-- ══════════════════════════════════════════════════════════════
LP.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local h=char:FindFirstChildWhichIsA("Humanoid")
    if h then
        ORIG_WS=h.WalkSpeed; ORIG_JH=h.JumpHeight; ORIG_JP=h.JumpPower
    end
    if getToggle("WalkSpeed") then applyWalkSpeed() end
    if getToggle("JumpBoost") then applyJump() end
    if getToggle("Flight") then startFlight() end
    if getToggle("Noclip") then startNoclip() end
    if getToggle("InfJump") then startInfJump() end
    if getToggle("AirStand") then startAirStand() end
    if getToggle("TPMouse") then startTPMouse() end
    if getToggle("ClickTP") then startClickTP() end
    if getToggle("FallDamage") then startFallDamage() end
    if getToggle("SelfHL") then
        local hl=Instance.new("Highlight"); hl.Name="R3dSelfHL"; hl.Adornee=char
        hl.FillColor=Options.SelfHLFill and Options.SelfHLFill.Value or Color3.fromRGB(0,200,255)
        hl.OutlineColor=Options.SelfHLOutline and Options.SelfHLOutline.Value or Color3.fromRGB(255,255,255)
        hl.FillTransparency=0.5; hl.OutlineTransparency=0
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
        Modules.SelfHL.Object=hl
        table.insert(HubObjects.Highlights, hl)
    end
    if getToggle("Heart") then
        if HubObjects.Heart then HubObjects.Heart:Destroy() end
        createHeart()
    end
    if getToggle("Thirdperson") then startThirdperson() end
    if getToggle("ESPEnabled") then
        for _,p in ipairs(Players:GetPlayers()) do addESPPlayer(p) end
    end
    if getToggle("SpeedDisplay") then startSpeedDisplay() end
    if getToggle("ClockDisplay") then startClock() end
    if getToggle("FPSCounter") then startFPSCounter() end
    if getToggle("Spectate") and SPECTATE_TARGET then startSpectate(SPECTATE_TARGET) end
    for target,hidden in pairs(HIDDEN_PLAYERS) do
        if hidden and target.Character then target.Character.Parent=nil end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  INICIALIZAÇÃO
-- ══════════════════════════════════════════════════════════════
Library:Notify({
    Title="R3d Hub v6.1",
    Description="Carregado!",
    Duration=6
})

-- Criar pastas de música se necessário
if isfolder and not isfolder("R3dHub") then makefolder("R3dHub") end
if isfolder and not isfolder("R3dHub/Music") then makefolder("R3dHub/Music") end
