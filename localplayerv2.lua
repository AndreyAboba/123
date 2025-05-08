-- Модуль LocalPlayer: Timer, Disabler, Speed, TickSpeed, HighJump, NoRagdoll, FastAttack
local LocalPlayer = {}

-- Кэшированные сервисы и данные
local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil

-- Локальная конфигурация модуля
LocalPlayer.Config = {
    Timer = {
        Enabled = false,
        Speed = 2.5,
        ToggleKey = nil
    },
    Disabler = {
        Enabled = false,
        ToggleKey = nil
    },
    Speed = {
        Enabled = false,
        AutoJump = false,
        FakeJump = false,
        Method = "Velocity",
        Speed = 16,
        JumpPower = 50,
        JumpInterval = 0.3,
        PulseTPDist = 5,
        PulseTPDelay = 0.2,
        ToggleKey = nil
    },
    TickSpeed = {
        Enabled = false,
        HighSpeedMultiplier = 1.4,
        NormalSpeedMultiplier = 0.1,
        OnDuration = 0.1,
        OffDuration = 0.22,
        ToggleKey = nil
    },
    HighJump = {
        Enabled = false,
        Method = "Velocity",
        JumpPower = 100,
        JumpKey = nil,
        DefaultJumpHeight = 7.5 -- Стандартная высота прыжка в Roblox (примерное значение)
    },
    NoRagdoll = {
        Enabled = false
    },
    FastAttack = {
        Enabled = false
    }
}

-- Состояния модулей
local TimerStatus = { Running = false, Connection = nil, Speed = LocalPlayer.Config.Timer.Speed, Key = LocalPlayer.Config.Timer.ToggleKey, Enabled = LocalPlayer.Config.Timer.Enabled }
local DisablerStatus = { Running = false, Connection = nil, Key = LocalPlayer.Config.Disabler.ToggleKey, Enabled = LocalPlayer.Config.Disabler.Enabled }
local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = LocalPlayer.Config.Speed.ToggleKey,
    Enabled = LocalPlayer.Config.Speed.Enabled,
    Method = LocalPlayer.Config.Speed.Method,
    Speed = LocalPlayer.Config.Speed.Speed,
    AutoJump = LocalPlayer.Config.Speed.AutoJump,
    FakeJump = LocalPlayer.Config.Speed.FakeJump,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpPower = LocalPlayer.Config.Speed.JumpPower,
    JumpInterval = LocalPlayer.Config.Speed.JumpInterval,
    PulseTPDistance = LocalPlayer.Config.Speed.PulseTPDist,
    PulseTPFrequency = LocalPlayer.Config.Speed.PulseTPDelay,
    LastPulseTPTime = 0
}
local TickSpeedStatus = {
    Running = false,
    Connection = nil,
    Key = LocalPlayer.Config.TickSpeed.ToggleKey,
    Enabled = LocalPlayer.Config.TickSpeed.Enabled,
    HighSpeedMultiplier = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier,
    NormalSpeedMultiplier = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier,
    OnDuration = LocalPlayer.Config.TickSpeed.OnDuration,
    OffDuration = LocalPlayer.Config.TickSpeed.OffDuration,
    Timer = 0,
    LastServerPosition = nil
}
local HighJumpStatus = {
    Enabled = LocalPlayer.Config.HighJump.Enabled,
    Method = LocalPlayer.Config.HighJump.Method,
    JumpPower = LocalPlayer.Config.HighJump.JumpPower,
    Key = LocalPlayer.Config.HighJump.JumpKey,
    LastJumpTime = 0,
    JumpCooldown = 1
}
local NoRagdollStatus = {
    Enabled = LocalPlayer.Config.NoRagdoll.Enabled,
    Connection = nil,
    BodyParts = nil
}
local FastAttackStatus = {
    Enabled = LocalPlayer.Config.FastAttack.Enabled,
    Connection = nil,
    AttackSpeed = 0,
    LastCheckTime = 0,
    CheckInterval = 0.1
}

-- Вспомогательные функции
local function getCharacterData()
    local character = LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

-- Проверка, активно ли UI (например, чат)
local function isUserInputFocused()
    return Services.UserInputService:GetFocusedTextBox() ~= nil
end

