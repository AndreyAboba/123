local LocalInfo = {
    Core = nil,
    Notify = nil,
    ScreenGui = nil,
    Frame = nil,
    HandCircleFrame = nil,
    SafeCircleFrame = nil,
    TitleLabel = nil,
    HandLabel = nil,
    SafeLabel = nil,
    HandIconFrame = nil,
    HandIcon = nil,
    SafeIconFrame = nil,
    SafeIcon = nil,
    HandProgressFramePercent = nil,
    HandProgressBarPercent = nil,
    HandGradientPercent = nil,
    SafeProgressFramePercent = nil,
    SafeProgressBarPercent = nil,
    SafeGradientPercent = nil,
    HandProgressLabelFrame = nil,
    HandProgressLabelPercent = nil,
    SafeProgressLabelFrame = nil,
    SafeProgressLabelPercent = nil,
    HandProgressBarCircle = nil,
    HandGradientCircle = nil,
    SafeProgressBarCircle = nil,
    SafeGradientCircle = nil,
    CurrentHand = {current = 0, max = 0},
    CurrentSafe = {current = 0, max = 0},
    CurrentHandPercent = 0,
    CurrentSafePercent = 0,
    UIConnection = nil,
    LastGradientColors = nil,
    GradientUpdateTime = 0,
    Elements = {},

    Config = {
        Enabled = false,
        UIStyleMode = "Circle",
        AnimateNumbers = true,
        AnimationDuration = 0.5,
        PercentStyle = {
            ShowHand = true,
            ShowSafe = true,
            ProgressBarWidth = 80,
            ProgressBarHeight = 10,
        },
        CircleStyle = {
            ShowHand = true,
            ShowSafe = true,
            CircleIconStyle = 2,
        },
        GradientSettings = {
            Enabled = true,
            Speed = 1,
            ColorSequence = nil,
        },
    }
}

local savedFramePosition = UDim2.new(0, 500, 0, 50)
local savedHandCirclePosition = UDim2.new(0, 490, 0, 40)
local savedSafeCirclePosition = UDim2.new(0, 570, 0, 40)
local UPDATE_INTERVAL = 1 / 30 -- 30 FPS для анимаций
local GRADIENT_INTERVAL = 1 / 15 -- 15 FPS для градиентов
local lastUpdate = 0

local function setupGui(Core)
    if not Core or not Core.Services or not Core.Services.CoreGuiService then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name, screenGui.ResetOnSpawn, screenGui.IgnoreGuiInset = "InventoryAndSafeCapacityGui", false, true
    screenGui.Parent = Core.Services.CoreGuiService
    LocalInfo.ScreenGui = screenGui
end

local function createIconFrame(pos, img)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(0, 20, 0, 20), pos, Color3.fromRGB(5, 5, 5), 0.5, 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
    local i = Instance.new("ImageLabel")
    i.Size, i.Position, i.BackgroundTransparency, i.Image = UDim2.new(0, 16, 0, 16), UDim2.new(0, 2, 0, 2), 1, img
    i.Parent = f
    f.Parent = LocalInfo.Frame
    return f, i
end

local function createProgressBar(pos, width, height)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(0, width, 0, height), pos, Color3.fromRGB(5, 5, 5), 0.5, 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
    local b = Instance.new("Frame")
    b.Size, b.BackgroundTransparency, b.BorderSizePixel = UDim2.new(0, 0, 1, 0), 0, 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 2)
    local g = Instance.new("UIGradient")
    g.Color, g.Rotation = ColorSequence.new(Color3.fromRGB(255, 255, 255)), 0
    g.Parent = b
    b.Parent = f
    f.Parent = LocalInfo.Frame
    return f, b, g
end

local function createProgressLabel(pos)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(0, 30, 0, 14), pos, Color3.fromRGB(5, 5, 5), 0.5, 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
    local l = Instance.new("TextLabel")
    l.Size, l.Position, l.BackgroundTransparency, l.Text, l.TextColor3, l.TextSize, l.Font, l.TextXAlignment, l.TextScaled, l.TextWrapped = 
        UDim2.new(0, 30, 0, 14), UDim2.new(0, 0, 0, 0), 1, "0%", Color3.fromRGB(255, 255, 245), 12, Enum.Font.Gotham, Enum.TextXAlignment.Center, true, true
    l.Parent = f
    f.Parent = LocalInfo.Frame
    return f, l
end

local function makeDraggable(f)
    if not f or not LocalInfo.Core or not LocalInfo.Core.Services or not LocalInfo.Core.Services.UserInputService then return end
    local dragging, dragStart, startPos = false, nil, nil
    LocalInfo.Core.Services.UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local mp = LocalInfo.Core.Services.UserInputService:GetMouseLocation()
            local fp, fs = f.Position, f.Size
            if mp.X >= fp.X.Offset and mp.X <= fp.X.Offset + fs.X.Offset and mp.Y >= fp.Y.Offset and mp.Y <= fp.Y.Offset + fs.Y.Offset then
                dragging, dragStart, startPos = true, mp, fp
            end
        end
    end)
    LocalInfo.Core.Services.UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local mp = LocalInfo.Core.Services.UserInputService:GetMouseLocation()
            f.Position = UDim2.new(0, startPos.X.Offset + (mp - dragStart).X, 0, startPos.Y.Offset + (mp - dragStart).Y)
            savedFramePosition = f.Position
        end
    end)
    LocalInfo.Core.Services.UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

