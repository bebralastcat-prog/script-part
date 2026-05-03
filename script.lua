-- Manipulate Parts - Visible to ALL (ReplicationFocus Method)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- 🔑 Включаем репликацию на весь Workspace
LocalPlayer.ReplicationFocus = Workspace
sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)

local Settings = {
    SelectedPart = nil,
    IsActive = false,
    HoldDistance = 10,
    MoveSpeed = 3,
    ThrowForce = 10000,
    RotateSpeed = 5,
    RotateMode = false,
    Range = 100,
}

-- Список захваченных частей
local ControlledParts = {}

-- Функция захвата части
local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        -- Делаем часть невесомой для управления
        part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
        part.CanCollide = false
        return true
    end
    return false
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PartManipulator"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 200, 0, 200)
MainFrame.Position = UDim2.new(0.8, 0, 0.4, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.BorderSizePixel = 0
Title.Text = "🎯 Parts Control"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.Parent = MainFrame

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, 0, 0, 50)
Info.Position = UDim2.new(0, 0, 0, 30)
Info.BackgroundTransparency = 1
Info.Text = "Click Part - Select\nE - Hold | Q - Throw\nR - Rotate | X - Drop"
Info.TextColor3 = Color3.fromRGB(200, 200, 200)
Info.Font = Enum.Font.SourceSans
Info.TextSize = 11
Info.TextWrapped = true
Info.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 85)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

local PartName = Instance.new("TextLabel")
PartName.Size = UDim2.new(1, 0, 0, 20)
PartName.Position = UDim2.new(0, 0, 0, 105)
PartName.BackgroundTransparency = 1
PartName.Text = "Selected: None"
PartName.TextColor3 = Color3.fromRGB(255, 255, 150)
PartName.Font = Enum.Font.SourceSans
PartName.TextSize = 11
PartName.Parent = MainFrame

-- Кнопки
local function CreateButton(name, y, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 25)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 12
    btn.Parent = MainFrame
    btn.MouseButton1Click:Connect(callback)
    return btn
end

CreateButton("Drop All Parts", 0.73, Color3.fromRGB(200, 50, 50), function()
    for _, part in pairs(ControlledParts) do
        if part and part.Parent then
            part.Anchored = false
            part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.new(0, 0, 0)
        end
    end
    ControlledParts = {}
    Settings.SelectedPart = nil
    Settings.IsActive = false
    PartName.Text = "Selected: None"
    StatusLabel.Text = "Status: Cleared"
end)

-- Выбор части кликом
Mouse.Button1Down:Connect(function()
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
    
    local target = Mouse.Target
    if target and target:IsA("BasePart") and not target.Anchored then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local dist = (char.HumanoidRootPart.Position - target.Position).Magnitude
            if dist <= Settings.Range then
                if not target:IsDescendantOf(char) then
                    if RetainPart(target) then
                        Settings.SelectedPart = target
                        table.insert(ControlledParts, target)
                        PartName.Text = "Selected: " .. target.Name
                        StatusLabel.Text = "Status: Selected"
                        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
                        print("🎯 Selected:", target.Name)
                    end
                end
            end
        end
    end
end)

-- Основной цикл управления физикой
RunService.Heartbeat:Connect(function()
    if Settings.SelectedPart and Settings.SelectedPart.Parent then
        local part = Settings.SelectedPart
        local char = LocalPlayer.Character
        
        if char and char:FindFirstChild("HumanoidRootPart") then
            local root = char.HumanoidRootPart
            local camera = Workspace.CurrentCamera
            
            if Settings.IsActive then
                -- Удержание перед игроком
                local targetPos = root.Position + (camera.CFrame.LookVector * Settings.HoldDistance) + Vector3.new(0, 2, 0)
                local direction = (targetPos - part.Position)
                part.Velocity = direction * Settings.MoveSpeed * 3 -- Видно всем благодаря ReplicationFocus!
            end
            
            if Settings.RotateMode then
                part.AngularVelocity = Vector3.new(0, Settings.RotateSpeed * 3, 0) -- Видно всем!
            end
        end
    end
end)

-- Клавиши
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E and Settings.SelectedPart then
        Settings.IsActive = not Settings.IsActive
        StatusLabel.Text = "Status: " .. (Settings.IsActive and "HOLDING" or "Selected")
        StatusLabel.TextColor3 = Settings.IsActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 100)
        print(Settings.IsActive and "✋ Holding part" or "👋 Released part")
        
    elseif input.KeyCode == Enum.KeyCode.Q and Settings.SelectedPart then
        local part = Settings.SelectedPart
        local mousePos = Mouse.Hit.Position
        local root = LocalPlayer.Character.HumanoidRootPart
        local direction = (mousePos - root.Position).Unit
        part.Velocity = direction * Settings.ThrowForce -- Бросок виден всем!
        part.CanCollide = true
        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
        Settings.SelectedPart = nil
        Settings.IsActive = false
        StatusLabel.Text = "Status: Thrown!"
        print("💨 Thrown part!")
        
    elseif input.KeyCode == Enum.KeyCode.R and Settings.SelectedPart then
        Settings.RotateMode = not Settings.RotateMode
        print(Settings.RotateMode and "🔄 Rotation ON" or "🔄 Rotation OFF")
        
    elseif input.KeyCode == Enum.KeyCode.X then
        if Settings.SelectedPart then
            Settings.SelectedPart.Velocity = Vector3.new(0, 0, 0)
            Settings.SelectedPart.AngularVelocity = Vector3.new(0, 0, 0)
        end
        Settings.SelectedPart = nil
        Settings.IsActive = false
        Settings.RotateMode = false
        PartName.Text = "Selected: None"
        StatusLabel.Text = "Status: Ready"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        print("❌ Deselected")
    end
end)

-- Подсветка
RunService.RenderStepped:Connect(function()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Highlight") and v.Parent ~= Settings.SelectedPart then
            if not table.find(ControlledParts, v.Parent) then
                v:Destroy()
            end
        end
    end
    
    if Settings.SelectedPart and Settings.SelectedPart.Parent then
        if not Settings.SelectedPart:FindFirstChildOfClass("Highlight") then
            local h = Instance.new("Highlight")
            h.FillColor = Color3.fromRGB(255, 200, 0)
            h.FillTransparency = 0.6
            h.OutlineColor = Color3.fromRGB(255, 150, 0)
            h.OutlineTransparency = 0
            h.Parent = Settings.SelectedPart
        end
    end
end)

print("✅ Part Manipulator Loaded (Visible to ALL Players)")
print("🔑 Using ReplicationFocus method")
print("🎯 Click part to select | E-Hold | Q-Throw | R-Rotate | X-Drop")
