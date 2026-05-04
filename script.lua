-- Ultimate Part Manipulator V6.5.1 (Master Toggle)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

LocalPlayer.ReplicationFocus = Workspace
sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)

-- Настройки
local Settings = {
    MasterEnabled = true,   -- ГЛАВНЫЙ ВЫКЛЮЧАТЕЛЬ
    SelectedPart = nil,
    IsActive = false,
    HoldDistance = 10,
    ThrowForce = 500,
    RotateSpeed = 8,
    TornadoSpeed = 8,
    TornadoHeight = 20,
    TornadoRadius = 20,
    RotateMode = false,
    TornadoMode = false,
    KillMode = false,
    FlingSpinSpeed = 500,

    AttachmentMode = false,
    PreviewPart = nil,
    PreviewPosition = nil,
    AttachmentStep = 2,
    AttachedParts = {},

    UseNetworkOwner = false,
    HighlightAll = false,
    HighlightColor = Color3.fromRGB(0, 255, 100),
    BuildingFling = false,
    SelectionEnabled = true,
}

local AllParts = {}
local NetworkOwnerFailed = false
local HighlightFolder = nil

local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        if Settings.UseNetworkOwner and not NetworkOwnerFailed then
            local success, err = pcall(function()
                part:SetNetworkOwner(LocalPlayer)
            end)
            if not success then NetworkOwnerFailed = true end
        end
        part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.3, 0.5)
        part.CanCollide = true
        return true
    end
    return false
end

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

local function GetUnanchoredPartsList()
    local list = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored then
            local char = LocalPlayer.Character
            if char and not v:IsDescendantOf(char) then
                table.insert(list, v)
            end
        end
    end
    return list
end

local function UpdateHighlightAll()
    if HighlightFolder then HighlightFolder:Destroy(); HighlightFolder = nil end
    if Settings.HighlightAll then
        HighlightFolder = Instance.new("Folder")
        HighlightFolder.Name = "HighlightFolder"
        HighlightFolder.Parent = Workspace
        for _, part in pairs(GetUnanchoredPartsList()) do
            local h = Instance.new("Highlight")
            h.FillColor = Settings.HighlightColor
            h.FillTransparency = 0.7
            h.OutlineColor = Settings.HighlightColor
            h.OutlineTransparency = 0
            h.Parent = HighlightFolder
            h.Adornee = part
        end
    end
end

-- Функция полного сброса (используется при выключении Master)
local function FullDrop()
    for _, part in pairs(AllParts) do
        if part and part.Parent then
            part.Anchored = false
            part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent then
            part.Anchored = false
            part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    AllParts = {}
    Settings.AttachedParts = {}
    Settings.SelectedPart = nil
    Settings.IsActive = false
    Settings.TornadoMode = false
    Settings.KillMode = false
    Settings.RotateMode = false
    Settings.PreviewPart = nil
    Settings.BuildingFling = false
end

-- === RAYFIELD UI ===
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Part Manipulator V6.5.1",
    LoadingTitle = "Part Manipulator",
    LoadingSubtitle = "by DeepSeek AI",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local VisualTab = Window:CreateTab("Visual", 4483362458)
local ListTab = Window:CreateTab("Parts List", 4483362458)

-- ===== MASTER CONTROL (новая секция) =====
local MasterSection = MainTab:CreateSection("Master Control")
MainTab:CreateToggle({
    Name = "🔴 MASTER TOGGLE (ON/OFF)",
    CurrentValue = true,
    Flag = "MasterEnabled",
    Callback = function(Value)
        Settings.MasterEnabled = Value
        if not Value then
            FullDrop()
            Rayfield:Notify({ Title = "Master OFF", Content = "Скрипт отключён. Все части сброшены.", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Master ON", Content = "Скрипт включён. Можно работать.", Duration = 3 })
        end
    end,
})

-- ===== MAIN TAB (остальное) =====
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
        FullDrop()
        Rayfield:Notify({ Title = "Dropped", Content = "Все части сброшены", Duration = 2, Image = 4483362458 })
    end,
})