local function makeDraggableV2(element)
    if not element or not LocalInfo.Core or not LocalInfo.Core.Services or not LocalInfo.Core.Services.UserInputService then return end
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, element.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    element.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    LocalInfo.Core.Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            local newPosX = math.clamp(startPos.X.Offset + delta.X, 0, LocalInfo.Core.Services.Workspace.CurrentCamera.ViewportSize.X - element.Size.X.Offset)
            local newPosY = math.clamp(startPos.Y.Offset + delta.Y, 0, LocalInfo.Core.Services.Workspace.CurrentCamera.ViewportSize.Y - element.Size.Y.Offset)
            element.Position = UDim2.new(0, newPosX, 0, newPosY)
            if element.Name == "HandCircleFrame" then savedHandCirclePosition = element.Position
            elseif element.Name == "SafeCircleFrame" then savedSafeCirclePosition = element.Position end
        end
    end)
end

local function createCircleProgress(parent, pos, img, isCircle)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(0, 70, 0, 70), pos, 1, 0
    
    local bg = Instance.new("Frame")
    bg.Size, bg.BackgroundTransparency, bg.ClipsDescendants = UDim2.new(1, 0, 1, 0), 1, true
    local bgb = Instance.new("Frame")
    bgb.Size, bgb.Position, bgb.BackgroundColor3, bgb.BackgroundTransparency, bgb.BorderSizePixel = 
        UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(5, 5, 5), 0.5, 0
    Instance.new("UICorner", bgb).CornerRadius = isCircle and UDim.new(1, 0) or UDim.new(0, 10)
    bgb.Parent = bg
    bg.Parent = f

    local pc = Instance.new("Frame")
    pc.Size, pc.BackgroundTransparency, pc.ClipsDescendants = UDim2.new(1, 0, 1, 0), 1, true
    local pb = Instance.new("Frame")
    pb.Size, pb.Position, pb.BackgroundTransparency, pb.BorderSizePixel = 
        UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 0), 0, 0
    Instance.new("UICorner", pb).CornerRadius = isCircle and UDim.new(1, 0) or UDim.new(0, 10)
    local g = Instance.new("UIGradient")
    g.Color, g.Rotation = ColorSequence.new(Color3.fromRGB(255, 255, 255)), 90
    g.Parent = pb
    pb.Parent = pc
    pc.Parent = f

    if LocalInfo.Config.CircleStyle.CircleIconStyle == 1 then
        local i = Instance.new("ImageLabel")
        i.Size, i.Position, i.BackgroundTransparency, i.Image, i.Parent = UDim2.new(0, 40, 0, 40), UDim2.new(0.5, -20, 0.5, -20), 1, img, f
    else
        local ifr = Instance.new("Frame")
        ifr.Size, ifr.Position, ifr.BackgroundColor3, ifr.BackgroundTransparency, ifr.BorderSizePixel = UDim2.new(0, 25, 0, 25), UDim2.new(1, -16, 0, -8), Color3.fromRGB(5, 5, 5), 0.5, 0
        Instance.new("UICorner", ifr).CornerRadius = UDim.new(0.5, 0)
        local i = Instance.new("ImageLabel")
        i.Size, i.Position, i.BackgroundTransparency, i.Image, i.Parent = UDim2.new(0, 18, 0, 18), UDim2.new(0.5, -9, 0.5, -9), 1, img, ifr
        ifr.Parent = f
    end

    f.Parent = parent
    return f, pb, g
end

local function animateValue(label, old, new, prefix)
    if not label or not LocalInfo.Config.AnimateNumbers then
        label.Text = (prefix or "") .. new.current .. " / " .. new.max
        return
    end
    local steps, stepDuration, currentStep = 10, LocalInfo.Config.AnimationDuration / 10, 0
    local startC, startM = old.current or 0, old.max or 0
    local deltaC, deltaM = (new.current - startC) / steps, (new.max - startM) / steps
    local conn = LocalInfo.Core.Services.RunService.Heartbeat:Connect(function(dt)
        currentStep = currentStep + 1
        label.Text = (prefix or "") .. math.floor(startC + deltaC * currentStep + 0.5) .. " / " .. math.floor(startM + deltaM * currentStep + 0.5)
        if currentStep >= steps then
            conn:Disconnect()
            label.Text = (prefix or "") .. new.current .. " / " .. new.max
        end
    end)
end

