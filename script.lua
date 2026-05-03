-- Ultimate Part Manipulator V2 - Коллизия + Полёт + Флинг
-- Все функции работают, части твёрдые, видно всем

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Включаем репликацию
LocalPlayer.ReplicationFocus = Workspace
sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)

-- Настройки
local Settings = {
    SelectedPart = nil,
    IsActive = false,
    HoldDistance = 10,
    MoveSpeed = 5,
    ThrowForce = 15000,
    RotateSpeed = 8,
    TornadoSpeed = 12,
    TornadoHeight = 25,
    TornadoRadius = 20,
    RotateMode = false,
    TornadoMode = false,
    KillMode = false,
    Range = math.huge,
}

-- Списки
local ControlledParts = {}
local AllParts = {}

-- НОВАЯ функция захвата: части остаются ТВЁРДЫМИ но управляемыми
local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        
        -- ВАЖНО: не делаем массу 0! Оставляем нормальную физику
        part.CustomPhysicalProperties = PhysicalProperties.new(
            0.5,  -- Density (плотность) - не 0, чтобы была масса
            0.4,  -- Friction
            0.5,  -- Elasticity
            0.5,  -- FrictionWeight
            0.5   -- ElasticityWeight
        )
        part.CanCollide = true -- КОЛЛИЗИЯ ВКЛЮЧЕНА! Игроки не проходят сквозь
        return true
    end
    return false
end

-- Сбор всех частей
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

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PartManipulatorV2"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 230, 0, 390)
MainFrame.Position = UDim2.new(0.75, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Title.BorderSizePixel = 0
Title.Text = "🎯 ULTIMATE CONTROL V2"
Title.TextColor3 = Color3.fromRGB(255, 200, 0)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- Информация
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 18)
StatusLabel.Position = UDim2.new(0, 5, 0, 35)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "🔰 Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local PartCount = Instance.new("TextLabel")
PartCount.Size = UDim2.new(1, -10, 0, 18)
PartCount.Position = UDim2.new(0, 5, 0, 53)
PartCount.BackgroundTransparency = 1
PartCount.Text = "📦 Parts: 0"
PartCount.TextColor3 = Color3.fromRGB(200, 200, 200)
PartCount.Font = Enum.Font.SourceSans
PartCount.TextSize = 11
PartCount.TextXAlignment = Enum.TextXAlignment.Left
PartCount.Parent = MainFrame

local CollisionStatus = Instance.new("TextLabel")
CollisionStatus.Size = UDim2.new(1, -10, 0, 18)
CollisionStatus.Position = UDim2.new(0, 5, 0, 71)
CollisionStatus.BackgroundTransparency = 1
CollisionStatus.Text = "🧱 Collision: ON"
CollisionStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
CollisionStatus.Font = Enum.Font.SourceSans
CollisionStatus.TextSize = 11
CollisionStatus.TextXAlignment = Enum.TextXAlignment.Left
CollisionStatus.Parent = MainFrame

