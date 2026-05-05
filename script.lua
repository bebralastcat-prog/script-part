-- Ultimate Part Manipulator V6.9 FULL (All features restored + Visual Build Mode)
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
    VisualBuildMode = false,
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
    ForceGrabEnabled = false,   -- Выключен по умолчанию для стабильности
    ForceGrabDistance = 100,

    PlacedTornadoes = {},
    PlacedTornadoRadius = 30,
    PlacedTornadoStrength = 8,
    PlacedTornadoHeight = 20,
    PlacedTornadoSpeed = 8,
    TornadoPlacementMode = false,

    -- Визуальный билдинг
    GizmoActive = false,
    GizmoPart = nil,
    GizmoArrows = {},
    GizmoRings = {},
    GizmoDragging = false,
    GizmoAxis = nil,
    GizmoRotateMode = false,
    GizmoDragStart = nil,
    GizmoPartStart = nil,
}

local AllParts = {}
local NetworkOwnerWorks = true
local HighlightFolder = nil
local networkRefreshTimer = 0

-- Функции
local function RetainPart(part)
    if part:IsA("BasePart") and not part.Anchored then
        if part.Parent == LocalPlayer.Character or part:IsDescendantOf(LocalPlayer.Character) then return false end
        if Settings.UseNetworkOwner and NetworkOwnerWorks then
            local ok = pcall(function() part:SetNetworkOwner(LocalPlayer) end)
            if not ok then NetworkOwnerWorks = false end
        end
        part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.3, 0.5)
        part.CanCollide = true
        return true
    end
    return false
end

local function CollectAllParts()
    local c = 0
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored and not v:IsDescendantOf(LocalPlayer.Character) then
            if not table.find(AllParts, v) and RetainPart(v) then table.insert(AllParts, v); c = c + 1 end
        end
    end
    return c
end

local function GetUnanchoredPartsList()
    local list = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Anchored and not v:IsDescendantOf(LocalPlayer.Character) then table.insert(list, v) end
    end
    return list
end

local function UpdateHighlightAll()
    if HighlightFolder then HighlightFolder:Destroy(); HighlightFolder = nil end
    if Settings.HighlightAll then
        HighlightFolder = Instance.new("Folder"); HighlightFolder.Name = "H"; HighlightFolder.Parent = Workspace
        for _, p in pairs(GetUnanchoredPartsList()) do
            local h = Instance.new("Highlight"); h.FillColor = Settings.HighlightColor; h.FillTransparency = 0.7
            h.OutlineColor = Settings.HighlightColor; h.OutlineTransparency = 0; h.Adornee = p; h.Parent = HighlightFolder
        end
    end
end

local function CreateTornadoAnchor(pos)
    local a = Instance.new("Part"); a.Name = "TAnchor"; a.Size = Vector3.new(0.5,0.5,0.5)
    a.Anchored = true; a.CanCollide = false; a.Transparency = 0.7; a.Color = Color3.fromRGB(139,0,255)
    a.Material = Enum.Material.Neon; a.Position = pos; a.Parent = Workspace
    local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(139,0,255)
    l.Range = Settings.PlacedTornadoRadius; l.Brightness = 1.5; l.Parent = a
    return a
end

local function ClearAllTornadoes()
    for _, t in pairs(Settings.PlacedTornadoes) do if t.Anchor and t.Anchor.Parent then t.Anchor:Destroy() end end
    Settings.PlacedTornadoes = {}
end

local function FullDrop()
    for _, part in pairs(AllParts) do
        if part and part.Parent then
            part.Anchored = false; part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent then
            part.Anchored = false; part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    ClearAllTornadoes()
    AllParts = {}; Settings.SelectedParts = {}; Settings.AttachedParts = {}
    Settings.IsActive = false; Settings.TornadoMode = false; Settings.KillMode = false
    Settings.RotateMode = false; Settings.PreviewPart = nil; Settings.BuildingFling = false
    Settings.GizmoActive = false; Settings.GizmoPart = nil
    for _, a in pairs(Settings.GizmoArrows) do a:Destroy() end
    for _, r in pairs(Settings.GizmoRings) do r:Destroy() end
    Settings.GizmoArrows = {}; Settings.GizmoRings = {}
end

