-- Ultimate Part Manipulator V5 (Rayfield UI + AlignPosition for infinite range)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Настройки
local Settings = {
    SelectedPart = nil,
    IsActive = false,
    HoldDistance = 10,
    MoveSpeed = 5,             -- не используется, оставлено для совместимости
    ThrowForce = 500,
    RotateSpeed = 8,
    TornadoSpeed = 8,
    TornadoHeight = 20,
    TornadoRadius = 20,
    RotateMode = false,
    TornadoMode = false,
    KillMode = false,

    AttachmentMode = false,
    PreviewPart = nil,
    PreviewPosition = nil,
    AttachmentStep = 2,
    AttachedParts = {},        -- { {Part, AlignPos, Att0, Att1, AnchorPart} }
}

local AllParts = {}           -- для Tornado и отслеживания

-- Функция захвата части
local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.3, 0.5)
        part.CanCollide = true
        return true
    end
    return false
end

-- Создать AlignPosition между частью и якорем (невидимой частью)
local function CreateAlign(part, targetPos)
    -- Удаляем старые аттачменты, если есть
    local oldAlign = part:FindFirstChild("AlignPosition")
    if oldAlign then oldAlign:Destroy() end
    local oldAtt0 = part:FindFirstChild("Att0")
    if oldAtt0 then oldAtt0:Destroy() end
    local oldAnchor = part:FindFirstChild("AnchorPart")
    if oldAnchor then oldAnchor:Destroy() end

    -- Якорь (невидимая anchored часть)
    local anchor = Instance.new("Part")
    anchor.Name = "AnchorPart"
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Position = targetPos
    anchor.Parent = Workspace

    -- Аттачменты
    local att0 = Instance.new("Attachment", part)
    att0.Name = "Att0"
    att0.Position = Vector3.new(0, 0, 0)
    local att1 = Instance.new("Attachment", anchor)
    att1.Position = Vector3.new(0, 0, 0)

    -- AlignPosition
    local align = Instance.new("AlignPosition", part)
    align.Name = "AlignPosition"
    align.MaxForce = 100000
    align.MaxVelocity = 1000
    align.Responsiveness = 100
    align.Attachment0 = att0
    align.Attachment1 = att1

    return anchor, align
end

-- Удалить привязку у части
local function RemoveAlign(part)
    local align = part:FindFirstChild("AlignPosition")
    if align then align:Destroy() end
    local att0 = part:FindFirstChild("Att0")
    if att0 then att0:Destroy() end
    local anchor = part:FindFirstChild("AnchorPart")
    if anchor then
        -- якорь может быть не прямым ребёнком, поищем
        local anch = align and align.Attachment1 and align.Attachment1.Parent
        if anch and anch:IsA("Part") and anch.Name == "AnchorPart" then
            anch:Destroy()
        end
    end
end

-- Собрать все части
local function CollectAllParts()
    local count = 0
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored then
            local char = LocalPlayer.Character
            if char and not v:IsDescendantOf(char) then
                if not table.find(AllParts, v) then
                    if RetainPart(v) then
                        table.insert(AllParts, v)
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- === RAYFIELD UI ===
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Part Manipulator V5",
    LoadingTitle = "Part Manipulator",
    LoadingSubtitle = "by DeepSeek AI",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- Коллекция
local CollectSection = MainTab:CreateSection("Collection")
MainTab:CreateButton({
    Name = "Collect All Parts",
    Callback = function()
        local count = CollectAllParts()
        Rayfield:Notify({ Title = "Collected", Content = "Собрано " .. count .. " частей", Duration = 2, Image = 4483362458 })
    end,
})
MainTab:CreateButton({
    Name = "Drop All Parts",
    Callback = function()
        for _, part in pairs(AllParts) do
            if part and part.Parent then
                RemoveAlign(part)
                part.Anchored = false
                part.CanCollide = true
                part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
                part.Velocity = Vector3.new(0, 0, 0)
                part.AngularVelocity = Vector3.new(0, 0, 0)
            end
        end
        AllParts = {}
        Settings.SelectedPart = nil
        Settings.IsActive = false
        Settings.TornadoMode = false
        Settings.KillMode = false
        Settings.RotateMode = false
        Settings.AttachedParts = {}
        Settings.PreviewPart = nil
        Rayfield:Notify({ Title = "Dropped", Content = "Все части сброшены", Duration = 2, Image = 4483362458 })
    end,
})

-- Настройки
local SettingsSection = MainTab:CreateSection("Settings")
MainTab:CreateSlider({
    Name = "Throw Force",
    Range = {100, 5000},
    Increment = 100,
    Suffix = "Studs/s",
    CurrentValue = Settings.ThrowForce,
    Flag = "ThrowForce",
    Callback = function(Value) Settings.ThrowForce = Value end,
})
MainTab:CreateSlider({
    Name = "Hold Distance",
    Range = {3, 30},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = Settings.HoldDistance,
    Flag = "HoldDistance",
    Callback = function(Value) Settings.HoldDistance = Value end,
})

