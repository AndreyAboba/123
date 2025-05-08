local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GunSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        RangePlus = { Value = 200, Default = 200 },
        HitPart = { Value = "Head", Default = "Head" },
        BulletSpeed = { Value = 2500, Default = 2500 },
        UseFOV = { Value = true, Default = true },
        FOV = { Value = 120, Default = 120 },
        ShowCircle = { Value = true, Default = true },
        CircleMethod = { Value = "Center", Default = "Center", Options = {"Center", "Cursor"} },
        PredictVisual = { Value = true, Default = true },
        TrajectoryBeam = { Value = true, Default = true },
        HitChance = { Value = 100, Default = 100 },
        PredictionStrength = { Value = 1.5, Default = 1.5 },
        PingCompensation = { Value = 0.1, Default = 0.1 },
        SmoothingFactor = { Value = 0.1, Default = 0.1 },
        ResolverEnabled = { Value = true, Default = true },
        ResolverThreshold = { Value = 0.3, Default = 0.3 },
        PositionHistorySize = { Value = 30, Default = 30 },
        SortMethod = { Value = "Mouse&Distance", Default = "Mouse&Distance" },
        ShotgunSupport = { Value = false, Default = false },
        GenBullet = { Value = 4, Default = 4 },
        TestGenBullet = { Value = false, Default = false }
    },
    State = {
        LastEventId = 0,
        LastTool = nil,
        PredictVisualPart = nil,
        TrajectoryBeam = nil,
        FovCircle = nil,
        V_U_4 = nil,
        Connection = nil,
        OldFireServer = nil,
        PositionHistory = {},
        LastVisualUpdateTime = 0,
        LastTargetPosition = {},
        LocalCharacter = nil,
        LocalRoot = nil,
        LastTargetPos = nil,
        LastPredictionPos = nil,
        LastTargetUpdate = 0,
        TargetUpdateInterval = 0.2, -- Увеличено для снижения нагрузки
        LastFriendsList = nil
    }
}

local function safeNotify(notifyFunc, prefix, message, isImportant)
    if notifyFunc then
        local success, errorMsg = pcall(function()
            notifyFunc(prefix, message, isImportant)
        end)
        if not success then
            warn(string.format("[GunSilent] Notify failed: %s", errorMsg))
        end
    end
end

local function safeCreateInstance(className, properties)
    local success, result = pcall(function()
        local instance = Instance.new(className)
        if properties then
            for prop, value in pairs(properties) do
                instance[prop] = value
            end
        end
        return instance
    end)
    if success then
        return result
    else
        warn(string.format("[GunSilent] Failed to create %s: %s", className, result))
        return nil
    end
end

local function isGunTool(tool)
    local items = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if not items then return false end
    local gunFolder = items:FindFirstChild("gun")
    if not gunFolder then return false end
    return gunFolder:FindFirstChild(tool.Name) ~= nil
end

local function isShotgun(tool)
    if not tool then return false end
    local ammoType = tool:GetAttribute("AmmoType")
    return ammoType and ammoType:lower() == "shotgun"
end

local function getGunRange(tool)
    return GunSilent.Settings.RangePlus.Value
end

local function getEquippedGunTool(character)
    if not character then return nil end
    for _, child in pairs(character:GetChildren()) do
        if child.ClassName == "Tool" and isGunTool(child) then
            return child
        end
    end
    return nil
end

local function updateFovCircle()
    if not GunSilent.Settings.ShowCircle.Value then
        if GunSilent.State.FovCircle then
            GunSilent.State.FovCircle.Visible = false
        end
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    local fovCircle = GunSilent.State.FovCircle
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.NumSides = 100
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Visible = true
        fovCircle.Filled = false
        GunSilent.State.FovCircle = fovCircle
    end

    local newRadius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    local circlePos = GunSilent.Settings.CircleMethod.Value == "Cursor" and UserInputService:GetMouseLocation() or camera.ViewportSize / 2

    fovCircle.Radius = newRadius
    fovCircle.Position = circlePos
    fovCircle.Visible = true
end

local function isInFov(targetPos, camera)
    if not GunSilent.Settings.UseFOV.Value then return true end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local referencePos = GunSilent.Settings.CircleMethod.Value == "Cursor" and UserInputService:GetMouseLocation() or camera.ViewportSize / 2
    local distanceFromReference = (Vector2.new(screenPos.X, screenPos.Y) - referencePos).Magnitude
    return distanceFromReference <= math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
end