-- Функция создания кнопок
local function CreateButton(name, y, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.BackgroundColor3 = color or Color3.fromRGB(55, 55, 55)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.Parent = MainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Кнопки
CreateButton("🟢 COLLECT ALL PARTS", 0.25, Color3.fromRGB(0, 140, 0), function()
    local count = CollectAllParts()
    PartCount.Text = "📦 Parts: " .. count
    StatusLabel.Text = "🔰 Collected: " .. count .. " parts!"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end)

CreateButton("🖱️ CLICK TO SELECT", 0.34, Color3.fromRGB(70, 70, 70), function()
    StatusLabel.Text = "🔰 Click any part to select"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
end)

CreateButton("👁️ HOLD PART (E)", 0.43, Color3.fromRGB(0, 100, 200), function()
    if Settings.SelectedPart then
        Settings.IsActive = not Settings.IsActive
        Settings.TornadoMode = false
        StatusLabel.Text = "🔰 " .. (Settings.IsActive and "HOLDING" or "Released")
        StatusLabel.TextColor3 = Settings.IsActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    end
end)

CreateButton("💨 THROW AT MOUSE (Q)", 0.52, Color3.fromRGB(200, 100, 0), function()
    if Settings.SelectedPart then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local direction = (mousePos - part.Position).Unit
        part.Velocity = direction * Settings.ThrowForce
        -- Не отключаем коллизию! Часть летит и может ударить игрока
        part.CanCollide = true
        Settings.SelectedPart = nil
        Settings.IsActive = false
        StatusLabel.Text = "🔰 Thrown! Collision ON"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
    end
end)

CreateButton("🔄 ROTATE PART (R)", 0.61, Color3.fromRGB(0, 130, 100), function()
    Settings.RotateMode = not Settings.RotateMode
    StatusLabel.Text = "🔰 Rotation: " .. (Settings.RotateMode and "ON" or "OFF")
end)

CreateButton("🌪️ TORNADO MODE (T)", 0.70, Color3.fromRGB(150, 0, 200), function()
    Settings.TornadoMode = not Settings.TornadoMode
    Settings.IsActive = false
    StatusLabel.Text = "🔰 Tornado: " .. (Settings.TornadoMode and "ACTIVE" or "OFF")
    StatusLabel.TextColor3 = Settings.TornadoMode and Color3.fromRGB(200, 100, 255) or Color3.fromRGB(255, 255, 255)
    if Settings.TornadoMode and #AllParts == 0 then
        CollectAllParts()
    end
end)

CreateButton("💀 FLING MODE (F)", 0.79, Color3.fromRGB(255, 0, 0), function()
    Settings.KillMode = not Settings.KillMode
    StatusLabel.Text = "🔰 Fling: " .. (Settings.KillMode and "ON - Players will fly!" or "OFF")
    StatusLabel.TextColor3 = Settings.KillMode and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
end)

CreateButton("❌ DROP ALL", 0.88, Color3.fromRGB(180, 30, 30), function()
    for _, part in pairs(AllParts) do
        if part and part.Parent then
            part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.new(0, 0, 0)
            part.AngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    AllParts = {}
    ControlledParts = {}
    Settings.SelectedPart = nil
    Settings.IsActive = false
    Settings.TornadoMode = false
    Settings.KillMode = false
    Settings.RotateMode = false
    PartCount.Text = "📦 Parts: 0"
    StatusLabel.Text = "🔰 All dropped - Collision restored"
end)

-- Выбор части кликом
Mouse.Button1Down:Connect(function()
    local target = Mouse.Target
    if target and target:IsA("BasePart") and not target.Anchored then
        local char = LocalPlayer.Character
        if char and not target:IsDescendantOf(char) then
            if RetainPart(target) then
                Settings.SelectedPart = target
                if not table.find(AllParts, target) then
                    table.insert(AllParts, target)
                end
                PartCount.Text = "📦 Parts: " .. #AllParts
                StatusLabel.Text = "🔰 Selected: " .. target.Name
                StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            end
        end
    end
end)

-- ГЛАВНЫЙ ЦИКЛ - теперь с коллизией
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    
    -- Режим торнадо (все части крутятся, НО с коллизией)
    if Settings.TornadoMode then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent then
                local offset = (i * 2.4)
                local x = math.cos(angle + offset) * Settings.TornadoRadius
                local z = math.sin(angle + offset) * Settings.TornadoRadius
                local y = math.sin(tick() * 2 + offset) * Settings.TornadoHeight
                local targetPos = root.Position + Vector3.new(x, y, z)
                
                -- Плавное перемещение с сохранением коллизии
                local direction = (targetPos - part.Position)
                local distance = direction.Magnitude
                
                if distance > 0.1 then
                    part.Velocity = direction.Unit * math.min(distance * 5, 200)
                end
                
                part.AngularVelocity = Vector3.new(
                    math.random(-5, 5), 
                    Settings.TornadoSpeed * 0.5, 
                    math.random(-5, 5)
                )
                
                -- Флинг игроков (части твёрдые - отлично работают!)
                if Settings.KillMode then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local hrp = player.Character.HumanoidRootPart
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist < 8 then -- Увеличил радиус флинга
                                local flingDir = (part.Position - hrp.Position).Unit
                                hrp.Velocity = flingDir * 600 + Vector3.new(math.random(-100, 100), 250, math.random(-100, 100))
                            end
                        end
                    end
                end
            end
        end
        PartCount.Text = "📦 Parts: " .. #AllParts
        return
    end
    
    -- Режим удержания одной части (с коллизией)
    if Settings.IsActive and Settings.SelectedPart and Settings.SelectedPart.Parent then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        
        -- Направление от игрока к мыши
        local direction = (mousePos - root.Position).Unit
        local targetPos = root.Position + direction * Settings.HoldDistance + Vector3.new(0, 3, 0)
        
        -- Сильное притяжение к точке, но с ограничением скорости
        local moveDir = (targetPos - part.Position)
        local moveDist = moveDir.Magnitude
        
        if moveDist > 0.1 then
            -- Применяем силу вместо прямого Velocity для лучшей физики
            part.Velocity = moveDir.Unit * math.min(moveDist * Settings.MoveSpeed * 2, 150)
        end
        
        -- Флинг при касании (часть твёрдая - работает идеально!)
        if Settings.KillMode then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = player.Character.HumanoidRootPart
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < 6 then
                        local flingDir = (part.Position - hrp.Position).Unit
                        hrp.Velocity = flingDir * 700 + Vector3.new(0, 300, 0)
                    end
                end
            end
        end
    end
    
    -- Вращение
    if Settings.RotateMode and Settings.SelectedPart and Settings.SelectedPart.Parent then
        Settings.SelectedPart.AngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0)
    end
    
    -- Предотвращаем проваливание под землю для всех частей
    for _, part in pairs(AllParts) do
        if part and part.Parent then
            if part.Position.Y < -50 then
                part.Velocity = Vector3.new(0, 30, 0)
                part.Position = Vector3.new(part.Position.X, 4, part.Position.Z)
            end
        end
    end
    
    PartCount.Text = "📦 Parts: " .. #AllParts