local function animateProgress(bar, label, oldP, newP)
    if not bar or not label or not LocalInfo.Config.AnimateNumbers then
        bar.Size = UDim2.new(newP / 100, 0, 1, 0)
        label.Text = math.floor(newP + 0.5) .. "%"
        return
    end
    local steps, currentStep = 10, 0
    local startP, deltaP = oldP, (newP - oldP) / steps
    local conn = LocalInfo.Core.Services.RunService.Heartbeat:Connect(function(dt)
        currentStep = currentStep + 1
        local ap = startP + deltaP * currentStep
        bar.Size = UDim2.new(ap / 100, 0, 1, 0)
        label.Text = math.floor(ap + 0.5) .. "%"
        if currentStep >= steps then
            conn:Disconnect()
            bar.Size = UDim2.new(newP / 100, 0, 1, 0)
            label.Text = math.floor(newP) .. "%"
        end
    end)
end

local function animateCircle(bar, oldP, newP)
    if not bar or not LocalInfo.Config.AnimateNumbers then
        local fh = newP / 100
        bar.Size, bar.Position = UDim2.new(1, 0, fh, 0), UDim2.new(0, 0, 1 - fh, 0)
        return
    end
    local steps, currentStep = 20, 0
    local startP, deltaP = oldP, (newP - oldP) / steps
    local conn = LocalInfo.Core.Services.RunService.Heartbeat:Connect(function(dt)
        currentStep = currentStep + 1
        local ap = startP + deltaP * currentStep
        local fh = ap / 100
        bar.Size, bar.Position = UDim2.new(1, 0, fh, 0), UDim2.new(0, 0, 1 - fh, 0)
        if currentStep >= steps then
            conn:Disconnect()
            bar.Size, bar.Position = UDim2.new(1, 0, newP / 100, 0), UDim2.new(0, 0, 1 - (newP / 100), 0)
        end
    end)
end

local function updateGradients(dt)
    if not LocalInfo.Config.GradientSettings.Enabled then return end
    LocalInfo.GradientUpdateTime = LocalInfo.GradientUpdateTime + dt * LocalInfo.Config.GradientSettings.Speed
    local offset = math.sin(LocalInfo.GradientUpdateTime)
    if LocalInfo.HandGradientPercent then LocalInfo.HandGradientPercent.Offset = Vector2.new(offset, 0) end
    if LocalInfo.SafeGradientPercent then LocalInfo.SafeGradientPercent.Offset = Vector2.new(offset, 0) end
    if LocalInfo.HandGradientCircle then LocalInfo.HandGradientCircle.Offset = Vector2.new(0, offset) end
    if LocalInfo.SafeGradientCircle then LocalInfo.SafeGradientCircle.Offset = Vector2.new(0, offset) end
end

local function updateAllGradients()
    local color1 = LocalInfo.Core.GradientColors and LocalInfo.Core.GradientColors.Color1.Value or Color3.fromRGB(0, 0, 255)
    local color2 = LocalInfo.Core.GradientColors and LocalInfo.Core.GradientColors.Color2.Value or Color3.fromRGB(147, 112, 219)
    LocalInfo.Config.GradientSettings.ColorSequence = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color1),
        ColorSequenceKeypoint.new(0.5, color2),
        ColorSequenceKeypoint.new(1, color1)
    })
    if LocalInfo.HandGradientPercent then LocalInfo.HandGradientPercent.Color = LocalInfo.Config.GradientSettings.ColorSequence end
    if LocalInfo.SafeGradientPercent then LocalInfo.SafeGradientPercent.Color = LocalInfo.Config.GradientSettings.ColorSequence end
    if LocalInfo.HandGradientCircle then LocalInfo.HandGradientCircle.Color = LocalInfo.Config.GradientSettings.ColorSequence end
    if LocalInfo.SafeGradientCircle then LocalInfo.SafeGradientCircle.Color = LocalInfo.Config.GradientSettings.ColorSequence end
end

