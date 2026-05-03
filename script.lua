-- Ultimate Part Manipulator - Все функции
-- Видно всем игрокам (ReplicationFocus метод)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Включаем репликацию на весь Workspace
LocalPlayer.ReplicationFocus = Workspace
sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)

-- Настройки
local Settings = {
    SelectedPart = nil,
    IsActive = false,
    HoldDistance = 10,
    MoveSpeed = 3,
    ThrowForce = 10000,
    RotateSpeed = 10,
    TornadoSpeed = 15,
    TornadoHeight = 30,
    TornadoRadius = 20,
    RotateMode = false,
    TornadoMode = false,
    KillMode = false,
    Range = math.huge, -- Бесконечная дальность
}

-- Список захваченных частей
local ControlledParts = {}
local AllParts = {}

-- Функция захвата части
local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        -- Невесомая
        part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
        part.CanCollide = false
        return true
    end
    return false
end

-- Собрать ВСЕ части вокруг
local function CollectAllParts()
    local count = 0
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored then
            local char = LocalPlayer.Character
            if char and not v:IsDescendantOf(char) then
                if RetainPart(v) then
                    table.insert(AllParts, v)
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PartManipulator"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 370)
MainFrame.Position = UDim2.new(0.75, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.BorderSizePixel = 0
Title.Text = "🎯 ULTIMATE CONTROL"
Title.TextColor3 = Color3.fromRGB(255, 200, 0)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 8)
UICornerTitle.Parent = Title

-- Статус
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 18)
StatusLabel.Position = UDim2.new(0, 5, 0, 32)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local PartCount = Instance.new("TextLabel")
PartCount.Size = UDim2.new(1, -10, 0, 18)
PartCount.Position = UDim2.new(0, 5, 0, 50)
PartCount.BackgroundTransparency = 1
PartCount.Text = "Parts: 0"
PartCount.TextColor3 = Color3.fromRGB(200, 200, 200)
PartCount.Font = Enum.Font.SourceSans
PartCount.TextSize = 11
PartCount.TextXAlignment = Enum.TextXAlignment.Left
PartCount.Parent = MainFrame

-- Функция создания кнопки
local function CreateButton(name, y, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 28)
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

-- Кнопки управления
CreateButton("🟢 COLLECT ALL PARTS", 0.22, Color3.fromRGB(0, 150, 0), function()
    local count = CollectAllParts()
    PartCount.Text = "Parts: " .. count
    StatusLabel.Text = "Collected: " .. count .. " parts!"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end)

CreateButton("🖱️ CLICK TO SELECT", 0.31, Color3.fromRGB(70, 70, 70), function()
    StatusLabel.Text = "Click any part to select"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
end)

CreateButton("👁️ HOLD PART (E)", 0.40, Color3.fromRGB(0, 100, 200), function()
    if Settings.SelectedPart then
        Settings.IsActive = not Settings.IsActive
        Settings.TornadoMode = false
        StatusLabel.Text = Settings.IsActive and "HOLDING" or "Released"
        StatusLabel.TextColor3 = Settings.IsActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    end
end)

CreateButton("💨 THROW AT MOUSE (Q)", 0.49, Color3.fromRGB(200, 100, 0), function()
    if Settings.SelectedPart then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local direction = (mousePos - part.Position).Unit
            part.Velocity = direction * Settings.ThrowForce
            part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            Settings.SelectedPart = nil
            Settings.IsActive = false
            StatusLabel.Text = "Thrown!"
            print("💨 Part thrown to mouse position!")
        end
    end
end)

CreateButton("🔄 ROTATE PART (R)", 0.58, Color3.fromRGB(0, 130, 100), function()
    Settings.RotateMode = not Settings.RotateMode
    StatusLabel.Text = "Rotation: " .. (Settings.RotateMode and "ON" or "OFF")
end)

CreateButton("🌪️ TORNADO MODE (T)", 0.67, Color3.fromRGB(150, 0, 200), function()
    Settings.TornadoMode = not Settings.TornadoMode
    Settings.IsActive = false
    StatusLabel.Text = "Tornado: " .. (Settings.TornadoMode and "ON" or "OFF")
    StatusLabel.TextColor3 = Settings.TornadoMode and Color3.fromRGB(200, 100, 255) or Color3.fromRGB(255, 255, 255)
end)

CreateButton("💀 FLING MODE (F)", 0.76, Color3.fromRGB(255, 0, 0), function()
    Settings.KillMode = not Settings.KillMode
    StatusLabel.Text = "Fling: " .. (Settings.KillMode and "ON" or "OFF")
    StatusLabel.TextColor3 = Settings.KillMode and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
end)

CreateButton("❌ DROP ALL", 0.85, Color3.fromRGB(180, 30, 30), function()
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
    PartCount.Text = "Parts: 0"
    StatusLabel.Text = "All dropped"
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
                PartCount.Text = "Parts: " .. #AllParts
                StatusLabel.Text = "Selected: " .. target.Name
                StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
                print("🎯 Selected:", target.Name)
            end
        end
    end
end)