local function getNearestPlayerGun(gunRange)
    local currentTime = tick()
    if currentTime - GunSilent.State.LastTargetUpdate < GunSilent.State.TargetUpdateInterval then
        local target = GunSilent.Core.GunSilentTarget.CurrentTarget
        if target and target.Character and target.Character.Humanoid and target.Character.Humanoid.Health > 0 then
            return target
        end
    end
    GunSilent.State.LastTargetUpdate = currentTime

    local friendsList = GunSilent.Core.Services.FriendsList or {}
    local friendsHash = {}
    for k in pairs(friendsList) do
        friendsHash[k:lower()] = true
    end

    local localRoot = GunSilent.State.LocalRoot
    if not localRoot then
        return nil
    end
    local rootPos = localRoot.Position
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end

    local nearestPlayer, shortestDistance, closestToCursor, bestScore = nil, gunRange, math.huge, math.huge
    local sortMethod = GunSilent.Settings.SortMethod.Value

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and not friendsHash[player.Name:lower()] then
            local targetChar = player.Character
            if targetChar then
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                local targetHumanoid = targetChar:FindFirstChild("Humanoid")
                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                    local distance = (rootPos - targetRoot.Position).Magnitude
                    local inFov = isInFov(targetRoot.Position, camera)
                    if inFov then
                        if sortMethod == "Mouse&Distance" then
                            local screenPos = camera:WorldToViewportPoint(targetRoot.Position)
                            local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                            local score = (cursorDistance / camera.ViewportSize.X) * 0.7 + (distance / (GunSilent.Settings.RangePlus.Value + 50)) * 0.3
                            if score < bestScore then
                                bestScore = score
                                nearestPlayer = player
                            end
                        elseif sortMethod == "Distance" and distance < shortestDistance then
                            shortestDistance = distance
                            nearestPlayer = player
                        elseif sortMethod == "Mouse" then
                            local screenPos = camera:WorldToViewportPoint(targetRoot.Position)
                            local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                            if cursorDistance < closestToCursor then
                                closestToCursor = cursorDistance
                                nearestPlayer = player
                            end
                        end
                    end
                end
            end
        end
    end

    GunSilent.Core.GunSilentTarget.CurrentTarget = nearestPlayer
    GunSilent.State.LastFriendsList = friendsList
    return nearestPlayer
end

local function isInVehicle(targetChar)
    local humanoid = targetChar:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.SeatPart ~= nil
    end
    return false
end

local function resolveVelocity(target, positionHistory, clientVelocity, targetChar)
    if not GunSilent.Settings.ResolverEnabled.Value or not positionHistory or #positionHistory < 3 then
        return clientVelocity
    end

    local currentTime = tick()
    local totalVelocity = Vector3.new(0, 0, 0)
    local totalWeight = 0
    local validEntries = 0
    local maxSpeedLimit = isInVehicle(targetChar) and 150 or 50

    local filteredHistory = {}
    for i = 1, #positionHistory do
        filteredHistory[#filteredHistory + 1] = positionHistory[i]
    end

    local calculatedVelocity = Vector3.new(0, 0, 0)
    local useCFrame = #filteredHistory > 2 and (function()
        local meanPos = Vector3.new(0, 0, 0)
        for _, entry in ipairs(filteredHistory) do
            meanPos = meanPos + entry.pos
        end
        meanPos = meanPos / #filteredHistory
        local variance = 0
        for _, entry in ipairs(filteredHistory) do
            variance = variance + (entry.pos - meanPos).Magnitude^2
        end
        return variance / #filteredHistory < 0.1
    end)()

    if useCFrame and targetChar:FindFirstChild("Head") and not isInVehicle(targetChar) then
        local headCFrame = targetChar.Head.CFrame
        local rootCFrame = targetChar.HumanoidRootPart.CFrame
        local offset = headCFrame.Position - rootCFrame.Position
        calculatedVelocity = offset / GunSilent.Settings.PingCompensation.Value
    else
        for i = #filteredHistory - 1, math.max(1, #filteredHistory - 10), -1 do
            local currEntry = filteredHistory[i + 1]
            local prevEntry = filteredHistory[i]
            local timeDelta = currEntry.time - prevEntry.time
            if timeDelta > 0 and timeDelta < 0.2 then
                local velocity = (currEntry.pos - prevEntry.pos) / timeDelta
                if velocity.Magnitude <= maxSpeedLimit * 1.5 then
                    local weight = 1 / (1 + (currentTime - currEntry.time) * 5)
                    totalVelocity = totalVelocity + velocity * weight
                    totalWeight = totalWeight + weight
                    validEntries = validEntries + 1
                end
            end
        end
        calculatedVelocity = validEntries > 0 and totalVelocity / totalWeight or Vector3.new(0, 0, 0)

        if isInVehicle(targetChar) and targetChar:FindFirstChild("HumanoidRootPart") then
            local rootCFrame = targetChar.HumanoidRootPart.CFrame
            local forwardVector = rootCFrame.LookVector
            calculatedVelocity = calculatedVelocity + forwardVector * calculatedVelocity.Magnitude * 0.3
        end
    end

    return calculatedVelocity