local function applyStyle()
    if not LocalInfo.Config.Enabled then
        if LocalInfo.Frame then savedFramePosition = LocalInfo.Frame.Position; LocalInfo.Frame:Destroy() end
        if LocalInfo.HandCircleFrame then savedHandCirclePosition = LocalInfo.HandCircleFrame.Position; LocalInfo.HandCircleFrame:Destroy() end
        if LocalInfo.SafeCircleFrame then savedSafeCirclePosition = LocalInfo.SafeCircleFrame.Position; LocalInfo.SafeCircleFrame:Destroy() end
        LocalInfo.Frame, LocalInfo.HandCircleFrame, LocalInfo.SafeCircleFrame = nil, nil, nil
        LocalInfo.TitleLabel, LocalInfo.HandLabel, LocalInfo.SafeLabel = nil, nil, nil
        LocalInfo.HandIconFrame, LocalInfo.HandIcon, LocalInfo.SafeIconFrame, LocalInfo.SafeIcon = nil, nil, nil, nil
        LocalInfo.HandProgressFramePercent, LocalInfo.HandProgressBarPercent, LocalInfo.HandGradientPercent = nil, nil, nil
        LocalInfo.SafeProgressFramePercent, LocalInfo.SafeProgressBarPercent, LocalInfo.SafeGradientPercent = nil, nil, nil
        LocalInfo.HandProgressLabelFrame, LocalInfo.HandProgressLabelPercent = nil, nil
        LocalInfo.SafeProgressLabelFrame, LocalInfo.SafeProgressLabelPercent = nil, nil
        LocalInfo.HandProgressBarCircle, LocalInfo.HandGradientCircle = nil, nil
        LocalInfo.SafeProgressBarCircle, LocalInfo.SafeGradientCircle = nil, nil
        return
    end

    if not LocalInfo.Frame then
        LocalInfo.Frame = Instance.new("Frame")
        LocalInfo.Frame.BackgroundColor3, LocalInfo.Frame.BackgroundTransparency, LocalInfo.Frame.BorderSizePixel = Color3.fromRGB(20, 30, 50), 0.3, 0
        Instance.new("UICorner", LocalInfo.Frame).CornerRadius = UDim.new(0, 10)
        LocalInfo.Frame.Position = savedFramePosition
        LocalInfo.Frame.Parent = LocalInfo.ScreenGui

        LocalInfo.TitleLabel = Instance.new("TextLabel")
        LocalInfo.TitleLabel.Size, LocalInfo.TitleLabel.Position, LocalInfo.TitleLabel.BackgroundTransparency = UDim2.new(0, 200, 0, 30), UDim2.new(0, 10, 0, 10), 1
        LocalInfo.TitleLabel.Text, LocalInfo.TitleLabel.TextColor3, LocalInfo.TitleLabel.TextSize = "Inventory & Safe Capacity", Color3.fromRGB(255, 255, 245), 16
        LocalInfo.TitleLabel.Font, LocalInfo.TitleLabel.TextXAlignment, LocalInfo.TitleLabel.TextScaled, LocalInfo.TitleLabel.TextWrapped, LocalInfo.TitleLabel.Parent = 
            Enum.Font.GothamBold, Enum.TextXAlignment.Left, true, true, LocalInfo.Frame

        LocalInfo.HandLabel = Instance.new("TextLabel")
        LocalInfo.HandLabel.Size, LocalInfo.HandLabel.Position, LocalInfo.HandLabel.BackgroundTransparency = UDim2.new(0, 200, 0, 20), UDim2.new(0, 10, 0, 40), 1
        LocalInfo.HandLabel.Text, LocalInfo.HandLabel.TextColor3, LocalInfo.HandLabel.TextSize = "Hand: 0 / 0", Color3.fromRGB(200, 200, 200), 14
        LocalInfo.HandLabel.Font, LocalInfo.HandLabel.TextXAlignment, LocalInfo.HandLabel.TextScaled, LocalInfo.HandLabel.TextWrapped, LocalInfo.HandLabel.Parent = 
            Enum.Font.Gotham, Enum.TextXAlignment.Left, true, true, LocalInfo.Frame

        LocalInfo.SafeLabel = Instance.new("TextLabel")
        LocalInfo.SafeLabel.Size, LocalInfo.SafeLabel.Position, LocalInfo.SafeLabel.BackgroundTransparency = UDim2.new(0, 200, 0, 20), UDim2.new(0, 10, 0, 60), 1
        LocalInfo.SafeLabel.Text, LocalInfo.SafeLabel.TextColor3, LocalInfo.SafeLabel.TextSize = "Safe: 0 / 0", Color3.fromRGB(200, 200, 200), 14
        LocalInfo.SafeLabel.Font, LocalInfo.SafeLabel.TextXAlignment, LocalInfo.SafeLabel.TextScaled, LocalInfo.SafeLabel.TextWrapped, LocalInfo.SafeLabel.Parent = 
            Enum.Font.Gotham, Enum.TextXAlignment.Left, true, true, LocalInfo.Frame

        LocalInfo.HandIconFrame, LocalInfo.HandIcon = createIconFrame(UDim2.new(0, 10, 0, 10), "rbxassetid://12166530009")
        LocalInfo.SafeIconFrame, LocalInfo.SafeIcon = createIconFrame(UDim2.new(0, 10, 0, 35), "rbxassetid://17685282932")
        LocalInfo.HandProgressFramePercent, LocalInfo.HandProgressBarPercent, LocalInfo.HandGradientPercent = createProgressBar(UDim2.new(0, 40, 0, 18), 80, 10)
        LocalInfo.SafeProgressFramePercent, LocalInfo.SafeProgressBarPercent, LocalInfo.SafeGradientPercent = createProgressBar(UDim2.new(0, 40, 0, 43), 80, 10)
        LocalInfo.HandProgressLabelFrame, LocalInfo.HandProgressLabelPercent = createProgressLabel(UDim2.new(0, 130, 0, 14))
        LocalInfo.SafeProgressLabelFrame, LocalInfo.SafeProgressLabelPercent = createProgressLabel(UDim2.new(0, 130, 0, 39))
    end

    local isCircleMode = LocalInfo.Config.UIStyleMode == "Circle" or LocalInfo.Config.UIStyleMode == "Rectangle"
    if isCircleMode then
        if LocalInfo.HandCircleFrame then savedHandCirclePosition = LocalInfo.HandCircleFrame.Position; LocalInfo.HandCircleFrame:Destroy() end
        if LocalInfo.SafeCircleFrame then savedSafeCirclePosition = LocalInfo.SafeCircleFrame.Position; LocalInfo.SafeCircleFrame:Destroy() end
        
        if LocalInfo.Config.CircleStyle.ShowHand then
            LocalInfo.HandCircleFrame, LocalInfo.HandProgressBarCircle, LocalInfo.HandGradientCircle = createCircleProgress(LocalInfo.ScreenGui, savedHandCirclePosition, "rbxassetid://12166530009", LocalInfo.Config.UIStyleMode == "Circle")
            if LocalInfo.HandCircleFrame then
                LocalInfo.HandCircleFrame.Name = "HandCircleFrame"
                makeDraggableV2(LocalInfo.HandCircleFrame)
            end
        end
        if LocalInfo.Config.CircleStyle.ShowSafe then
            LocalInfo.SafeCircleFrame, LocalInfo.SafeProgressBarCircle, LocalInfo.SafeGradientCircle = createCircleProgress(LocalInfo.ScreenGui, savedSafeCirclePosition, "rbxassetid://17685282932", LocalInfo.Config.UIStyleMode == "Circle")
            if LocalInfo.SafeCircleFrame then
                LocalInfo.SafeCircleFrame.Name = "SafeCircleFrame"
                makeDraggableV2(LocalInfo.SafeCircleFrame)
            end
        end
    end

    LocalInfo.TitleLabel.Visible, LocalInfo.HandLabel.Visible, LocalInfo.SafeLabel.Visible = false, false, false
    LocalInfo.HandIconFrame.Visible, LocalInfo.HandIcon.Visible = false, false
    LocalInfo.HandProgressFramePercent.Visible, LocalInfo.HandProgressBarPercent.Visible = false, false
    LocalInfo.HandProgressLabelFrame.Visible, LocalInfo.HandProgressLabelPercent.Visible = false, false
    LocalInfo.SafeIconFrame.Visible, LocalInfo.SafeIcon.Visible = false, false
    LocalInfo.SafeProgressFramePercent.Visible, LocalInfo.SafeProgressBarPercent.Visible = false, false
    LocalInfo.SafeProgressLabelFrame.Visible, LocalInfo.SafeProgressLabelPercent.Visible = false, false
    LocalInfo.Frame.Visible = false
    if LocalInfo.HandCircleFrame then LocalInfo.HandCircleFrame.Visible = false end
    if LocalInfo.SafeCircleFrame then LocalInfo.SafeCircleFrame.Visible = false end

    if LocalInfo.Config.UIStyleMode == "Default" then
        LocalInfo.TitleLabel.Visible, LocalInfo.HandLabel.Visible, LocalInfo.SafeLabel.Visible, LocalInfo.Frame.Visible = true, true, true, true
        LocalInfo.Frame.Size = UDim2.new(0, 220, 0, 120)
    elseif LocalInfo.Config.UIStyleMode == "Percent" then
        local sh, ss = LocalInfo.Config.PercentStyle.ShowHand, LocalInfo.Config.PercentStyle.ShowSafe
        LocalInfo.HandIconFrame.Visible, LocalInfo.HandIcon.Visible = sh, sh
        LocalInfo.HandProgressFramePercent.Visible, LocalInfo.HandProgressBarPercent.Visible = sh, sh
        LocalInfo.HandProgressLabelFrame.Visible, LocalInfo.HandProgressLabelPercent.Visible = sh, sh
        LocalInfo.SafeIconFrame.Visible, LocalInfo.SafeIcon.Visible = ss, ss
        LocalInfo.SafeProgressFramePercent.Visible, LocalInfo.SafeProgressBarPercent.Visible = ss, ss
        LocalInfo.SafeProgressLabelFrame.Visible, LocalInfo.SafeProgressLabelPercent.Visible = ss, ss
        LocalInfo.Frame.Visible = true
        LocalInfo.Frame.Size = (sh and ss) and UDim2.new(0, 180, 0, 70) or UDim2.new(0, 180, 0, 40)
        if sh then
            LocalInfo.HandIconFrame.Position = UDim2.new(0, 10, 0, sh and ss and 10 or 10)
            LocalInfo.HandProgressFramePercent.Position = UDim2.new(0, 40, 0, sh and ss and 18 or 14)
            LocalInfo.HandProgressLabelFrame.Position = UDim2.new(0, 120, 0, sh and ss and 14 or 12)
        end
        if ss then
            LocalInfo.SafeIconFrame.Position = UDim2.new(0, 10, 0, sh and ss and 35 or 10)
            LocalInfo.SafeProgressFramePercent.Position = UDim2.new(0, 40, 0, sh and ss and 43 or 14)
            LocalInfo.SafeProgressLabelFrame.Position = UDim2.new(0, 120, 0, sh and ss and 39 or 12)
        end
    elseif isCircleMode then
        if LocalInfo.Config.CircleStyle.ShowHand and LocalInfo.HandCircleFrame then LocalInfo.HandCircleFrame.Visible = true end
        if LocalInfo.Config.CircleStyle.ShowSafe and LocalInfo.SafeCircleFrame then LocalInfo.SafeCircleFrame.Visible = true end
    end
    updateAllGradients()
    makeDraggable(LocalInfo.Frame)
