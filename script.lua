-- Ultimate Part Manipulator V6.7 (Placeable Tornadoes)
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
    MasterEnabled = true,
    SelectedParts = {},
    IsActive = false,
    HoldDistance = 10,
    ThrowForce = 500,
    RotateSpeed = 8,
    TornadoSpeed = 8,
    TornadoHeight = 20,
    TornadoRadius = 30,
    RotateMode = false,
    TornadoMode = false,
    KillMode = false,
    FlingSpinSpeed = 500,

    AttachmentMode = false,
    VisualAttachmentMode = false,
    PreviewPart = nil,
    PreviewPosition = nil,
    AttachmentStep = 2,
    AttachedParts = {},

    UseNetworkOwner = true,
    HighlightAll = false,
    HighlightColor = Color3.fromRGB(0, 255, 100),
    BuildingFling = false,
    SelectionEnabled = true,
    MultiSelectKey = Enum.KeyCode.LeftControl,

    NetworkRefreshInterval = 1.0,
    ForceGrabEnabled = true,
    ForceGrabDistance = 100,

    PlacedTornadoes = {},
    PlacedTornadoRadius = 30,
    PlacedTornadoStrength = 8,
    PlacedTornadoHeight = 20,
    PlacedTornadoSpeed = 8,
    TornadoPlacementMode = false,
}

local AllParts = {}
local NetworkOwnerFailed = false
local NetworkOwnerTested = false
local HighlightFolder = nil
local networkRefreshTimer = 0

local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then
            return false
        end
        if Settings.UseNetworkOwner and not NetworkOwnerFailed then
            local success, err = pcall(function()
                part:SetNetworkOwner(LocalPlayer)
            end)
            if not success then
                NetworkOwnerFailed = true
            else
                NetworkOwnerTested = true
            end
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

local function CreateTornadoAnchor(position)
    local anchor = Instance.new("Part")
    anchor.Name = "TornadoAnchor"
    anchor.Size = Vector3.new(0.5, 0.5, 0.5)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 0.7
    anchor.Color = Color3.fromRGB(139, 0, 255)
    anchor.Material = Enum.Material.Neon
    anchor.Position = position
    anchor.Parent = Workspace
    
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(139, 0, 255)
    glow.Range = Settings.PlacedTornadoRadius
    glow.Brightness = 1.5
    glow.Parent = anchor
    
    return anchor
end

local function ClearAllTornadoes()
    for _, tornado in pairs(Settings.PlacedTornadoes) do
        if tornado.Anchor and tornado.Anchor.Parent then
            tornado.Anchor:Destroy()
        end
    end
    Settings.PlacedTornadoes = {}
end

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
    ClearAllTornadoes()
    AllParts = {}
    Settings.SelectedParts = {}
    Settings.AttachedParts = {}
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
    Name = "Part Manipulator V6.7",
    LoadingTitle = "Part Manipulator",
    LoadingSubtitle = "by DeepSeek AI",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local TornadoTab = Window:CreateTab("Tornado", 4483362458)
local VisualTab = Window:CreateTab("Visual", 4483362458)
local ListTab = Window:CreateTab("Parts List", 4483362458)

-- ===== MASTER CONTROL =====
MainTab:CreateSection("Master Control")
MainTab:CreateToggle({
    Name = "🔴 MASTER TOGGLE",
    CurrentValue = true,
    Flag = "MasterEnabled",
    Callback = function(Value)
        Settings.MasterEnabled = Value
        if not Value then FullDrop() end
    end,
})

-- ===== SETTINGS =====
local SettingsSection = MainTab:CreateSection("Settings")
MainTab:CreateToggle({
    Name = "Use Network Ownership",
    CurrentValue = true,
    Flag = "UseNetworkOwner",
    Callback = function(Value) Settings.UseNetworkOwner = Value end,
})
MainTab:CreateToggle({
    Name = "Selection Mode",
    CurrentValue = true,
    Flag = "SelectionEnabled",
    Callback = function(Value) Settings.SelectionEnabled = Value end,
})
MainTab:CreateSlider({
    Name = "Throw Force",
    Range = {100, 5000}, Increment = 100, Suffix = "Studs/s",
    CurrentValue = Settings.ThrowForce,
    Callback = function(Value) Settings.ThrowForce = Value end,
})
MainTab:CreateSlider({
    Name = "Hold Distance",
    Range = {3, 30}, Increment = 1, Suffix = "Studs",
    CurrentValue = Settings.HoldDistance,
    Callback = function(Value) Settings.HoldDistance = Value end,
})
MainTab:CreateSlider({
    Name = "Fling Spin Speed",
    Range = {100, 2000}, Increment = 50, Suffix = "rad/s",
    CurrentValue = Settings.FlingSpinSpeed,
    Callback = function(Value) Settings.FlingSpinSpeed = Value end,
})