-- Actions
local ActionsSection = MainTab:CreateSection("Actions")
MainTab:CreateToggle({
    Name = "Hold Part",
    CurrentValue = false,
    Flag = "HoldPart",
    Callback = function(Value)
        if not Settings.SelectedPart then
            Rayfield:Notify({ Title = "Error", Content = "Нет выбранной части", Duration = 2 })
            return
        end
        Settings.IsActive = Value
        if Value then
            Settings.TornadoMode = false
            -- Для удобства во время удержания отключаем коллизию
            Settings.SelectedPart.CanCollide = false
            -- Создаём AlignPosition к якорю, который будем двигать за мышью
            local part = Settings.SelectedPart
            RemoveAlign(part)
            local anchor, align = CreateAlign(part, part.Position)
            part:WaitForChild("AnchorPart", 1) -- не нужно, якорь не в части
            -- Сохраним anchor в part, чтобы потом найти
            -- Запомним связь в Settings
            Settings.HoldAnchor = anchor
        else
            if Settings.SelectedPart then
                Settings.SelectedPart.CanCollide = true
                RemoveAlign(Settings.SelectedPart)
                Settings.HoldAnchor = nil
            end
        end
    end,
})
MainTab:CreateToggle({
    Name = "Rotate Part",
    CurrentValue = false,
    Flag = "RotatePart",
    Callback = function(Value)
        if not Settings.SelectedPart then
            Rayfield:Notify({ Title = "Error", Content = "Нет выбранной части", Duration = 2 })
            return
        end
        Settings.RotateMode = Value
    end,
})
MainTab:CreateButton({
    Name = "Throw Part",
    Callback = function()
        if not Settings.SelectedPart then
            Rayfield:Notify({ Title = "Error", Content = "Нет выбранной части", Duration = 2 })
            return
        end
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local direction = (mousePos - part.Position).Unit
        RemoveAlign(part)
        part.CanCollide = true
        part.Velocity = direction * Settings.ThrowForce
        Settings.SelectedPart = nil
        Settings.IsActive = false
        Settings.RotateMode = false
        Rayfield:Notify({ Title = "Thrown", Content = "Часть брошена", Duration = 2 })
    end,
})

MainTab:CreateToggle({
    Name = "Tornado Mode",
    CurrentValue = false,
    Flag = "TornadoMode",
    Callback = function(Value)
        Settings.TornadoMode = Value
        Settings.IsActive = false
        if Value and #AllParts == 0 then CollectAllParts() end
        if Value then
            -- Для каждой части создаём AlignPosition с якорем, который будем крутить
            for _, part in pairs(AllParts) do
                if not part:FindFirstChild("AlignPosition") then
                    local anchor, align = CreateAlign(part, part.Position)
                end
            end
        else
            for _, part in pairs(AllParts) do
                RemoveAlign(part)
            end
        end
    end,
})
MainTab:CreateToggle({
    Name = "Fling Mode",
    CurrentValue = false,
    Flag = "FlingMode",
    Callback = function(Value) Settings.KillMode = Value end,
})

-- Attachment Mode
local AttachSection = MainTab:CreateSection("Attachment Mode")
MainTab:CreateToggle({
    Name = "Attachment Mode",
    CurrentValue = false,
    Flag = "AttachmentMode",
    Callback = function(Value)
        Settings.AttachmentMode = Value
        Settings.PreviewPart = nil
        Settings.PreviewPosition = nil
        if Value then
            Rayfield:Notify({
                Title = "Attachment",
                Content = "Режим прикрепления ВКЛ. Кликните по части, затем E/Q/X/Z для движения, Enter для фиксации.",
                Duration = 5
            })
        end
    end,
})
MainTab:CreateSlider({
    Name = "Attachment Step",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "Studs",
    CurrentValue = Settings.AttachmentStep,
    Flag = "AttachStep",
    Callback = function(Value) Settings.AttachmentStep = Value end,
})
MainTab:CreateButton({
    Name = "Unattach All",
    Callback = function()
        for _, item in pairs(Settings.AttachedParts) do
            local part = item.Part
            if part and part.Parent then
                RemoveAlign(part)
                part.Anchored = false
                part.CanCollide = true
                part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
                part.Velocity = Vector3.new(0, 0, 0)
                part.AngularVelocity = Vector3.new(0, 0, 0)
            end
        end
        Settings.AttachedParts = {}
        Rayfield:Notify({ Title = "Unattached", Content = "Все прикреплённые части сброшены.", Duration = 2 })
    end,
})