end

local function parseCapacity(text)
    if not text or type(text) ~= "string" then return 0, 0 end
    local current, max = text:match("(%d+)%s*/%s*(%d+)") or text:match("(%d+)%s*из%s*(%d+)")
    return tonumber(current) or 0, tonumber(max) or 0
end

local function updateCapacity()
    if not LocalInfo.Config.Enabled or not LocalInfo.Core or not LocalInfo.Core.Services or not LocalInfo.Core.Services.ReplicatedStorage then return end

    local ui_module = require(LocalInfo.Core.Services.ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("Core", 5):WaitForChild("UI", 5))
    if not ui_module or type(ui_module.get) ~= "function" then
        ui_module = { get = function(k) return k == "DefaultItemsMaxItems" and {Text = "5/10"} or k == "TransferSafeMaxItems" and {Text = "2/10"} or nil end }
        if LocalInfo.Notify then LocalInfo.Notify("Inventory Capacity", "Failed to load UI module, using default values", true) end
    end

    local hl, sl = ui_module.get("DefaultItemsMaxItems"), ui_module.get("TransferSafeMaxItems")
    if not hl or not hl.Text or not sl or not sl.Text then
        if LocalInfo.Config.UIStyleMode == "Default" then
            LocalInfo.HandLabel.Text, LocalInfo.SafeLabel.Text = "Hand: N/A", "Safe: N/A"
        elseif LocalInfo.Config.UIStyleMode == "Percent" then
            if LocalInfo.HandProgressBarPercent then LocalInfo.HandProgressBarPercent.Size = UDim2.new(0, 0, 1, 0); LocalInfo.HandProgressLabelPercent.Text = "N/A" end
            if LocalInfo.SafeProgressBarPercent then LocalInfo.SafeProgressBarPercent.Size = UDim2.new(0, 0, 1, 0); LocalInfo.SafeProgressLabelPercent.Text = "N/A" end
        elseif (LocalInfo.Config.UIStyleMode == "Circle" or LocalInfo.Config.UIStyleMode == "Rectangle") then
            if LocalInfo.HandProgressBarCircle then LocalInfo.HandProgressBarCircle.Size, LocalInfo.HandProgressBarCircle.Position = UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 0) end
            if LocalInfo.SafeProgressBarCircle then LocalInfo.SafeProgressBarCircle.Size, LocalInfo.SafeProgressBarCircle.Position = UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 0) end
        end
        LocalInfo.CurrentHand, LocalInfo.CurrentSafe = {current = 0, max = 0}, {current = 0, max = 0}
        return
    end

    local hc, hm = parseCapacity(hl.Text)
    if hc and hm then
        local nh = {current = hc, max = hm}
        if LocalInfo.Config.UIStyleMode == "Default" and LocalInfo.HandLabel then animateValue(LocalInfo.HandLabel, LocalInfo.CurrentHand, nh, "Hand: ") end
        if LocalInfo.Config.UIStyleMode == "Percent" and LocalInfo.Config.PercentStyle.ShowHand then
            local np = hm > 0 and (hc / hm * 100) or 0
            animateProgress(LocalInfo.HandProgressBarPercent, LocalInfo.HandProgressLabelPercent, LocalInfo.CurrentHandPercent, np)
            LocalInfo.CurrentHandPercent = np
        end
        if (LocalInfo.Config.UIStyleMode == "Circle" or LocalInfo.Config.UIStyleMode == "Rectangle") and LocalInfo.Config.CircleStyle.ShowHand then
            local np = hm > 0 and (hc / hm * 100) or 0
            animateCircle(LocalInfo.HandProgressBarCircle, LocalInfo.CurrentHandPercent, np)
            LocalInfo.CurrentHandPercent = np
        end
        LocalInfo.CurrentHand = nh
    end

    local sc, sm = parseCapacity(sl.Text)
    if sc and sm then
        local ns = {current = sc, max = sm}
        if LocalInfo.Config.UIStyleMode == "Default" and LocalInfo.SafeLabel then animateValue(LocalInfo.SafeLabel, LocalInfo.CurrentSafe, ns, "Safe: ") end
        if LocalInfo.Config.UIStyleMode == "Percent" and LocalInfo.Config.PercentStyle.ShowSafe then
            local np = sm > 0 and (sc / sm * 100) or 0
            animateProgress(LocalInfo.SafeProgressBarPercent, LocalInfo.SafeProgressLabelPercent, LocalInfo.CurrentSafePercent, np)
            LocalInfo.CurrentSafePercent = np
        end
        if (LocalInfo.Config.UIStyleMode == "Circle" or LocalInfo.Config.UIStyleMode == "Rectangle") and LocalInfo.Config.CircleStyle.ShowSafe then
            local np = sm > 0 and (sc / sm * 100) or 0
            animateCircle(LocalInfo.SafeProgressBarCircle, LocalInfo.CurrentSafePercent, np)
            LocalInfo.CurrentSafePercent = np
        end
        LocalInfo.CurrentSafe = ns
    end
