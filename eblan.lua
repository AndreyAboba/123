-- Модуль Combat: AutoInteract
local Combat = {
    Settings = {
        Enabled = { Value = false, Default = false },
        TargetObject = { Value = "AirDrop", Default = "AirDrop" },
        MaxDistance = { Value = 10, Default = 10 }
    },
    State = {
        ProcessedObjects = {},
        ActiveObjects = {}
    }
}

function Combat.Init(UI, Core, notify)
    -- Проверка, жив ли игрок
    local function isPlayerInGame()
        local char = Core.PlayerData.LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        return char and humanoid and humanoid.Health > 0
    end

    -- Расчёт расстояния до объекта
    local function getDistanceToObject(obj)
        local char = Core.PlayerData.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not obj.Parent then return math.huge end
        local pos = obj:GetPivot().Position
        return (root.Position - pos).Magnitude
    end

    -- Активация ProximityPrompt
    local function triggerPrompt(prompt, targetObject)
        if not targetObject.Parent then return false end
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            Combat.State.ActiveObjects[targetObject] = true
            local char = Core.PlayerData.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                Combat.State.ActiveObjects[targetObject] = nil
                return false
            end
            local distance = getDistanceToObject(targetObject)
            if distance <= Combat.Settings.MaxDistance.Value then
                prompt.RequiresLineOfSight = false
                local originalDist = prompt.MaxActivationDistance
                prompt.MaxActivationDistance = distance + 5
                prompt:InputHoldBegin()
                task.wait(0.4)
                prompt:InputHoldEnd()
                prompt.MaxActivationDistance = originalDist
                Combat.State.ProcessedObjects[targetObject] = true
            end
            Combat.State.ActiveObjects[targetObject] = nil
            return true
        end
        return false
    end

    -- Основной цикл AutoInteract
    local function start()
        if not Combat.Settings.Enabled.Value then return end
        Core.Services.RunService.Heartbeat:Connect(function()
            if not Combat.Settings.Enabled.Value or not isPlayerInGame() then return end
            if Combat.Settings.TargetObject.Value == "Dumpster" then
                local props = Core.Services.Workspace:FindFirstChild("Map") and Core.Services.Workspace.Map:FindFirstChild("Props")
                if props then
                    for _, obj in pairs(props:GetChildren()) do
                        if obj.Name == "Dumpster" then
                            local dist = getDistanceToObject(obj)
                            if dist <= Combat.Settings.MaxDistance.Value then
                                local trash = obj:FindFirstChild("Trash")
                                local prompt = trash and trash:FindFirstChild("Attachment") and trash.Attachment:FindFirstChild("ProximityPrompt")
                                if prompt then triggerPrompt(prompt, obj) end
                            end
                        end
                    end
                end
            elseif Combat.Settings.TargetObject.Value == "Bin" then
                for _, obj in pairs(Core.Services.Workspace:GetDescendants()) do
                    if obj.Name == "Bin" then
                        local dist = getDistanceToObject(obj)
                        if dist <= Combat.Settings.MaxDistance.Value then
                            local prompt = obj:FindFirstChild("Meshes/bin_Cube") and obj["Meshes/bin_Cube"]:FindFirstChild("ProximityPrompt")
                            if prompt then triggerPrompt(prompt, obj) end
                        end
                    end
                end
            elseif Combat.Settings.TargetObject.Value == "AirDrop" then
                local airDrop = Core.Services.Workspace:FindFirstChild("AirDropModel")
                local crate = airDrop and airDrop:FindFirstChild("Weapon Crate")
                if crate then
                    local dist = getDistanceToObject(crate)
                    if dist <= Combat.Settings.MaxDistance.Value then
                        local prompt = crate:FindFirstChild("Model") and crate.Model:FindFirstChild("BoxInteriorBottom") and crate.Model.BoxInteriorBottom:FindFirstChild("ProximityPrompt")
                        if prompt then triggerPrompt(prompt, crate) end
                    end
                end
            end
        end)
    end

    -- Настройка UI
    if UI.Sections.AutoInteract then
        UI.Sections.AutoInteract:Header({ Name = "Настройки АвтоВзаимодействия" })
        UI.Sections.AutoInteract:Toggle({
            Name = "Включено",
            Default = Combat.Settings.Enabled.Default,
            Callback = function(v)
                Combat.Settings.Enabled.Value = v
                if v then start() notify("АвтоВзаимодействие", "Включено", true) else notify("АвтоВзаимодействие", "Выключено", true) end
            end
        })
        UI.Sections.AutoInteract:Dropdown({
            Name = "Объект",
            Options = {"Bin", "Dumpster", "AirDrop"},
            Default = Combat.Settings.TargetObject.Default,
            Callback = function(v)
                Combat.Settings.TargetObject.Value = v
                notify("АвтоВзаимодействие", "Объект: " .. v, true)
            end
        })
        UI.Sections.AutoInteract:Slider({
            Name = "Макс. расстояние",
            Minimum = 5,
            Maximum = 50,
            Default = Combat.Settings.MaxDistance.Default,
            Precision = 1,
            Callback = function(v)
                Combat.Settings.MaxDistance.Value = v
                notify("АвтоВзаимодействие", "Макс. расстояние: " .. v, false)
            end
        })
    end
end

return Combat