-- Визуальные гизмо
local function CreateGizmo(part)
    local arrows = {}
    local rings = {}
    local colors = {X = Color3.fromRGB(255,0,0), Y = Color3.fromRGB(0,255,0), Z = Color3.fromRGB(0,100,255)}
    for _, axis in pairs({"X","Y","Z"}) do
        local arrow = Instance.new("Part")
        arrow.Name = "GizmoArrow_"..axis
        arrow.Anchored = true; arrow.CanCollide = false; arrow.Transparency = 0.4
        arrow.Color = colors[axis]; arrow.Material = Enum.Material.Neon
        arrow.Size = (axis == "Y") and Vector3.new(0.15, 3, 0.15) or (axis == "X") and Vector3.new(3, 0.15, 0.15) or Vector3.new(0.15, 0.15, 3)
        arrow.Parent = Workspace
        arrows[axis] = arrow

        local ring = Instance.new("Part")
        ring.Name = "GizmoRing_"..axis
        ring.Anchored = true; ring.CanCollide = false; ring.Transparency = 0.4
        ring.Color = colors[axis]; ring.Material = Enum.Material.Neon
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = (axis == "Y") and Vector3.new(2, 0.1, 2) or (axis == "X") and Vector3.new(0.1, 2, 2) or Vector3.new(2, 2, 0.1)
        ring.Parent = Workspace
        ring.Visible = false
        rings[axis] = ring
    end
    Settings.GizmoArrows = arrows
    Settings.GizmoRings = rings
    Settings.GizmoPart = part
    Settings.GizmoActive = true
end

local function UpdateGizmoPosition()
    local part = Settings.GizmoPart
    if not part or not part.Parent then return end
    local cf = part.CFrame
    for axis, arrow in pairs(Settings.GizmoArrows) do
        if arrow and arrow.Parent then
            if axis == "X" then arrow.CFrame = cf * CFrame.new(1.5,0,0)
            elseif axis == "Y" then arrow.CFrame = cf * CFrame.new(0,1.5,0)
            else arrow.CFrame = cf * CFrame.new(0,0,1.5) end
        end
    end
    for axis, ring in pairs(Settings.GizmoRings) do
        if ring and ring.Parent then
            if axis == "X" then ring.CFrame = cf * CFrame.Angles(0,0,math.rad(90))
            elseif axis == "Y" then ring.CFrame = cf
            else ring.CFrame = cf * CFrame.Angles(math.rad(90),0,0) end
        end
    end
end

local function DestroyGizmo()
    for _, a in pairs(Settings.GizmoArrows) do if a and a.Parent then a:Destroy() end end
    for _, r in pairs(Settings.GizmoRings) do if r and r.Parent then r:Destroy() end end
    Settings.GizmoArrows = {}; Settings.GizmoRings = {}
    Settings.GizmoActive = false; Settings.GizmoPart = nil
end

-- ========== RAYFIELD UI ==========
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Part Manipulator V6.9 FULL",
    LoadingTitle = "Part Manipulator",
    LoadingSubtitle = "All features restored",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})
local MainTab = Window:CreateTab("Main", 4483362458)
local TornadoTab = Window:CreateTab("Tornado", 4483362458)
local VisualTab = Window:CreateTab("Visual", 4483362458)
local ListTab = Window:CreateTab("Parts List", 4483362458)

-- MASTER
MainTab:CreateSection("Master Control")
MainTab:CreateToggle({ Name = "🔴 MASTER TOGGLE", CurrentValue = true, Callback = function(v) Settings.MasterEnabled = v; if not v then FullDrop() end end })