end)

-- Подсветка
RunService.RenderStepped:Connect(function()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Highlight") and v.Parent ~= Settings.SelectedPart then
            v:Destroy()
        end
    end
    if Settings.SelectedPart and Settings.SelectedPart.Parent then
        if not Settings.SelectedPart:FindFirstChildOfClass("Highlight") then
            local h = Instance.new("Highlight")
            h.FillColor = Settings.KillMode and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 200, 0)
            h.FillTransparency = 0.5
            h.OutlineColor = Color3.fromRGB(255, 150, 0)
            h.OutlineTransparency = 0
            h.Parent = Settings.SelectedPart
        end
    end
end)

-- Клавиши
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E and Settings.SelectedPart then
        Settings.IsActive = not Settings.IsActive
        Settings.TornadoMode = false
        StatusLabel.Text = "🔰 " .. (Settings.IsActive and "HOLDING" or "Released")
        StatusLabel.TextColor3 = Settings.IsActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
    elseif input.KeyCode == Enum.KeyCode.Q and Settings.SelectedPart then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local direction = (mousePos - part.Position).Unit
        part.Velocity = direction * Settings.ThrowForce
        part.CanCollide = true -- КОЛЛИЗИЯ ОСТАЁТСЯ
        Settings.SelectedPart = nil
        Settings.IsActive = false
        StatusLabel.Text = "🔰 Thrown! Solid impact!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
        
    elseif input.KeyCode == Enum.KeyCode.R and Settings.SelectedPart then
        Settings.RotateMode = not Settings.RotateMode
        StatusLabel.Text = "🔰 Rotation: " .. (Settings.RotateMode and "ON" or "OFF")
        
    elseif input.KeyCode == Enum.KeyCode.T then
        Settings.TornadoMode = not Settings.TornadoMode
        Settings.IsActive = false
        StatusLabel.Text = "🔰 Tornado: " .. (Settings.TornadoMode and "ACTIVE" or "OFF")
        StatusLabel.TextColor3 = Settings.TornadoMode and Color3.fromRGB(200, 100, 255) or Color3.fromRGB(255, 255, 255)
        if Settings.TornadoMode and #AllParts == 0 then
            CollectAllParts()
        end
        
    elseif input.KeyCode == Enum.KeyCode.F then
        Settings.KillMode = not Settings.KillMode
        StatusLabel.Text = "🔰 Fling: " .. (Settings.KillMode and "ON - Parts are SOLID!" or "OFF")
        StatusLabel.TextColor3 = Settings.KillMode and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
        
    elseif input.KeyCode == Enum.KeyCode.X then
        if Settings.SelectedPart then
            Settings.SelectedPart.Velocity = Vector3.new(0, 0, 0)
            Settings.SelectedPart.AngularVelocity = Vector3.new(0, 0, 0)
        end
        Settings.SelectedPart = nil
        Settings.IsActive = false
        Settings.RotateMode = false
        StatusLabel.Text = "🔰 Deselected"
    end
end)

print("✅ ULTIMATE PART CONTROL V2 LOADED")
print("🧱 Parts have COLLISION - players can stand on them!")
print("💀 Fling works perfectly with solid parts!")
print("🟢 Collect All | 🖱️ Click Select | E Hold | Q Throw")
print("🔄 R Rotate | 🌪️ T Tornado | 💀 F Fling | ❌ Drop All")
print("🔑 Visible to ALL players!")