-- ===== ACTIONS =====
MainTab:CreateSection("Actions")
MainTab:CreateButton({
    Name = "Collect All Parts",
    Callback = function()
        local count = CollectAllParts()
        Rayfield:Notify({ Title = "Collected", Content = "Собрано " .. count .. " частей", Duration = 2 })
    end,
})
MainTab:CreateButton({
    Name = "Drop All Parts",
    Callback = function()
        FullDrop()
        Rayfield:Notify({ Title = "Dropped", Content = "Все сброшены", Duration = 2 })
    end,
})
MainTab:CreateToggle({
    Name = "Hold Parts",
    CurrentValue = false,
    Callback = function(Value)
        Settings.IsActive = Value
        if Value then Settings.TornadoMode = false end
    end,
})
MainTab:CreateToggle({
    Name = "Rotate Parts",
    CurrentValue = false,
    Callback = function(Value) Settings.RotateMode = Value end,
})
MainTab:CreateButton({
    Name = "Throw Parts",
    Callback = function()
        if #Settings.SelectedParts == 0 then return end
        local mousePos = Mouse.Hit.Position
        for _, part in pairs(Settings.SelectedParts) do
            if part and part.Parent then
                part.CanCollide = true
                part.Velocity = (mousePos - part.Position).Unit * Settings.ThrowForce
            end
        end
        Settings.SelectedParts = {}
        Settings.IsActive = false
    end,
})
MainTab:CreateToggle({
    Name = "Tornado Mode (Around Player)",
    CurrentValue = false,
    Callback = function(Value)
        Settings.TornadoMode = Value
        Settings.IsActive = false
        if Value and #AllParts == 0 then CollectAllParts() end
    end,
})
MainTab:CreateToggle({
    Name = "Fling Mode",
    CurrentValue = false,
    Callback = function(Value) Settings.KillMode = Value end,
})

-- ===== TORNADO TAB =====
TornadoTab:CreateSection("Placed Tornadoes")
TornadoTab:CreateToggle({
    Name = "Placement Mode (Click to place)",
    CurrentValue = false,
    Callback = function(Value)
        Settings.TornadoPlacementMode = Value
        if Value then
            Rayfield:Notify({ Title = "Tornado", Content = "Кликните мышкой по месту, где создать торнадо", Duration = 4 })
        end
    end,
})
TornadoTab:CreateSlider({
    Name = "Tornado Radius",
    Range = {10, 200}, Increment = 5, Suffix = "Studs",
    CurrentValue = Settings.PlacedTornadoRadius,
    Callback = function(Value) Settings.PlacedTornadoRadius = Value end,
})
TornadoTab:CreateSlider({
    Name = "Tornado Strength",
    Range = {1, 30}, Increment = 1, Suffix = "x",
    CurrentValue = Settings.PlacedTornadoStrength,
    Callback = function(Value) Settings.PlacedTornadoStrength = Value end,
})
TornadoTab:CreateSlider({
    Name = "Tornado Height",
    Range = {5, 80}, Increment = 5, Suffix = "Studs",
    CurrentValue = Settings.PlacedTornadoHeight,
    Callback = function(Value) Settings.PlacedTornadoHeight = Value end,
})
TornadoTab:CreateSlider({
    Name = "Tornado Speed",
    Range = {1, 20}, Increment = 1, Suffix = "rad/s",
    CurrentValue = Settings.PlacedTornadoSpeed,
    Callback = function(Value) Settings.PlacedTornadoSpeed = Value end,
})
TornadoTab:CreateButton({
    Name = "Clear All Tornadoes",
    Callback = function()
        ClearAllTornadoes()
        Rayfield:Notify({ Title = "Tornadoes", Content = "Все стационарные торнадо удалены", Duration = 2 })
    end,
})

-- ===== VISUAL TAB =====
VisualTab:CreateSection("Highlight Unanchored Parts")
VisualTab:CreateToggle({
    Name = "Highlight All Unanchored",
    CurrentValue = false,
    Callback = function(Value)
        Settings.HighlightAll = Value
        UpdateHighlightAll()
    end,
})
VisualTab:CreateButton({
    Name = "Refresh Highlights",
    Callback = function()
        UpdateHighlightAll()
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
    Callback = function() RefreshPartsList() end,
})

local TeleportInput = ListTab:CreateInput({
    Name = "Part Name",
    PlaceholderText = "Введите имя части",
    RemoveTextAfterFocusLost = false,
    Callback = function() end,
})
ListTab:CreateButton({
    Name = "Teleport to Part",
    Callback = function()
        local name = TeleportInput.CurrentValue
        if not name or name == "" then return end
        for _, part in pairs(GetUnanchoredPartsList()) do
            if part.Name:lower():find(name:lower()) then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                    return
                end
            end
        end
    end,
})