-- Выбор части
Mouse.Button1Down:Connect(function()
    local target = Mouse.Target
    if not (target and target:IsA("BasePart") and not target.Anchored) then return end
    local char = LocalPlayer.Character
    if not char or target:IsDescendantOf(char) then return end

    if Settings.AttachmentMode then
        -- Если уже прикреплена – открепить
        for i, item in pairs(Settings.AttachedParts) do
            if item.Part == target then
                RemoveAlign(target)
                target.Anchored = false
                target.CanCollide = true
                target.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
                target.Velocity = Vector3.new(0, 0, 0)
                table.remove(Settings.AttachedParts, i)
                Rayfield:Notify({ Title = "Unattached", Content = "Часть откреплена.", Duration = 2 })
                return
            end
        end

        -- Начать превью
        if RetainPart(target) then
            Settings.PreviewPart = target
            Settings.PreviewPart.CanCollide = false   -- без коллизии для удобства позиционирования
            Settings.PreviewPosition = target.Position
            if not table.find(AllParts, target) then
                table.insert(AllParts, target)
            end
            -- Создадим AlignPosition для превью, чтобы часть следовала за PreviewPosition
            RemoveAlign(target)
            local anchor, align = CreateAlign(target, Settings.PreviewPosition)
            Settings.PreviewAnchor = anchor
            Rayfield:Notify({ Title = "Preview", Content = "E/Q - высота, X/Z - вправо/влево, Enter - закрепить.", Duration = 2 })
        end
    else
        if RetainPart(target) then
            Settings.SelectedPart = target
            if not table.find(AllParts, target) then
                table.insert(AllParts, target)
            end
            Rayfield:Notify({ Title = "Selected", Content = "Выбрана: " .. target.Name, Duration = 2, Image = 4483362458 })
        end
    end
end)

-- Основной цикл
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart

    -- Обновление позиций якорей для AlignPosition
    -- Tornado
    if Settings.TornadoMode then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent then
                local anchor = nil
                -- Ищем якорь этой части (он может быть где-то в Workspace, но мы не храним ссылку)
                -- Проще: найдём все AnchorPart и проверим их AlignPosition
                -- Вместо этого мы в режиме Tornado при создании сохранили якоря в массиве, но не сделали этого.
                -- Исправим: в коллбеке Tornado mode надо сохранять якоря в таблицу, чтобы обновлять их позиции.
                -- Пока для простоты будем пробегать по детям Workspace и искать AnchorPart, привязанный к этой части.
                -- Это громоздко, поэтому в следующей итерации оптимизируем, но сейчас для работоспособности:
                local align = part:FindFirstChild("AlignPosition")
                if align and align.Attachment1 and align.Attachment1.Parent and align.Attachment1.Parent:IsA("Part") and align.Attachment1.Parent.Name == "AnchorPart" then
                    anchor = align.Attachment1.Parent
                end
                if anchor then
                    local offset = i * 2.4
                    local x = math.cos(angle + offset) * Settings.TornadoRadius
                    local z = math.sin(angle + offset) * Settings.TornadoRadius
                    local y = math.sin(tick() * 2 + offset) * Settings.TornadoHeight
                    anchor.Position = root.Position + Vector3.new(x, y, z)
                end
                part.AngularVelocity = Vector3.new(0, Settings.TornadoSpeed, 0)

                if Settings.KillMode then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local hrp = player.Character.HumanoidRootPart
                            if (part.Position - hrp.Position).Magnitude < 5 then
                                hrp.Velocity = (part.Position - hrp.Position).Unit * 500 + Vector3.new(0, 200, 0)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Hold (удержание одной части)
    if Settings.IsActive and Settings.SelectedPart and Settings.SelectedPart.Parent and not Settings.AttachmentMode then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local targetPos = root.Position + (mousePos - root.Position).Unit * Settings.HoldDistance + Vector3.new(0, 3, 0)
        -- Передвигаем якорь
        if Settings.HoldAnchor then
            Settings.HoldAnchor.Position = targetPos
        end
        if Settings.KillMode then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = player.Character.HumanoidRootPart
                    if (part.Position - hrp.Position).Magnitude < 4 then
                        hrp.Velocity = (part.Position - hrp.Position).Unit * 600 + Vector3.new(0, 250, 0)
                    end
                end
            end
        end
    end

    -- Вращение
    if Settings.RotateMode and Settings.SelectedPart and Settings.SelectedPart.Parent and not Settings.AttachmentMode then
        Settings.SelectedPart.AngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0)
    end

    -- Превью (строительство)
    if Settings.PreviewPart and Settings.PreviewPart.Parent and Settings.AttachmentMode then
        if Settings.PreviewAnchor then
            Settings.PreviewAnchor.Position = Settings.PreviewPosition
        end
    end
