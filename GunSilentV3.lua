local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GunSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        RangePlus = { Value = 50, Default = 50 },
        HitPart = { Value = "Head", Default = "Head" },
        UseFOV = { Value = true, Default = true },
        FOV = { Value = 120, Default = 120 },
        ShowCircle = { Value = true, Default = true },
        CircleMethod = { Value = "Cursor", Default = "Cursor" },
        TargetVisual = { Value = true, Default = true },
        HitChance = { Value = 100, Default = 100 }
    },
    State = {
        LastEventId = 0,
        LastTool = nil,
        TargetVisualPart = nil,
        FovCircle = nil,
        AimBeam = nil,
        Connection = nil,
        OldFireServer = nil,
        LocalCharacter = nil,
        LocalRoot = nil,
        LastTarget = nil,
        LastNotifyTime = 0,
        NotifyCooldown = 1 -- Задержка в секундах между уведомлениями
    }
}

local function isGunTool(tool)
    local items = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if not items then return false end
    local gunFolder = items:FindFirstChild("gun")
    if not gunFolder then return false end
    return gunFolder:FindFirstChild(tool.Name) ~= nil
end

local function getGunRange(tool)
    return (tool and tool:GetAttribute("Range") or 50) + GunSilent.Settings.RangePlus.Value
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

local function updateFovCircle(deltaTime)
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
    local circlePos
    if GunSilent.Settings.CircleMethod.Value == "Middle" then
        circlePos = camera.ViewportSize / 2
    else
        circlePos = UserInputService:GetMouseLocation()
    end

    if fovCircle.Radius ~= newRadius or fovCircle.Position ~= circlePos then
        fovCircle.Radius = newRadius
        fovCircle.Position = circlePos
    end
    fovCircle.Visible = true
end

local function isInFov(targetPos, camera)
    if not GunSilent.Settings.UseFOV.Value then return true end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local referencePos = GunSilent.Settings.CircleMethod.Value == "Middle" and camera.ViewportSize / 2 or UserInputService:GetMouseLocation()
    local distanceFromReference = (Vector2.new(screenPos.X, screenPos.Y) - referencePos).Magnitude
    return distanceFromReference <= math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
end

local function getNearestPlayerGun(gunRange)
    local localRoot = GunSilent.State.LocalRoot
    if not localRoot then return nil end
    local rootPos = localRoot.Position
    local camera = Workspace.CurrentCamera
    local nearestPlayer, shortestDistance = nil, gunRange
    local currentTime = tick()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            local targetChar = player.Character
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                local targetRoot = targetChar.HumanoidRootPart
                local targetHumanoid = targetChar.Humanoid
                if targetHumanoid.Health > 0 and isInFov(targetRoot.Position, camera) then
                    local distance = (rootPos - targetRoot.Position).Magnitude
                    if distance <= shortestDistance then
                        shortestDistance = distance
                        nearestPlayer = player
                        if nearestPlayer ~= GunSilent.State.LastTarget and currentTime - GunSilent.State.LastNotifyTime >= GunSilent.State.NotifyCooldown then
                            GunSilent.notify("GunSilent", "Target selected: " .. player.Name .. " at distance: " .. math.floor(distance), true)
                            GunSilent.State.LastNotifyTime = currentTime
                            GunSilent.State.LastTarget = nearestPlayer
                        end
                    end
                end
            end
        end
    end
    return nearestPlayer
end

local function getAimCFrameGun(target)
    local localRoot = GunSilent.State.LocalRoot
    if not target or not target.Character or not localRoot then return nil end
    local targetChar = target.Character
    local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    if not hitPart then return nil end
    local aimPos = hitPart.Position
    return CFrame.new(localRoot.Position, aimPos)
end

local function createHitDataGun(target)
    local localRoot = GunSilent.State.LocalRoot
    if not target or not target.Character or not localRoot then return nil end
    local targetChar = target.Character
    local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    if not hitPart then return nil end
    local direction = (hitPart.Position - localRoot.Position).Unit
    return {{Normal = direction, Instance = hitPart, Position = hitPart.Position, Material = Enum.Material.Plastic}}
end