end

local function predictTargetPositionGun(target)
    local localRoot = GunSilent.State.LocalRoot
    if not target or not target.Character or not localRoot then
        return { position = nil, direction = nil, timeToTarget = 0, clientPosition = nil }
    end

    local targetChar = target.Character
    local myPos = localRoot.Position
    local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local equippedTool = getEquippedGunTool(GunSilent.State.LocalCharacter)
    if not hitPart or not targetRoot or not equippedTool then
        return { position = nil, direction = nil, timeToTarget = 0, clientPosition = nil }
    end

    local targetPos = hitPart.Position
    local targetId = tostring(target.UserId)
    local isTeleporting = GunSilent.State.LastTargetPosition[targetId] and (targetPos - GunSilent.State.LastTargetPosition[targetId]).Magnitude > 50
    GunSilent.State.LastTargetPosition[targetId] = targetPos

    local distance = (targetPos - myPos).Magnitude
    local bulletSpeed = GunSilent.Settings.BulletSpeed.Value
    local timeToTarget = distance / bulletSpeed

    local positionHistory = GunSilent.State.PositionHistory[target] or {}
    GunSilent.State.PositionHistory[target] = positionHistory
    local currentTime = tick()

    positionHistory[#positionHistory + 1] = { pos = targetPos, time = currentTime, velocity = targetRoot.Velocity }
    while #positionHistory > GunSilent.Settings.PositionHistorySize.Value do
        table.remove(positionHistory, 1)
    end

    local clientPos = targetPos
    local resolvedVelocity = resolveVelocity(target, positionHistory, targetRoot.Velocity, targetChar)

    local predictedPos = clientPos
    if not isTeleporting then
        local targetSpeed = resolvedVelocity.Magnitude
        local isInVehicle = isInVehicle(targetChar)
        local predictionStrength = GunSilent.Settings.PredictionStrength.Value
        if isInVehicle then
            predictionStrength = predictionStrength * 1.5
        end

        if targetSpeed < 5 then
            local ping = GunSilent.Settings.PingCompensation.Value * math.clamp(distance / 50, 0.5, 1.0)
            predictedPos = clientPos + resolvedVelocity * ping
        else
            local speedFactor = 0.8 + (targetSpeed / (isInVehicle and 150 or 50)) * 0.5
            local ping = GunSilent.Settings.PingCompensation.Value * math.clamp(distance / 50, 0.5, 1.0)
            local accuracyFactor = math.clamp(getGunRange(equippedTool) / distance, 0.5, 1.0)
            local totalPredictionTime = (timeToTarget + ping) * predictionStrength * speedFactor * accuracyFactor
            predictedPos = clientPos + resolvedVelocity * totalPredictionTime

            if GunSilent.State.LastPredictionPos then
                predictedPos = GunSilent.State.LastPredictionPos:Lerp(predictedPos, 1 - GunSilent.Settings.SmoothingFactor.Value)
            end
        end
        GunSilent.State.LastPredictionPos = predictedPos
    end

    return {
        position = predictedPos,
        direction = (predictedPos - myPos).Unit,
        timeToTarget = timeToTarget,
        clientPosition = clientPos
    }
end

local function getAimCFrameGun(target)
    local localRoot = GunSilent.State.LocalRoot
    if not target or not target.Character or not localRoot then return nil end
    local prediction = predictTargetPositionGun(target)
    if not prediction.position or not prediction.direction then return nil end
    return CFrame.new(localRoot.Position, localRoot.Position + prediction.direction)
end

local function createHitDataGun(target)
    local localRoot = GunSilent.State.LocalRoot
    if not target or not target.Character or not localRoot then return nil end
    local targetChar = target.Character
    local prediction = predictTargetPositionGun(target)
    if not prediction.position or not prediction.direction then return nil end

    local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    if not hitPart then return nil end

    local equippedTool = getEquippedGunTool(GunSilent.State.LocalCharacter)
    local isShotgunWeapon = GunSilent.Settings.ShotgunSupport.Value and equippedTool and isShotgun(equippedTool)
    local useMultiBullets = isShotgunWeapon or GunSilent.Settings.TestGenBullet.Value
    local numBullets = useMultiBullets and (isShotgunWeapon and GunSilent.Settings.GenBullet.Value or 4) or 1
    local hitData = {}

    if useMultiBullets then
        for i = 1, numBullets do
            hitData[i] = {{Normal = prediction.direction, Instance = hitPart, Position = prediction.position}}
        end
    else
        hitData[1] = {{Normal = prediction.direction, Instance = hitPart, Position = prediction.position}}
    end
    return hitData
end

local function updateVisualsGun(target)
    local currentTime = tick()
    if currentTime - GunSilent.State.LastVisualUpdateTime < 0.016 then return end
    GunSilent.State.LastVisualUpdateTime = currentTime

    local localRoot = GunSilent.State.LocalRoot
    if not GunSilent.Settings.Enabled.Value or not localRoot then
        if GunSilent.State.PredictVisualPart then
            GunSilent.State.PredictVisualPart.Transparency = 1
        end
        if GunSilent.State.TrajectoryBeam then
            GunSilent.State.TrajectoryBeam.Enabled = false
        end
        return
    end

    local prediction = target and predictTargetPositionGun(target)
    local targetPos = prediction and prediction.clientPosition
    local predictionPos = prediction and prediction.position

    if not target or not target.Character or not predictionPos or not prediction.direction then
        if GunSilent.State.PredictVisualPart then
            GunSilent.State.PredictVisualPart.Transparency = 1
        end
        if GunSilent.State.TrajectoryBeam then
            GunSilent.State.TrajectoryBeam.Enabled = false
        end
        return
    end

    -- Оптимизация: обновляем визуализацию только при значительном изменении позиции
    if GunSilent.State.LastTargetPos and (targetPos - GunSilent.State.LastTargetPos).Magnitude < 1 then return end

    local targetChar = target.Character
    local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    if not hitPart then return end

    GunSilent.State.LastTargetPos, GunSilent.State.LastPredictionPos = targetPos, predictionPos
    local startPos = localRoot.Position + Vector3.new(0, 1.5, 0)

    if GunSilent.Settings.PredictVisual.Value then
        local predictVisualPart = GunSilent.State.PredictVisualPart
        if not predictVisualPart then
            predictVisualPart = safeCreateInstance("Part", {
                Size = Vector3.new(0.5, 0.5, 0.5),
                Shape = Enum.PartType.Ball,
                Anchored = true,
                CanCollide = false,
                Transparency = 0.3,
                Parent = Workspace
            })
            GunSilent.State.PredictVisualPart = predictVisualPart
        end
        if predictVisualPart then
            predictVisualPart.Position = prediction.position
            predictVisualPart.Color = Color3.fromRGB(0, 255, 255)
            predictVisualPart.Transparency = 0.3
        end
    elseif GunSilent.State.PredictVisualPart then
        GunSilent.State.PredictVisualPart.Transparency = 1
    end

    if GunSilent.Settings.TrajectoryBeam.Value and GunSilent.Settings.PredictVisual.Value then
        local trajectoryBeam = GunSilent.State.TrajectoryBeam
        if not trajectoryBeam then
            trajectoryBeam = safeCreateInstance("Beam", {
                FaceCamera = true,
                Width0 = 0.15,
                Width1 = 0.15,
                Transparency = NumberSequence.new(0.4),
                Color = ColorSequence.new(Color3.fromRGB(147, 112, 219)),
                Parent = Workspace
            })
            if trajectoryBeam then
                GunSilent.State.TrajectoryBeam = trajectoryBeam
                GunSilent.State.TrajectoryAttachment0 = safeCreateInstance("Attachment", { Parent = localRoot })
                GunSilent.State.TrajectoryAttachment1 = safeCreateInstance("Attachment", { Parent = GunSilent.State.PredictVisualPart })
                trajectoryBeam.Attachment0 = GunSilent.State.TrajectoryAttachment0
                trajectoryBeam.Attachment1 = GunSilent.State.TrajectoryAttachment1
            end
        end
        if trajectoryBeam and GunSilent.State.TrajectoryAttachment0 and GunSilent.State.TrajectoryAttachment1 then
            if not GunSilent.State.TrajectoryAttachment0.Parent or not GunSilent.State.TrajectoryAttachment1.Parent then
                GunSilent.State.TrajectoryAttachment0.Parent = localRoot
                GunSilent.State.TrajectoryAttachment1.Parent = GunSilent.State.PredictVisualPart
            end
            trajectoryBeam.Enabled = true
        else
            if GunSilent.State.TrajectoryBeam then
                GunSilent.State.TrajectoryBeam.Enabled = false
            end
        end
    elseif GunSilent.State.TrajectoryBeam then
        GunSilent.State.TrajectoryBeam.Enabled = false
    end
end

local function initializeGunSilent()
    if GunSilent.State.Connection then GunSilent.State.Connection:Disconnect() end
    if not GunSilent.State.V_U_4 then
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and not getmetatable(obj) and obj.event and obj.func then
                GunSilent.State.V_U_4 = obj
                break
            end
        end
    end

    if not GunSilent.State.OldFireServer then
        GunSilent.State.OldFireServer = hookfunction(game:GetService("ReplicatedStorage").Remotes.Send.FireServer, function(self, ...)
            local args = {...}
            local modifiedArgs = args
            if GunSilent.Settings.Enabled.Value and #args >= 2 and typeof(args[1]) == "number" and math.random(100) <= GunSilent.Settings.HitChance.Value then
                GunSilent.State.LastEventId = args[1]
                local equippedTool = getEquippedGunTool(GunSilent.State.LocalCharacter)
                if equippedTool and args[2] == "shoot_gun" then
                    local gunRange = getGunRange(equippedTool)
                    local nearestPlayer = getNearestPlayerGun(gunRange)
                    if nearestPlayer then
                        local aimCFrame = getAimCFrameGun(nearestPlayer)
                        local hitData = createHitDataGun(nearestPlayer)
                        if aimCFrame and hitData then
                            modifiedArgs = {args[1], args[2], equippedTool, aimCFrame, hitData}
                            safeNotify(GunSilent.notify, "GunSilent", "Firing at target: " .. nearestPlayer.Name, false)
                        else
                            safeNotify(GunSilent.notify, "GunSilent", "Failed to generate aim data", false)
                        end
                    else
                        safeNotify(GunSilent.notify, "GunSilent", "No valid target found", false)
                    end
                end
            end
            return GunSilent.State.OldFireServer(self, unpack(modifiedArgs))
        end)
    end

    GunSilent.State.Connection = RunService.RenderStepped:Connect(function(deltaTime)
        if not GunSilent.Settings.Enabled.Value then
            if GunSilent.State.FovCircle then GunSilent.State.FovCircle.Visible = false end
            GunSilent.Core.GunSilentTarget.CurrentTarget = nil
            updateVisualsGun(nil)
            return
        end

        local character = GunSilent.State.LocalCharacter
        if character and not character:FindFirstChild("HumanoidRootPart") then
            GunSilent.State.LocalRoot = nil
            if GunSilent.State.TrajectoryAttachment0 then
                GunSilent.State.TrajectoryAttachment0:Destroy()
                GunSilent.State.TrajectoryAttachment0 = nil
            end
            if GunSilent.State.TrajectoryAttachment1 then
                GunSilent.State.TrajectoryAttachment1:Destroy()
                GunSilent.State.TrajectoryAttachment1 = nil
            end
        end

        local currentTool = getEquippedGunTool(character)
        if currentTool ~= GunSilent.State.LastTool then
            if currentTool and not GunSilent.State.LastTool then
                safeNotify(GunSilent.notify, "GunSilent", "Equipped: " .. currentTool.Name .. " (RangePlus: " .. getGunRange(currentTool) .. ")", true)
            elseif GunSilent.State.LastTool and not currentTool then
                safeNotify(GunSilent.notify, "GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                safeNotify(GunSilent.notify, "GunSilent", "Switched to " .. currentTool.Name .. " (RangePlus: " .. getGunRange(currentTool) .. ")", true)
            end
            GunSilent.State.LastTool = currentTool
        end

        updateFovCircle()
        if not currentTool then
            GunSilent.Core.GunSilentTarget.CurrentTarget = nil
            updateVisualsGun(nil)
            return
        end

        local gunRange = getGunRange(currentTool)
        local nearestPlayer = getNearestPlayerGun(gunRange)
        updateVisualsGun(nearestPlayer)
    end)
end

local function Init(UI, Core, notify)
    GunSilent.Core = Core
    GunSilent.notify = notify

    local LocalPlayer = Core.PlayerData.LocalPlayer
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function(character)
            character:WaitForChild("HumanoidRootPart")
            GunSilent.State.LocalCharacter = character
            GunSilent.State.LocalRoot = character.HumanoidRootPart
            -- Пересоздаем Attachment после спавна
            if GunSilent.State.TrajectoryBeam and not GunSilent.State.TrajectoryAttachment0 then
                GunSilent.State.TrajectoryAttachment0 = safeCreateInstance("Attachment", { Parent = GunSilent.State.LocalRoot })
                if GunSilent.State.TrajectoryBeam.Attachment0 then
                    GunSilent.State.TrajectoryBeam.Attachment0 = GunSilent.State.TrajectoryAttachment0
                end
            end
            if GunSilent.State.TrajectoryBeam and not GunSilent.State.TrajectoryAttachment1 then
                GunSilent.State.TrajectoryAttachment1 = safeCreateInstance("Attachment", { Parent = GunSilent.State.PredictVisualPart })
                if GunSilent.State.TrajectoryBeam.Attachment1 then
                    GunSilent.State.TrajectoryBeam.Attachment1 = GunSilent.State.TrajectoryAttachment1
                end
            end
        end)
        if LocalPlayer.Character then
            GunSilent.State.LocalCharacter = LocalPlayer.Character
            GunSilent.State.LocalRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        end
    end

    if UI.Tabs.Combat then
        UI.Sections.GunSilent = UI.Tabs.Combat:Section({ Side = "Right", Name = "GunSilent" })
        if UI.Sections.GunSilent then
            local uiElements = {}

            UI.Sections.GunSilent:Header({ Name = "GunSilent" })
            uiElements.GSEnabled = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Enabled",
                    Default = GunSilent.Settings.Enabled.Value,
                    Callback = function(value)
                        GunSilent.Settings.Enabled.Value = value
                        initializeGunSilent()
                        safeNotify(GunSilent.notify, "GunSilent", "GunSilent " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'GSEnabled'),
                callback = function(value)
                    GunSilent.Settings.Enabled.Value = value
                    initializeGunSilent()
                    safeNotify(GunSilent.notify, "GunSilent", "GunSilent " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.RangePlus = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Range Plus",
                    Minimum = 0,
                    Maximum = 300,
                    Default = GunSilent.Settings.RangePlus.Value,
                    Precision = 0,
                    Callback = function(value)
                        GunSilent.Settings.RangePlus.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Range Plus set to: " .. value, false)
                    end
                }, 'RangePlus'),
                callback = function(value)
                    GunSilent.Settings.RangePlus.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Range Plus set to: " .. value, false)
                end
            }
            uiElements.HitPart = {
                element = UI.Sections.GunSilent:Dropdown({
                    Name = "Hit Part",
                    Default = GunSilent.Settings.HitPart.Value,
                    Options = {"Head", "UpperTorso", "HumanoidRootPart"},
                    Callback = function(value)
                        GunSilent.Settings.HitPart.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Hit Part set to: " .. value, true)
                    end
                }, 'HitPart'),
                callback = function(value)
                    GunSilent.Settings.HitPart.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Hit Part set to: " .. value, true)
                end
            }
            uiElements.ShotgunSupport = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Shotgun Support",
                    Default = GunSilent.Settings.ShotgunSupport.Value,
                    Callback = function(value)
                        GunSilent.Settings.ShotgunSupport.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Shotgun Support " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'ShotgunSupport'),
                callback = function(value)
                    GunSilent.Settings.ShotgunSupport.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Shotgun Support " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.GenerateBullets = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Generate Bullets",
                    Default = GunSilent.Settings.GenBullet.Value,
                    Minimum = 1,
                    Maximum = 10,
                    Precision = 0,
                    Callback = function(value)
                        GunSilent.Settings.GenBullet.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Number of Bullets set to: " .. value, false)
                    end
                }, 'GenerateBullets'),
                callback = function(value)
                    GunSilent.Settings.GenBullet.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Number of Bullets set to: " .. value, false)
                end
            }
            uiElements.TestGenerateBullets = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Test Generate Bullets",
                    Default = GunSilent.Settings.TestGenBullet.Value,
                    Callback = function(value)
                        GunSilent.Settings.TestGenBullet.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Test Generate Bullets " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'TestGenerateBullets'),
                callback = function(value)
                    GunSilent.Settings.TestGenBullet.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Test Generate Bullets " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.SortMethod = {
                element = UI.Sections.GunSilent:Dropdown({
                    Name = "Sort Method",
                    Default = GunSilent.Settings.SortMethod.Value,
                    Options = {"Mouse", "Distance", "Mouse&Distance"},
                    Callback = function(value)
                        GunSilent.Settings.SortMethod.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Sort Method set to: " .. value, true)
                    end
                }, 'SortMethod'),
                callback = function(value)
                    GunSilent.Settings.SortMethod.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Sort Method set to: " .. value, true)
                end
            }
            uiElements.UseFOV = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Use FOV",
                    Default = GunSilent.Settings.UseFOV.Value,
                    Callback = function(value)
                        GunSilent.Settings.UseFOV.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Use FOV " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'UseFOV'),
                callback = function(value)
                    GunSilent.Settings.UseFOV.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Use FOV " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.FOV = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "FOV",
                    Default = GunSilent.Settings.FOV.Value,
                    Minimum = 30,
                    Maximum = 120,
                    Precision = 0,
                    Callback = function(value)
                        GunSilent.Settings.FOV.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "FOV set to: " .. value, false)
                    end
                }, 'FOV'),
                callback = function(value)
                    GunSilent.Settings.FOV.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "FOV set to: " .. value, false)
                end
            }
            uiElements.ShowCircle = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Show Circle",
                    Default = GunSilent.Settings.ShowCircle.Value,
                    Callback = function(value)
                        GunSilent.Settings.ShowCircle.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Show Circle " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'ShowCircle'),
                callback = function(value)
                    GunSilent.Settings.ShowCircle.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Show Circle " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.CircleMethod = {
                element = UI.Sections.GunSilent:Dropdown({
                    Name = "Circle Method",
                    Default = GunSilent.Settings.CircleMethod.Value,
                    Options = GunSilent.Settings.CircleMethod.Options,
                    Callback = function(value)
                        GunSilent.Settings.CircleMethod.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Circle Method set to: " .. value, true)
                    end
                }, 'CircleMethod'),
                callback = function(value)
                    GunSilent.Settings.CircleMethod.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Circle Method set to: " .. value, true)
                end
            }
            uiElements.PredictVisual = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Predict Visual",
                    Default = GunSilent.Settings.PredictVisual.Value,
                    Callback = function(value)
                        GunSilent.Settings.PredictVisual.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Predict Visual " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'PredictVisual'),
                callback = function(value)
                    GunSilent.Settings.PredictVisual.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Predict Visual " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.TrajectoryBeam = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Trajectory Beam",
                    Default = GunSilent.Settings.TrajectoryBeam.Value,
                    Callback = function(value)
                        GunSilent.Settings.TrajectoryBeam.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Trajectory Beam " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'TrajectoryBeam'),
                callback = function(value)
                    GunSilent.Settings.TrajectoryBeam.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Trajectory Beam " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.HitChance = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Hit Chance",
                    Default = GunSilent.Settings.HitChance.Value,
                    Minimum = 0,
                    Maximum = 100,
                    Precision = 0,
                    Callback = function(value)
                        GunSilent.Settings.HitChance.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Hit Chance set to: " .. value .. "%", false)
                    end
                }, 'HitChance'),
                callback = function(value)
                    GunSilent.Settings.HitChance.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Hit Chance set to: " .. value .. "%", false)
                end
            }
            UI.Sections.GunSilent:Header({ Name = "Prediction Settings" })
            uiElements.PredictionStrength = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Prediction Strength",
                    Minimum = 0.5,
                    Maximum = 1.5,
                    Default = GunSilent.Settings.PredictionStrength.Value,
                    Precision = 2,
                    Callback = function(value)
                        GunSilent.Settings.PredictionStrength.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Prediction Strength set to: " .. value, false)
                    end
                }, 'PredictionStrength'),
                callback = function(value)
                    GunSilent.Settings.PredictionStrength.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Prediction Strength set to: " .. value, false)
                end
            }
            uiElements.PingCompensation = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Ping Compensation",
                    Minimum = 0.0,
                    Maximum = 0.2,
                    Default = GunSilent.Settings.PingCompensation.Value,
                    Precision = 3,
                    Callback = function(value)
                        GunSilent.Settings.PingCompensation.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Ping Compensation set to: " .. value .. "s", false)
                    end
                }, 'PingCompensation'),
                callback = function(value)
                    GunSilent.Settings.PingCompensation.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Ping Compensation set to: " .. value .. "s", false)
                end
            }
            uiElements.SmoothingFactor = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Smoothing Factor",
                    Minimum = 0.05,
                    Maximum = 0.2,
                    Default = GunSilent.Settings.SmoothingFactor.Value,
                    Precision = 2,
                    Callback = function(value)
                        GunSilent.Settings.SmoothingFactor.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Smoothing Factor set to: " .. value, false)
                    end
                }, 'SmoothingFactor'),
                callback = function(value)
                    GunSilent.Settings.SmoothingFactor.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Smoothing Factor set to: " .. value, false)
                end
            }
            uiElements.ResolverEnabled = {
                element = UI.Sections.GunSilent:Toggle({
                    Name = "Resolver Enabled",
                    Default = GunSilent.Settings.ResolverEnabled.Value,
                    Callback = function(value)
                        GunSilent.Settings.ResolverEnabled.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Resolver " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'ResolverEnabled'),
                callback = function(value)
                    GunSilent.Settings.ResolverEnabled.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Resolver " .. (value and "Enabled" or "Disabled"), true)
                end
            }
            uiElements.ResolverThreshold = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Resolver Threshold",
                    Minimum = 0.2,
                    Maximum = 0.5,
                    Default = GunSilent.Settings.ResolverThreshold.Value,
                    Precision = 2,
                    Callback = function(value)
                        GunSilent.Settings.ResolverThreshold.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Resolver Threshold set to: " .. value, false)
                    end
                }, 'ResolverThreshold'),
                callback = function(value)
                    GunSilent.Settings.ResolverThreshold.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Resolver Threshold set to: " .. value, false)
                end
            }
            uiElements.BulletSpeed = {
                element = UI.Sections.GunSilent:Slider({
                    Name = "Bullet Speed",
                    Minimum = 1000,
                    Maximum = 5000,
                    Default = GunSilent.Settings.BulletSpeed.Value,
                    Precision = 0,
                    Callback = function(value)
                        GunSilent.Settings.BulletSpeed.Value = value
                        safeNotify(GunSilent.notify, "GunSilent", "Bullet Speed set to: " .. value, false)
                    end
                }, 'BulletSpeed'),
                callback = function(value)
                    GunSilent.Settings.BulletSpeed.Value = value
                    safeNotify(GunSilent.notify, "GunSilent", "Bullet Speed set to: " .. value, false)
                end
            }
            local gunconfigSection = UI.Tabs.Config:Section({ Name = "GunSilent Sync", Side = "Right" })
            gunconfigSection:Header({ Name = "GunSilent Settings Sync" })
            gunconfigSection:Button({
                Name = "Sync Settings",
                Callback = function()
                    uiElements.GSEnabled.callback(uiElements.GSEnabled.element:GetState())
                    uiElements.RangePlus.callback(uiElements.RangePlus.element:GetValue())
                    local hitPartOptions = uiElements.HitPart.element:GetOptions()
                    for option, selected in pairs(hitPartOptions) do
                        if selected then
                            uiElements.HitPart.callback(option)
                            break
                        end
                    end
                    uiElements.ShotgunSupport.callback(uiElements.ShotgunSupport.element:GetState())
                    uiElements.GenerateBullets.callback(uiElements.GenerateBullets.element:GetValue())
                    uiElements.TestGenerateBullets.callback(uiElements.TestGenerateBullets.element:GetState())
                    local sortMethodOptions = uiElements.SortMethod.element:GetOptions()
                    for option, selected in pairs(sortMethodOptions) do
                        if selected then
                            uiElements.SortMethod.callback(option)
                            break
                        end
                    end
                    uiElements.UseFOV.callback(uiElements.UseFOV.element:GetState())
                    uiElements.FOV.callback(uiElements.FOV.element:GetValue())
                    uiElements.ShowCircle.callback(uiElements.ShowCircle.element:GetState())
                    uiElements.CircleMethod.callback(uiElements.CircleMethod.element:GetValue())
                    uiElements.PredictVisual.callback(uiElements.PredictVisual.element:GetState())
                    uiElements.TrajectoryBeam.callback(uiElements.TrajectoryBeam.element:GetState())
                    uiElements.HitChance.callback(uiElements.HitChance.element:GetValue())
                    uiElements.PredictionStrength.callback(uiElements.PredictionStrength.element:GetValue())
                    uiElements.PingCompensation.callback(uiElements.PingCompensation.element:GetValue())
                    uiElements.SmoothingFactor.callback(uiElements.SmoothingFactor.element:GetValue())
                    uiElements.ResolverEnabled.callback(uiElements.ResolverEnabled.element:GetState())
                    uiElements.ResolverThreshold.callback(uiElements.ResolverThreshold.element:GetValue())
                    uiElements.BulletSpeed.callback(uiElements.BulletSpeed.element:GetValue())
                    safeNotify(GunSilent.notify, "GunSilent", "Settings synchronized with UI!", true)
                end
            }, 'SyncSettings')
        end
    end

    initializeGunSilent()
end

return { Init = Init }
