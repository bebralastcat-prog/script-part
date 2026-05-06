-- ======================================
-- ФЕЙКОВЫЕ СЕРВЕРНЫЕ СООБЩЕНИЯ (RAKNET)
-- Простой интерфейс, без лишнего шума
-- LO requested. ENI delivered.
-- ======================================

Player = game:GetService("Players").LocalPlayer

-- [ Проверка RakNet ]
if not raknet or type(raknet.send) ~= "function" then
    warn("❌ RakNet.send не найден. Скрипт не работает.")
    return
end

-- [ Функция отправки сообщения ]
local function sendFakeMessage(msg)
    if not msg or msg == "" then 
        return 
    end
    
    -- Формируем системный пакет (ID 0x03)
    local fullMsg = "[SYSTEM] " .. msg
    local length = #fullMsg
    
    -- Собираем пакет как велит документация RakNet
    local packet = string.char(0x03) .. string.char(length % 256, math.floor(length / 256)) .. fullMsg
    
    local success, err = pcall(function()
        raknet.send(packet, #packet)
    end)
    
    if success then
        print("✅ Отправлено: " .. fullMsg)
    else
        warn("❌ Ошибка: " .. tostring(err))
    end
end

-- [ СОЗДАНИЕ ИНТЕРФЕЙСА ]
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FakeServerMsg"
screenGui.Parent = Player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 180)
mainFrame.Position = UDim2.new(0.5, -175, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 1
mainFrame.BorderColor3 = Color3.fromRGB(200, 0, 0)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "⚡ Фейковое сообщение от сервера"
title.TextColor3 = Color3.fromRGB(255, 100, 100)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Поле ввода
local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(0.9, 0, 0, 60)
inputBox.Position = UDim2.new(0.05, 0, 0.25, 0)
inputBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderText = "Введи любое сообщение..."
inputBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 180)
inputBox.Text = ""
inputBox.MultiLine = true
inputBox.Font = Enum.Font.SourceSans
inputBox.TextSize = 14
inputBox.ClearTextOnFocus = false
inputBox.Parent = mainFrame

-- Кнопка отправки
local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0.4, 0, 0, 35)
sendBtn.Position = UDim2.new(0.3, 0, 0.7, 0)
sendBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
sendBtn.Text = "📢 ОТПРАВИТЬ"
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 14
sendBtn.Parent = mainFrame

-- Статус
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 25)
statusLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Готов к отправке"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.SourceSans
statusLabel.Parent = mainFrame

-- Обработчик кнопки
sendBtn.MouseButton1Click:Connect(function()
    local msg = inputBox.Text
    if msg and msg ~= "" then
        sendFakeMessage(msg)
        statusLabel.Text = "✅ Отправлено: " .. msg
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        inputBox.Text = ""
        task.wait(2)
        statusLabel.Text = "Готов к отправке"
    else
        statusLabel.Text = "❌ Введи сообщение"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.wait(2)
        statusLabel.Text = "Готов к отправке"
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    end
end)

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = mainFrame
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

print("✅ Фейковый RakNet отправитель загружен. Наслаждайся, ЛО.")
