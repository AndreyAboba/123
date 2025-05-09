local Aimbot = {}

-- Конфигурация аимбота
local Settings = {
    FOV = 100, -- Поле зрения
    ShowFOV = true, -- Показывать круг FOV
    Hitbox = "Head", -- Хитбокс: "Head", "Torso"
    Smoothness = 0.2, -- Плавность (0 - мгновенно, 1 - плавно)
    Enabled = false -- Состояние аимбота
}

-- Инициализация модуля
function Aimbot.Init(UI, Core, notify)
    -- Служебные переменные
    local Players = Core.Services.Players
    local RunService = Core.Services.RunService
    local UserInputService = Core.Services.UserInputService
    local Camera = Core.PlayerData.Camera
    local LocalPlayer = Core.PlayerData.LocalPlayer
    local FOVCircle = Drawing.new("Circle")

    -- Настройка круга FOV
    FOVCircle.Visible = Settings.ShowFOV
    FOVCircle.Radius = Settings.FOV
    FOVCircle.Color = Color3.new(1, 0, 0)
    FOVCircle.Thickness = 2
    FOVCircle.Filled = false
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- Функция проверки видимости игрока
    local function IsPlayerVisible(player)
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
        local ray = Ray.new(Camera.CFrame.Position, (character.HumanoidRootPart.Position - Camera.CFrame.Position).Unit * 1000)
        local part, position = Core.Services.Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
        return part and part:IsDescendantOf(character)
    end

    -- Функция поиска ближайшего игрока
    local function GetClosestPlayer()
        local ClosestPlayer = nil
        local ClosestDistance = Settings.FOV
        local MousePos = UserInputService:GetMouseLocation()

        for _, Player in pairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild(Settings.Hitbox) and IsPlayerVisible(Player) then
                local Hitbox = Player.Character[Settings.Hitbox]
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Hitbox.Position)
                if OnScreen then
                    local Distance = (Vector2.new(ScreenPos.X, ScreenPos.Y) - MousePos).Magnitude
                    if Distance < ClosestDistance then
                        ClosestDistance = Distance
                        ClosestPlayer = Player
                    end
                end
            end
        end
        return ClosestPlayer
    end

    -- Основной цикл аимбота
    RunService.RenderStepped:Connect(function()
        FOVCircle.Visible = Settings.ShowFOV and Settings.Enabled
        if Settings.ShowFOV then
            FOVCircle.Position = UserInputService:GetMouseLocation()
        end

        if Settings.Enabled then
            local Target = GetClosestPlayer()
            if Target and Target.Character and Target.Character:FindFirstChild(Settings.Hitbox) then
                local Hitbox = Target.Character[Settings.Hitbox]
                local TargetPosition = Hitbox.Position
                local LookVector = (TargetPosition - Camera.CFrame.Position).Unit
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookVector)
            end
        end
    end)

    -- UI для аимбота в секции Combat
    local CombatSection = UI.Tabs.Combat:Section({ Name = "Aimbot", Side = "Left" })
    CombatSection:Header({ Name = "Aimbot" }) -- Добавлен заголовок
    CombatSection:Toggle({
        Name = "Enabled",
        Default = Settings.Enabled,
        Callback = function(value)
            Settings.Enabled = value
            notify("Aimbot", value and "Enabled" or "Disabled", false)
        end
    }, "AimbotEnabled")
    CombatSection:Toggle({
        Name = "Show FOV Circle",
        Default = Settings.ShowFOV,
        Callback = function(value)
            Settings.ShowFOV = value
            FOVCircle.Visible = value and Settings.Enabled
        end
    }, "AimbotShowFOV")
    CombatSection:Slider({
        Name = "FOV Radius",
        Minimum = 50,
        Maximum = 300,
        Default = Settings.FOV,
        Callback = function(value)
            Settings.FOV = value
            FOVCircle.Radius = value
        end
    }, "AimbotFOV")
    CombatSection:Dropdown({
        Name = "Hitbox",
        Options = { "Head", "Torso" },
        Default = Settings.Hitbox,
        Callback = function(value)
            Settings.Hitbox = value
        end
    }, "AimbotHitbox")
    CombatSection:Slider({
        Name = "Smoothness",
        Minimum = 0,
        Maximum = 1,
        Default = Settings.Smoothness,
        Callback = function(value)
            Settings.Smoothness = value
        end
    }, "AimbotSmoothness")

    -- Кнопка на экране
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "AimbotToggleButtonGui"
    buttonGui.Parent = Core.Services.CoreGuiService
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false

    local State = {
        Button = { Dragging = false, InitialMousePos = nil, InitialButtonPos = nil, TouchStartTime = 0, TouchThreshold = 0.2 }
    }

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, 50, 0, 50)
    local centerX = (Camera.ViewportSize.X - 50) / 2
    local centerY = (Camera.ViewportSize.Y - 50) / 2
    buttonFrame.Position = UDim2.new(0, centerX, 0, centerY)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Parent = buttonGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = buttonFrame

    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://18821914323"
    buttonIcon.ImageTransparency = Settings.Enabled and 0 or 0.5
    buttonIcon.Parent = buttonFrame

    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.Button.TouchStartTime = tick()
            local mousePos = Vector2.new(input.Position.X, input.Position.Y)
            State.Button.Dragging = true
            State.Button.InitialMousePos = mousePos
            State.Button.InitialButtonPos = Vector2.new(buttonFrame.Position.X.Offset, buttonFrame.Position.Y.Offset)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) and State.Button.Dragging then
            local currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
            if State.Button.InitialMousePos and State.Button.InitialButtonPos then
                local delta = currentMousePos - State.Button.InitialMousePos
                local newX = State.Button.InitialButtonPos.X + delta.X
                local newY = State.Button.InitialButtonPos.Y + delta.Y
                newX = math.max(0, math.min(newX, Camera.ViewportSize.X - buttonFrame.Size.X.Offset))
                newY = math.max(0, math.min(newY, Camera.ViewportSize.Y - buttonFrame.Size.Y.Offset))
                buttonFrame.Position = UDim2.new(0, newX, 0, newY)
            end
        end
    end)

    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            State.Button.Dragging = false
            if tick() - State.Button.TouchStartTime < State.Button.TouchThreshold then
                Settings.Enabled = not Settings.Enabled
                buttonIcon.ImageTransparency = Settings.Enabled and 0 or 0.5
                notify("Aimbot", Settings.Enabled and "Enabled" or "Disabled", false)
            end
            State.Button.InitialMousePos = nil
            State.Button.InitialButtonPos = nil
        end
    end)

    notify("Aimbot", "Module loaded successfully", true)
end

return Aimbot
