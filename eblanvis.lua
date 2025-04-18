-- Модуль Visuals: VehicleSpeed и VehicleFly
local Visuals = {
    VehicleSpeed = {
        Settings = {
            Enabled = { Value = false, Default = false },
            SpeedBoostMultiplier = { Value = 1.65, Default = 1.65 }
        },
        State = {
            IsBoosting = false,
            CurrentVehicle = nil
        }
    },
    VehicleFly = {
        Settings = {
            Enabled = { Value = false, Default = false },
            FlySpeed = { Value = 50, Default = 50 }
        },
        State = {
            IsFlying = false,
            FlyBodyVelocity = nil
        }
    }
}

function Visuals.Init(UI, Core, notify)
    -- Общая функция: получение текущего транспорта
    local function getCurrentVehicle()
        local char = Core.PlayerData.LocalPlayer.Character
        local humanoid = char and char.Humanoid
        local seat = humanoid and humanoid.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            return seat.Parent, seat
        end
        return nil, nil
    end

    -- VehicleSpeed: функции
    local function applyVehicleSpeed(vehicle, multiplier)
        local motors = vehicle and vehicle:FindFirstChild("Motors")
        if motors then
            local baseSpeed = motors:GetAttribute("forwardMaxSpeed") or 35
            motors:SetAttribute("forwardMaxSpeed", baseSpeed * multiplier)
        end
    end

    local function resetVehicleSpeed(vehicle)
        local motors = vehicle and vehicle:FindFirstChild("Motors")
        if motors then
            motors:SetAttribute("forwardMaxSpeed", 35)
        end
    end

    local function startVehicleSpeed()
        Core.Services.RunService.Heartbeat:Connect(function()
            if not Visuals.VehicleSpeed.Settings.Enabled.Value then return end
            local vehicle, seat = getCurrentVehicle()
            if vehicle then
                if vehicle ~= Visuals.VehicleSpeed.State.CurrentVehicle then
                    if Visuals.VehicleSpeed.State.CurrentVehicle then
                        resetVehicleSpeed(Visuals.VehicleSpeed.State.CurrentVehicle)
                    end
                    Visuals.VehicleSpeed.State.CurrentVehicle = vehicle
                end
                applyVehicleSpeed(vehicle, Visuals.VehicleSpeed.Settings.SpeedBoostMultiplier.Value)
            elseif Visuals.VehicleSpeed.State.CurrentVehicle then
                resetVehicleSpeed(Visuals.VehicleSpeed.State.CurrentVehicle)
                Visuals.VehicleSpeed.State.CurrentVehicle = nil
            end
        end)
    end

    -- VehicleFly: функции
    local function enableFlight(vehicle, seat, enable)
        if not vehicle or not seat then return end
        if enable and not Visuals.VehicleFly.State.IsFlying then
            Visuals.VehicleFly.State.IsFlying = true
            Visuals.VehicleFly.State.FlyBodyVelocity = Instance.new("BodyVelocity")
            Visuals.VehicleFly.State.FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            Visuals.VehicleFly.State.FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            Visuals.VehicleFly.State.FlyBodyVelocity.Parent = seat
        elseif not enable and Visuals.VehicleFly.State.IsFlying then
            Visuals.VehicleFly.State.IsFlying = false
            if Visuals.VehicleFly.State.FlyBodyVelocity then
                Visuals.VehicleFly.State.FlyBodyVelocity:Destroy()
                Visuals.VehicleFly.State.FlyBodyVelocity = nil
            end
        end
    end

    local function updateFlight(vehicle, seat)
        if not vehicle or not seat or not Visuals.VehicleFly.State.IsFlying then return end
        local input = Core.Services.UserInputService
        local look = Core.PlayerData.Camera.CFrame.LookVector
        local moveDir = Vector3.new(0, 0, 0)
        if input:IsKeyDown(Enum.KeyCode.W) then moveDir += look end
        if input:IsKeyDown(Enum.KeyCode.S) then moveDir -= look end
        if input:IsKeyDown(Enum.KeyCode.E) then moveDir += Vector3.new(0, 1, 0) end
        if input:IsKeyDown(Enum.KeyCode.Q) then moveDir -= Vector3.new(0, 1, 0) end
        Visuals.VehicleFly.State.FlyBodyVelocity.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * Visuals.VehicleFly.Settings.FlySpeed.Value or Vector3.new(0, 0, 0)
    end

    local function startVehicleFly()
        Core.Services.RunService.Heartbeat:Connect(function()
            if not Visuals.VehicleFly.Settings.Enabled.Value then return end
            local vehicle, seat = getCurrentVehicle()
            if vehicle and seat then
                if not Visuals.VehicleFly.State.IsFlying then
                    enableFlight(vehicle, seat, true)
                end
                updateFlight(vehicle, seat)
            elseif Visuals.VehicleFly.State.IsFlying then
                local lastVehicle, lastSeat = getCurrentVehicle()
                if lastVehicle and lastSeat then
                    enableFlight(lastVehicle, lastSeat, false)
                end
            end
        end)
    end

    -- Настройка UI для VehicleSpeed
    if UI.Sections.VehicleSpeed then
        UI.Sections.VehicleSpeed:Header({ Name = "Настройки Скорости Транспорта" })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Включено",
            Default = Visuals.VehicleSpeed.Settings.Enabled.Default,
            Callback = function(v)
                Visuals.VehicleSpeed.Settings.Enabled.Value = v
                if v then startVehicleSpeed() notify("Скорость Транспорта", "Включено", true) else notify("Скорость Транспорта", "Выключено", true) end
            end
        })
        UI.Sections.VehicleSpeed:Slider({
            Name = "Множитель скорости",
            Minimum = 1,
            Maximum = 5,
            Default = Visuals.VehicleSpeed.Settings.SpeedBoostMultiplier.Default,
            Precision = 2,
            Callback = function(v)
                Visuals.VehicleSpeed.Settings.SpeedBoostMultiplier.Value = v
                notify("Скорость Транспорта", "Множитель: " .. v, false)
            end
        })
    end

    -- Настройка UI для VehicleFly
    if UI.Sections.VehicleFly then
        UI.Sections.VehicleFly:Header({ Name = "Настройки Полёта Транспорта" })
        UI.Sections.VehicleFly:Toggle({
            Name = "Включено",
            Default = Visuals.VehicleFly.Settings.Enabled.Default,
            Callback = function(v)
                Visuals.VehicleFly.Settings.Enabled.Value = v
                if v then startVehicleFly() notify("Полёт Транспорта", "Включено", true) else notify("Полёт Транспорта", "Выключено", true) end
            end
        })
        UI.Sections.VehicleFly:Slider({
            Name = "Скорость полёта",
            Minimum = 10,
            Maximum = 200,
            Default = Visuals.VehicleFly.Settings.FlySpeed.Default,
            Precision = 1,
            Callback = function(v)
                Visuals.VehicleFly.Settings.FlySpeed.Value = v
                notify("Полёт Транспорта", "Скорость: " .. v, false)
            end
        })
    end
end

return Visuals