-- Главный цикл
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    
    -- Режим торнадо (все части крутятся вокруг)
    if Settings.TornadoMode then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent then
                local offset = (i * 2.4) -- Равномерное распределение
                local x = math.cos(angle + offset) * Settings.TornadoRadius
                local z = math.sin(angle + offset) * Settings.TornadoRadius
                local y = math.sin(tick() * 2 + offset) * Settings.TornadoHeight
                local targetPos = root.Position + Vector3.new(x, y, z)
                part.Velocity = (targetPos - part.Position) * 5
                part.AngularVelocity = Vector3.new(math.random(-10, 10), Settings.TornadoSpeed, math.random(-10, 10))
                
                -- Флинг режим - убиваем игроков рядом с частями
                if Settings.KillMode then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local hrp = player.Character.HumanoidRootPart
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist < 5 then
                                hrp.Velocity = (part.Position - hrp.Position).Unit * 500 + Vector3.new(0, 200, 0)
                                hrp.AssemblyLinearVelocity = Vector3.new(math.random(-100, 100), 300, math.random(-100, 100))
                            end
                        end
                    end
                end
            end
        end
        return
    end
    
    -- Режим удержания одной части
    if Settings.IsActive and Settings.SelectedPart and Settings.SelectedPart.Parent then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position -- Используем позицию мыши, а не камеры!
        local camera = Workspace.CurrentCamera
        
        -- Позиция удержания: направление от игрока к мыши
        local direction = (mousePos - root.Position).Unit
        local targetPos = root.Position + direction * Settings.HoldDistance + Vector3.new(0, 3, 0)
        
        -- Двигаем часть к позиции по направлению мыши
        part.Velocity = (targetPos - part.Position) * Settings.MoveSpeed * 5
        
        -- Флинг при касании игроков
        if Settings.KillMode then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = player.Character.HumanoidRootPart
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist < 4 then
                        local flingDir = (part.Position - hrp.Position).Unit
                        hrp.Velocity = flingDir * 800 + Vector3.new(0, 300, 0)
                    end
                end
            end
        end
    end
    
    -- Вращение выбранной части
    if Settings.RotateMode and Settings.SelectedPart and Settings.SelectedPart.Parent then
        Settings.SelectedPart.AngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0)
    end
    
    -- Обновление счетчика
    PartCount.Text = "Parts: " .. #AllParts
end)

-- Подсветка выбранной части
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

-- Клавиши управления
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E and Settings.SelectedPart then
        Settings.IsActive = not Settings.IsActive
        Settings.TornadoMode = false
        StatusLabel.Text = Settings.IsActive and "HOLDING" or "Released"
        StatusLabel.TextColor3 = Settings.IsActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
    elseif input.KeyCode == Enum.KeyCode.Q and Settings.SelectedPart then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local root = LocalPlayer.Character.HumanoidRootPart
        local direction = (mousePos - part.Position).Unit
        part.Velocity = direction * Settings.ThrowForce
        part.CanCollide = true
        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
        Settings.SelectedPart = nil
        Settings.IsActive = false
        StatusLabel.Text = "Thrown to mouse!"
        print("💨 Thrown!")
        
    elseif input.KeyCode == Enum.KeyCode.R and Settings.SelectedPart then
        Settings.RotateMode = not Settings.RotateMode
        print("🔄 Rotation:", Settings.RotateMode)
        
    elseif input.KeyCode == Enum.KeyCode.T then
        Settings.TornadoMode = not Settings.TornadoMode
        Settings.IsActive = false
        StatusLabel.Text = "Tornado: " .. (Settings.TornadoMode and "ON" or "OFF")
        StatusLabel.TextColor3 = Settings.TornadoMode and Color3.fromRGB(200, 100, 255) or Color3.fromRGB(255, 255, 255)
        if Settings.TornadoMode and #AllParts == 0 then
            CollectAllParts()
        end
        
    elseif input.KeyCode == Enum.KeyCode.F then
        Settings.KillMode = not Settings.KillMode
        StatusLabel.Text = "Fling: " .. (Settings.KillMode and "ON - Players will fly!" or "OFF")
        StatusLabel.TextColor3 = Settings.KillMode and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
        
    elseif input.KeyCode == Enum.KeyCode.X then
        if Settings.SelectedPart then
            Settings.SelectedPart.Velocity = Vector3.new(0, 0, 0)
            Settings.SelectedPart.AngularVelocity = Vector3.new(0, 0, 0)
        end
        Settings.SelectedPart = nil
        Settings.IsActive = false
        Settings.RotateMode = false
        StatusLabel.Text = "Deselected"
    end
end)

print("✅ ULTIMATE PART CONTROL LOADED")
print("🟢 Collect All - Grab every part")
print("🖱️ Click - Select single part")
print("👁️ E - Hold part at MOUSE direction")
print("💨 Q - Throw part at MOUSE cursor")
print("🔄 R - Rotate part")
print("🌪️ T - Tornado mode (all parts spin)")
print("💀 F - Fling mode (launch players)")
print("❌ Drop All - Release everything")
print("🔑 Visible to ALL players!")