-- ===== ОБРАБОТКА КЛИКОВ =====
Mouse.Button1Down:Connect(function()
    if not Settings.MasterEnabled then return end
    
    if Settings.TornadoPlacementMode then
        local pos = Mouse.Hit.Position
        if pos then
            local anchor = CreateTornadoAnchor(pos)
            table.insert(Settings.PlacedTornadoes, {
                Anchor = anchor,
                Radius = Settings.PlacedTornadoRadius,
                Strength = Settings.PlacedTornadoStrength,
                Height = Settings.PlacedTornadoHeight,
                Speed = Settings.PlacedTornadoSpeed,
            })
            Rayfield:Notify({ Title = "Tornado", Content = "Торнадо создано!", Duration = 2 })
        end
        return
    end
    
    if not Settings.SelectionEnabled then return end
    
    local target = Mouse.Target
    if not (target and target:IsA("BasePart") and not target.Anchored) then return end
    local char = LocalPlayer.Character
    if not char or target:IsDescendantOf(char) then return end
    
    local isMultiSelect = UserInputService:IsKeyDown(Settings.MultiSelectKey)
    
    if Settings.ForceGrabEnabled and Settings.UseNetworkOwner and not NetworkOwnerFailed then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (target.Position - root.Position).Magnitude
            if dist > Settings.ForceGrabDistance then
                local origCFrame = target.CFrame
                target.CFrame = CFrame.new(root.Position + Vector3.new(0, -50, 0))
                RunService.Heartbeat:Wait()
                target.CFrame = origCFrame
            end
        end
    end
    
    if RetainPart(target) then
        if isMultiSelect then
            local found = false
            for _, p in pairs(Settings.SelectedParts) do
                if p == target then found = true break end
            end
            if not found and #Settings.SelectedParts < 100 then
                table.insert(Settings.SelectedParts, target)
                table.insert(AllParts, target)
            end
        else
            Settings.SelectedParts = {target}
            if not table.find(AllParts, target) then
                table.insert(AllParts, target)
            end
        end
    end
end)

-- ===== ГЛАВНЫЙ ЦИКЛ =====
RunService.Heartbeat:Connect(function(deltaTime)
    if not Settings.MasterEnabled then return end
    
    if Settings.UseNetworkOwner and not NetworkOwnerFailed then
        networkRefreshTimer = networkRefreshTimer + deltaTime
        if networkRefreshTimer >= Settings.NetworkRefreshInterval then
            networkRefreshTimer = 0
            for _, part in pairs(AllParts) do
                if part and part.Parent then
                    pcall(function() part:SetNetworkOwner(LocalPlayer) end)
                end
            end
        end
    end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    -- Обычное торнадо (вокруг игрока)
    if Settings.TornadoMode and root then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent and not part.Anchored then
                local offset = i * 2.4
                local x = math.cos(angle + offset) * Settings.TornadoRadius
                local z = math.sin(angle + offset) * Settings.TornadoRadius
                local y = math.sin(tick() * 2 + offset) * Settings.TornadoHeight
                part.Velocity = (root.Position + Vector3.new(x, y, z) - part.Position) * 5
                if Settings.KillMode then
                    part.AssemblyAngularVelocity = Vector3.new(math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed), math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed), math.random(-Settings.FlingSpinSpeed, Settings.FlingSpinSpeed))
                end
            end
        end
    end
    
    -- Стационарные торнадо
    for _, tornado in pairs(Settings.PlacedTornadoes) do
        if tornado.Anchor and tornado.Anchor.Parent then
            local center = tornado.Anchor.Position
            local angle = tick() * tornado.Speed
            for _, part in pairs(GetUnanchoredPartsList()) do
                if part and part.Parent and not part.Anchored then
                    local dist = (part.Position - center).Magnitude
                    if dist < tornado.Radius then
                        local offset = math.atan2(part.Position.Z - center.Z, part.Position.X - center.X)
                        local orbitX = math.cos(angle + offset) * math.min(dist, tornado.Radius * 0.8)
                        local orbitZ = math.sin(angle + offset) * math.min(dist, tornado.Radius * 0.8)
                        local orbitY = math.sin(tick() * 2 + offset) * tornado.Height * 0.5
                        part.Velocity = (center + Vector3.new(orbitX, orbitY, orbitZ) - part.Position) * tornado.Strength
                        part.AssemblyAngularVelocity = Vector3.new(0, tornado.Speed, 0)
                    end
                end
            end
        end
    end
    
    -- Удержание
    if Settings.IsActive and #Settings.SelectedParts > 0 and root then
        local mousePos = Mouse.Hit.Position
        for _, part in pairs(Settings.SelectedParts) do
            if part and part.Parent then
                local targetPos = root.Position + (mousePos - root.Position).Unit * Settings.HoldDistance + Vector3.new(0, 3, 0)
                part.Velocity = (targetPos - part.Position) * 10
            end
        end
    end
    
    -- Вращение
    if Settings.RotateMode and #Settings.SelectedParts > 0 then
        for _, part in pairs(Settings.SelectedParts) do
            if part and part.Parent then
                part.AssemblyAngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0)
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
                local isSelected = false
                for _, p in pairs(Settings.SelectedParts) do
                    if p == parent then isSelected = true break end
                end
                if not isSelected then
                    local isAttached = false
                    for _, item in pairs(Settings.AttachedParts) do
                        if item.Part == parent then isAttached = true break end
                    end
                    if not isAttached then v:Destroy() end
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
    
    for _, part in pairs(Settings.SelectedParts) do
        addHighlight(part, Color3.fromRGB(255, 200, 0))
    end
end)

RefreshPartsList()

print("Part Manipulator V6.7 loaded – Placed Tornadoes! Click where you want the vortex.")