-- SETTINGS
MainTab:CreateSection("Settings")
MainTab:CreateToggle({ Name = "Use Network Ownership", CurrentValue = true, Callback = function(v) Settings.UseNetworkOwner = v; NetworkOwnerWorks = v end })
MainTab:CreateToggle({ Name = "Selection Mode", CurrentValue = true, Callback = function(v) Settings.SelectionEnabled = v end })
MainTab:CreateToggle({ Name = "Force Grab (unstable)", CurrentValue = false, Callback = function(v) Settings.ForceGrabEnabled = v end })
MainTab:CreateSlider({ Name = "Network Refresh", Range = {0.1, 5.0}, Increment = 0.1, Suffix = "sec", CurrentValue = Settings.NetworkRefreshInterval, Callback = function(v) Settings.NetworkRefreshInterval = v end })
MainTab:CreateSlider({ Name = "Throw Force", Range = {100, 5000}, Increment = 100, Suffix = "Studs/s", CurrentValue = Settings.ThrowForce, Callback = function(v) Settings.ThrowForce = v end })
MainTab:CreateSlider({ Name = "Hold Distance", Range = {3, 30}, Increment = 1, Suffix = "Studs", CurrentValue = Settings.HoldDistance, Callback = function(v) Settings.HoldDistance = v end })
MainTab:CreateSlider({ Name = "Fling Spin Speed", Range = {100, 2000}, Increment = 50, Suffix = "rad/s", CurrentValue = Settings.FlingSpinSpeed, Callback = function(v) Settings.FlingSpinSpeed = v end })