end)

-- Клавиатура
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local key = input.KeyCode

    if Settings.AttachmentMode and Settings.PreviewPart then
        local step = Settings.AttachmentStep
        local pos = Settings.PreviewPosition

        if key == Enum.KeyCode.E then
            Settings.PreviewPosition = pos + Vector3.new(0, step, 0)
        elseif key == Enum.KeyCode.Q then
            Settings.PreviewPosition = pos + Vector3.new(0, -step, 0)
        elseif key == Enum.KeyCode.X then
            Settings.PreviewPosition = pos + Vector3.new(step, 0, 0)
        elseif key == Enum.KeyCode.Z then
            Settings.PreviewPosition = pos + Vector3.new(-step, 0, 0)
        elseif key == Enum.KeyCode.Return then
            local part = Settings.PreviewPart
            -- Убираем старую привязку, если есть, и делаем anchored
            RemoveAlign(part)
            part.Anchored = true
            part.CanCollide = true
            part.Velocity = Vector3.new(0, 0, 0)
            part.AngularVelocity = Vector3.new(0, 0, 0)
            table.insert(Settings.AttachedParts, {Part = part, TargetPos = Settings.PreviewPosition})
            Settings.PreviewPart = nil
            Settings.PreviewPosition = nil
            if Settings.PreviewAnchor then
                Settings.PreviewAnchor:Destroy()
                Settings.PreviewAnchor = nil
            end
            Rayfield:Notify({ Title = "Attached", Content = "Часть закреплена статично!", Duration = 2 })
        elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Escape then
            local part = Settings.PreviewPart
            RemoveAlign(part)
            part.CanCollide = true
            part.Velocity = Vector3.new(0, 0, 0)
            Settings.PreviewPart = nil
            Settings.PreviewPosition = nil
            if Settings.PreviewAnchor then
                Settings.PreviewAnchor:Destroy()
                Settings.PreviewAnchor = nil
            end
            Rayfield:Notify({ Title = "Cancelled", Content = "Превью отменено.", Duration = 2 })
        end
        return
    end

    -- Обычные клавиши
    if key == Enum.KeyCode.E and not Settings.AttachmentMode then
        if Settings.SelectedPart then
            Settings.IsActive = not Settings.IsActive
            Settings.TornadoMode = false
        end
    elseif key == Enum.KeyCode.Q and not Settings.AttachmentMode then
        if Settings.SelectedPart then
            local part = Settings.SelectedPart
            local mousePos = Mouse.Hit.Position
            local direction = (mousePos - part.Position).Unit
            RemoveAlign(part)
            part.CanCollide = true
            part.Velocity = direction * Settings.ThrowForce
            Settings.SelectedPart = nil
            Settings.IsActive = false
            Settings.RotateMode = false
        end
    elseif key == Enum.KeyCode.R and not Settings.AttachmentMode then
        if Settings.SelectedPart then
            Settings.RotateMode = not Settings.RotateMode
        end
    elseif key == Enum.KeyCode.T and not Settings.AttachmentMode then
        Settings.TornadoMode = not Settings.TornadoMode
        Settings.IsActive = false
        if Settings.TornadoMode then
            if #AllParts == 0 then CollectAllParts() end
            for _, part in pairs(AllParts) do
                if not part:FindFirstChild("AlignPosition") then
                    local anchor, align = CreateAlign(part, part.Position)
                end
            end
        else
            for _, part in pairs(AllParts) do
                RemoveAlign(part)
            end
        end
    elseif key == Enum.KeyCode.F and not Settings.AttachmentMode then
        Settings.KillMode = not Settings.KillMode
    end
end)

-- Подсветка
RunService.RenderStepped:Connect(function()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Highlight") then
            local parent = v.Parent
            if parent ~= Settings.SelectedPart and parent ~= Settings.PreviewPart then
                local isAttached = false
                for _, item in pairs(Settings.AttachedParts) do
                    if item.Part == parent then isAttached = true break end
                end
                if not isAttached then
                    v:Destroy()
                end
            end
        end
    end

    local function addHighlight(part, color)
        if part and part.Parent and not part:FindFirstChildOfClass("Highlight") then
            local h = Instance.new("Highlight")
            h.FillColor = color
            h.FillTransparency = 0.5
            h.OutlineColor = Color3.fromRGB(255, 150, 0)
            h.Parent = part
        end
    end

    if Settings.PreviewPart then
        addHighlight(Settings.PreviewPart, Color3.fromRGB(0, 255, 255))
    elseif Settings.SelectedPart then
        addHighlight(Settings.SelectedPart, Color3.fromRGB(255, 200, 0))
    end
end)

print("Part Manipulator V5 loaded – AlignPosition for infinite range.")
