local AutoInteract = {
    Settings = {
        Enabled = { Value = false, Default = false },
        TargetObject = { Value = "AirDrop", Default = "AirDrop" },
        MaxDistance = { Value = 10, Default = 10 },
        MinusHoldTime = { Value = 10, Default = 10 },
        MinDistanceBetweenObjects = { Value = 5, Default = 5 },
        ActivationDelay = { Value = 1.0, Default = 1.0 },
        EnableDebugLogs = { Value = true, Default = true }
    },
    State = {
        ProcessedObjects = {},
        LastDistance = {},
        ActiveObjects = {},
        BinCache = {},
        LastBinCacheUpdate = 0,
        BinCacheUpdateInterval = 10,
        LastUpdateTime = 0,
        UpdateInterval = 0.1,
        OriginalHoldTimes = {}
    }
}

function AutoInteract.Init(UI, Core, notify)
    local debugLog = function(...)
        if AutoInteract.Settings.EnableDebugLogs.Value then print(...) end
    end

    local function isPlayerInGame()
        local char = Core.PlayerData.LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        return char and humanoid and humanoid.Health > 0 and humanoid.WalkSpeed > 0 and humanoid.JumpPower > 0
    end

    local function isTargetObject(name)
        return name == "Dumpster" or name == "Bin" or name == "AirDrop"
    end

    local function getDistanceToObject(obj, objectType)
        local char = Core.PlayerData.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not obj.Parent then return math.huge end

        local pos
        local success = pcall(function()
            if objectType == "AirDrop" then
                local bottom = obj:FindFirstChild("Model") and obj.Model:FindFirstChild("BoxInteriorBottom")
                pos = bottom and bottom.Position or obj:GetPivot().Position
            elseif objectType == "Bin" then
                local mesh = obj:FindFirstChild("Meshes/bin_Cube")
                pos = mesh and mesh.Position or obj:GetPivot().Position
            elseif objectType == "Dumpster" then
                local trash = obj:FindFirstChild("Trash")
                pos = trash and trash.Position or obj:GetPivot().Position
            else
                pos = obj:GetPivot().Position
            end
        end)
        return success and (root.Position - pos).Magnitude or math.huge
    end

    local function getDistanceBetweenObjects(obj1, obj2)
        local pos1, pos2
        local s1 = pcall(function() pos1 = obj1:GetPivot().Position end)
        local s2 = pcall(function() pos2 = obj2:GetPivot().Position end)
        return s1 and s2 and (pos1 - pos2).Magnitude or math.huge
    end

    local function updateBinCache()
        if tick() - AutoInteract.State.LastBinCacheUpdate < AutoInteract.State.BinCacheUpdateInterval then return end
        AutoInteract.State.BinCache = {}
        for _, obj in pairs(Core.Services.Workspace:GetDescendants()) do
            if obj.Name == "Bin" and isTargetObject(obj.Name) then
                local mesh = obj:FindFirstChild("Meshes/bin_Cube")
                if mesh and mesh:FindFirstChild("ProximityPrompt") then
                    table.insert(AutoInteract.State.BinCache, obj)
                end
            end
        end
        AutoInteract.State.LastBinCacheUpdate = tick()
    end

    local function forceTriggerPrompt(prompt, targetObject, objectType)
        if not targetObject.Parent then
            AutoInteract.State.ProcessedObjects[targetObject] = nil
            AutoInteract.State.LastDistance[targetObject] = nil
            AutoInteract.State.OriginalHoldTimes[targetObject] = nil
            return false
        end

        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            for activeObj, _ in pairs(AutoInteract.State.ActiveObjects) do
                if getDistanceBetweenObjects(targetObject, activeObj) < AutoInteract.Settings.MinDistanceBetweenObjects.Value then
                    task.wait(AutoInteract.Settings.ActivationDelay.Value)
                    return false
                end
            end

            AutoInteract.State.ActiveObjects[targetObject] = true
            local char = Core.PlayerData.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                AutoInteract.State.ActiveObjects[targetObject] = nil
                return false
            end

            local pos
            local success = pcall(function()
                pos = objectType == "AirDrop" and (targetObject:FindFirstChild("Model") and targetObject.Model:FindFirstChild("BoxInteriorBottom")).Position or targetObject:GetPivot().Position
            end)
            if not success then
                AutoInteract.State.ActiveObjects[targetObject] = nil
                return false
            end

            local distance = (root.Position - pos).Magnitude
            if distance <= AutoInteract.Settings.MaxDistance.Value then
                prompt.RequiresLineOfSight = false
                local originalDist = prompt.MaxActivationDistance
                prompt.MaxActivationDistance = distance + 5

                if not AutoInteract.State.OriginalHoldTimes[targetObject] then
                    AutoInteract.State.OriginalHoldTimes[targetObject] = prompt.HoldDuration or 1
                end
                local holdTime = AutoInteract.State.OriginalHoldTimes[targetObject]
                local newHoldTime = math.max(0, holdTime * (1 - AutoInteract.Settings.MinusHoldTime.Value / 100))
                prompt.HoldDuration = newHoldTime

                local triggered = false
                local conn
                conn = prompt.Triggered:Connect(function()
                    triggered = true
                    conn:Disconnect()
                end)

                prompt:InputHoldBegin()
                local start = tick()
                local elapsed = 0
                while elapsed < newHoldTime do
                    task.wait(math.min(0.0167, newHoldTime - elapsed))
                    elapsed = tick() - start
                    if getDistanceToObject(targetObject, objectType) > AutoInteract.Settings.MaxDistance.Value then
                        prompt:InputHoldEnd()
                        prompt.MaxActivationDistance = originalDist
                        prompt.HoldDuration = holdTime
                        AutoInteract.State.ActiveObjects[targetObject] = nil
                        return false
                    end
                end
                task.wait(0.4)
                prompt:InputHoldEnd()
                task.wait(0.4)
                if triggered then
                    AutoInteract.State.ProcessedObjects[targetObject] = true
                end

                prompt.MaxActivationDistance = originalDist
                prompt.HoldDuration = holdTime
            end
            AutoInteract.State.ActiveObjects[targetObject] = nil
            return triggered
        end
        AutoInteract.State.ActiveObjects[targetObject] = nil
        return false
    end

    local function start()
        if not AutoInteract.Settings.Enabled.Value then return end
        Core.Services.RunService.Heartbeat:Connect(function()
            if not AutoInteract.Settings.Enabled.Value or not isPlayerInGame() then return end
            local ct = tick()
            if ct - AutoInteract.State.LastUpdateTime < AutoInteract.State.UpdateInterval then return end
            AutoInteract.State.LastUpdateTime = ct

            if AutoInteract.Settings.TargetObject.Value == "Dumpster" then
                local props = Core.Services.Workspace:FindFirstChild("Map") and Core.Services.Workspace.Map:FindFirstChild("Props")
                if props then
                    for _, obj in pairs(props:GetChildren()) do
                        if isTargetObject(obj.Name) then
                            local dist = getDistanceToObject(obj, "Dumpster")
                            if dist > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[obj] then
                                AutoInteract.State.ProcessedObjects[obj] = nil
                            end
                            AutoInteract.State.LastDistance[obj] = dist
                            if dist <= AutoInteract.Settings.MaxDistance.Value then
                                local trash = obj:FindFirstChild("Trash")
                                local prompt = trash and trash:FindFirstChild("Attachment") and trash.Attachment:FindFirstChild("ProximityPrompt")
                                if prompt then forceTriggerPrompt(prompt, obj, "Dumpster") end
                            end
                        end
                    end
                end
            elseif AutoInteract.Settings.TargetObject.Value == "Bin" then
                updateBinCache()
                for _, obj in pairs(AutoInteract.State.BinCache) do
                    if not obj.Parent then
                        AutoInteract.State.LastDistance[obj] = nil
                        AutoInteract.State.ProcessedObjects[obj] = nil
                    else
                        local dist = getDistanceToObject(obj, "Bin")
                        if dist > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[obj] then
                            AutoInteract.State.ProcessedObjects[obj] = nil
                        end
                        AutoInteract.State.LastDistance[obj] = dist
                        if dist <= AutoInteract.Settings.MaxDistance.Value then
                            local prompt = obj:FindFirstChild("Meshes/bin_Cube") and obj["Meshes/bin_Cube"]:FindFirstChild("ProximityPrompt")
                            if prompt then forceTriggerPrompt(prompt, obj, "Bin") end
                        end
                    end
                end
            elseif AutoInteract.Settings.TargetObject.Value == "AirDrop" then
                local airDrop = Core.Services.Workspace:FindFirstChild("AirDropModel")
                local crate = airDrop and airDrop:FindFirstChild("Weapon Crate")
                if crate and isTargetObject("AirDrop") then
                    local dist = getDistanceToObject(crate, "AirDrop")
                    if dist > AutoInteract.Settings.MaxDistance.Value and AutoInteract.State.ProcessedObjects[crate] then
                        AutoInteract.State.ProcessedObjects[crate] = nil
                    end
                    AutoInteract.State.LastDistance[crate] = dist
                    if dist <= AutoInteract.Settings.MaxDistance.Value then
                        local prompt = crate:FindFirstChild("Model") and crate.Model:FindFirstChild("BoxInteriorBottom") and crate.Model.BoxInteriorBottom:FindFirstChild("ProximityPrompt")
                        if prompt then forceTriggerPrompt(prompt, crate, "AirDrop") end
                    end
                end
            end

            if ct % 60 == 0 then
                for obj, _ in pairs(AutoInteract.State.ProcessedObjects) do
                    if obj.Name ~= "Weapon Crate" then
                        AutoInteract.State.ProcessedObjects[obj] = nil
                        AutoInteract.State.LastDistance[obj] = nil
                    end
                end
            end
        end)
    end

    Core.Services.Workspace.ChildAdded:Connect(function(child)
        if child.Name == "AirDropModel" then
            for obj, _ in pairs(AutoInteract.State.ProcessedObjects) do
                if obj.Name == "Weapon Crate" then
                    AutoInteract.State.ProcessedObjects[obj] = nil
                    AutoInteract.State.LastDistance[obj] = nil
                    AutoInteract.State.OriginalHoldTimes[obj] = nil
                end
            end
        end
    end)

    if UI.Sections.AutoInteract then
        UI.Sections.AutoInteract:Header({ Name = "AutoInteract Settings" })
        UI.Sections.AutoInteract:Toggle({
            Name = "Enabled",
            Default = AutoInteract.Settings.Enabled.Default,
            Callback = function(v)
                AutoInteract.Settings.Enabled.Value = v
                if v then start() notify("AutoInteract", "Enabled", true) else notify("AutoInteract", "Disabled", true) end
            end
        })
        UI.Sections.AutoInteract:Dropdown({
            Name = "Target Object",
            Options = {"Bin", "Dumpster", "AirDrop"},
            Default = AutoInteract.Settings.TargetObject.Default,
            Callback = function(v)
                AutoInteract.Settings.TargetObject.Value = v
                notify("AutoInteract", "Target Object: " .. v, true)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Max Distance",
            Minimum = 5,
            Maximum = 50,
            Default = AutoInteract.Settings.MaxDistance.Default,
            Precision = 1,
            Callback = function(v)
                AutoInteract.Settings.MaxDistance.Value = v
                notify("AutoInteract", "Max Distance: " .. v, false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Minus Hold Time",
            Minimum = 0,
            Maximum = 100,
            Default = AutoInteract.Settings.MinusHoldTime.Default,
            Precision = 0,
            Suffix = "%",
            Callback = function(v)
                AutoInteract.Settings.MinusHoldTime.Value = v
                notify("AutoInteract", "Minus Hold Time: " .. v .. "%", false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Min Distance Between Objects",
            Minimum = 1,
            Maximum = 20,
            Default = AutoInteract.Settings.MinDistanceBetweenObjects.Default,
            Precision = 1,
            Callback = function(v)
                AutoInteract.Settings.MinDistanceBetweenObjects.Value = v
                notify("AutoInteract", "Min Distance Between Objects: " .. v, false)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Activation Delay",
            Minimum = 0.1,
            Maximum = 5,
            Default = AutoInteract.Settings.ActivationDelay.Default,
            Precision = 1,
            Callback = function(v)
                AutoInteract.Settings.ActivationDelay.Value = v
                notify("AutoInteract", "Activation Delay: " .. v, false)
            end
        })
        UI.Sections.AutoInteract:Toggle({
            Name = "Enable Debug Logs",
            Default = AutoInteract.Settings.EnableDebugLogs.Default,
            Callback = function(v)
                AutoInteract.Settings.EnableDebugLogs.Value = v
                notify("AutoInteract", "Debug Logs " .. (v and "Enabled" or "Disabled"), false)
            end
        })
    end
end

return AutoInteract

local VehicleSpeed = {
    Settings = {
        Enabled = { Value = false, Default = false },
        SpeedBoostMultiplier = { Value = 1.65, Default = 1.65 },
        HoldSpeed = { Value = false, Default = false },
        HoldKeybind = { Value = Enum.KeyCode.LeftShift, Default = Enum.KeyCode.LeftShift }
    },
    State = {
        IsBoosting = false,
        OriginalAttributes = {},
        CurrentVehicle = nil,
        Connection = nil
    }
}

function VehicleSpeed.Init(UI, Core, notify)
    local function getCurrentVehicle()
        local char = Core.PlayerData.LocalPlayer.Character
        local humanoid = char and char.Humanoid
        local seat = humanoid and humanoid.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            local vehicle = seat.Parent
            if vehicle:IsDescendantOf(Core.Services.Workspace.Vehicles) then
                return vehicle, seat
            end
        end
        return nil, nil
    end

    local function isATV(vehicle)
        return vehicle and vehicle.Name:lower():find("atv") and true or false
    end

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

    local function resetVehicleAttributes(vehicle)
        local motors = vehicle and vehicle:FindFirstChild("Motors")
        local attrs = motors and VehicleSpeed.State.OriginalAttributes[vehicle]
        if motors and attrs then
            motors:SetAttribute("forwardMaxSpeed", attrs.forwardMaxSpeed)
            motors:SetAttribute("nitroMaxSpeed", attrs.nitroMaxSpeed)
            motors:SetAttribute("acceleration", attrs.acceleration)
        end
    end

    local function applyVehicleAttributes(vehicle, multiplier)
        local motors = vehicle and vehicle:FindFirstChild("Motors")
        local attrs = motors and VehicleSpeed.State.OriginalAttributes[vehicle]
        if motors and attrs then
            local effectiveMult = isATV(vehicle) and math.min(multiplier, 1.55) or multiplier
            motors:SetAttribute("forwardMaxSpeed", attrs.forwardMaxSpeed * effectiveMult)
            motors:SetAttribute("nitroMaxSpeed", attrs.nitroMaxSpeed * effectiveMult)
            motors:SetAttribute("acceleration", attrs.acceleration * effectiveMult)
        end
    end

    local function start()
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
            elseif VehicleSpeed.State.IsBoosting then
                resetVehicleAttributes(vehicle)
                VehicleSpeed.State.IsBoosting = false
            end
        end)

        notify("VehicleSpeed", "Started with SpeedBoostMultiplier: " .. VehicleSpeed.Settings.SpeedBoostMultiplier.Value, true)
    end

    local function stop()
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

    local function setSpeedBoostMultiplier(v)
        VehicleSpeed.Settings.SpeedBoostMultiplier.Value = v
        notify("VehicleSpeed", "SpeedBoostMultiplier: " .. v, false)
        if VehicleSpeed.State.IsBoosting then
            local vehicle = getCurrentVehicle()
            if vehicle then applyVehicleAttributes(vehicle, v) end
        end
    end

    Core.PlayerData.LocalPlayer.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid")
        humanoid.Seated:Connect(function(isSeated)
            if not isSeated and VehicleSpeed.State.CurrentVehicle then
                resetVehicleAttributes(VehicleSpeed.State.CurrentVehicle)
                VehicleSpeed.State.IsBoosting = false
                VehicleSpeed.State.CurrentVehicle = nil
            end
        end)
    end)

    if UI.Sections.VehicleSpeed then
        UI.Sections.VehicleSpeed:Header({ Name = "Vehicle Speed Settings" })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Enabled",
            Default = VehicleSpeed.Settings.Enabled.Default,
            Callback = function(v)
                VehicleSpeed.Settings.Enabled.Value = v
                if v then start() else stop() end
            end
        })
        UI.Sections.VehicleSpeed:Slider({
            Name = "Speed Boost Multiplier",
            Minimum = 1,
            Maximum = 5,
            Default = VehicleSpeed.Settings.SpeedBoostMultiplier.Default,
            Precision = 2,
            Callback = setSpeedBoostMultiplier
        })
        UI.Sections.VehicleSpeed:Toggle({
            Name = "Hold Speed",
            Default = VehicleSpeed.Settings.HoldSpeed.Default,
            Callback = function(v)
                VehicleSpeed.Settings.HoldSpeed.Value = v
                notify("VehicleSpeed", "Hold Speed " .. (v and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.VehicleSpeed:Keybind({
            Name = "Hold Keybind",
            Default = VehicleSpeed.Settings.HoldKeybind.Default,
            Callback = function(v)
                VehicleSpeed.Settings.HoldKeybind.Value = v
                notify("VehicleSpeed", "Hold Keybind: " .. tostring(v), true)
            end
        })
    end
end

return VehicleSpeed