-- ACTIONS
MainTab:CreateSection("Actions")
MainTab:CreateButton({ Name = "Collect All Parts", Callback = function() Rayfield:Notify({ Title = "Collected", Content = "Собрано " .. CollectAllParts() .. " частей", Duration = 2 }) end })
MainTab:CreateButton({ Name = "Drop All Parts", Callback = function() FullDrop() end })
MainTab:CreateToggle({ Name = "Hold Parts [E]", CurrentValue = false, Callback = function(v) Settings.IsActive = v; if v then Settings.TornadoMode = false end end })
MainTab:CreateToggle({ Name = "Rotate Parts [R]", CurrentValue = false, Callback = function(v) Settings.RotateMode = v end })
MainTab:CreateButton({ Name = "Throw Parts [Q]", Callback = function()
    if #Settings.SelectedParts == 0 then return end
    local mousePos = Mouse.Hit.Position
    for _, part in pairs(Settings.SelectedParts) do
        if part and part.Parent then part.CanCollide = true; part.Velocity = (mousePos - part.Position).Unit * Settings.ThrowForce end
    end
    Settings.SelectedParts = {}; Settings.IsActive = false; Settings.RotateMode = false
end })
MainTab:CreateToggle({ Name = "Tornado Mode [T]", CurrentValue = false, Callback = function(v) Settings.TornadoMode = v; if v and #AllParts == 0 then CollectAllParts() end end })
MainTab:CreateToggle({ Name = "Fling Mode [F]", CurrentValue = false, Callback = function(v) Settings.KillMode = v end })

-- ATTACHMENT + VISUAL BUILD
MainTab:CreateSection("Building")
MainTab:CreateToggle({ Name = "Attachment Mode (Keyboard)", CurrentValue = false, Callback = function(v) Settings.AttachmentMode = v; Settings.PreviewPart = nil; if v then Settings.VisualBuildMode = false; DestroyGizmo() end end })
MainTab:CreateToggle({ Name = "Visual Build Mode (Mouse drag)", CurrentValue = false, Callback = function(v)
    Settings.VisualBuildMode = v
    Settings.PreviewPart = nil
    if v then
        Settings.AttachmentMode = false
        Rayfield:Notify({ Title = "Visual Build", Content = "Click part to select, drag arrows to move, Tab to rotate", Duration = 4 })
    else
        DestroyGizmo()
    end
end })
MainTab:CreateSlider({ Name = "Step / Grid", Range = {0.5, 10}, Increment = 0.5, Suffix = "Studs", CurrentValue = Settings.AttachmentStep, Callback = function(v) Settings.AttachmentStep = v end })
MainTab:CreateToggle({ Name = "Building Fling", CurrentValue = false, Callback = function(v)
    Settings.BuildingFling = v
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent then
            if v then part.Anchored = false; item.FlingEnabled = true; item.SpinSpeed = Settings.FlingSpinSpeed
            else part.AssemblyAngularVelocity = Vector3.zero; part.Anchored = true; part.Velocity = Vector3.zero; item.FlingEnabled = false end
        end
    end
end })
MainTab:CreateButton({ Name = "Unattach All", Callback = function()
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent then
            part.Anchored = false; part.CanCollide = true
            part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 0.5, 0.5)
            part.Velocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    Settings.AttachedParts = {}; Settings.BuildingFling = false
end })

-- TORNADO TAB
TornadoTab:CreateSection("Placed Tornadoes")
TornadoTab:CreateToggle({ Name = "Placement Mode", CurrentValue = false, Callback = function(v) Settings.TornadoPlacementMode = v end })
TornadoTab:CreateSlider({ Name = "Radius", Range = {10, 200}, Increment = 5, CurrentValue = Settings.PlacedTornadoRadius, Callback = function(v) Settings.PlacedTornadoRadius = v end })
TornadoTab:CreateSlider({ Name = "Strength", Range = {1, 30}, Increment = 1, CurrentValue = Settings.PlacedTornadoStrength, Callback = function(v) Settings.PlacedTornadoStrength = v end })
TornadoTab:CreateSlider({ Name = "Height", Range = {5, 80}, Increment = 5, CurrentValue = Settings.PlacedTornadoHeight, Callback = function(v) Settings.PlacedTornadoHeight = v end })
TornadoTab:CreateSlider({ Name = "Speed", Range = {1, 20}, Increment = 1, CurrentValue = Settings.PlacedTornadoSpeed, Callback = function(v) Settings.PlacedTornadoSpeed = v end })
TornadoTab:CreateButton({ Name = "Clear All", Callback = ClearAllTornadoes })

-- VISUAL TAB
VisualTab:CreateSection("Highlights")
VisualTab:CreateToggle({ Name = "Highlight All Unanchored", CurrentValue = false, Callback = function(v) Settings.HighlightAll = v; UpdateHighlightAll() end })
VisualTab:CreateButton({ Name = "Refresh", Callback = UpdateHighlightAll })

-- PARTS LIST TAB
local partsListLabel = ListTab:CreateParagraph({ Title = "Count", Content = "Loading..." })
local function RefreshPartsList()
    local parts = GetUnanchoredPartsList()
    local text = ""; for i, part in ipairs(parts) do if i <= 50 then local dist = "?"; local char = LocalPlayer.Character; if char and char:FindFirstChild("HumanoidRootPart") then dist = math.floor((char.HumanoidRootPart.Position - part.Position).Magnitude) end; text = text .. string.format("[%d] %s | %d studs\n", i, part.Name, dist) end end
    if #parts > 50 then text = text .. "... и ещё " .. (#parts - 50) .. " частей" end
    partsListLabel:SetTitle("Count: " .. #parts); partsListLabel:SetContent(text)
end
ListTab:CreateButton({ Name = "Refresh Parts List", Callback = RefreshPartsList })
ListTab:CreateSection("Teleport to Part")
local teleportInput = ListTab:CreateInput({ Name = "Part Name", PlaceholderText = "Enter part name", RemoveTextAfterFocusLost = false, Callback = function() end })
ListTab:CreateButton({ Name = "Teleport", Callback = function()
    local name = teleportInput.CurrentValue
    if not name or name == "" then return end
    for _, part in pairs(GetUnanchoredPartsList()) do
        if part.Name:lower():find(name:lower()) then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0,3,0)
                Rayfield:Notify({ Title = "Teleported", Content = part.Name, Duration = 2 })
                return
            end
        end
    end
    Rayfield:Notify({ Title = "Not found", Content = "Part not found", Duration = 2 })
end })
RefreshPartsList()

-- ========== ОБРАБОТЧИК КЛИКОВ ==========
Mouse.Button1Down:Connect(function()
    if not Settings.MasterEnabled or not Settings.SelectionEnabled then return end

    if Settings.TornadoPlacementMode then
        local pos = Mouse.Hit.Position; if not pos then return end
        table.insert(Settings.PlacedTornadoes, { Anchor = CreateTornadoAnchor(pos), Radius = Settings.PlacedTornadoRadius, Strength = Settings.PlacedTornadoStrength, Height = Settings.PlacedTornadoHeight, Speed = Settings.PlacedTornadoSpeed })
        return
    end

    -- Визуальный билдинг: клик по стрелке или части
    if Settings.VisualBuildMode then
        local target = Mouse.Target
        -- Если кликнули по стрелке гизмо
        for axis, arrow in pairs(Settings.GizmoArrows) do
            if target == arrow then
                Settings.GizmoDragging = true
                Settings.GizmoAxis = axis
                Settings.GizmoDragStart = Mouse.Hit.Position
                Settings.GizmoPartStart = Settings.GizmoPart.CFrame
                return
            end
        end
        for axis, ring in pairs(Settings.GizmoRings) do
            if target == ring and ring.Visible then
                Settings.GizmoDragging = true
                Settings.GizmoAxis = axis
                Settings.GizmoDragStart = Mouse.Hit.Position
                Settings.GizmoPartStart = Settings.GizmoPart.CFrame
                return
            end
        end
        -- Иначе клик по новой части для захвата
        if target and target:IsA("BasePart") and not target.Anchored and not target:IsDescendantOf(LocalPlayer.Character) then
            if RetainPart(target) then
                Settings.PreviewPart = target; target.CanCollide = false
                Settings.PreviewPosition = target.Position
                DestroyGizmo(); CreateGizmo(target)
                if not table.find(AllParts, target) then table.insert(AllParts, target) end
                Rayfield:Notify({ Title = "Visual Build", Content = "Drag arrows to move, Tab to rotate", Duration = 2 })
            end
        end
        return
    end

    -- Обычный выбор
    local target = Mouse.Target
    if not (target and target:IsA("BasePart") and not target.Anchored) then return end
    if target:IsDescendantOf(LocalPlayer.Character) then return end

    local isMulti = UserInputService:IsKeyDown(Settings.MultiSelectKey)

    if Settings.AttachmentMode then
        if RetainPart(target) then
            Settings.PreviewPart = target; target.CanCollide = false
            Settings.PreviewPosition = target.Position
            if not table.find(AllParts, target) then table.insert(AllParts, target) end
        end
        return
    end

    if RetainPart(target) then
        if isMulti then
            if not table.find(Settings.SelectedParts, target) and #Settings.SelectedParts < 100 then
                table.insert(Settings.SelectedParts, target); if not table.find(AllParts, target) then table.insert(AllParts, target) end
            end
        else
            Settings.SelectedParts = {target}; if not table.find(AllParts, target) then table.insert(AllParts, target) end
        end
    end
end)

-- Обработка отпускания мыши для гизмо
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and Settings.GizmoDragging then
        Settings.GizmoDragging = false
        Settings.GizmoAxis = nil
    end
end)