local SettingsSection = MainTab:CreateSection("Settings")
MainTab:CreateToggle({
    Name = "Use Network Ownership",
    CurrentValue = false,
    Flag = "UseNetworkOwner",
    Callback = function(Value)
        Settings.UseNetworkOwner = Value
        if Value then NetworkOwnerFailed = false end
    end,
})
MainTab:CreateToggle({
    Name = "Selection Mode (Click to select)",
    CurrentValue = true,
    Flag = "SelectionEnabled",
    Callback = function(Value)
        Settings.SelectionEnabled = Value
    end,
})
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
MainTab:CreateSlider({
    Name = "Fling Spin Speed",
    Range = {100, 2000},
    Increment = 50,
    Suffix = "rad/s",
    CurrentValue = Settings.FlingSpinSpeed,
    Flag = "FlingSpinSpeed",
    Callback = function(Value) Settings.FlingSpinSpeed = Value end,
})

local ActionsSection = MainTab:CreateSection("Actions")
MainTab:CreateToggle({
    Name = "Hold Part",
    CurrentValue = false,
    Flag = "HoldPart",
    Callback = function(Value)
        if not Settings.MasterEnabled then return end
        if not Settings.SelectedPart then
            Rayfield:Notify({ Title = "Error", Content = "Нет выбранной части", Duration = 2 })
            return
        end
        Settings.IsActive = Value
        if Value then
            Settings.TornadoMode = false
            Settings.SelectedPart.CanCollide = false
            if Settings.KillMode then
                Settings.SelectedPart.AssemblyAngularVelocity = Vector3.new(
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed)
                )
            end
        else
            if Settings.SelectedPart then
                Settings.SelectedPart.CanCollide = true
                if not Settings.KillMode then
                    Settings.SelectedPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end,
})
MainTab:CreateToggle({
    Name = "Rotate Part",
    CurrentValue = false,
    Flag = "RotatePart",
    Callback = function(Value)
        if not Settings.MasterEnabled then return end
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
        if not Settings.MasterEnabled then return end
        if not Settings.SelectedPart then
            Rayfield:Notify({ Title = "Error", Content = "Нет выбранной части", Duration = 2 })
            return
        end
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local direction = (mousePos - part.Position).Unit
        part.CanCollide = true
        part.Velocity = direction * Settings.ThrowForce
        if Settings.KillMode then
            part.AssemblyAngularVelocity = Vector3.new(
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed)
            )
        end
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
        if not Settings.MasterEnabled then return end
        Settings.TornadoMode = Value
        Settings.IsActive = false
        if Value and #AllParts == 0 then CollectAllParts() end
    end,
})
MainTab:CreateToggle({
    Name = "Fling Mode",
    CurrentValue = false,
    Flag = "FlingMode",
    Callback = function(Value)
        if not Settings.MasterEnabled then return end
        Settings.KillMode = Value
        if not Value then
            for _, part in pairs(AllParts) do
                if part and part.Parent then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            if Settings.SelectedPart then
                Settings.SelectedPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end,
})

