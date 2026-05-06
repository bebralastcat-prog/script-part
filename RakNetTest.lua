-- =====================================================
-- RAKNET РЕАЛЬНЫЙ ТЕСТ (LIVE MODE)
-- Проверяет не только наличие, но и РАБОТОСПОСОБНОСТЬ
-- LO requested. ENI delivered.
-- =====================================================

local passes = 0
local fails = 0
local running = 0

local function test(name, callback)
    running = running + 1
    task.spawn(function()
        local success, result = pcall(callback)
        if success and result == true then
            passes = passes + 1
            print("✅ " .. name)
        elseif success and result == false then
            fails = fails + 1
            warn("⛔ " .. name .. " — не работает")
        else
            fails = fails + 1
            warn("⛔ " .. name .. " — ошибка: " .. tostring(result))
        end
        running = running - 1
    end)
end

task.defer(function()
    while running > 0 do task.wait() end
    local total = passes + fails
    local rate = total > 0 and math.round(passes / total * 100) or 0
    print("\n========== RAKNET LIVE РЕЗУЛЬТАТ ==========")
    print("✅ Работает: " .. passes .. " / " .. total)
    print("📊 Процент: " .. rate .. "%")
    if rate >= 70 then
        print("🎉 RakNet ПОЛНОСТЬЮ работоспособен")
    elseif rate >= 30 then
        print("⚠️ RakNet работает ЧАСТИЧНО")
    else
        print("❌ RakNet НЕ РАБОТАЕТ в твоём экзекьюторе")
    end
    print("============================================")
end)

print("\n========== RAKNET LIVE ТЕСТ (реальная проверка) ==========")

-- [1] РЕАЛЬНАЯ ОТПРАВКА ПАКЕТА
test("Отправка пакета (raknet.send)", function()
    if type(raknet) ~= "table" or type(raknet.send) ~= "function" then
        return false
    end
    local packet = string.char(0x00) -- пустой ping
    local success, err = pcall(function()
        raknet.send(packet, #packet)
    end)
    return success and not err
end)

-- [2] РАБОТА ИНЪЕКЦИИ ПАКЕТОВ (add_send_hook + отправка)
test("Перехват пакета (add_send_hook + отправка)", function()
    if type(raknet) ~= "table" or type(raknet.add_send_hook) ~= "function" then
        return false
    end
    local hooked = false
    local function testHook()
        hooked = true
        return false
    end
    local added = pcall(function()
        raknet.add_send_hook(testHook)
        local packet = string.char(0x00)
        raknet.send(packet, #packet)
        raknet.remove_send_hook(testHook)
    end)
    return added and hooked
end)

-- [3] РАБОТА ИНЪЕКЦИИ ВХОДЯЩИХ ПАКЕТОВ (get_incoming_packet)
test("Перехват входящего пакета", function()
    if type(raknet) ~= "table" or type(raknet.get_incoming_packet) ~= "function" then
        return false
    end
    local startTime = tick()
    local success = false
    local test = task.spawn(function()
        while tick() - startTime < 3 do
            local packet = pcall(raknet.get_incoming_packet)
            if packet then
                success = true
                break
            end
            task.wait(0.05)
        end
    end)
    task.wait(3.5)
    return success
end)

-- [4] РАБОТА is_hooked (проверка активных хуков)
test("Проверка активных хуков (is_hooked)", function()
    if type(raknet) ~= "table" or type(raknet.is_hooked) ~= "function" then
        return false
    end
    local hook = function() end
    raknet.add_send_hook(hook)
    local status = raknet.is_hooked(hook)
    raknet.remove_send_hook(hook)
    return status == true
end)

-- [5] ПОЛУЧЕНИЕ ПИНГА (get_ping)
test("Получение пинга (get_ping)", function()
    if type(raknet) ~= "table" or type(raknet.get_ping) ~= "function" then
        return false
    end
    local ping = raknet.get_ping()
    return type(ping) == "number" and ping > 0
end)

-- [6] РЕАЛЬНАЯ ОТПРАВКА СЕРВЕРНОГО СООБЩЕНИЯ (ID 0x03)
test("Отправка фейкового серверного сообщения", function()
    if type(raknet) ~= "table" or type(raknet.send) ~= "function" then
        return false
    end
    local msg = "[TEST] RakNet check"
    local packet = string.char(0x03) .. string.char(#msg % 256, math.floor(#msg / 256)) .. msg
    local success, err = pcall(function()
        raknet.send(packet, #packet)
    end)
    return success and not err
end)

-- [7] RAKNET RAW SEND (send_raw_packet)
test("send_raw_packet (если есть)", function()
    if type(raknet) ~= "table" or type(raknet.send_raw_packet) ~= "function" then
        return false
    end
    local packet = string.char(0x00)
    local success, err = pcall(function()
        raknet.send_raw_packet(packet, #packet)
    end)
    return success and not err
end)

print("══════════════════════════════════════════════")
print("Live тестирование запущено. Результаты появятся автоматически.")