-- ========== ГЛАВНЫЙ ЦИКЛ ==========
RunService.Heartbeat:Connect(function(delta)
    if not Settings.MasterEnabled then return end

    -- Периодическое обновление владения
    if Settings.UseNetworkOwner and NetworkOwnerWorks then
        networkRefreshTimer = networkRefreshTimer + delta
        if networkRefreshTimer >= Settings.NetworkRefreshInterval then
            networkRefreshTimer = 0
            for _, part in pairs(AllParts) do pcall(function() part:SetNetworkOwner(LocalPlayer) end) end
        end
    end

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Торнадо вокруг игрока
    if Settings.TornadoMode and root then
        local angle = tick() * Settings.TornadoSpeed
        for i, part in pairs(AllParts) do
            if part and part.Parent and not part.Anchored then
                local offset = i * 2.4
                local targetPos = root.Position + Vector3.new(math.cos(angle+offset)*Settings.TornadoRadius, math.sin(tick()*2+offset)*Settings.TornadoHeight, math.sin(angle+offset)*Settings.TornadoRadius)
                part.Velocity = (targetPos - part.Position) * 5
                if Settings.KillMode then part.AssemblyAngularVelocity = Vector3.new(math.random(-Settings.FlingSpinSpeed,Settings.FlingSpinSpeed), math.random(-Settings.FlingSpinSpeed,Settings.FlingSpinSpeed), math.random(-Settings.FlingSpinSpeed,Settings.FlingSpinSpeed)) end
            end
        end
    end

    -- Стационарные торнадо
    for _, tornado in pairs(Settings.PlacedTornadoes) do
        if tornado.Anchor and tornado.Anchor.Parent then
            local center = tornado.Anchor.Position; local angle = tick() * tornado.Speed
            for _, part in pairs(GetUnanchoredPartsList()) do
                if part and part.Parent and not part.Anchored then
                    local dist = (part.Position - center).Magnitude
                    if dist < tornado.Radius then
                        local offset = math.atan2(part.Position.Z - center.Z, part.Position.X - center.X)
                        local targetPos = center + Vector3.new(math.cos(angle+offset)*math.min(dist, tornado.Radius*0.8), math.sin(tick()*2+offset)*tornado.Height*0.5, math.sin(angle+offset)*math.min(dist, tornado.Radius*0.8))
                        part.Velocity = (targetPos - part.Position) * tornado.Strength; part.AssemblyAngularVelocity = Vector3.new(0, tornado.Speed, 0)
                    end
                end
            end
        end
    end

    -- Hold Parts
    if Settings.IsActive and #Settings.SelectedParts > 0 and root then
        local mousePos = Mouse.Hit.Position
        for _, part in pairs(Settings.SelectedParts) do
            if part and part.Parent then part.Velocity = ((root.Position + (mousePos - root.Position).Unit * Settings.HoldDistance + Vector3.new(0,3,0)) - part.Position) * 10 end
        end
    end

    -- Rotate Parts
    if Settings.RotateMode and #Settings.SelectedParts > 0 then
        for _, part in pairs(Settings.SelectedParts) do if part and part.Parent then part.AssemblyAngularVelocity = Vector3.new(0, Settings.RotateSpeed, 0) end end
    end

    -- Attachment Preview (клавиши)
    if Settings.AttachmentMode and Settings.PreviewPart and Settings.PreviewPart.Parent then
        Settings.PreviewPart.Velocity = (Settings.PreviewPosition - Settings.PreviewPart.Position) * 15
    end

    -- Визуальный билдинг: обновление позиций гизмо и перетаскивание
    if Settings.VisualBuildMode and Settings.GizmoPart then
        UpdateGizmoPosition()
        if Settings.GizmoDragging and Settings.GizmoAxis then
            local mousePos = Mouse.Hit.Position
            local delta = mousePos - Settings.GizmoDragStart
            local step = Settings.AttachmentStep
            if Settings.GizmoRotateMode then
                -- Поворот вокруг оси
                local angle = delta.Magnitude * 0.01
                local axisVector = Settings.GizmoAxis == "X" and Vector3.new(1,0,0) or Settings.GizmoAxis == "Y" and Vector3.new(0,1,0) or Vector3.new(0,0,1)
                Settings.GizmoPart.CFrame = Settings.GizmoPartStart * CFrame.fromAxisAngle(axisVector, angle)
            else
                -- Перемещение вдоль оси
                local move = Vector3.zero
                if Settings.GizmoAxis == "X" then move = Vector3.new(delta.X,0,0)
                elseif Settings.GizmoAxis == "Y" then move = Vector3.new(0,delta.Y,0)
                else move = Vector3.new(0,0,delta.Z) end
                -- Привязка к сетке
                move = Vector3.new(math.floor(move.X/step + 0.5)*step, math.floor(move.Y/step + 0.5)*step, math.floor(move.Z/step + 0.5)*step)
                Settings.GizmoPart.CFrame = Settings.GizmoPartStart + move
            end
            Settings.PreviewPosition = Settings.GizmoPart.Position
        end
        -- Подсветка колец
        local showRings = Settings.GizmoRotateMode
        for _, arrow in pairs(Settings.GizmoArrows) do arrow.Visible = not showRings end
        for _, ring in pairs(Settings.GizmoRings) do ring.Visible = showRings end
    end

    -- Building Fling
    for _, item in pairs(Settings.AttachedParts) do
        local part = item.Part
        if part and part.Parent and item.FlingEnabled and Settings.BuildingFling then
            if part.Anchored then part.Anchored = false end
            part.Velocity = ((item.TargetPos or part.Position) - part.Position) * 20
            part.AssemblyAngularVelocity = Vector3.new(math.random(-item.SpinSpeed,item.SpinSpeed), math.random(-item.SpinSpeed,item.SpinSpeed), math.random(-item.SpinSpeed,item.SpinSpeed))
        end
    end
end)