local function updateVisualsGun(target, hasWeapon)
    local localRoot = GunSilent.State.LocalRoot
    if not GunSilent.Settings.Enabled.Value or not hasWeapon or not localRoot then
        if GunSilent.State.TargetVisualPart then GunSilent.State.TargetVisualPart.Transparency = 1 end
        if GunSilent.State.AimBeam then GunSilent.State.AimBeam.Enabled = false end
        return
    end

    local targetChar = target and target.Character
    if GunSilent.Settings.TargetVisual.Value and targetChar then
        local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
        if targetHead then
            local targetVisualPart = GunSilent.State.TargetVisualPart
            if not targetVisualPart then
                targetVisualPart = Instance.new("Part")
                targetVisualPart.Size = Vector3.new(1, 1, 1)
                targetVisualPart.Shape = Enum.PartType.Ball
                targetVisualPart.Anchored = true
                targetVisualPart.CanCollide = false
                targetVisualPart.Color = Color3.fromRGB(255, 0, 0)
                targetVisualPart.Parent = Workspace
                GunSilent.State.TargetVisualPart = targetVisualPart
            end
            targetVisualPart.Position = targetHead.Position + Vector3.new(0, 3, 0)
            targetVisualPart.Transparency = 0.5
        end
    elseif GunSilent.State.TargetVisualPart then
        GunSilent.State.TargetVisualPart.Transparency = 1
    end

    if targetChar then
        local hitPart = targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
        if hitPart then
            local aimBeam = GunSilent.State.AimBeam
            if not aimBeam then
                aimBeam = Instance.new("Beam")
                aimBeam.FaceCamera = true
                aimBeam.Width0 = 0.2
                aimBeam.Width1 = 0.2
                aimBeam.Transparency = NumberSequence.new(0.5)
                aimBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
                local attachment0 = Instance.new("Attachment")
                local attachment1 = Instance.new("Attachment")
                aimBeam.Attachment0 = attachment0
                aimBeam.Attachment1 = attachment1
                aimBeam.Parent = Workspace
                GunSilent.State.AimBeam = aimBeam
            end
            aimBeam.Attachment0.Parent = localRoot
            aimBeam.Attachment1.Parent = hitPart
            aimBeam.Enabled = true
        end
    elseif GunSilent.State.AimBeam then
        GunSilent.State.AimBeam.Enabled = false
    end
end