-- TickSpeed Functions
local TickSpeed = {}
TickSpeed.Start = function()
    if TickSpeedStatus.Running then return end
    local _, rootPart = getCharacterData()
    if not rootPart then return end

    -- Устанавливаем приоритет клиента
    local success, err = pcall(function()
        setsimulationradius(10000)
    end)
    if not success then
        warn("TickSpeed: setsimulationradius failed: " .. tostring(err))
        notify("TickSpeed", "Failed to set simulation radius.", true)
        return
    end

    TickSpeedStatus.Running = true
    TickSpeedStatus.LastServerPosition = rootPart.Position

    TickSpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function(deltaTime)
        if not TickSpeedStatus.Enabled or not TickSpeedStatus.Running then return end
        local humanoid, rootPart = getCharacterData()
        if not humanoid or not rootPart then return end

        -- Обновляем таймер
        local cycleTime = TickSpeedStatus.OnDuration + TickSpeedStatus.OffDuration
        TickSpeedStatus.Timer = (TickSpeedStatus.Timer + deltaTime) % cycleTime

        -- Определяем текущий множитель скорости
        local currentMultiplier = (TickSpeedStatus.Timer < TickSpeedStatus.OnDuration) and TickSpeedStatus.HighSpeedMultiplier or TickSpeedStatus.NormalSpeedMultiplier

        -- Получаем направление движения
        local moveDirection = humanoid.MoveDirection
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit

            -- Вычисляем смещение
            local speed = 16 * currentMultiplier -- 16 — стандартная скорость
            local offset = moveDirection * speed * deltaTime

            -- Применяем новую позицию
            local currentCFrame = rootPart.CFrame
            rootPart.CFrame = currentCFrame + offset

            -- Ограничиваем отклонение от серверной позиции
            local currentPos = rootPart.Position
            local deviation = (currentPos - TickSpeedStatus.LastServerPosition).Magnitude
            if deviation > 5 then
                local correction = (currentPos - TickSpeedStatus.LastServerPosition).Unit * (deviation - 5)
                rootPart.CFrame = CFrame.new(currentPos - correction)
            end
        end
    end)

    -- Отслеживание сброса позиции сервером
    TickSpeedStatus.ServerConnection = Services.RunService.Stepped:Connect(function()
        local _, rootPart = getCharacterData()
        if not rootPart then return end
        local serverPos = rootPart.Position
        if (serverPos - TickSpeedStatus.LastServerPosition).Magnitude > 1 then
            TickSpeedStatus.LastServerPosition = serverPos
        end
    end)

    notify("TickSpeed", "Started", true)
end

TickSpeed.Stop = function()
    if TickSpeedStatus.Connection then
        TickSpeedStatus.Connection:Disconnect()
        TickSpeedStatus.Connection = nil
    end
    if TickSpeedStatus.ServerConnection then
        TickSpeedStatus.ServerConnection:Disconnect()
        TickSpeedStatus.ServerConnection = nil
    end
    TickSpeedStatus.Running = false
    TickSpeedStatus.Timer = 0
    local _, rootPart = getCharacterData()
    if rootPart and TickSpeedStatus.LastServerPosition then
        rootPart.CFrame = CFrame.new(TickSpeedStatus.LastServerPosition)
    end
    notify("TickSpeed", "Stopped", true)
end

TickSpeed.SetHighSpeedMultiplier = function(value)
    TickSpeedStatus.HighSpeedMultiplier = value
    LocalPlayer.Config.TickSpeed.HighSpeedMultiplier = value
    notify("TickSpeed", "HighSpeedMultiplier set to: " .. value, false)
end

TickSpeed.SetNormalSpeedMultiplier = function(value)
    TickSpeedStatus.NormalSpeedMultiplier = value
    LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier = value
    notify("TickSpeed", "NormalSpeedMultiplier set to: " .. value, false)
end

TickSpeed.SetOnDuration = function(value)
    TickSpeedStatus.OnDuration = value
    LocalPlayer.Config.TickSpeed.OnDuration = value
    notify("TickSpeed", "OnDuration set to: " .. value, false)
end

TickSpeed.SetOffDuration = function(value)
    TickSpeedStatus.OffDuration = value
    LocalPlayer.Config.TickSpeed.OffDuration = value
    notify("TickSpeed", "OffDuration set to: " .. value, false)
end