local AttachSection = MainTab:CreateSection("Attachment Mode")
MainTab:CreateToggle({
    Name = "Attachment Mode",
    CurrentValue = false,
    Flag = "AttachmentMode",
    Callback = function(Value)
        if not Settings.MasterEnabled then return end
        Settings.AttachmentMode = Value
        Settings.PreviewPart = nil
        Settings.PreviewPosition = nil
        if Value then
            Rayfield:Notify({
                Title = "Attachment",
                Content = "Клик по части, E/Q/X/Z движение, Enter закрепить, R+Fling = флинг-ловушка!",
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

MainTab:CreateToggle({
    Name = "Building Fling (Attached Parts Spin)",
    CurrentValue = false,
    Flag = "BuildingFling",
    Callback = function(Value)
        if not Settings.MasterEnabled then return end
        Settings.BuildingFling = Value
        if Value then
            for _, item in pairs(Settings.AttachedParts) do
                local part = item.Part
                if part and part.Parent then
                    part.Anchored = false
                    item.FlingEnabled = true
                    item.SpinSpeed = Settings.FlingSpinSpeed
                end
            end
        else
            for _, item in pairs(Settings.AttachedParts) do
                local part = item.Part
                if part and part.Parent then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    part.Anchored = true
                    part.Velocity = Vector3.new(0, 0, 0)
                    item.FlingEnabled = false
                end
            end
        end
    end,
})

MainTab:CreateButton({
    Name = "Unattach All",
    Callback = function()
        for _, item in pairs(Settings.AttachedParts) do
            local part = item.Part
            if part and part.Parent then
                part.Anchored = false
                part.CanCollide = true
                part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
                part.Velocity = Vector3.new(0, 0, 0)
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
        Settings.AttachedParts = {}
        Settings.BuildingFling = false
        Rayfield:Notify({ Title = "Unattached", Content = "Все прикреплённые части сброшены.", Duration = 2 })
    end,
})

-- ===== VISUAL TAB =====
local HighlightSection = VisualTab:CreateSection("Highlight Unanchored Parts")
VisualTab:CreateToggle({
    Name = "Highlight All Unanchored",
    CurrentValue = false,
    Flag = "HighlightAll",
    Callback = function(Value)
        Settings.HighlightAll = Value
        UpdateHighlightAll()
    end,
})
VisualTab:CreateButton({
    Name = "Refresh Highlights",
    Callback = function()
        UpdateHighlightAll()
        Rayfield:Notify({ Title = "Refreshed", Content = "Подсветка обновлена", Duration = 2 })
    end,
})

-- ===== PARTS LIST TAB =====
local PartsListSection = ListTab:CreateSection("All Unanchored Parts")
local partsListLabel = ListTab:CreateParagraph({ Title = "Count", Content = "Loading..." })

local function RefreshPartsList()
    local parts = GetUnanchoredPartsList()
    local text = ""
    for i, part in ipairs(parts) do
        if i <= 50 then
            local dist = "?"
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                dist = math.floor((char.HumanoidRootPart.Position - part.Position).Magnitude)
            end
            text = text .. string.format("[%d] %s | %d studs\n", i, part.Name, dist)
        end
    end
    if #parts > 50 then
        text = text .. "... и ещё " .. (#parts - 50) .. " частей"
    end
    partsListLabel:SetTitle("Count: " .. #parts)
    partsListLabel:SetContent(text)
end

ListTab:CreateButton({
    Name = "Refresh Parts List",
    Callback = function()
        RefreshPartsList()
        Rayfield:Notify({ Title = "Refreshed", Content = "Список обновлён", Duration = 2 })
    end,
})

local TeleportSection = ListTab:CreateSection("Teleport to Part")
local TeleportInput = ListTab:CreateInput({
    Name = "Part Name",
    PlaceholderText = "Введите имя части",
    RemoveTextAfterFocusLost = false,
    Flag = "TeleportPartName",
    Callback = function() end,
})
ListTab:CreateButton({
    Name = "Teleport to Part",
    Callback = function()
        local name = TeleportInput.CurrentValue
        if not name or name == "" then
            Rayfield:Notify({ Title = "Error", Content = "Введите имя части", Duration = 2 })
            return
        end
        for _, part in pairs(GetUnanchoredPartsList()) do
            if part.Name:lower():find(name:lower()) then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                    Rayfield:Notify({ Title = "Teleported", Content = "К части: " .. part.Name, Duration = 2 })
                    return
                end
            end
        end
        Rayfield:Notify({ Title = "Not Found", Content = "Часть не найдена", Duration = 2 })
    end,
})

-- ===== ЛОГИКА ВЫБОРА ЧАСТИ =====
Mouse.Button1Down:Connect(function()
    if not Settings.MasterEnabled then return end
    if not Settings.SelectionEnabled then return end

    local target = Mouse.Target
    if not (target and target:IsA("BasePart") and not target.Anchored) then return end
    local char = LocalPlayer.Character
    if not char or target:IsDescendantOf(char) then return end

    if Settings.AttachmentMode then
        for i, item in pairs(Settings.AttachedParts) do
            if item.Part == target then
                target.Anchored = false
                target.CanCollide = true
                target.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
                target.Velocity = Vector3.new(0, 0, 0)
                target.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                table.remove(Settings.AttachedParts, i)
                Rayfield:Notify({ Title = "Unattached", Content = "Часть откреплена.", Duration = 2 })
                return
            end
        end

        if RetainPart(target) then
            Settings.PreviewPart = target
            target.CanCollide = false
            Settings.PreviewPosition = target.Position
            if not table.find(AllParts, target) then
                table.insert(AllParts, target)
            end
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

-- ===== ГЛАВНЫЙ ФИЗИЧЕСКИЙ ЦИКЛ =====
RunService.Heartbeat:Connect(function()
    if not Settings.MasterEnabled then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart

    -- Торнадо
    if Settings.TornadoMode then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent and not part.Anchored then
                local offset = i * 2.4
                local x = math.cos(angle + offset) * Settings.TornadoRadius
                local z = math.sin(angle + offset) * Settings.TornadoRadius
                local y = math.sin(tick() * 2 + offset) * Settings.TornadoHeight
                local targetPos = root.Position + Vector3.new(x, y, z)
                part.Velocity = (targetPos - part.Position) * 5
                
                if Settings.KillMode then
                    part.AssemblyAngularVelocity = Vector3.new(
                        math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                        math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                        math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed)
                    )
                else
                    part.AssemblyAngularVelocity = Vector3.new(0, Settings.TornadoSpeed, 0)
                end
            end
        end
    end

    -- Удержание
    if Settings.IsActive and Settings.SelectedPart and Settings.SelectedPart.Parent and not Settings.AttachmentMode then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local targetPos = root.Position + (mousePos - root.Position).Unit * Settings.HoldDistance + Vector3.new(0, 3, 0)
        part.Velocity = (targetPos - part.Position) * 10

        if Settings.KillMode then
            part.AssemblyAngularVelocity = Vector3.new(
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed)
            )
        end
    end

    -- Вращение
    if Settings.RotateMode and Settings.SelectedPart and Settings.SelectedPart.Parent and not Settings.AttachmentMode then
        if not Settings.KillMode then
            Settings.SelectedPart.AssemblyAngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0)
        end
    end

    -- Превью (строительство)
    if Settings.PreviewPart and Settings.PreviewPart.Parent and Settings.AttachmentMode then
        local part = Settings.PreviewPart
        part.Velocity = (Settings.PreviewPosition - part.Position) * 15
    end

    -- Прикреплённые части с флингом
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent then
            if item.FlingEnabled and Settings.BuildingFling then
                if part.Anchored then
                    part.Anchored = false
                end
                local targetPos = item.TargetPos or part.Position
                part.Velocity = (targetPos - part.Position) * 20
                part.AssemblyAngularVelocity = Vector3.new(
                    math.random(-item.SpinSpeed, item.SpinSpeed),
                    math.random(-item.SpinSpeed, item.SpinSpeed),
                    math.random(-item.SpinSpeed, item.SpinSpeed)
                )
                part.CanCollide = true
            elseif not item.FlingEnabled and not part.Anchored then
                part.Anchored = true
                part.Velocity = Vector3.new(0, 0, 0)
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

-- ===== КЛАВИАТУРА =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not Settings.MasterEnabled then return end

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
            part.Anchored = true
            part.CanCollide = true
            part.Velocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            table.insert(Settings.AttachedParts, {
                Part = part,
                TargetPos = Settings.PreviewPosition,
                FlingEnabled = false,
                SpinSpeed = Settings.FlingSpinSpeed
            })
            Settings.PreviewPart = nil
            Settings.PreviewPosition = nil
            Rayfield:Notify({ Title = "Attached", Content = "Часть закреплена! Включите Building Fling для ловушки.", Duration = 3 })
        elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Escape then
            local part = Settings.PreviewPart
            if part and part.Parent then
                part.CanCollide = true
                part.Velocity = Vector3.new(0, 0, 0)
            end
            Settings.PreviewPart = nil
            Settings.PreviewPosition = nil
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
            part.CanCollide = true
            part.Velocity = direction * Settings.ThrowForce
            if Settings.KillMode then
                part.AssemblyAngularVelocity = Vector3.new(
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed),
                    math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed)
                )
            end
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
        if Settings.TornadoMode and #AllParts == 0 then CollectAllParts() end
    elseif key == Enum.KeyCode.F and not Settings.AttachmentMode then
        Settings.KillMode = not Settings.KillMode
        if not Settings.KillMode then
            for _, part in pairs(AllParts) do
                if part and part.Parent then
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            if Settings.SelectedPart then
                Settings.SelectedPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

-- Подсветка
RunService.RenderStepped:Connect(function()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Highlight") then
            local parent = v.Parent
            if parent ~= HighlightFolder then
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

RefreshPartsList()

print("Part Manipulator V6.5.1 loaded - Master Toggle ready!")