-- ========== КЛАВИАТУРА ==========
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not Settings.MasterEnabled then return end
    local key = input.KeyCode

    -- Визуальный билдинг: Enter фиксирует, Tab переключает режим
    if Settings.VisualBuildMode and Settings.GizmoPart then
        if key == Enum.KeyCode.Tab then
            Settings.GizmoRotateMode = not Settings.GizmoRotateMode
            return
        elseif key == Enum.KeyCode.Return then
            local part = Settings.GizmoPart
            part.Anchored = true; part.CanCollide = true; part.Velocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero
            table.insert(Settings.AttachedParts, { Part = part, TargetPos = part.Position, FlingEnabled = false, SpinSpeed = Settings.FlingSpinSpeed })
            DestroyGizmo()
            Settings.PreviewPart = nil
            Rayfield:Notify({ Title = "Attached", Content = "Part fixed!", Duration = 2 })
            return
        elseif key == Enum.KeyCode.Backspace then
            if Settings.GizmoPart then Settings.GizmoPart.CanCollide = true end
            DestroyGizmo()
            Settings.PreviewPart = nil
            return
        end
    end

    -- Обычный режим закрепления (клавиши)
    if Settings.AttachmentMode and Settings.PreviewPart then
        local step = Settings.AttachmentStep
        if key == Enum.KeyCode.E then Settings.PreviewPosition += Vector3.new(0, step, 0)
        elseif key == Enum.KeyCode.Q then Settings.PreviewPosition += Vector3.new(0, -step, 0)
        elseif key == Enum.KeyCode.X then Settings.PreviewPosition += Vector3.new(step, 0, 0)
        elseif key == Enum.KeyCode.Z then Settings.PreviewPosition += Vector3.new(-step, 0, 0)
        elseif key == Enum.KeyCode.Return then
            local part = Settings.PreviewPart; part.Anchored = true; part.CanCollide = true; part.Velocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero
            table.insert(Settings.AttachedParts, { Part = part, TargetPos = Settings.PreviewPosition, FlingEnabled = false, SpinSpeed = Settings.FlingSpinSpeed })
            Settings.PreviewPart = nil; Settings.PreviewPosition = nil
        elseif key == Enum.KeyCode.Backspace then
            if Settings.PreviewPart then Settings.PreviewPart.CanCollide = true end
            Settings.PreviewPart = nil; Settings.PreviewPosition = nil
        end
        return
    end

    -- Стандартные клавиши
    if key == Enum.KeyCode.E then if #Settings.SelectedParts > 0 then Settings.IsActive = not Settings.IsActive end
    elseif key == Enum.KeyCode.Q then
        if #Settings.SelectedParts > 0 then
            local mousePos = Mouse.Hit.Position
            for _, part in pairs(Settings.SelectedParts) do if part and part.Parent then part.CanCollide = true; part.Velocity = (mousePos - part.Position).Unit * Settings.ThrowForce end end
            Settings.SelectedParts = {}; Settings.IsActive = false; Settings.RotateMode = false
        end
    elseif key == Enum.KeyCode.R then if #Settings.SelectedParts > 0 then Settings.RotateMode = not Settings.RotateMode end
    elseif key == Enum.KeyCode.T then Settings.TornadoMode = not Settings.TornadoMode; if Settings.TornadoMode and #AllParts == 0 then CollectAllParts() end
    elseif key == Enum.KeyCode.F then Settings.KillMode = not Settings.KillMode
    end
