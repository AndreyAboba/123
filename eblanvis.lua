-- Модуль Vehicles: VehicleSpeed и VehicleFly
local Vehicles = {
    VehicleSpeed = {
        Settings = {
            Enabled = { Value = false, Default = false },
            SpeedBoostMultiplier = { Value = 1.65, Default = 1.65 },
            HoldSpeed = { Value = false, Default = false },
            HoldKeybind = { Value = Enum.KeyCode.LeftShift, Default = Enum.KeyCode.LeftShift },
            ToggleKey = { Value = Enum.KeyCode.F, Default = Enum.KeyCode.F }
        },
        State = {
            IsBoosting = false,
            OriginalAttributes = {},
            CurrentVehicle = nil,
            Connection = nil
        }
    },
    VehicleFly = {
        Settings = {
            Enabled = { Value = false, Default = false },
            FlySpeed = { Value = 50, Default = 50 },
            ToggleKey = { Value = Enum.KeyCode.G, Default = Enum.KeyCode.G }
        },
        State = {
            IsFlying = false,
            FlyBodyVelocity = nil,
            LastWheelReset = 0,
            OriginalWheelData = {},
            Connection = nil
        }
    }
}

function Vehicles.Init(UI, Core, notify)
    local VehicleSpeed = Vehicles.VehicleSpeed
    local VehicleFly = Vehicles.VehicleFly

    -- Общая функция: получение текущего транспорта
    local function getCurrentVehicle()
        local char = Core.PlayerData.LocalPlayer.Character
        if char and char.Humanoid and char.Humanoid.SeatPart and char.Humanoid.SeatPart:IsA("VehicleSeat") then
            local vehicle = char.Humanoid.SeatPart.Parent
            if vehicle:IsDescendantOf(Core.Services.Workspace.Vehicles) then
                return vehicle, char.Humanoid.SeatPart
            end
        end
        return nil, nil
    end

    -- Проверка, является ли транспорт ATV
    local function isATV(vehicle)
        if vehicle and vehicle.Name:lower():find("atv") then
            return true
        end
        return false
    end

    -- Стабилизация колёс
    local function stabilizeWheels(vehicle, seat)
        for _, part in ipairs(vehicle:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                for _, constraint in ipairs(part:GetChildren()) do
                    if constraint:IsA("SpringConstraint") then
                        constraint.Damping = math.clamp(constraint.Damping * 1.2, 0, 1000)
                        constraint.Stiffness = math.clamp(constraint.Stiffness * 1.2, 0, 5000)
                    elseif constraint:IsA("HingeConstraint") then
                        constraint.AngularVelocity = math.clamp(constraint.AngularVelocity, -50, 50)
                    end
                end
            end
        end
    end

    -- Сброс характеристик транспорта
    local function resetVehicleAttributes(vehicle)
        if not vehicle then return end
        local motors = vehicle:FindFirstChild("Motors")
        if not motors then return end

        local attributes = VehicleSpeed.State.OriginalAttributes[vehicle]
        if attributes then
            motors:SetAttribute("forwardMaxSpeed", attributes.forwardMaxSpeed)
            motors:SetAttribute("nitroMaxSpeed", attributes.nitroMaxSpeed)
            motors:SetAttribute("acceleration", attributes.acceleration)
        end
    end

    -- Применение характеристик с учётом множителя
    local function applyVehicleAttributes(vehicle, multiplier)
        if not vehicle then return end
        local motors = vehicle:FindFirstChild("Motors")
        if not motors or not VehicleSpeed.State.OriginalAttributes[vehicle] then return end

        local effectiveMultiplier = isATV(vehicle) and math.min(multiplier, 1.55) or multiplier
        motors:SetAttribute("forwardMaxSpeed", VehicleSpeed.State.OriginalAttributes[vehicle].forwardMaxSpeed * effectiveMultiplier)
        motors:SetAttribute("nitroMaxSpeed", VehicleSpeed.State.OriginalAttributes[vehicle].nitroMaxSpeed * effectiveMultiplier)
        motors:SetAttribute("acceleration", VehicleSpeed.State.OriginalAttributes[vehicle].acceleration * effectiveMultiplier)
    end

    -- Функции VehicleSpeed
    VehicleSpeed.Start = function()
        if VehicleSpeed.State.Connection then
            VehicleSpeed.State.Connection:Disconnect()
            VehicleSpeed.State.Connection = nil
        end

        VehicleSpeed.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
            if not VehicleSpeed.Settings.Enabled.Value then return end

            local vehicle, seat = getCurrentVehicle()
            if not vehicle then
                if VehicleSpeed.State.IsBoosting and VehicleSpeed.State.CurrentVehicle then
                    resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
                    VehicleSpeed.State.IsBoosting = false
                    VehicleSpeed.State.CurrentVehicle = nil
                end
                return
            end

            local motors = vehicle:FindFirstChild("Motors")
            if not motors then return end

            if vehicle ~= VehicleSpeed.State.CurrentVehicle then
                if VehicleSpeed.State.CurrentVehicle then
                    resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
                end
                VehicleSpeed.State.CurrentVehicle = vehicle
                if not VehicleSpeed.State.OriginalAttributes[vehicle] then
                    VehicleSpeed.State.OriginalAttributes[vehicle] = {
                        forwardMaxSpeed = motors:GetAttribute("forwardMaxSpeed") or 35,
                        nitroMaxSpeed = motors:GetAttribute("nitroMaxSpeed") or 105,
                        acceleration = motors:GetAttribute("acceleration") or 15
                    }
                end
            end

            local shouldBoost = VehicleSpeed.Settings.HoldSpeed.Value and Core.Services.UserInputService:IsKeyDown(VehicleSpeed.Settings.HoldKeybind.Value) or true

            if shouldBoost then
                if not VehicleSpeed.State.IsBoosting then
                    VehicleSpeed.State.IsBoosting = true
                end
                applyVehicleAttributes(vehicle, VehicleSpeed.Settings.SpeedBoostMultiplier.Value)
                stabilizeWheels(vehicle, seat)
            elseif not shouldBoost and VehicleSpeed.State.IsBoosting then
                resetVehicleAttributes(vehicle)
                VehicleSpeed.State.IsBoosting = false
            end
        end)

        notify("VehicleSpeed", "Started with SpeedBoostMultiplier: " .. VehicleSpeed.Settings.SpeedBoostMultiplier.Value, true)
    end

    VehicleSpeed.Stop = function()
        if VehicleSpeed.State.Connection then
            VehicleSpeed.State.Connection:Disconnect()
            VehicleSpeed.State.Connection = nil
        end

        if VehicleSpeed.State.CurrentVehicle and VehicleSpeed.State.IsBoosting then
            resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
        end

        VehicleSpeed.State.IsBoosting = false
        VehicleSpeed.State.CurrentVehicle = nil
        VehicleSpeed.State.OriginalAttributes = {}
        notify("VehicleSpeed", "Stopped", true)
    end

    VehicleSpeed.SetSpeedBoostMultiplier = function(newMultiplier)
        VehicleSpeed.Settings.SpeedBoostMultiplier.Value = newMultiplier
        notify("VehicleSpeed", "SpeedBoostMultiplier set to: " .. newMultiplier, false)

        if VehicleSpeed.State.IsBoosting then
            local vehicle, _ = getCurrentVehicle()
            if vehicle then
                applyVehicleAttributes(vehicle, newMultiplier)
            end
        end
    end

    -- Функции VehicleFly
    VehicleFly.EnableFlight = function(vehicle, seat, enable)
        if not vehicle or not seat then return end

        if enable and not VehicleFly.State.IsFlying then
            VehicleFly.State.IsFlying = true
            VehicleFly.State.FlyBodyVelocity = Instance.new("BodyVelocity")
            VehicleFly.State.FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            VehicleFly.State.FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            VehicleFly.State.FlyBodyVelocity.Parent = seat

            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    VehicleFly.State.OriginalWheelData[part] = {
                        Position = part.Position - seat.Position,
                        Mass = part.Mass,
                        Constraints = {}
                    }
                    for _, constraint in ipairs(part:GetChildren()) do
                        if constraint:IsA("HingeConstraint") then
                            VehicleFly.State.OriginalWheelData[part].Constraints.Hinge = {
                                TargetAngle = constraint.TargetAngle,
                                AngularVelocity = constraint.AngularVelocity
                            }
                        elseif constraint:IsA("SpringConstraint") then
                            VehicleFly.State.OriginalWheelData[part].Constraints.Spring = {
                                FreeLength = constraint.FreeLength,
                                Stiffness = constraint.Stiffness,
                                Damping = constraint.Damping
                            }
                        end
                    end
                end
            end

            seat.AssemblyLinearVelocity = Vector3.new(seat.AssemblyLinearVelocity.X, 10, seat.AssemblyLinearVelocity.Z)
        elseif not enable and VehicleFly.State.IsFlying then
            VehicleFly.State.IsFlying = false
            if VehicleFly.State.FlyBodyVelocity then
                VehicleFly.State.FlyBodyVelocity:Destroy()
                VehicleFly.State.FlyBodyVelocity = nil
            end

            local pos = seat.Position
            local _, yaw, _ = seat.CFrame:ToEulerAnglesYXZ()
            seat.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
            seat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            seat.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local data = VehicleFly.State.OriginalWheelData[part]
                    if data then
                        for _, constraint in ipairs(part:GetChildren()) do
                            if constraint:IsA("HingeConstraint") and data.Constraints.Hinge then
                                constraint.AngularVelocity = 0
                                constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                            elseif constraint:IsA("SpringConstraint") and data.Constraints.Spring then
                                constraint.FreeLength = data.Constraints.Spring.FreeLength
                                constraint.Stiffness = data.Constraints.Spring.Stiffness
                                constraint.Damping = data.Constraints.Spring.Damping
                            end
                        end
                    end
                end
            end

            for i = 1, 5 do
                task.wait(0.1)
                if not vehicle.Parent then break end
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                        local data = VehicleFly.State.OriginalWheelData[part]
                        if data then
                            local errorDist = (part.Position - seat.Position - data.Position).Magnitude
                            if errorDist > 0.05 and errorDist < 10 then
                                local massFactor = math.clamp(1 / (data.Mass or 1), 0.1, 1)
                                for _, constraint in ipairs(part:GetChildren()) do
                                    if constraint:IsA("SpringConstraint") then
                                        constraint.FreeLength -= errorDist * massFactor * 0.2
                                    end
                                end
                            end
                        end
                        local roll, pitch = part.CFrame:ToEulerAnglesXYZ()
                        if math.abs(roll) > math.rad(5) or math.abs(pitch) > math.rad(5) then
                            for _, constraint in ipairs(part:GetChildren()) do
                                if constraint:IsA("HingeConstraint") and data and data.Constraints.Hinge then
                                    constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    VehicleFly.UpdateFlight = function(vehicle, seat)
        if not vehicle or not seat or not VehicleFly.State.IsFlying or not VehicleFly.State.FlyBodyVelocity then return end

        local humanoid = Core.PlayerData.LocalPlayer.Character and Core.PlayerData.LocalPlayer.Character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.SeatPart ~= seat then
            VehicleFly.EnableFlight(vehicle, seat, false)
            return
        end

        local look = Core.PlayerData.Camera.CFrame.LookVector
        local right = Core.PlayerData.Camera.CFrame.RightVector
        local moveDir = Vector3.new(0, 0, 0)

        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += look end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= look end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= right end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += right end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir += Vector3.new(0, 1, 0) end
        if Core.Services.UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir -= Vector3.new(0, 1, 0) end

        VehicleFly.State.FlyBodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * VehicleFly.Settings.FlySpeed.Value or Vector3.new(0, 0, 0)

        local pos = seat.Position
        local flatLook = Vector3.new(look.X, 0, look.Z).Unit
        seat.CFrame = CFrame.new(pos, pos + flatLook)

        if tick() - VehicleFly.State.LastWheelReset > 0.05 then
            VehicleFly.State.LastWheelReset = tick()
            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("wheel") then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local data = VehicleFly.State.OriginalWheelData[part]
                    if data then
                        local errorDist = (part.Position - seat.Position - data.Position).Magnitude
                        if errorDist > 0.05 and errorDist < 10 then
                            local massFactor = math.clamp(1 / (data.Mass or 1), 0.1, 1)
                            for _, constraint in ipairs(part:GetChildren()) do
                                if constraint:IsA("SpringConstraint") then
                                    constraint.FreeLength -= errorDist * massFactor * 0.2
                                end
                            end
                        end
                        local roll, pitch = part.CFrame:ToEulerAnglesXYZ()
                        if math.abs(roll) > math.rad(5) or math.abs(pitch) > math.rad(5) then
                            for _, constraint in ipairs(part:GetChildren()) do
                                if constraint:IsA("HingeConstraint") and data.Constraints.Hinge then
                                    constraint.AngularVelocity = 0
                                    constraint.TargetAngle = data.Constraints.Hinge.TargetAngle
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    VehicleFly.Start = function()
        if VehicleFly.State.Connection then
            VehicleFly.State.Connection:Disconnect()
            VehicleFly.State.Connection = nil
        end

        VehicleFly.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
            if not VehicleFly.Settings.Enabled.Value then return end

            local vehicle, seat = getCurrentVehicle()
            if vehicle and seat then
                if not VehicleFly.State.IsFlying then
                    VehicleFly.EnableFlight(vehicle, seat, true)
                end
                VehicleFly.UpdateFlight(vehicle, seat)
            else
                if VehicleFly.State.IsFlying then
                    local lastVehicle, lastSeat = getCurrentVehicle()
                    if lastVehicle and lastSeat then
                        VehicleFly.EnableFlight(lastVehicle, lastSeat, false)
                    end
                end
            end
        end)

        notify("VehicleFly", "Started with FlySpeed: " .. VehicleFly.Settings.FlySpeed.Value, true)
    end

    VehicleFly.Stop = function()
        if VehicleFly.State.Connection then
            VehicleFly.State.Connection:Disconnect()
            VehicleFly.State.Connection = nil
        end

        local vehicle, seat = getCurrentVehicle()
        if vehicle and seat and VehicleFly.State.IsFlying then
            VehicleFly.EnableFlight(vehicle, seat, false)
        end

        VehicleFly.State.IsFlying = false
        VehicleFly.State.OriginalWheelData = {}
        notify("VehicleFly", "Stopped", true)
    end

    VehicleFly.SetFlySpeed = function(newSpeed)
        VehicleFly.Settings.FlySpeed.Value = newSpeed
        notify("VehicleFly", "FlySpeed set to: " .. newSpeed, false)
    end

    -- Обработка посадки/высадки из транспорта
    Core.PlayerData.LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Seated:Connect(function(isSeated, seatPart)
            if not isSeated then
                if VehicleSpeed.Settings.Enabled.Value and VehicleSpeed.State.IsBoosting then
                    VehicleSpeed.Stop()
                    VehicleSpeed.Start()
                end
                if VehicleFly.Settings.Enabled.Value and VehicleFly.State.IsFlying then
                    VehicleFly.Stop()
                    VehicleFly.Start()
                end
            end
        end)
    end)

    -- Настройка UI для VehicleSpeed
    if UI.Sections.VehicleSpeed then
        UI.Sections.VehicleSpeed:Header({ Name = "Vehicle Speed Settings" })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Enabled",
            Default = VehicleSpeed.Settings.Enabled.Default,
            Callback = function(value)
                VehicleSpeed.Settings.Enabled.Value = value
                if value then VehicleSpeed.Start() else VehicleSpeed.Stop() end
            end
        })
        UI.Sections.VehicleSpeed:Slider({
            Name = "Speed Boost Multiplier",
            Minimum = 1,
            Maximum = 5,
            Default = VehicleSpeed.Settings.SpeedBoostMultiplier.Default,
            Precision = 2,
            Callback = VehicleSpeed.SetSpeedBoostMultiplier
        })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Hold Speed",
            Default = VehicleSpeed.Settings.HoldSpeed.Default,
            Callback = function(value)
                VehicleSpeed.Settings.HoldSpeed.Value = value
                notify("VehicleSpeed", "Hold Speed " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.VehicleSpeed:Keybind({
            Name = "Hold Keybind",
            Default = VehicleSpeed.Settings.HoldKeybind.Default,
            Callback = function(value)
                if value ~= VehicleSpeed.Settings.HoldKeybind.Value then
                    VehicleSpeed.Settings.HoldKeybind.Value = value
                    notify("VehicleSpeed", "Hold Keybind set to: " .. tostring(value), true)
                end
            end
        })
        UI.Sections.VehicleSpeed:Keybind({
            Name = "Toggle Key",
            Default = VehicleSpeed.Settings.ToggleKey.Default,
            Callback = function(value)
                VehicleSpeed.Settings.ToggleKey.Value = value
                if VehicleSpeed.Settings.Enabled.Value then
                    if VehicleSpeed.State.Connection then
                        VehicleSpeed.Stop()
                    else
                        VehicleSpeed.Start()
                    end
                else
                    notify("VehicleSpeed", "Enable Vehicle Speed to use keybind.", true)
                end
            end
        })
    end

    -- Настройка UI для VehicleFly
    if UI.Sections.VehicleFly then
        UI.Sections.VehicleFly:Header({ Name = "Vehicle Fly Settings" })
        UI.Sections.VehicleFly:Toggle({
            Name = "Enabled",
            Default = VehicleFly.Settings.Enabled.Default,
            Callback = function(value)
                VehicleFly.Settings.Enabled.Value = value
                if value then VehicleFly.Start() else VehicleFly.Stop() end
            end
        })
        UI.Sections.VehicleFly:Slider({
            Name = "Fly Speed",
            Minimum = 10,
            Maximum = 200,
            Default = VehicleFly.Settings.FlySpeed.Default,
            Precision = 1,
            Callback = VehicleFly.SetFlySpeed
        })
        UI.Sections.VehicleFly:Keybind({
            Name = "Toggle Key",
            Default = VehicleFly.Settings.ToggleKey.Default,
            Callback = function(value)
                VehicleFly.Settings.ToggleKey.Value = value
                if VehicleFly.Settings.Enabled.Value then
                    if VehicleFly.State.Connection then
                        VehicleFly.Stop()
                    else
                        VehicleFly.Start()
                    end
                else
                    notify("VehicleFly", "Enable Vehicle Fly to use keybind.", true)
                end
            }
        })
    end
end

return Vehicles
