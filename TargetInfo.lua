local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGuiService = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TargetInfo = {
    Init = function(UI, Core, notify)
        -- Настройки для TargetHud
        local TargetHud = {
            Settings = {
                Enabled = { Value = false, Default = false },
                Preview = { Value = false, Default = false },
                AvatarPulseDuration = { Value = 0.4, Default = 0.4 },
                DamageAnimationCooldown = { Value = 0.5, Default = 0.5 },
                OrbsEnabled = { Value = true, Default = true },
                OrbCount = { Value = 6, Default = 6 },
                OrbLifetime = { Value = 1.5, Default = 1.5 },
                OrbFadeDuration = { Value = 0.9, Default = 0.9 },
                OrbMoveDistance = { Value = 50, Default = 50 }
            },
            State = {
                CurrentTarget = nil,
                CurrentThumbnail = nil,
                PreviousHealth = nil,
                LastDamageAnimationTime = 0,
                LastUpdateTime = 0,
                UpdateInterval = 0.1
            }
        }

        -- Настройки для TargetInventory
        local TargetInventorySettings = {
            ShowNick = false,
            AlwaysVisible = true,
            DistanceLimit = 0,
            TargetMode = "GunSilent Target",
            Enabled = false,
            AppearAnim = true,
            FOV = { Value = 100, Default = 100 },
            ShowCircle = { Value = false, Default = false },
            CircleMethod = { Value = "Middle", Default = "Middle" },
            CircleGradient = { Value = false, Default = false },
            LastTarget = nil,
            LastUpdateTime = 0,
            UpdateInterval = 0.2,
            LastFovUpdateTime = 0,
            FovUpdateInterval = 1/30 -- ~30 FPS для круга FOV
        }

        -- Создание ScreenGui для TargetHud
        local hudScreenGui = Instance.new("ScreenGui")
        hudScreenGui.Name = "TargetHUDGui"
        hudScreenGui.Parent = Core.Services.CoreGuiService
        hudScreenGui.ResetOnSpawn = false
        hudScreenGui.IgnoreGuiInset = true

        local hudFrame = Instance.new("Frame")
        hudFrame.Size = UDim2.new(0, 220, 0, 90)
        hudFrame.Position = UDim2.new(0, 500, 0, 50)
        hudFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        hudFrame.BackgroundTransparency = 0.3
        hudFrame.BorderSizePixel = 0
        hudFrame.Visible = false
        hudFrame.Parent = hudScreenGui

        local hudCorner = Instance.new("UICorner")
        hudCorner.CornerRadius = UDim.new(0, 10)
        hudCorner.Parent = hudFrame

        local playerIcon = Instance.new("ImageLabel")
        playerIcon.Size = UDim2.new(0, 40, 0, 40)
        playerIcon.Position = UDim2.new(0, 10, 0, 10)
        playerIcon.BackgroundTransparency = 1
        playerIcon.Image = ""
        playerIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        playerIcon.Visible = false
        playerIcon.Parent = hudFrame

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 5)
        iconCorner.Parent = playerIcon

        local orbFrame = Instance.new("Frame")
        orbFrame.Size = UDim2.new(0, 40, 0, 40)
        orbFrame.Position = UDim2.new(0, 10, 0, 10)
        orbFrame.BackgroundTransparency = 1
        orbFrame.Visible = true
        orbFrame.Parent = hudFrame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 150, 0, 40)
        nameLabel.Position = UDim2.new(0, 60, 0, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "None"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 16
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextScaled = true
        nameLabel.TextWrapped = true
        nameLabel.Visible = false
        nameLabel.Parent = hudFrame

        local healthLabel = Instance.new("TextLabel")
        healthLabel.Size = UDim2.new(0, 150, 0, 20)
        healthLabel.Position = UDim2.new(0, 60, 0, 50)
        healthLabel.BackgroundTransparency = 1
        healthLabel.Text = "HP: 0.0"
        healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        healthLabel.TextSize = 16
        healthLabel.Font = Enum.Font.Gotham
        healthLabel.TextXAlignment = Enum.TextXAlignment.Left
        healthLabel.Visible = false
        healthLabel.Parent = hudFrame

        local healthBarBackground = Instance.new("Frame")
        healthBarBackground.Size = UDim2.new(0, 200, 0, 10)
        healthBarBackground.Position = UDim2.new(0, 10, 0, 75)
        healthBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        healthBarBackground.BackgroundTransparency = 0.5
        healthBarBackground.BorderSizePixel = 0
        healthBarBackground.Visible = false
        healthBarBackground.Parent = hudFrame

        local healthBarBgCorner = Instance.new("UICorner")
        healthBarBgCorner.CornerRadius = UDim.new(0, 5)
        healthBarBgCorner.Parent = healthBarBackground

        local healthBarFill = Instance.new("Frame")
        healthBarFill.Size = UDim2.new(0, 0, 0, 10)
        healthBarFill.Position = UDim2.new(0, 0, 0, 0)
        healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBarFill.BorderSizePixel = 0
        healthBarFill.Visible = false
        healthBarFill.Parent = healthBarBackground

        local healthBarFillCorner = Instance.new("UICorner")
        healthBarFillCorner.CornerRadius = UDim.new(0, 5)
        healthBarFillCorner.Parent = healthBarFill

        -- Создание ScreenGui для TargetInventory
        local invScreenGui = Instance.new("ScreenGui")
        invScreenGui.Name = "TargetInventoryGui"
        invScreenGui.ResetOnSpawn = false
        invScreenGui.IgnoreGuiInset = true
        invScreenGui.Parent = Core.Services.CoreGuiService

        local invFrame = Instance.new("Frame")
        invFrame.Size = UDim2.new(0, 220, 0, 150)
        invFrame.Position = UDim2.new(0, 50, 0, 250)
        invFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        invFrame.BackgroundTransparency = 0.3
        invFrame.BorderSizePixel = 0
        invFrame.Visible = false
        invFrame.Parent = invScreenGui

        local invCorner = Instance.new("UICorner")
        invCorner.CornerRadius = UDim.new(0, 10)
        invCorner.Parent = invFrame

        local invTitleLabel = Instance.new("TextLabel")
        invTitleLabel.Size = UDim2.new(0, 200, 0, 20)
        invTitleLabel.Position = UDim2.new(0, 10, 0, 10)
        invTitleLabel.BackgroundTransparency = 1
        invTitleLabel.Text = "Target Inventory"
        invTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        invTitleLabel.TextSize = 16
        invTitleLabel.Font = Enum.Font.GothamBold
        invTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        invTitleLabel.Parent = invFrame

        local equippedContainer = Instance.new("Frame")
        equippedContainer.Size = UDim2.new(0, 200, 0, 20)
        equippedContainer.Position = UDim2.new(0, 10, 0, 35)
        equippedContainer.BackgroundTransparency = 1
        equippedContainer.Parent = invFrame

        local equippedIcon = Instance.new("ImageLabel")
        equippedIcon.Size = UDim2.new(0, 20, 0, 20)
        equippedIcon.Position = UDim2.new(0, 0, 0, 0)
        equippedIcon.BackgroundTransparency = 1
        equippedIcon.Image = ""
        equippedIcon.Parent = equippedContainer

        local equippedLabel = Instance.new("TextLabel")
        equippedLabel.Size = UDim2.new(0, 170, 0, 20)
        equippedLabel.Position = UDim2.new(0, 25, 0, 0)
        equippedLabel.BackgroundTransparency = 1
        equippedLabel.Text = "Equipped: None"
        equippedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        equippedLabel.TextSize = 14
        equippedLabel.Font = Enum.Font.Gotham
        equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
        equippedLabel.Parent = equippedContainer

        local inventoryFrame = Instance.new("ScrollingFrame")
        inventoryFrame.Size = UDim2.new(0, 200, 0, 85)
        inventoryFrame.Position = UDim2.new(0, 10, 0, 55)
        inventoryFrame.BackgroundTransparency = 1
        inventoryFrame.BorderSizePixel = 0
        inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        inventoryFrame.ScrollBarThickness = 5
        inventoryFrame.Parent = invFrame

        local inventoryListLayout = Instance.new("UIListLayout")
        inventoryListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        inventoryListLayout.Padding = UDim.new(0, 2)
        inventoryListLayout.Parent = inventoryFrame

        local nickLabel = Instance.new("TextLabel")
        nickLabel.Size = UDim2.new(0, 200, 0, 20)
        nickLabel.Position = UDim2.new(0, 10, 0, 125)
        nickLabel.BackgroundTransparency = 1
        nickLabel.Text = ""
        nickLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nickLabel.TextSize = 14
        nickLabel.Font = Enum.Font.GothamBold
        nickLabel.TextXAlignment = Enum.TextXAlignment.Center
        nickLabel.Parent = invFrame

        -- Круг FOV для TargetInventory
        local fovCircle = Instance.new("Frame")
        fovCircle.Size = UDim2.new(0, TargetInventorySettings.FOV.Value, 0, TargetInventorySettings.FOV.Value)
        fovCircle.Position = UDim2.new(0.5, -TargetInventorySettings.FOV.Value / 2, 0.5, -TargetInventorySettings.FOV.Value / 2)
        fovCircle.BackgroundTransparency = 1
        fovCircle.Visible = false
        fovCircle.Parent = invScreenGui

        local fovCircleBorder = Instance.new("UIStroke")
        fovCircleBorder.Color = Color3.fromRGB(255, 255, 255)
        fovCircleBorder.Thickness = 1
        fovCircleBorder.Transparency = 0.5
        fovCircleBorder.Parent = fovCircle

        local fovCircleCorner = Instance.new("UICorner")
        fovCircleCorner.CornerRadius = UDim.new(1, 0)
        fovCircleCorner.Parent = fovCircle

        -- Функции TargetHud
        local function UpdatePlayerIcon(target)
            if not target then
                playerIcon.Image = ""
                playerIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                playerIcon.Size = UDim2.new(0, 40, 0, 40)
                TargetHud.State.CurrentThumbnail = nil
                return
            end

            local userId = target.UserId
            if TargetHud.State.CurrentThumbnail and TargetHud.State.CurrentThumbnail.UserId == userId then
                return
            end

            local success, thumbnailUrl = pcall(function()
                return Core.Services.Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)

            if success and thumbnailUrl then
                playerIcon.Image = thumbnailUrl
                TargetHud.State.CurrentThumbnail = { UserId = userId, Url = thumbnailUrl }
            else
                playerIcon.Image = ""
                TargetHud.State.CurrentThumbnail = nil
            end
        end

        local function UpdateHealthBarColor(health, maxHealth)
            local healthPercent = health / maxHealth
            local green = Color3.fromRGB(0, 255, 0)
            local yellow = Color3.fromRGB(255, 255, 0)
            local red = Color3.fromRGB(255, 0, 0)

            local color
            if healthPercent > 0.5 then
                local t = (healthPercent - 0.5) / 0.5
                color = green:Lerp(yellow, 1 - t)
            else
                local t = healthPercent / 0.5
                color = yellow:Lerp(red, 1 - t)
            end

            healthBarFill.BackgroundColor3 = color
        end

        local function CreateOrb()
            local orb = Instance.new("ImageLabel")
            orb.Size = UDim2.new(0, 8, 0, 8)
            orb.BackgroundTransparency = 0
            orb.Image = "rbxassetid://0"
            orb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            orb.Position = UDim2.new(0.5, -4, 0.5, -4)
            orb.Parent = orbFrame

            local orbCorner = Instance.new("UICorner")
            orbCorner.CornerRadius = UDim.new(0.5, 0)
            orbCorner.Parent = orb

            local orbGradient = Instance.new("UIGradient")
            orbGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Core.GradientColors.Color1.Value),
                ColorSequenceKeypoint.new(1, Core.GradientColors.Color2.Value)
            })
            orbGradient.Rotation = 45
            orbGradient.Parent = orb

            return orb
        end

        local function AnimateOrb(orb)
            local angle = math.random() * 2 * math.pi
            local moveX = math.cos(angle) * TargetHud.Settings.OrbMoveDistance.Value
            local moveY = math.sin(angle) * TargetHud.Settings.OrbMoveDistance.Value

            local targetPosition = UDim2.new(0.5, -4 + moveX, 0.5, -4 + moveY)
            local tweenInfo = TweenInfo.new(TargetHud.Settings.OrbLifetime.Value, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

            Core.Services.TweenService:Create(orb, tweenInfo, {
                Size = UDim2.new(0, 0, 0, 0),
                Position = targetPosition,
                BackgroundTransparency = 1
            }):Play()

            task.delay(TargetHud.Settings.OrbFadeDuration.Value, function()
                orb:Destroy()
            end)
        end

        local function PlayDamageAnimation()
            if not TargetHud.State.CurrentTarget or tick() - TargetHud.State.LastDamageAnimationTime < TargetHud.Settings.DamageAnimationCooldown.Value then
                return
            end
            TargetHud.State.LastDamageAnimationTime = tick()

            local redColor = Color3.fromRGB(200, 0, 0)
            local originalColor = Color3.fromRGB(255, 255, 255)
            local originalSize = UDim2.new(0, 40, 0, 40)
            local pulseSize = UDim2.new(0, 44, 0, 44)

            Core.Services.TweenService:Create(
                playerIcon,
                TweenInfo.new(TargetHud.Settings.AvatarPulseDuration.Value, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = redColor, Size = pulseSize }
            ):Play()

            if TargetHud.Settings.OrbsEnabled.Value then
                local orbCount = math.min(TargetHud.Settings.OrbCount.Value, 10)
                for i = 1, orbCount do
                    AnimateOrb(CreateOrb())
                end
            end

            task.delay(TargetHud.Settings.AvatarPulseDuration.Value, function()
                Core.Services.TweenService:Create(
                    playerIcon,
                    TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { ImageColor3 = originalColor, Size = originalSize }
                ):Play()
            end)
        end

        local function UpdateHudPreview()
            if not TargetHud.Settings.Enabled.Value then
                hudFrame.Visible = false
                return
            end

            if TargetHud.Settings.Preview.Value then
                hudFrame.Visible = true
                playerIcon.Visible = true
                nameLabel.Visible = true
                healthLabel.Visible = true
                healthBarBackground.Visible = true
                healthBarFill.Visible = true

                -- Проверяем, есть ли валидная текущая цель
                local target = TargetHud.State.CurrentTarget
                if target and target.Character and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 then
                    local humanoid = target.Character.Humanoid
                    nameLabel.Text = target.Name
                    healthLabel.Text = string.format("HP: %.1f", humanoid.Health)
                    healthBarFill.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
                    UpdateHealthBarColor(humanoid.Health, humanoid.MaxHealth)
                    UpdatePlayerIcon(target)
                else
                    -- Если цели нет или она невалидна, показываем локального игрока
                    nameLabel.Text = "Preview"
                    healthLabel.Text = "HP: 100.0"
                    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
                    UpdateHealthBarColor(100, 100)
                    UpdatePlayerIcon(Core.PlayerData.LocalPlayer)
                end
            elseif not TargetHud.State.CurrentTarget then
                hudFrame.Visible = false
                playerIcon.Visible = false
                nameLabel.Visible = false
                healthLabel.Visible = false
                healthBarBackground.Visible = false
                healthBarFill.Visible = false
            end
        end

        local function UpdateTargetHud()
            if not TargetHud.Settings.Enabled.Value then
                UpdateHudPreview()
                return
            end

            local currentTime = tick()
            if currentTime - TargetHud.State.LastUpdateTime < TargetHud.State.UpdateInterval then
                return
            end
            TargetHud.State.LastUpdateTime = currentTime

            local target = Core.GunSilentTarget.CurrentTarget
            if TargetHud.Settings.Preview.Value then
                target = TargetHud.State.CurrentTarget or Core.PlayerData.LocalPlayer
            end

            -- Проверка валидности цели
            if not target or not target.Character or not target.Character:FindFirstChild("Humanoid") or target.Character.Humanoid.Health <= 0 then
                TargetHud.State.CurrentTarget = nil
                TargetHud.State.PreviousHealth = nil
                UpdateHudPreview()
                return
            end

            local humanoid = target.Character.Humanoid
            local health = humanoid.Health
            local maxHealth = humanoid.MaxHealth

            hudFrame.Visible = true
            playerIcon.Visible = true
            nameLabel.Visible = true
            healthLabel.Visible = true
            healthBarBackground.Visible = true
            healthBarFill.Visible = true

            nameLabel.Text = target.Name
            healthLabel.Text = string.format("HP: %.1f", health)
            healthBarFill.Size = UDim2.new(health / maxHealth, 0, 1, 0)
            UpdateHealthBarColor(health, maxHealth)
            UpdatePlayerIcon(target)

            if TargetHud.State.PreviousHealth and health < TargetHud.State.PreviousHealth then
                PlayDamageAnimation()
            end
            TargetHud.State.PreviousHealth = health
            TargetHud.State.CurrentTarget = target
        end

        -- Перетаскивание для TargetHud
        local hudDragging = false
        local hudDragStart = nil
        local hudStartPos = nil

        Core.Services.UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and hudFrame.Visible then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local hudPos = hudFrame.Position
                local hudSize = hudFrame.Size
                if mousePos.X >= hudPos.X.Offset and mousePos.X <= hudPos.X.Offset + hudSize.X.Offset and
                   mousePos.Y >= hudPos.Y.Offset and mousePos.Y <= hudPos.Y.Offset + hudSize.Y.Offset then
                    hudDragging = true
                    hudDragStart = mousePos
                    hudStartPos = hudPos
                end
            end
        end)

        Core.Services.UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and hudDragging then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local delta = mousePos - hudDragStart
                hudFrame.Position = UDim2.new(0, hudStartPos.X.Offset + delta.X, 0, hudStartPos.Y.Offset + delta.Y)
            end
        end)

        Core.Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                hudDragging = false
            end
        end)

        -- Функции TargetInventory
        local function getItemIcon(itemName)
            local Items = ReplicatedStorage:WaitForChild("Items")
            local GunItems = Items:WaitForChild("gun")
            local MeleeItems = Items:WaitForChild("melee")
            local ThrowableItems = Items:WaitForChild("throwable")
            local ConsumableItems = Items:WaitForChild("consumable")
            local MiscItems = Items:WaitForChild("misc")

            if GunItems:FindFirstChild(itemName) then return "rbxassetid://109065124754087"
            elseif MeleeItems:FindFirstChild(itemName) then return "rbxassetid://10455604811"
            elseif ThrowableItems:FindFirstChild(itemName) then return "rbxassetid://13492316452"
            elseif ConsumableItems:FindFirstChild(itemName) then return "rbxassetid://17181103870"
            elseif MiscItems:FindFirstChild(itemName) then return "rbxassetid://6966623635"
            else return "" end
        end

        local function getTargetEquippedItem(target)
            if not target or not target.Character then return "None", nil end
            local character = target.Character
            for _, item in pairs(character:GetChildren()) do
                if item:IsA("Tool") and item.Name:lower() ~= "fists" then
                    return item.Name, item.Name
                end
            end
            return "None", nil
        end

        local function getTargetInventory(target)
            if not target then return {} end
            local backpack = target:FindFirstChild("Backpack")
            if not backpack then return {} end
            local _, equippedItemName = getTargetEquippedItem(target)
            local items = {}
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") and item.Name:lower() ~= "fists" and item.Name ~= equippedItemName then
                    table.insert(items, item.Name)
                end
            end
            return items
        end

        local function getNearestPlayerToMouse()
            local localPlayer = Core.PlayerData.LocalPlayer
            local localCharacter = localPlayer.Character
            if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return nil end
            local localPos = localCharacter.HumanoidRootPart.Position

            local referencePos
            if TargetInventorySettings.CircleMethod.Value == "Middle" then
                local viewportSize = Core.Services.Workspace.CurrentCamera.ViewportSize
                referencePos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
            else
                referencePos = Core.Services.UserInputService:GetMouseLocation()
            end

            local nearestPlayer = nil
            local minDist = TargetInventorySettings.FOV.Value

            for _, player in pairs(Core.Services.Players:GetPlayers()) do
                if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPos = player.Character.HumanoidRootPart.Position
                    local screenPos = Core.Services.Workspace.CurrentCamera:WorldToScreenPoint(targetPos)
                    local distToReference = (Vector2.new(screenPos.X, screenPos.Y) - referencePos).Magnitude
                    local worldDist = (localPos - targetPos).Magnitude

                    if distToReference < minDist and (TargetInventorySettings.DistanceLimit == 0 or worldDist <= TargetInventorySettings.DistanceLimit) then
                        minDist = distToReference
                        nearestPlayer = player
                    end
                end
            end
            return nearestPlayer
        end

        local function isGunEquipped()
            local character = Core.PlayerData.LocalPlayer.Character
            if not character then return false end
            for _, child in pairs(character:GetChildren()) do
                if child:IsA("Tool") then
                    local gunItem = game:GetService("ReplicatedStorage"):WaitForChild("Items"):WaitForChild("gun"):FindFirstChild(child.Name)
                    return gunItem ~= nil
                end
            end
            return false
        end

        local function playAppearAnimation()
            if not TargetInventorySettings.AppearAnim then
                invFrame.Size = UDim2.new(0, 220, 0, 150)
                invFrame.BackgroundTransparency = 0.3
                for _, child in pairs(invFrame:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                        child.Visible = true
                    end
                end
                return
            end

            for _, child in pairs(invFrame:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                    child.Visible = false
                end
            end

            invFrame.Size = UDim2.new(0, 220 * 0.5, 0, 150 * 0.5)
            invFrame.BackgroundTransparency = 1

            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            Core.Services.TweenService:Create(invFrame, tweenInfo, {
                Size = UDim2.new(0, 220, 0, 150),
                BackgroundTransparency = 0.3
            }):Play()

            task.delay(0.5, function()
                for _, child in pairs(invFrame:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("ImageLabel") then
                        child.Visible = true
                    end
                end
            end)
        end

        local function updateFovCirclePosition()
            if not TargetInventorySettings.Enabled or not TargetInventorySettings.ShowCircle.Value or
               not (TargetInventorySettings.TargetMode == "Mouse" or TargetInventorySettings.TargetMode == "All") then
                fovCircle.Visible = false
                return
            end

            local currentTime = tick()
            if currentTime - TargetInventorySettings.LastFovUpdateTime < TargetInventorySettings.FovUpdateInterval then
                return
            end
            TargetInventorySettings.LastFovUpdateTime = currentTime

            fovCircle.Visible = true
            fovCircle.Size = UDim2.new(0, TargetInventorySettings.FOV.Value, 0, TargetInventorySettings.FOV.Value)
            if TargetInventorySettings.CircleMethod.Value == "Middle" then
                fovCircle.Position = UDim2.new(0.5, -TargetInventorySettings.FOV.Value / 2, 0.5, -TargetInventorySettings.FOV.Value / 2)
            elseif TargetInventorySettings.CircleMethod.Value == "Cursor" then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                fovCircle.Position = UDim2.new(0, mousePos.X - TargetInventorySettings.FOV.Value / 2, 0, mousePos.Y - TargetInventorySettings.FOV.Value / 2)
            end

            if TargetInventorySettings.CircleGradient.Value then
                local t = (math.sin(currentTime * 2) + 1) / 2
                fovCircleBorder.Color = Core.GradientColors.Color1.Value:Lerp(Core.GradientColors.Color2.Value, t)
            else
                fovCircleBorder.Color = Color3.fromRGB(255, 255, 255)
            end
        end

        local function updateTargetInventoryView()
            if not TargetInventorySettings.Enabled then
                invFrame.Visible = false
                return
            end

            local currentTime = tick()
            if currentTime - TargetInventorySettings.LastUpdateTime < TargetInventorySettings.UpdateInterval then
                return
            end
            TargetInventorySettings.LastUpdateTime = currentTime

            local target = nil
            local useMouseTargeting = false

            if TargetInventorySettings.TargetMode == "GunSilent Target" or TargetInventorySettings.TargetMode == "All" then
                target = Core.GunSilentTarget.CurrentTarget
            end
            if TargetInventorySettings.TargetMode == "Mouse" or (TargetInventorySettings.TargetMode == "All" and not target) then
                target = getNearestPlayerToMouse()
                useMouseTargeting = true
            end

            -- Проверка валидности цели
            if target and (not target.Character or not target.Character:FindFirstChild("Humanoid") or target.Character.Humanoid.Health <= 0) then
                target = nil
            end

            local shouldBeVisible = TargetInventorySettings.AlwaysVisible or (target ~= nil)
            if shouldBeVisible and not invFrame.Visible then
                invFrame.Visible = true
                playAppearAnimation()
            elseif not shouldBeVisible then
                invFrame.Visible = false
                return
            end

            -- Пропуск обновления UI, если цель не изменилась
            if TargetInventorySettings.LastTarget == target then
                return
            end
            TargetInventorySettings.LastTarget = target

            if TargetInventorySettings.ShowNick then
                nickLabel.Text = target and target.Name or "No Target"
                nickLabel.Visible = true
            else
                nickLabel.Visible = false
            end

            if not target then
                equippedLabel.Text = "Equipped: No Target"
                equippedIcon.Image = ""
                equippedLabel.Position = UDim2.new(0, 0, 0, 0)
                for _, child in pairs(inventoryFrame:GetChildren()) do
                    if child:IsA("Frame") then child:Destroy() end
                end
                local emptyLabel = Instance.new("Frame")
                emptyLabel.Size = UDim2.new(1, 0, 0, 20)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Parent = inventoryFrame
                local emptyText = Instance.new("TextLabel")
                emptyText.Size = UDim2.new(1, 0, 1, 0)
                emptyText.BackgroundTransparency = 1
                emptyText.Text = "Items: No Target"
                emptyText.TextColor3 = Color3.fromRGB(255, 255, 255)
                emptyText.TextSize = 14
                emptyText.Font = Enum.Font.Gotham
                emptyText.TextXAlignment = Enum.TextXAlignment.Left
                emptyText.Parent = emptyLabel
                inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 20)
                return
            end

            local equippedItem, equippedItemName = getTargetEquippedItem(target)
            equippedLabel.Text = "Equipped: " .. equippedItem
            if equippedItemName then
                equippedIcon.Image = getItemIcon(equippedItemName)
                equippedLabel.Position = UDim2.new(0, 25, 0, 0)
            else
                equippedIcon.Image = ""
                equippedLabel.Position = UDim2.new(0, 0, 0, 0)
            end

            for _, child in pairs(inventoryFrame:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end

            local inventory = getTargetInventory(target)
            if #inventory > 0 then
                for i, itemName in ipairs(inventory) do
                    local itemContainer = Instance.new("Frame")
                    itemContainer.Size = UDim2.new(1, 0, 0, 20)
                    itemContainer.BackgroundTransparency = 1
                    itemContainer.LayoutOrder = i
                    itemContainer.Parent = inventoryFrame

                    local itemIcon = Instance.new("ImageLabel")
                    itemIcon.Size = UDim2.new(0, 20, 0, 20)
                    itemIcon.Position = UDim2.new(0, 0, 0, 0)
                    itemIcon.BackgroundTransparency = 1
                    itemIcon.Image = getItemIcon(itemName)
                    itemIcon.Parent = itemContainer

                    local itemLabel = Instance.new("TextLabel")
                    itemLabel.Size = UDim2.new(0, 170, 0, 20)
                    itemLabel.Position = UDim2.new(0, 25, 0, 0)
                    itemLabel.BackgroundTransparency = 1
                    itemLabel.Text = itemName
                    itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    itemLabel.TextSize = 14
                    itemLabel.Font = Enum.Font.Gotham
                    itemLabel.TextXAlignment = Enum.TextXAlignment.Left
                    itemLabel.Parent = itemContainer
                end
                inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, #inventory * 22)
            else
                local emptyLabel = Instance.new("Frame")
                emptyLabel.Size = UDim2.new(1, 0, 0, 20)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Parent = inventoryFrame
                local emptyText = Instance.new("TextLabel")
                emptyText.Size = UDim2.new(1, 0, 1, 0)
                emptyText.BackgroundTransparency = 1
                emptyText.Text = "Items: None"
                emptyText.TextColor3 = Color3.fromRGB(255, 255, 255)
                emptyText.TextSize = 14
                emptyText.Font = Enum.Font.Gotham
                emptyText.TextXAlignment = Enum.TextXAlignment.Left
                emptyText.Parent = emptyLabel
                inventoryFrame.CanvasSize = UDim2.new(0, 0, 0, 20)
            end
        end

        -- Перетаскивание для TargetInventory
        local invDragging = false
        local invDragStart = nil
        local invStartPos = nil

        Core.Services.UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and invFrame.Visible then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local invPos = invFrame.Position
                local invSize = invFrame.Size
                if mousePos.X >= invPos.X.Offset and mousePos.X <= invPos.X.Offset + invSize.X.Offset and
                   mousePos.Y >= invPos.Y.Offset and mousePos.Y <= invPos.Y.Offset + invSize.Y.Offset then
                    invDragging = true
                    invDragStart = mousePos
                    invStartPos = invPos
                end
            end
        end)

        Core.Services.UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and invDragging then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local delta = mousePos - invDragStart
                invFrame.Position = UDim2.new(0, invStartPos.X.Offset + delta.X, 0, invStartPos.Y.Offset + delta.Y)
            end
        end)

        Core.Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                invDragging = false
            end
        end)

        -- UI для TargetHud
        if UI.Tabs.Visuals then
            UI.Sections.TargetHud = UI.Tabs.Visuals:Section({ Name = "Target HUD", Side = "Left" })
            if UI.Sections.TargetHud then
                UI.Sections.TargetHud:Header({ Name = "Target HUD Settings" })
                UI.Sections.TargetHud:Toggle({
                    Name = "Enabled",
                    Default = TargetHud.Settings.Enabled.Default,
                    Callback = function(value)
                        TargetHud.Settings.Enabled.Value = value
                        notify("Target HUD", "Target HUD " .. (value and "Enabled" or "Disabled"), true)
                        UpdateHudPreview()
                    end
                }, 'TGEnabled')
                UI.Sections.TargetHud:Toggle({
                    Name = "Preview",
                    Default = TargetHud.Settings.Preview.Default,
                    Callback = function(value)
                        TargetHud.Settings.Preview.Value = value
                        notify("Target HUD", "Preview " .. (value and "Enabled" or "Disabled"), true)
                        UpdateHudPreview()
                    end
                }, 'TPreview')
                UI.Sections.TargetHud:Slider({
                    Name = "Avatar Pulse CD",
                    Minimum = 0.1,
                    Maximum = 2,
                    Default = TargetHud.Settings.AvatarPulseDuration.Default,
                    Precision = 1,
                    Callback = function(value)
                        TargetHud.Settings.AvatarPulseDuration.Value = value
                        notify("Target HUD", "Avatar Pulse Duration set to: " .. value)
                    end
                }, 'TAvatarPulseCD')
                UI.Sections.TargetHud:Slider({
                    Name = "DamageAnim Cd",
                    Minimum = 0.1,
                    Maximum = 2,
                    Default = TargetHud.Settings.DamageAnimationCooldown.Default,
                    Precision = 1,
                    Callback = function(value)
                        TargetHud.Settings.DamageAnimationCooldown.Value = value
                        notify("Target HUD", "Damage Animation Cooldown set to: " .. value)
                    end
                }, 'TDamageAnimCD')
                UI.Sections.TargetHud:Toggle({
                    Name = "Orbs Enabled",
                    Default = TargetHud.Settings.OrbsEnabled.Default,
                    Callback = function(value)
                        TargetHud.Settings.OrbsEnabled.Value = value
                        notify("Target HUD", "Orbs " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'TOrbsEnabled')
                UI.Sections.TargetHud:Slider({
                    Name = "Orb Count",
                    Minimum = 1,
                    Maximum = 10,
                    Default = TargetHud.Settings.OrbCount.Default,
                    Precision = 0,
                    Callback = function(value)
                        TargetHud.Settings.OrbCount.Value = value
                        notify("Target HUD", "Orb Count set to: " .. value)
                    end
                }, 'TORBCount')
                UI.Sections.TargetHud:Slider({
                    Name = "Orb Lifetime",
                    Minimum = 0.1,
                    Maximum = 2,
                    Default = TargetHud.Settings.OrbLifetime.Default,
                    Precision = 1,
                    Callback = function(value)
                        TargetHud.Settings.OrbLifetime.Value = value
                        notify("Target HUD", "Orb Lifetime set to: " .. value)
                    end
                }, 'TOrbLifetime')
                UI.Sections.TargetHud:Slider({
                    Name = "OrbFade Duration",
                    Minimum = 0.1,
                    Maximum = 1,
                    Default = TargetHud.Settings.OrbFadeDuration.Default,
                    Precision = 1,
                    Callback = function(value)
                        TargetHud.Settings.OrbFadeDuration.Value = value
                        notify("Target HUD", "Orb Fade Duration set to: " .. value)
                    end
                }, 'TOrbFadeDuration')
                UI.Sections.TargetHud:Slider({
                    Name = "Orb Move Distance",
                    Minimum = 10,
                    Maximum = 120,
                    Default = TargetHud.Settings.OrbMoveDistance.Default,
                    Precision = 0,
                    Callback = function(value)
                        TargetHud.Settings.OrbMoveDistance.Value = value
                        notify("Target HUD", "Orb Move Distance set to: " .. value)
                    end
                }, 'TOrbMoveDistance')
            end

            -- UI для TargetInventory
            UI.Sections.TargetInventory = UI.Tabs.Visuals:Section({ Name = "Target Inventory", Side = "Left" })
            if UI.Sections.TargetInventory then
                UI.Sections.TargetInventory:Header({ Name = "Target Inventory Settings" })
                UI.Sections.TargetInventory:Toggle({
                    Name = "Enabled",
                    Default = false,
                    Callback = function(value)
                        TargetInventorySettings.Enabled = value
                        invFrame.Visible = value and TargetInventorySettings.AlwaysVisible
                        notify("Target Inventory", "Target Inventory " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'TEnabled')
                UI.Sections.TargetInventory:Toggle({
                    Name = "Show Nick",
                    Default = false,
                    Callback = function(value)
                        TargetInventorySettings.ShowNick = value
                        notify("Target Inventory", "Show Nick " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'ShowNickT')
                UI.Sections.TargetInventory:Toggle({
                    Name = "Always Visible",
                    Default = true,
                    Callback = function(value)
                        TargetInventorySettings.AlwaysVisible = value
                        if TargetInventorySettings.Enabled then
                            invFrame.Visible = value
                        end
                        notify("Target Inventory", "Always Visible " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'AlwaysVisible')
                UI.Sections.TargetInventory:Slider({
                    Name = "Distance Limit",
                    Minimum = 0,
                    Maximum = 100,
                    Default = 0,
                    Precision = 0,
                    Callback = function(value)
                        TargetInventorySettings.DistanceLimit = value
                        notify("Target Inventory", "Distance Limit set to " .. value)
                    end
                }, 'TDistanceLimit')
                UI.Sections.TargetInventory:Dropdown({
                    Name = "Target Mode",
                    Options = {"GunSilent Target", "Mouse", "All"},
                    Default = "GunSilent Target",
                    Callback = function(value)
                        TargetInventorySettings.TargetMode = value
                        notify("Target Inventory", "Target Mode set to " .. value, true)
                    end
                }, 'GTargetMode')
                UI.Sections.TargetInventory:Slider({
                    Name = "FOV",
                    Minimum = 50,
                    Maximum = 500,
                    Default = TargetInventorySettings.FOV.Default,
                    Precision = 0,
                    Callback = function(value)
                        TargetInventorySettings.FOV.Value = value
                        notify("Target Inventory", "FOV set to: " .. value)
                    end
                }, 'TFOV')
                UI.Sections.TargetInventory:Toggle({
                    Name = "Show FOV Circle",
                    Default = TargetInventorySettings.ShowCircle.Default,
                    Callback = function(value)
                        TargetInventorySettings.ShowCircle.Value = value
                        notify("Target Inventory", "FOV Circle " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'TShowFOVCircle')
                UI.Sections.TargetInventory:Toggle({
                    Name = "Circle Gradient",
                    Default = TargetInventorySettings.CircleGradient.Default,
                    Callback = function(value)
                        TargetInventorySettings.CircleGradient.Value = value
                        notify("Target Inventory", "Circle Gradient " .. (value and "Enabled" or "Disabled"), true)
                    end
                }, 'CircleTGradient')
                UI.Sections.TargetInventory:Dropdown({
                    Name = "Circle Method",
                    Options = {"Middle", "Cursor"},
                    Default = TargetInventorySettings.CircleMethod.Default,
                    Callback = function(value)
                        TargetInventorySettings.CircleMethod.Value = value
                        notify("Target Inventory", "Circle Method set to: " .. value, true)
                    end
                }, 'CircleMethod')
            end
        end

        -- Обновление TargetInventory и TargetHud
        Core.Services.RunService.Stepped:Connect(function()
            if TargetHud.Settings.Enabled.Value then
                UpdateTargetHud()
            end
            if TargetInventorySettings.Enabled then
                updateTargetInventoryView()
            end
        end)

        -- Отдельное обновление позиции круга FOV для плавности
        Core.Services.RunService.RenderStepped:Connect(function()
            updateFovCirclePosition()
        end)

        -- Очистка при выгрузке
    end
}

return TargetInfo