-- FastAttack Functions
local FastAttack = {}
FastAttack.Start = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end

    FastAttackStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not FastAttackStatus.Enabled then return end
        local currentTime = tick()
        if currentTime - FastAttackStatus.LastCheckTime < FastAttackStatus.CheckInterval then return end
        FastAttackStatus.LastCheckTime = currentTime

        local backpack = LocalPlayerObj:FindFirstChild("Backpack")
        if not backpack then return end

        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute("Speed") then
                local success = pcall(function()
                    item:SetAttribute("Speed", FastAttackStatus.AttackSpeed)
                end)
                if not success then warn("FastAttack: Failed to set Speed for " .. item.Name) end
            end
        end
    end)

    notify("FastAttack", "Started with Speed set to 0", true)
end

FastAttack.Stop = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end

    local backpack = LocalPlayerObj:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute("Speed") then
                pcall(function()
                    item:SetAttribute("Speed", 1)
                end)
            end
        end
    end

    notify("FastAttack", "Stopped, attack speed restored to 1", true)
end

-- Timer Functions
local Timer = {}
Timer.Start = function()
    if TimerStatus.Running then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if TimerStatus.Speed <= 1 then return end
        local _, rootPart = getCharacterData()
        if not rootPart then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = newSpeed
    LocalPlayer.Config.Timer.Speed = newSpeed
    notify("Timer", "Speed set to: " .. newSpeed, false)
end

-- Disabler Functions
local Disabler = {}
Disabler.DisableSignals = function(character)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(Disabler.DisableSignals)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Functions
local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime)
    if SpeedStatus.Method == "Velocity" then
        humanoid.WalkSpeed = SpeedStatus.Speed
    elseif SpeedStatus.Method == "CFrame" then
        if moveDirection.Magnitude > 0 then
            local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * 0.0167)
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
        end
    elseif SpeedStatus.Method == "PulseTP" then
        if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
            local teleportVector = moveDirection.Unit * SpeedStatus.PulseTPDistance
            local destination = rootPart.Position + teleportVector
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime)
    if SpeedStatus.AutoJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, SpeedStatus.JumpPower, rootPart.Velocity.Z)
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
    if SpeedStatus.FakeJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        if humanoid.Health > 0 then
            local newCFrame = rootPart.CFrame + Vector3.new(0, SpeedStatus.JumpPower / 20, 0)
            rootPart.CFrame = newCFrame
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end

    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not SpeedStatus.Enabled or not SpeedStatus.Running then return end
        local humanoid, rootPart = getCharacterData()
        if not humanoid or not rootPart or humanoid.Health <= 0 then return end
        local currentTime = tick()
        local moveDirection = humanoid.MoveDirection
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime)
        Speed.UpdateJumps(humanoid, rootPart, currentTime)
    end)

    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    local humanoid = getCharacterData()
    if humanoid then
        humanoid.WalkSpeed = 16
    end
    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = newSpeed
    LocalPlayer.Config.Speed.Speed = newSpeed
    notify("Speed", "Speed set to: " .. newSpeed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    LocalPlayer.Config.Speed.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = value
    LocalPlayer.Config.Speed.PulseTPDist = value
    notify("Speed", "PulseTP Distance set to: " .. value, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = value
    LocalPlayer.Config.Speed.PulseTPDelay = value
    notify("Speed", "PulseTP Frequency set to: " .. value, false)
end

Speed.SetJumpPower = function(newPower)
    SpeedStatus.JumpPower = newPower
    LocalPlayer.Config.Speed.JumpPower = newPower
    notify("Speed", "JumpPower set to: " .. newPower, false)
end

Speed.SetJumpInterval = function(newInterval)
    SpeedStatus.JumpInterval = newInterval
    LocalPlayer.Config.Speed.JumpInterval = newInterval
    notify("Speed", "JumpInterval set to: " .. newInterval, false)
end

-- HighJump Functions
local HighJump = {}
HighJump.Trigger = function()
    if not HighJumpStatus.Enabled then
        notify("HighJump", "HighJump is disabled. Enable it to use keybind.", true)
        return
    end
    local humanoid, rootPart = getCharacterData()
    if not humanoid or not rootPart then return end
    local currentTime = tick()
    if humanoid:GetState() ~= Enum.HumanoidStateType.Running or currentTime - HighJumpStatus.LastJumpTime < HighJumpStatus.JumpCooldown then
        notify("HighJump", humanoid:GetState() ~= Enum.HumanoidStateType.Running and "You must be on the ground to high jump!" or "HighJump is on cooldown!", true)
        return
    end
    -- Устанавливаем JumpHeight только на момент прыжка
    humanoid.JumpHeight = HighJumpStatus.JumpPower
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    if HighJumpStatus.Method == "Velocity" then
        local gravity = Services.Workspace.Gravity or 196.2
        local jumpVelocity = math.sqrt(2 * HighJumpStatus.JumpPower * gravity)
        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, jumpVelocity, rootPart.Velocity.Z)
    else
        local newCFrame = rootPart.CFrame + Vector3.new(0, HighJumpStatus.JumpPower / 10, 0)
        rootPart.CFrame = newCFrame
    end
    HighJumpStatus.LastJumpTime = currentTime
    -- Сразу восстанавливаем стандартную высоту прыжка
    humanoid.JumpHeight = LocalPlayer.Config.HighJump.DefaultJumpHeight
    notify("HighJump", "Performed HighJump with method: " .. HighJumpStatus.Method, true)
end

HighJump.SetMethod = function(newMethod)
    HighJumpStatus.Method = newMethod
    LocalPlayer.Config.HighJump.Method = newMethod
    notify("HighJump", "Method set to: " .. newMethod, false)
end

HighJump.SetJumpPower = function(newPower)
    HighJumpStatus.JumpPower = newPower
    LocalPlayer.Config.HighJump.JumpPower = newPower
    notify("HighJump", "JumpPower set to: " .. newPower, false)
end

HighJump.RestoreJumpHeight = function()
    local humanoid = getCharacterData()
    if humanoid then
        humanoid.JumpHeight = LocalPlayer.Config.HighJump.DefaultJumpHeight
    end
end

-- NoRagdoll Functions
local NoRagdoll = {}
NoRagdoll.Start = function(character)
    if not character then return end
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end

    local success, parts = pcall(function()
        return {
            LowerTorso = character:WaitForChild("LowerTorso", 5),
            UpperTorso = character:WaitForChild("UpperTorso", 5),
            LeftFoot = character:WaitForChild("LeftFoot", 5),
            RightFoot = character:WaitForChild("RightFoot", 5)
        }
    end)
    if not success or not (parts.LowerTorso and parts.UpperTorso and parts.LeftFoot and parts.RightFoot) then
        warn("NoRagdoll: Failed to find required character parts")
        notify("NoRagdoll", "Failed to initialize: missing character parts.", true)
        return
    end
    NoRagdollStatus.BodyParts = parts

    local function updatePhysics()
        local p = NoRagdollStatus.BodyParts
        if p.LowerTorso:FindFirstChild("MoveForce") then
            p.LowerTorso.MoveForce.Enabled = false
        end
        if p.UpperTorso:FindFirstChild("FloatPosition") then
            p.UpperTorso.FloatPosition.Enabled = false
        end
        if p.LeftFoot:FindFirstChild("LeftFootPosition") then
            p.LeftFoot.LeftFootPosition.Enabled = false
        end
        if p.RightFoot:FindFirstChild("RightFootPosition") then
            p.RightFoot.RightFootPosition.Enabled = false
        end
        for _, motor in ipairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") then
                motor.Enabled = true
            end
        end
    end

    updatePhysics()
    NoRagdollStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not NoRagdollStatus.Enabled then return end
        updatePhysics()
    end)

    notify("NoRagdoll", "Started", true)