local function initializeGunSilent()
    if GunSilent.State.Connection then GunSilent.State.Connection:Disconnect() end

    if not GunSilent.State.OldFireServer then
        GunSilent.State.OldFireServer = hookfunction(game:GetService("ReplicatedStorage").Remotes.Send.FireServer, function(self, ...)
            local args = {...}
            if #args < 2 then
                GunSilent.notify("GunSilent", "FireServer called with insufficient args: " .. tostring(#args), true)
                return GunSilent.State.OldFireServer(self, unpack(args))
            end

            if GunSilent.Settings.Enabled.Value and typeof(args[1]) == "number" and args[2] == "shoot_gun" and math.random(100) <= GunSilent.Settings.HitChance.Value then
                GunSilent.State.LastEventId = args[1]
                local equippedTool = getEquippedGunTool(GunSilent.State.LocalCharacter)
                if not equippedTool then
                    GunSilent.notify("GunSilent", "No equipped gun tool found during FireServer", true)
                    return GunSilent.State.OldFireServer(self, unpack(args))
                end

                local gunRange = getGunRange(equippedTool)
                local nearestPlayer = getNearestPlayerGun(gunRange)
                if not nearestPlayer then
                    GunSilent.notify("GunSilent", "No target found within range during FireServer", true)
                    return GunSilent.State.OldFireServer(self, unpack(args))
                end

                local aimCFrame = getAimCFrameGun(nearestPlayer)
                local hitData = createHitDataGun(nearestPlayer)
                if not aimCFrame or not hitData then
                    GunSilent.notify("GunSilent", "Failed to generate aim data during FireServer", true)
                    return GunSilent.State.OldFireServer(self, unpack(args))
                end

                GunSilent.notify("GunSilent", "Firing at target: " .. nearestPlayer.Name .. " with event ID: " .. tostring(GunSilent.State.LastEventId), true)
                return GunSilent.State.OldFireServer(self, GunSilent.State.LastEventId, "shoot_gun", equippedTool, aimCFrame, hitData)
            end
            return GunSilent.State.OldFireServer(self, unpack(args))
        end)
    end

    GunSilent.State.Connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not GunSilent.Settings.Enabled.Value then
            if GunSilent.State.FovCircle then GunSilent.State.FovCircle.Visible = false end
            updateVisualsGun(nil, false)
            return
        end

        local character = GunSilent.State.LocalCharacter
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            GunSilent.notify("GunSilent", "Local character or root part not found", true)
            return
        end

        local currentTool = getEquippedGunTool(character)
        if currentTool ~= GunSilent.State.LastTool then
            if currentTool and not GunSilent.State.LastTool then
                GunSilent.notify("GunSilent", "Equipped: " .. currentTool.Name .. " (Total Range: " .. getGunRange(currentTool) .. ")", true)
            elseif GunSilent.State.LastTool and not currentTool then
                GunSilent.notify("GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                GunSilent.notify("GunSilent", "Switched to " .. currentTool.Name .. " (Range: " .. getGunRange(currentTool) .. ")", true)
            end
            GunSilent.State.LastTool = currentTool
        end

        updateFovCircle(deltaTime)
        if not currentTool then
            updateVisualsGun(nil, false)
            return
        end

        local gunRange = getGunRange(currentTool)
        local nearestPlayer = getNearestPlayerGun(gunRange)
        updateVisualsGun(nearestPlayer, true)
    end)
end

local function Init(UI, Core, notify)
    GunSilent.Core = Core
    GunSilent.notify = notify

    local LocalPlayer = Players.LocalPlayer
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function(character)
            character:WaitForChild("HumanoidRootPart")
            GunSilent.State.LocalCharacter = character
            GunSilent.State.LocalRoot = character.HumanoidRootPart
            GunSilent.notify("GunSilent", "Local character initialized", true)
        end)
        if LocalPlayer.Character then
            GunSilent.State.LocalCharacter = LocalPlayer.Character
            GunSilent.State.LocalRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if GunSilent.State.LocalRoot then
                GunSilent.notify("GunSilent", "Local character loaded on init", true)
            end
        end
    end

    if UI.Tabs.Combat then
        UI.Sections.GunSilent = UI.Tabs.Combat:Section({ Side = "Right", Name = "GunSilent" })
        if UI.Sections.GunSilent then
            UI.Sections.GunSilent:Header({ Name = "GunSilent" })
            UI.Sections.GunSilent:Toggle({
                Name = "Enabled",
                Default = GunSilent.Settings.Enabled.Value,
                Callback = function(value)
                    GunSilent.Settings.Enabled.Value = value
                    initializeGunSilent()
                    notify("GunSilent", "GunSilent " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Range Plus",
                Minimum = 0,
                Maximum = 200,
                Default = GunSilent.Settings.RangePlus.Value,
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.RangePlus.Value = value
                    notify("GunSilent", "Range Plus set to: " .. value, false)
                end
            })
            UI.Sections.GunSilent:Dropdown({
                Name = "Hit Part",
                Default = GunSilent.Settings.HitPart.Value,
                Options = {"Head", "UpperTorso", "HumanoidRootPart"},
                Callback = function(value)
                    GunSilent.Settings.HitPart.Value = value
                    notify("GunSilent", "Hit Part set to: " .. value, true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Use FOV",
                Default = GunSilent.Settings.UseFOV.Value,
                Callback = function(value)
                    GunSilent.Settings.UseFOV.Value = value
                    notify("GunSilent", "Use FOV " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "FOV",
                Default = GunSilent.Settings.FOV.Value,
                Minimum = 0,
                Maximum = 120,
                DisplayMethod = "Value",
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.FOV.Value = value
                    notify("GunSilent", "FOV set to: " .. value)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Circle",
                Default = GunSilent.Settings.ShowCircle.Value,
                Callback = function(value)
                    GunSilent.Settings.ShowCircle.Value = value
                    notify("GunSilent", "Show Circle " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Dropdown({
                Name = "Circle Method",
                Default = GunSilent.Settings.CircleMethod.Value,
                Options = {"Cursor", "Middle"},
                Callback = function(value)
                    GunSilent.Settings.CircleMethod.Value = value
                    notify("GunSilent", "Circle Method set to: " .. value, true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Target Visual",
                Default = GunSilent.Settings.TargetVisual.Value,
                Callback = function(value)
                    GunSilent.Settings.TargetVisual.Value = value
                    notify("GunSilent", "Target Visual " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.GunSilent:Slider({
                Name = "Hit Chance",
                Default = GunSilent.Settings.HitChance.Value,
                Minimum = 0,
                Maximum = 100,
                DisplayMethod = "Percent",
                Precision = 0,
                Callback = function(value)
                    GunSilent.Settings.HitChance.Value = value
                    notify("GunSilent", "Hit Chance set to: " .. value .. "%")
                end
            })
        end
    end

    initializeGunSilent()
end

return { Init = Init }