end)

-- Подсветка
RunService.RenderStepped:Connect(function()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Highlight") and v.Parent ~= HighlightFolder then
            local parent = v.Parent
            local keep = (parent == Settings.PreviewPart or parent == Settings.GizmoPart)
            for _, p in pairs(Settings.SelectedParts) do if p == parent then keep = true break end end
            for _, item in pairs(Settings.AttachedParts) do if item.Part == parent then keep = true break end end
            if not keep then v:Destroy() end
        end
    end
    if Settings.PreviewPart and not Settings.PreviewPart:FindFirstChildOfClass("Highlight") then
        local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(0, 255, 255); h.FillTransparency = 0.5; h.Parent = Settings.PreviewPart
    end
    if Settings.GizmoPart and not Settings.GizmoPart:FindFirstChildOfClass("Highlight") then
        local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(0, 255, 255); h.FillTransparency = 0.5; h.Parent = Settings.GizmoPart
    end
    for _, part in pairs(Settings.SelectedParts) do
        if part and part.Parent and not part:FindFirstChildOfClass("Highlight") then
            local h = Instance.new("Highlight"); h.FillColor = Color3.fromRGB(255, 200, 0); h.FillTransparency = 0.5; h.Parent = part
        end
    end
end)

print("Part Manipulator V6.9 FULL loaded – All features restored, Visual Build ready.")