end

NoRagdoll.Stop = function()
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end
    NoRagdollStatus.BodyParts = nil
    notify("NoRagdoll", "Stopped", true)
end

-- Настройка UI
local function SetupUI(UI)
    -- Таблица для хранения UI-элементов
    local uiElements = {}

    -- Timer UI
    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        uiElements.TimerEnabled = UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Timer.Enabled,
            Callback = function(value)
                TimerStatus.Enabled = value
                LocalPlayer.Config.Timer.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        }, "TimerEnabled")
        uiElements.TimerSpeed = UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = LocalPlayer.Config.Timer.Speed,
            Precision = 1,
            Callback = function(value)
                Timer.SetSpeed(value)
                LocalPlayer.Config.Timer.Speed = value
            end
        }, "TimerSpeed")
        uiElements.TimerKey = UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Timer.ToggleKey,
            Callback = function(value)
                TimerStatus.Key = value
                LocalPlayer.Config.Timer.ToggleKey = value
                if isUserInputFocused() then return end
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        }, "TimerKey")
    end

    -- Disabler UI
    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        uiElements.DisablerEnabled = UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Disabler.Enabled,
            Callback = function(value)
                DisablerStatus.Enabled = value
                LocalPlayer.Config.Disabler.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        }, "DisablerEnabled")
        uiElements.DisablerKey = UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Disabler.ToggleKey,
            Callback = function(value)
                DisablerStatus.Key = value
                LocalPlayer.Config.Disabler.ToggleKey = value
                if isUserInputFocused() then return end
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        }, "DisablerKey")
    end

    -- Speed UI
    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        uiElements.SpeedEnabled = UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.Speed.Enabled,
            Callback = function(value)
                SpeedStatus.Enabled = value
                LocalPlayer.Config.Speed.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        }, "SpeedEnabled")
        uiElements.SpeedAutoJump = UI.Sections.Speed:Toggle({
            Name = "AutoJump",
            Default = LocalPlayer.Config.Speed.AutoJump,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                LocalPlayer.Config.Speed.AutoJump = value
                notify("Speed", "AutoJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "SpeedAutoJump")
        uiElements.SpeedFakeJump = UI.Sections.Speed:Toggle({
            Name = "FakeJump",
            Default = LocalPlayer.Config.Speed.FakeJump,
            Callback = function(value)
                SpeedStatus.FakeJump = value
                LocalPlayer.Config.Speed.FakeJump = value
                notify("Speed", "FakeJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "SpeedFakeJump")
        uiElements.SpeedMethod = UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"Velocity", "CFrame", "PulseTP"},
            Default = LocalPlayer.Config.Speed.Method,
            Callback = function(value)
                Speed.SetMethod(value)
                LocalPlayer.Config.Speed.Method = value
            end
        }, "SpeedMethod")
        uiElements.Speed = UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 16,
            Maximum = 250,
            Default = LocalPlayer.Config.Speed.Speed,
            Precision = 1,
            Callback = function(value)
                Speed.SetSpeed(value)
                LocalPlayer.Config.Speed.Speed = value
            end
        }, "Speed")
        uiElements.SpeedJumpPower = UI.Sections.Speed:Slider({
            Name = "Jump Power",
            Minimum = 10,
            Maximum = 100,
            Default = LocalPlayer.Config.Speed.JumpPower,
            Precision = 1,
            Callback = function(value)
                Speed.SetJumpPower(value)
                LocalPlayer.Config.Speed.JumpPower = value
            end
        }, "SpeedJumpPower")
        uiElements.SpeedJumpInterval = UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = LocalPlayer.Config.Speed.JumpInterval,
            Precision = 1,
            Callback = function(value)
                Speed.SetJumpInterval(value)
                LocalPlayer.Config.Speed.JumpInterval = value
            end
        }, "SpeedJumpInterval")
        uiElements.SpeedPulseTPDistance = UI.Sections.Speed:Slider({
            Name = "PulseTP Dist",
            Minimum = 1,
            Maximum = 20,
            Default = LocalPlayer.Config.Speed.PulseTPDist,
            Precision = 1,
            Callback = function(value)
                Speed.SetPulseTPDistance(value)
                LocalPlayer.Config.Speed.PulseTPDist = value
            end
        }, "SpeedPulseTPDistance")
        uiElements.SpeedPulseTPFrequency = UI.Sections.Speed:Slider({
            Name = "PulseTP Delay",
            Minimum = 0.1,
            Maximum = 1,
            Default = LocalPlayer.Config.Speed.PulseTPDelay,
            Precision = 2,
            Callback = function(value)
                Speed.SetPulseTPFrequency(value)
                LocalPlayer.Config.Speed.PulseTPDelay = value
            end
        }, "SpeedPulseTPFrequency")
        uiElements.SpeedKey = UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.Speed.ToggleKey,
            Callback = function(value)
                SpeedStatus.Key = value
                LocalPlayer.Config.Speed.ToggleKey = value
                if isUserInputFocused() then return end
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        }, "SpeedKey")
    end

    -- TickSpeed UI
    if UI.Sections.TickSpeed then
        UI.Sections.TickSpeed:Header({ Name = "TickSpeed" })
        uiElements.TickSpeedEnabled = UI.Sections.TickSpeed:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.TickSpeed.Enabled,
            Callback = function(value)
                TickSpeedStatus.Enabled = value
                LocalPlayer.Config.TickSpeed.Enabled = value
                if value then TickSpeed.Start() else TickSpeed.Stop() end
            end
        }, "TickSpeedEnabled")
        uiElements.TickSpeedHighMultiplier = UI.Sections.TickSpeed:Slider({
            Name = "High Speed Multiplier",
            Minimum = 1,
            Maximum = 3,
            Default = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier,
            Precision = 1,
            Callback = function(value)
                TickSpeed.SetHighSpeedMultiplier(value)
                LocalPlayer.Config.TickSpeed.HighSpeedMultiplier = value
            end
        }, "TickSpeedHighMultiplier")
        uiElements.TickSpeedNormalMultiplier = UI.Sections.TickSpeed:Slider({
            Name = "Normal Speed Multiplier",
            Minimum = 0.1,
            Maximum = 1,
            Default = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier,
            Precision = 1,
            Callback = function(value)
                TickSpeed.SetNormalSpeedMultiplier(value)
                LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier = value
            end
        }, "TickSpeedNormalMultiplier")
        uiElements.TickSpeedOnDuration = UI.Sections.TickSpeed:Slider({
            Name = "On Duration",
            Minimum = 0.05,
            Maximum = 0.5,
            Default = LocalPlayer.Config.TickSpeed.OnDuration,
            Precision = 2,
            Callback = function(value)
                TickSpeed.SetOnDuration(value)
                LocalPlayer.Config.TickSpeed.OnDuration = value
            end
        }, "TickSpeedOnDuration")
        uiElements.TickSpeedOffDuration = UI.Sections.TickSpeed:Slider({
            Name = "Off Duration",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = LocalPlayer.Config.TickSpeed.OffDuration,
            Precision = 2,
            Callback = function(value)
                TickSpeed.SetOffDuration(value)
                LocalPlayer.Config.TickSpeed.OffDuration = value
            end
        }, "TickSpeedOffDuration")
        uiElements.TickSpeedKey = UI.Sections.TickSpeed:Keybind({
            Name = "Toggle Key",
            Default = LocalPlayer.Config.TickSpeed.ToggleKey,
            Callback = function(value)
                TickSpeedStatus.Key = value
                LocalPlayer.Config.TickSpeed.ToggleKey = value
                if isUserInputFocused() then return end
                if TickSpeedStatus.Enabled then
                    if TickSpeedStatus.Running then TickSpeed.Stop() else TickSpeed.Start() end
                else
                    notify("TickSpeed", "Enable TickSpeed to use keybind.", true)
                end
            end
        }, "TickSpeedKey")
    end

    -- HighJump UI
    if UI.Sections.HighJump then
        UI.Sections.HighJump:Header({ Name = "HighJump" })
        uiElements.HighJumpEnabled = UI.Sections.HighJump:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.HighJump.Enabled,
            Callback = function(value)
                HighJumpStatus.Enabled = value
                LocalPlayer.Config.HighJump.Enabled = value
                if not value then
                    HighJump.RestoreJumpHeight()
                end
                notify("HighJump", "HighJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "HighJumpEnabled")
        uiElements.HighJumpMethod = UI.Sections.HighJump:Dropdown({
            Name = "Method",
            Options = {"Velocity", "CFrame"},
            Default = LocalPlayer.Config.HighJump.Method,
            Callback = function(value)
                HighJump.SetMethod(value)
                LocalPlayer.Config.HighJump.Method = value
            end
        }, "HighJumpMethod")
        uiElements.HighJumpPower = UI.Sections.HighJump:Slider({
            Name = "Jump Power",
            Minimum = 50,
            Maximum = 200,
            Default = LocalPlayer.Config.HighJump.JumpPower,
            Precision = 1,
            Callback = function(value)
                HighJump.SetJumpPower(value)
                LocalPlayer.Config.HighJump.JumpPower = value
            end
        }, "HighJumpPower")
        uiElements.HighJumpKey = UI.Sections.HighJump:Keybind({
            Name = "Jump Key",
            Default = LocalPlayer.Config.HighJump.JumpKey,
            Callback = function(value)
                HighJumpStatus.Key = value
                LocalPlayer.Config.HighJump.JumpKey = value
                if isUserInputFocused() then return end
                HighJump.Trigger()
            end
        }, "HighJumpKey")
    end

    -- NoRagdoll UI
    if UI.Sections.NoRagdoll then
        UI.Sections.NoRagdoll:Header({ Name = "NoRagdoll" })
        uiElements.NoRagdollEnabled = UI.Sections.NoRagdoll:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.NoRagdoll.Enabled,
            Callback = function(value)
                NoRagdollStatus.Enabled = value
                LocalPlayer.Config.NoRagdoll.Enabled = value
                if value then NoRagdoll.Start(LocalPlayerObj.Character) else NoRagdoll.Stop() end
            end
        }, "NoRagdollEnabled")
    end

    -- FastAttack UI
    if UI.Sections.FastAttack then
        UI.Sections.FastAttack:Header({ Name = "FastAttack" })
        uiElements.FastAttackEnabled = UI.Sections.FastAttack:Toggle({
            Name = "Enabled",
            Default = LocalPlayer.Config.FastAttack.Enabled,
            Callback = function(value)
                FastAttackStatus.Enabled = value
                LocalPlayer.Config.FastAttack.Enabled = value
                if value then FastAttack.Start() else FastAttack.Stop() end
            end
        }, "FastAttackEnabled")
    end

    -- LocalPlayer Sync UI
    local localconfigSection = UI.Tabs.Config:Section({ Name = "Local Player Sync", Side = "Right" })
    localconfigSection:Header({ Name = "LocalPlayer Settings Sync" })
    localconfigSection:Button({
        Name = "Sync Config",
        Callback = function()
            -- Обновляем LocalPlayer.Config на основе текущих значений UI
            LocalPlayer.Config.Timer.Enabled = uiElements.TimerEnabled:GetState()
            LocalPlayer.Config.Timer.Speed = uiElements.TimerSpeed:GetValue()
            LocalPlayer.Config.Timer.ToggleKey = uiElements.TimerKey:GetBind()

            LocalPlayer.Config.Disabler.Enabled = uiElements.DisablerEnabled:GetState()
            LocalPlayer.Config.Disabler.ToggleKey = uiElements.DisablerKey:GetBind()

            LocalPlayer.Config.Speed.Enabled = uiElements.SpeedEnabled:GetState()
            LocalPlayer.Config.Speed.AutoJump = uiElements.SpeedAutoJump:GetState()
            LocalPlayer.Config.Speed.FakeJump = uiElements.SpeedFakeJump:GetState()
            local speedMethodOptions = uiElements.SpeedMethod:GetOptions()
            for option, selected in pairs(speedMethodOptions) do
                if selected then
                    LocalPlayer.Config.Speed.Method = option
                    break
                end
            end
            LocalPlayer.Config.Speed.Speed = uiElements.Speed:GetValue()
            LocalPlayer.Config.Speed.JumpPower = uiElements.SpeedJumpPower:GetValue()
            LocalPlayer.Config.Speed.JumpInterval = uiElements.SpeedJumpInterval:GetValue()
            LocalPlayer.Config.Speed.PulseTPDist = uiElements.SpeedPulseTPDistance:GetValue()
            LocalPlayer.Config.Speed.PulseTPDelay = uiElements.SpeedPulseTPFrequency:GetValue()
            LocalPlayer.Config.Speed.ToggleKey = uiElements.SpeedKey:GetBind()

            LocalPlayer.Config.TickSpeed.Enabled = uiElements.TickSpeedEnabled:GetState()
            LocalPlayer.Config.TickSpeed.HighSpeedMultiplier = uiElements.TickSpeedHighMultiplier:GetValue()
            LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier = uiElements.TickSpeedNormalMultiplier:GetValue()
            LocalPlayer.Config.TickSpeed.OnDuration = uiElements.TickSpeedOnDuration:GetValue()
            LocalPlayer.Config.TickSpeed.OffDuration = uiElements.TickSpeedOffDuration:GetValue()
            LocalPlayer.Config.TickSpeed.ToggleKey = uiElements.TickSpeedKey:GetBind()

            LocalPlayer.Config.HighJump.Enabled = uiElements.HighJumpEnabled:GetState()
            local highJumpMethodOptions = uiElements.HighJumpMethod:GetOptions()
            for option, selected in pairs(highJumpMethodOptions) do
                if selected then
                    LocalPlayer.Config.HighJump.Method = option
                    break
                end
            end
            LocalPlayer.Config.HighJump.JumpPower = uiElements.HighJumpPower:GetValue()
            LocalPlayer.Config.HighJump.JumpKey = uiElements.HighJumpKey:GetBind()

            LocalPlayer.Config.NoRagdoll.Enabled = uiElements.NoRagdollEnabled:GetState()

            LocalPlayer.Config.FastAttack.Enabled = uiElements.FastAttackEnabled:GetState()

            -- Синхронизируем внутренние состояния с обновлённым LocalPlayer.Config
            TimerStatus.Enabled = LocalPlayer.Config.Timer.Enabled
            TimerStatus.Speed = LocalPlayer.Config.Timer.Speed
            TimerStatus.Key = LocalPlayer.Config.Timer.ToggleKey
            if TimerStatus.Enabled then
                if not TimerStatus.Running then Timer.Start() end
            else
                if TimerStatus.Running then Timer.Stop() end
            end

            DisablerStatus.Enabled = LocalPlayer.Config.Disabler.Enabled
            DisablerStatus.Key = LocalPlayer.Config.Disabler.ToggleKey
            if DisablerStatus.Enabled then
                if not DisablerStatus.Running then Disabler.Start() end
            else
                if DisablerStatus.Running then Disabler.Stop() end
            end

            SpeedStatus.Enabled = LocalPlayer.Config.Speed.Enabled
            SpeedStatus.AutoJump = LocalPlayer.Config.Speed.AutoJump
            SpeedStatus.FakeJump = LocalPlayer.Config.Speed.FakeJump
            SpeedStatus.Method = LocalPlayer.Config.Speed.Method
            SpeedStatus.Speed = LocalPlayer.Config.Speed.Speed
            SpeedStatus.JumpPower = LocalPlayer.Config.Speed.JumpPower
            SpeedStatus.JumpInterval = LocalPlayer.Config.Speed.JumpInterval
            SpeedStatus.PulseTPDistance = LocalPlayer.Config.Speed.PulseTPDist
            SpeedStatus.PulseTPFrequency = LocalPlayer.Config.Speed.PulseTPDelay
            SpeedStatus.Key = LocalPlayer.Config.Speed.ToggleKey
            if SpeedStatus.Enabled then
                if not SpeedStatus.Running then Speed.Start() end
            else
                if SpeedStatus.Running then Speed.Stop() end
            end

            TickSpeedStatus.Enabled = LocalPlayer.Config.TickSpeed.Enabled
            TickSpeedStatus.HighSpeedMultiplier = LocalPlayer.Config.TickSpeed.HighSpeedMultiplier
            TickSpeedStatus.NormalSpeedMultiplier = LocalPlayer.Config.TickSpeed.NormalSpeedMultiplier
            TickSpeedStatus.OnDuration = LocalPlayer.Config.TickSpeed.OnDuration
            TickSpeedStatus.OffDuration = LocalPlayer.Config.TickSpeed.OffDuration
            TickSpeedStatus.Key = LocalPlayer.Config.TickSpeed.ToggleKey
            if TickSpeedStatus.Enabled then
                if not TickSpeedStatus.Running then TickSpeed.Start() end
            else
                if TickSpeedStatus.Running then TickSpeed.Stop() end
            end

            HighJumpStatus.Enabled = LocalPlayer.Config.HighJump.Enabled
            HighJumpStatus.Method = LocalPlayer.Config.HighJump.Method
            HighJumpStatus.JumpPower = LocalPlayer.Config.HighJump.JumpPower
            HighJumpStatus.Key = LocalPlayer.Config.HighJump.JumpKey
            if not HighJumpStatus.Enabled then
                HighJump.RestoreJumpHeight()
            end

            NoRagdollStatus.Enabled = LocalPlayer.Config.NoRagdoll.Enabled
            if NoRagdollStatus.Enabled then
                NoRagdoll.Start(LocalPlayerObj.Character)
            else
                NoRagdoll.Stop()
            end

            FastAttackStatus.Enabled = LocalPlayer.Config.FastAttack.Enabled
            if FastAttackStatus.Enabled then
                FastAttack.Start()
            else
                FastAttack.Stop()
            end

            notify("LocalPlayer", "Config synchronized!", true)
        end
    })
end

-- Инициализация модуля
function LocalPlayer.Init(UI, core, notifyFunc)
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed

    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        if NoRagdollStatus.Enabled then
            NoRagdoll.Start(newChar)
        end
        if TickSpeedStatus.Enabled then
            TickSpeed.Start()
        end
        if not HighJumpStatus.Enabled then
            HighJump.RestoreJumpHeight()
        end
    end)

    SetupUI(UI)

    -- Восстанавливаем JumpHeight при инициализации, если HighJump выключен
    if not HighJumpStatus.Enabled then
        HighJump.RestoreJumpHeight()
    end
end

return LocalPlayer