end

local function Init(UI, Core, notify)
    if not Core then return end
    LocalInfo.Core, LocalInfo.Notify = Core, notify
    LocalInfo.LastGradientColors = {Color1 = Core.GradientColors.Color1.Value, Color2 = Core.GradientColors.Color2.Value}
    setupGui(Core)
    updateAllGradients()

    if LocalInfo.Config.CircleStyle.ShowHand then
        LocalInfo.HandCircleFrame, LocalInfo.HandProgressBarCircle, LocalInfo.HandGradientCircle = createCircleProgress(LocalInfo.ScreenGui, savedHandCirclePosition, "rbxassetid://12166530009", LocalInfo.Config.UIStyleMode == "Circle")
        if LocalInfo.HandCircleFrame then
            LocalInfo.HandCircleFrame.Name = "HandCircleFrame"
            makeDraggableV2(LocalInfo.HandCircleFrame)
        end
    end
    if LocalInfo.Config.CircleStyle.ShowSafe then
        LocalInfo.SafeCircleFrame, LocalInfo.SafeProgressBarCircle, LocalInfo.SafeGradientCircle = createCircleProgress(LocalInfo.ScreenGui, savedSafeCirclePosition, "rbxassetid://17685282932", LocalInfo.Config.UIStyleMode == "Circle")
        if LocalInfo.SafeCircleFrame then
            LocalInfo.SafeCircleFrame.Name = "SafeCircleFrame"
            makeDraggableV2(LocalInfo.SafeCircleFrame)
        end
    end

    if UI and UI.Sections and UI.Sections.InventoryCapacity then
        UI.Sections.InventoryCapacity:Header({ Name = "Inventory Capacity Settings" })
        local enabledToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "Enabled",
            Default = LocalInfo.Config.Enabled,
            Callback = function(value)
                LocalInfo.Config.Enabled = value
                applyStyle()
                if value then makeDraggable(LocalInfo.Frame) end
                if LocalInfo.Notify then LocalInfo.Notify("Inventory Capacity", "Inventory Capacity " .. (value and "Enabled" or "Disabled"), true) end
            end
        }, "LocalInfo_Enabled")
        local styleModeDropdown = UI.Sections.InventoryCapacity:Dropdown({
            Name = "UIStyleMode",
            Options = {"Default", "Percent", "Circle", "Rectangle"},
            Default = LocalInfo.Config.UIStyleMode,
            Callback = function(value)
                LocalInfo.Config.UIStyleMode = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_UIStyleMode")
        local animateNumbersToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "AnimateNumbers",
            Default = LocalInfo.Config.AnimateNumbers,
            Callback = function(value) LocalInfo.Config.AnimateNumbers = value end
        }, "LocalInfo_AnimateNumbers")
        local animationDurationSlider = UI.Sections.InventoryCapacity:Slider({
            Name = "AnimationDuration",
            Default = LocalInfo.Config.AnimationDuration,
            Minimum = 0.1,
            Maximum = 2,
            Precision = 1,
            Callback = function(value) LocalInfo.Config.AnimationDuration = value end
        }, "LocalInfo_AnimationDuration")
        local showHandToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "ShowHand",
            Default = LocalInfo.Config.PercentStyle.ShowHand,
            Callback = function(value)
                LocalInfo.Config.PercentStyle.ShowHand = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_PercentStyle_ShowHand")
        local showSafeToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "ShowSafe",
            Default = LocalInfo.Config.PercentStyle.ShowSafe,
            Callback = function(value)
                LocalInfo.Config.PercentStyle.ShowSafe = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_PercentStyle_ShowSafe")
        local barWidthSlider = UI.Sections.InventoryCapacity:Slider({
            Name = "ProgressBarWidth",
            Default = LocalInfo.Config.PercentStyle.ProgressBarWidth,
            Minimum = 40,
            Maximum = 160,
            Precision = 0,
            Callback = function(value)
                LocalInfo.Config.PercentStyle.ProgressBarWidth = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_PercentStyle_ProgressBarWidth")
        local barHeightSlider = UI.Sections.InventoryCapacity:Slider({
            Name = "ProgressBarHeight",
            Default = LocalInfo.Config.PercentStyle.ProgressBarHeight,
            Minimum = 1,
            Maximum = 20,
            Precision = 0,
            Callback = function(value)
                LocalInfo.Config.PercentStyle.ProgressBarHeight = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_PercentStyle_ProgressBarHeight")
        local showHandCircleToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "ShowHandCircle",
            Default = LocalInfo.Config.CircleStyle.ShowHand,
            Callback = function(value)
                LocalInfo.Config.CircleStyle.ShowHand = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_CircleStyle_ShowHand")
        local showSafeCircleToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "ShowSafeCircle",
            Default = LocalInfo.Config.CircleStyle.ShowSafe,
            Callback = function(value)
                LocalInfo.Config.CircleStyle.ShowSafe = value
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_CircleStyle_ShowSafe")
        local circleIconStyleDropdown = UI.Sections.InventoryCapacity:Dropdown({
            Name = "CircleIconStyle",
            Options = {"1", "2"},
            Default = tostring(LocalInfo.Config.CircleStyle.CircleIconStyle),
            Callback = function(value)
                LocalInfo.Config.CircleStyle.CircleIconStyle = tonumber(value)
                applyStyle()
                updateCapacity()
            end
        }, "LocalInfo_CircleStyle_CircleIconStyle")
        local gradientEnabledToggle = UI.Sections.InventoryCapacity:Toggle({
            Name = "GradientEnabled",
            Default = LocalInfo.Config.GradientSettings.Enabled,
            Callback = function(value)
                LocalInfo.Config.GradientSettings.Enabled = value
                applyStyle()
            end
        }, "LocalInfo_GradientSettings_Enabled")
        local gradientSpeedSlider = UI.Sections.InventoryCapacity:Slider({
            Name = "GradientSpeed",
            Default = LocalInfo.Config.GradientSettings.Speed,
            Minimum = 0.1,
            Maximum = 5,
            Precision = 1,
            Callback = function(value) LocalInfo.Config.GradientSettings.Speed = value end
        }, "LocalInfo_GradientSettings_Speed")

        table.insert(LocalInfo.Elements, enabledToggle)
        table.insert(LocalInfo.Elements, styleModeDropdown)
        table.insert(LocalInfo.Elements, animateNumbersToggle)
        table.insert(LocalInfo.Elements, animationDurationSlider)
        table.insert(LocalInfo.Elements, showHandToggle)
        table.insert(LocalInfo.Elements, showSafeToggle)
        table.insert(LocalInfo.Elements, barWidthSlider)
        table.insert(LocalInfo.Elements, barHeightSlider)
        table.insert(LocalInfo.Elements, showHandCircleToggle)
        table.insert(LocalInfo.Elements, showSafeCircleToggle)
        table.insert(LocalInfo.Elements, circleIconStyleDropdown)
        table.insert(LocalInfo.Elements, gradientEnabledToggle)
        table.insert(LocalInfo.Elements, gradientSpeedSlider)

        UI.Sections.InventoryCapacity.applyStyle = applyStyle
        UI.Sections.InventoryCapacity.updateCapacity = updateCapacity
        UI.Sections.InventoryCapacity.makeDraggable = makeDraggable
        UI.Sections.InventoryCapacity.makeDraggableV2 = makeDraggableV2
        UI.Sections.InventoryCapacity.Frame = LocalInfo.Frame
        UI.Sections.InventoryCapacity.HandCircleFrame = LocalInfo.HandCircleFrame
        UI.Sections.InventoryCapacity.SafeCircleFrame = LocalInfo.SafeCircleFrame
    end

    if LocalInfo.Core and LocalInfo.Core.Services and LocalInfo.Core.Services.RunService then
        LocalInfo.UIConnection = LocalInfo.Core.Services.RunService.Heartbeat:Connect(function(dt)
            local currentTime = tick()
            if not LocalInfo.Config.Enabled or currentTime - lastUpdate < UPDATE_INTERVAL then return end
            lastUpdate = currentTime

            updateCapacity()
            local color1 = LocalInfo.Core.GradientColors.Color1.Value
            local color2 = LocalInfo.Core.GradientColors.Color2.Value
            if LocalInfo.LastGradientColors.Color1 ~= color1 or LocalInfo.LastGradientColors.Color2 ~= color2 then
                LocalInfo.LastGradientColors.Color1, LocalInfo.LastGradientColors.Color2 = color1, color2
                updateAllGradients()
            end
            if currentTime - LocalInfo.GradientUpdateTime >= GRADIENT_INTERVAL then
                updateGradients(dt)
                LocalInfo.GradientUpdateTime = currentTime
            end
        end)
    end
end

return { Init = Init }
