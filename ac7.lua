local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local thread = require("thread")
local computer = require("computer")

-- Конфигурация системы
local STORAGE_CONFIG = {
    primaryStorage = "/home/",
    maxMemoryItems = 4000,
    maxCraftables = 2000,
    chunkSize = 50
}

if not component.isAvailable("me_interface") then
  print("Ошибка: ME интерфейс не найден!")
  print("Убедитесь что ME интерфейс подключен к компьютеру")
  return
end

local me = component.me_interface
local running = true
local craftThread = nil
local craftingEnabled = false

local craftDB = {}  
local configFile = "/craft_config.dat"

local meKnowledgeFile = "/me_knowledge.dat"
local meKnowledge = {
    items = {},          
    craftables = {},     
    cpus = {},           
    patterns = {},       
    craftTimes = {},     
    craftHistory = {},   
    researchDB = {}      
}

-- Функция очистки памяти
local function freeMemory()
    local temp = {}
    for i = 1, 50 do
        temp[i] = {}
        for j = 1, 5 do
            temp[i][j] = string.rep("x", 50)
        end
    end
    temp = nil
end

local function tableLength(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- УЛУЧШЕННАЯ функция загрузки базы знаний
local function loadMEKnowledge()
    local file = io.open(meKnowledgeFile, "r")
    if file then
        local data = file:read("*a")
        file:close()
        if data and data ~= "" then
            local success, loaded = pcall(serialization.unserialize, data)
            if success and loaded then
                meKnowledge.items = loaded.items or {}
                meKnowledge.craftables = loaded.craftables or {}
                meKnowledge.cpus = loaded.cpus or {}
                meKnowledge.patterns = loaded.patterns or {}
                meKnowledge.craftTimes = loaded.craftTimes or {}
                meKnowledge.craftHistory = loaded.craftHistory or {}
                meKnowledge.researchDB = loaded.researchDB or {}
                
                print("✅ База знаний ME системы загружена")
                print("   Предметы: " .. #meKnowledge.items)
                print("   Крафты: " .. #meKnowledge.craftables)
                print("   Паттерны: " .. tableLength(meKnowledge.patterns))
                return true
            else
                print("❌ Ошибка десериализации базы знаний")
            end
        else
            print("📁 Файл базы знаний пуст")
        end
    else
        print("📁 Файл базы знаний не найден")
    end
    return false
end

-- УЛУЧШЕННАЯ функция сохранения базы знаний
local function saveMEKnowledge()
    local success = false
    
    -- Создаем упрощенные данные для сохранения
    local saveData = {
        items = {},
        craftables = {},
        cpus = meKnowledge.cpus or {},
        patterns = meKnowledge.patterns or {},
        craftTimes = meKnowledge.craftTimes or {},
        researchDB = meKnowledge.researchDB or {}
    }
    
    -- Сохраняем предметы (до 4000)
    if meKnowledge.items then
        for i = 1, math.min(STORAGE_CONFIG.maxMemoryItems, #meKnowledge.items) do
            local item = meKnowledge.items[i]
            if item then
                table.insert(saveData.items, {
                    name = item.name,
                    size = item.size or 0,
                    label = item.label or "нет"
                })
            end
        end
    end
    
    -- Сохраняем крафты (до 2000)
    if meKnowledge.craftables then
        for i = 1, math.min(STORAGE_CONFIG.maxCraftables, #meKnowledge.craftables) do
            local craftable = meKnowledge.craftables[i]
            if craftable and craftable.itemStack then
                table.insert(saveData.craftables, {
                    index = craftable.index,
                    itemStack = {
                        name = craftable.itemStack.name,
                        label = craftable.itemStack.label or "нет"
                    }
                })
            end
        end
    end
    
    -- Пытаемся сохранить с обработкой ошибок
    for attempt = 1, 5 do
        local file = io.open(meKnowledgeFile, "w")
        if file then
            local ok, serialized = pcall(serialization.serialize, saveData)
            if ok and serialized then
                file:write(serialized)
                file:close()
                success = true
                break
            else
                file:close()
                print("⚠️ Попытка сохранения " .. attempt .. " не удалась")
            end
        end
        os.sleep(0.3)
    end
    
    return success
end

local function loadConfig()
    local file = io.open(configFile, "r")
    if file then
        local data = file:read("*a")
        file:close()
        if data and data ~= "" then
            local success, loaded = pcall(serialization.unserialize, data)
            if success and loaded then
                craftDB = loaded
                print("✅ Загружено автокрафтов: " .. tableLength(craftDB))
                return true
            else
                print("❌ Ошибка загрузки конфига")
            end
        end
    end
    craftDB = {}
    return false
end

local function saveConfig()
    local success = false
    for attempt = 1, 3 do
        local file = io.open(configFile, "w")
        if file then
            local ok, serialized = pcall(serialization.serialize, craftDB)
            if ok and serialized then
                file:write(serialized)
                file:close()
                success = true
                break
            else
                file:close()
            end
        end
        os.sleep(0.2)
    end
    return success
end

-- УЛУЧШЕННЫЙ показ страниц (35 строк)
local function showPaginated(data, title, itemsPerPage)
    if not data or #data == 0 then
        print("   Нет данных для отображения")
        print("\nНажмите Enter для продолжения...")
        io.read()
        return
    end
    
    itemsPerPage = itemsPerPage or 35
    local totalPages = math.ceil(#data / itemsPerPage)
    local currentPage = 1
    
    while true do
        term.clear()
        print("=== " .. title .. " ===")
        print("Страница " .. currentPage .. " из " .. totalPages)
        print()
        
        local startIndex = (currentPage - 1) * itemsPerPage + 1
        local endIndex = math.min(currentPage * itemsPerPage, #data)
        
        for i = startIndex, endIndex do
            if data[i] then
                print(data[i])
            end
        end
        
        print("\n" .. string.rep("=", 40))
        print("Навигация: [P]редыдущая | [N]следующая | [E]выход")
        
        local input = io.read():lower()
        if input == "n" and currentPage < totalPages then
            currentPage = currentPage + 1
        elseif input == "p" and currentPage > 1 then
            currentPage = currentPage - 1
        elseif input == "e" then
            break
        end
    end
end

-- УМНЫЙ АНАЛИЗ ME СИСТЕМЫ (без физического крафта)
local function analyzeMESystem()
    print("🔍 Запуск интеллектуального анализа ME системы...")
    
    -- Очистка старых данных
    meKnowledge.items = {}
    meKnowledge.craftables = {}
    meKnowledge.patterns = {}
    
    if not meKnowledge.cpus then meKnowledge.cpus = {} end
    if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
    if not meKnowledge.researchDB then meKnowledge.researchDB = {} end
    
    -- Анализ предметов
    print("📦 Анализ предметов в системе...")
    local success, items = pcall(me.getItemsInNetwork)
    if success and items then
        local itemCount = #items
        print("   Найдено предметов: " .. itemCount)
        
        for chunkStart = 1, itemCount, STORAGE_CONFIG.chunkSize do
            local chunkEnd = math.min(chunkStart + STORAGE_CONFIG.chunkSize - 1, itemCount)
            
            for i = chunkStart, chunkEnd do
                local item = items[i]
                if item and item.name then
                    table.insert(meKnowledge.items, {
                        name = item.name,
                        size = item.size or 0,
                        label = item.label or "нет"
                    })
                end
                
                if i % 20 == 0 then
                    freeMemory()
                    os.sleep(0.05)
                end
            end
            
            if chunkEnd % 200 == 0 then
                print("   Обработано: " .. chunkEnd .. "/" .. itemCount)
            end
        end
        print("✅ Предметов проанализировано: " .. #meKnowledge.items)
    else
        print("❌ Ошибка анализа предметов")
    end
    
    -- Анализ крафтов (БЕЗ ФИЗИЧЕСКОГО КРАФТА)
    print("🛠️ Интеллектуальный анализ крафтов...")
    local success, craftables = pcall(me.getCraftables)
    if success and craftables then
        local craftableCount = #craftables
        print("   Найдено крафтов: " .. craftableCount)
        
        local researched = 0
        local tempResearchDB = {}
        
        for chunkStart = 1, craftableCount, 25 do
            local chunkEnd = math.min(chunkStart + 24, craftableCount)
            
            for i = chunkStart, chunkEnd do
                local craftable = craftables[i]
                if craftable and craftable.getItemStack then
                    local itemSuccess, itemStack = pcall(craftable.getItemStack)
                    if itemSuccess and itemStack and itemStack.name then
                        -- Сохраняем информацию о крафте
                        local craftableInfo = {
                            index = i,
                            itemStack = {
                                name = itemStack.name,
                                label = itemStack.label or "нет"
                            }
                        }
                        table.insert(meKnowledge.craftables, craftableInfo)
                        
                        -- Сохраняем паттерн для быстрого поиска
                        meKnowledge.patterns[itemStack.name] = i
                        
                        -- Добавляем в исследовательскую базу
                        table.insert(tempResearchDB, {
                            craftableIndex = i,
                            itemID = itemStack.name,
                            label = itemStack.label or "Без названия"
                        })
                        
                        researched = researched + 1
                    end
                end
                
                if i % 10 == 0 then
                    freeMemory()
                    os.sleep(0.1)
                end
            end
            
            if chunkEnd % 100 == 0 then
                print("   Исследовано крафтов: " .. researched .. "/" .. craftableCount)
            end
        end
        
        meKnowledge.researchDB = tempResearchDB
        print("✅ Крафтов исследовано: " .. researched)
    else
        print("❌ Ошибка анализа крафтов")
    end
    
    -- Анализ ЦП
    print("⚡ Анализ процессоров крафта...")
    local success, cpus = pcall(me.getCraftingCPUs)
    if success and cpus then
        meKnowledge.cpus = {}
        for i, cpu in ipairs(cpus) do
            if cpu then
                table.insert(meKnowledge.cpus, {
                    index = i,
                    busy = cpu.busy or false,
                    storage = cpu.storage or 0,
                    name = cpu.name or "ЦП #" .. i
                })
            end
        end
        print("✅ Процессоров найдено: " .. #meKnowledge.cpus)
    else
        print("❌ Ошибка анализа процессоров")
    end
    
    -- Финальное сохранение
    freeMemory()
    if saveMEKnowledge() then
        print("\n🎉 Анализ завершен успешно!")
        print("📊 Итоги:")
        print("   📦 Предметы: " .. #meKnowledge.items)
        print("   🛠️ Крафты: " .. #meKnowledge.craftables)
        print("   🔗 Паттерны: " .. tableLength(meKnowledge.patterns))
        print("   ⚡ Процессоры: " .. #meKnowledge.cpus)
    else
        print("❌ Ошибка сохранения данных")
    end
    
    print("\nНажмите Enter для продолжения...")
    io.read()
end

-- УМНЫЙ ПОИСК CRAFTABLE (золотая функция - без перебора)
local function findCraftableSmart(itemID, itemName)
    -- Проверяем паттерны (основной метод)
    if meKnowledge.patterns and meKnowledge.patterns[itemID] then
        local craftableIndex = meKnowledge.patterns[itemID]
        return craftableIndex
    end
    
    -- Ищем в craftables по itemStack
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack and craftableInfo.itemStack.name == itemID then
                meKnowledge.patterns[itemID] = i
                saveMEKnowledge()
                return i
            end
        end
    end
    
    -- Ищем по совпадению label
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack then
                local stack = craftableInfo.itemStack
                if stack.label and stack.label:lower():find(itemName:lower(), 1, true) then
                    meKnowledge.patterns[itemID] = i
                    saveMEKnowledge()
                    return i
                end
            end
        end
    end
    
    return nil
end

local function getItemCount(itemID)
    if not meKnowledge.items then return 0 end
    for i, item in ipairs(meKnowledge.items) do
        if item.name == itemID then
            return item.size or 0
        end
    end
    return 0
end

local function updateItemCounts()
    local success, items = pcall(me.getItemsInNetwork)
    if success and items and meKnowledge.items then
        for i, item in ipairs(items) do
            if item and item.name then
                for j, knownItem in ipairs(meKnowledge.items) do
                    if knownItem.name == item.name then
                        knownItem.size = item.size or 0
                        break
                    end
                end
            end
        end
    end
end

local function getAvailableCPU(preferredCPUs, allowOtherCPUs)
    local success, cpus = pcall(me.getCraftingCPUs)
    if not success or not cpus then
        return nil
    end
    
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpus[cpuIndex] and not cpus[cpuIndex].busy then
            return cpuIndex
        end
    end
    
    if allowOtherCPUs then
        for i, cpu in ipairs(cpus) do
            if cpu and not cpu.busy then
                local isPreferred = false
                for _, preferredIndex in ipairs(preferredCPUs) do
                    if i == preferredIndex then
                        isPreferred = true
                        break
                    end
                end
                if not isPreferred then
                    return i
                end
            end
        end
    end
    
    return nil
end

local function requestCraft(itemID, amount, preferredCPUs, allowOtherCPUs, craftName)
    local craftableIndex = nil
    
    for name, data in pairs(craftDB) do
        if data.itemID == itemID then
            craftableIndex = data.craftableIndex
            break
        end
    end
    
    if not craftableIndex then
        craftableIndex = findCraftableSmart(itemID, craftName)
        if craftableIndex then
            for name, data in pairs(craftDB) do
                if data.itemID == itemID then
                    data.craftableIndex = craftableIndex
                    saveConfig()
                    break
                end
            end
        else
            print("❌ Не удалось найти крафт для " .. craftName)
            return false
        end
    end
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Крафт не найден: #" .. craftableIndex)
        return false
    end
    
    local craftable = craftables[craftableIndex]
    local craftSuccess, result = pcall(craftable.request, amount)
    
    if craftSuccess then
        if result then
            print("✅ Заказан крафт: " .. craftName .. " x" .. amount)
            return true
        else
            print("❌ Крафт недоступен: " .. craftName)
            return false
        end
    else
        print("❌ Ошибка заказа: " .. tostring(result))
        return false
    end
end

local function waitForCraft(itemID, targetAmount, craftName)
    local averageTime = meKnowledge.craftTimes and meKnowledge.craftTimes[itemID]
    local timeout = averageTime and (averageTime * 2 + 60) or 300
    local startTime = computer.uptime()
    
    while computer.uptime() - startTime < timeout do
        updateItemCounts()  
        local currentCount = getItemCount(itemID)
        local elapsed = math.floor(computer.uptime() - startTime)
        print("   📦 " .. currentCount .. "/" .. targetAmount .. " (" .. elapsed .. "с)")
        
        if currentCount >= targetAmount then
            print("✅ Готово: " .. craftName)
            
            if not meKnowledge.craftTimes or not meKnowledge.craftTimes[itemID] then
                local actualTime = computer.uptime() - startTime
                if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
                meKnowledge.craftTimes[itemID] = actualTime
                saveMEKnowledge()
            end
            
            return true
        end
        
        os.sleep(5)
    end
    
    print("❌ Таймаут ожидания: " .. craftName)
    return false
end

-- ОСНОВНОЙ ЦИКЛ АВТОКРАФТА
local function craftLoop()
    print("🚀 Запуск поддержки автокрафта...")
    
    while craftingEnabled do
        for name, craftData in pairs(craftDB) do
            if not craftingEnabled then break end
            
            updateItemCounts()
            local currentCount = getItemCount(craftData.itemID)
            
            if currentCount < craftData.targetAmount then
                local needed = craftData.targetAmount - currentCount
                print("\n🔍 " .. name .. ": " .. currentCount .. "/" .. craftData.targetAmount)
                print("🛠️ Нужно: " .. needed .. " шт.")
                
                local availableCPU = getAvailableCPU(craftData.preferredCPUs, craftData.allowOtherCPUs)
                
                if availableCPU then
                    if requestCraft(craftData.itemID, needed, craftData.preferredCPUs, craftData.allowOtherCPUs, name) then
                        waitForCraft(craftData.itemID, craftData.targetAmount, name)
                    end
                else
                    print("⏳ Все ЦП заняты, ждем...")
                    os.sleep(10)
                end
            end
            
            os.sleep(craftData.checkTimeout)
        end
        
        if craftingEnabled then
            print("\n--- 🔄 Цикл завершен ---")
            os.sleep(10)
        end
    end
end

-- ФУНКЦИЯ ПЕРЕКЛЮЧЕНИЯ АВТОКРАФТА
local function toggleAutoCraft()
    if craftingEnabled then
        craftingEnabled = false
        if craftThread then
            craftThread:join()
            craftThread = nil
        end
        print("🛑 Поддержка автокрафта остановлена")
    else
        if tableLength(craftDB) == 0 then
            print("❌ Нет автокрафтов для поддержки!")
            os.sleep(2)
            return
        end
        craftingEnabled = true
        craftThread = thread.create(craftLoop)
        print("🚀 Поддержка автокрафта запущена")
    end
    os.sleep(1)
end

-- УЛУЧШЕННЫЙ ИНТЕРФЕЙС ДОБАВЛЕНИЯ АВТОКРАФТА
local function addAutoCraft()
    term.clear()
    print("=== ➕ ДОБАВЛЕНИЕ АВТОКРАФТА ===")
    print()
    
    -- Показываем последние 10 предметов
    print("📦 Последние предметы в системе:")
    local recentItems = {}
    if meKnowledge.items and #meKnowledge.items > 0 then
        local startIndex = math.max(1, #meKnowledge.items - 9)
        for i = startIndex, #meKnowledge.items do
            if meKnowledge.items[i] then
                local item = meKnowledge.items[i]
                print("  " .. item.name .. " - " .. (item.size or 0) .. " шт. (" .. (item.label or "нет") .. ")")
                table.insert(recentItems, item)
            end
        end
    else
        print("  Нет данных о предметах")
    end
    
    print("\n" .. string.rep("=", 40))
    
    print("Введите название автокрафта:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        print("❌ Автокрафт с таким именем уже существует!")
        os.sleep(2)
        return
    end
    
    print("Введите ID предмета:")
    local itemID = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    local itemExists = false
    local itemLabel = ""
    if meKnowledge.items then
        for i, item in ipairs(meKnowledge.items) do
            if item.name == itemID then
                itemExists = true
                itemLabel = item.label or itemID
                break
            end
        end
    end
    
    if not itemExists then
        print("❌ Предмет не найден в системе!")
        os.sleep(2)
        return
    end
    
    print("Целевое количество:")
    local targetAmount = tonumber(io.read())
    
    if not targetAmount or targetAmount <= 0 then
        print("❌ Неверное количество!")
        os.sleep(2)
        return
    end
    
    -- Показываем доступные ЦП
    print("\n⚡ Доступные процессоры:")
    if meKnowledge.cpus and #meKnowledge.cpus > 0 then
        for i, cpu in ipairs(meKnowledge.cpus) do
            local status = cpu.busy and "ЗАНЯТ" or "СВОБОДЕН"
            print("  #" .. i .. ": " .. status .. " (" .. (cpu.name or "ЦП") .. ")")
        end
    else
        print("  Нет данных о процессорах")
    end
    
    print("Номера ЦП (через запятую):")
    local cpuInput = io.read():gsub("^%s*(.-)%s*$", "%1")
    local preferredCPUs = {}
    for cpuStr in cpuInput:gmatch("[^,]+") do
        local cpuIndex = tonumber(cpuStr:match("%d+"))
        if cpuIndex then
            table.insert(preferredCPUs, cpuIndex)
        end
    end
    
    local maxCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    if #preferredCPUs == 0 then
        print("❌ Не указаны ЦП!")
        os.sleep(2)
        return
    end
    
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpuIndex < 1 or cpuIndex > maxCPUs then
            print("❌ Неверный номер ЦП: " .. cpuIndex)
            os.sleep(2)
            return
        end
    end
    
    print("Использовать другие ЦП если заняты? (y/n):")
    local allowOtherInput = io.read():lower()
    local allowOtherCPUs = (allowOtherInput == "y" or allowOtherInput == "yes" or allowOtherInput == "да")
    
    print("Интервал проверки (секунды, минимум 5):")
    local timeout = tonumber(io.read())
    
    if not timeout or timeout < 5 then
        timeout = 5
        print("Установлен интервал 5 секунд")
    end
    
    -- Умный поиск крафта
    local craftableIndex = findCraftableSmart(itemID, craftName)
    
    craftDB[craftName] = {
        itemID = itemID,
        targetAmount = targetAmount,
        preferredCPUs = preferredCPUs,
        allowOtherCPUs = allowOtherCPUs,
        checkTimeout = timeout,
        craftableIndex = craftableIndex
    }
    
    if saveConfig() then
        print("\n✅ Автокрафт добавлен!")
        print("   Предмет: " .. itemLabel)
        print("   Целевое количество: " .. targetAmount)
        print("   ЦП: " .. table.concat(preferredCPUs, ", "))
        if craftableIndex then
            print("   Найден крафт: #" .. craftableIndex)
        else
            print("   ⚠️ Крафт не найден")
        end
    else
        print("❌ Ошибка сохранения")
    end
    os.sleep(3)
end

-- ПРОСМОТР БАЗЫ АВТОКРАФТОВ
local function viewCraftDB()
    if tableLength(craftDB) == 0 then
        print("База автокрафтов пуста!")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for name, data in pairs(craftDB) do
        local current = getItemCount(data.itemID)
        local status = current >= data.targetAmount and "✅" or "❌"
        local craftableInfo = data.craftableIndex and ("Крафт: #" .. data.craftableIndex) or "Крафт: не найден"
        local cpusInfo = "ЦП: " .. table.concat(data.preferredCPUs, ", ") .. (data.allowOtherCPUs and " (+другие)" or "")
        
        local craftTime = meKnowledge.craftTimes and meKnowledge.craftTimes[data.itemID]
        local timeInfo = craftTime and string.format("Время: %.1f сек", craftTime) or "Время: не измерено"
        
        local entry = string.format("%s %s\n  📦 %d/%d | ID: %s\n  %s\n  ⏰ %d сек | %s\n  %s\n%s",
            status, name, current, data.targetAmount, data.itemID, cpusInfo, 
            data.checkTimeout, timeInfo, craftableInfo, string.rep("-", 40))
        
        table.insert(dataToShow, entry)
    end
    
    showPaginated(dataToShow, "📊 БАЗА АВТОКРАФТОВ", 8)
end

-- УДАЛЕНИЕ АВТОКРАФТА
local function removeAutoCraft()
    term.clear()
    print("=== ❌ УДАЛЕНИЕ АВТОКРАФТА ===")
    
    if tableLength(craftDB) == 0 then
        print("База автокрафтов пуста!")
        os.sleep(2)
        return
    end
    
    local craftNames = {}
    for name in pairs(craftDB) do
        table.insert(craftNames, name)
    end
    
    showPaginated(craftNames, "СПИСОК АВТОКРАФТОВ", 35)
    
    print("\nВведите название для удаления:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        craftDB[craftName] = nil
        if saveConfig() then
            print("✅ Автокрафт удален!")
        else
            print("❌ Ошибка сохранения")
        end
    else
        print("❌ Автокрафт не найден!")
    end
    os.sleep(2)
end

-- БАЗА ЗНАНИЙ ME
local function showMEKnowledge()
    term.clear()
    print("=== 📚 БАЗА ЗНАНИЙ ME СИСТЕМЫ ===")
    print()
    
    local totalItems = meKnowledge.items and #meKnowledge.items or 0
    local totalCraftables = meKnowledge.craftables and #meKnowledge.craftables or 0
    local totalPatterns = tableLength(meKnowledge.patterns or {})
    local totalCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    local totalCraftTimes = tableLength(meKnowledge.craftTimes or {})
    
    print("📊 Общая статистика:")
    print("   📦 Предметы: " .. totalItems)
    print("   🛠️ Крафты: " .. totalCraftables)
    print("   🔗 Паттерны: " .. totalPatterns)
    print("   ⚡ Процессоры: " .. totalCPUs)
    print("   ⏱️ Время крафта: " .. totalCraftTimes)
    
    print("\n" .. string.rep("=", 40))
    print("1 - Просмотр предметов")
    print("2 - Просмотр крафтов") 
    print("3 - Просмотр паттернов")
    print("4 - Просмотр процессоров")
    print("5 - Назад")
    print("\nВыберите действие:")
    
    local choice = io.read()
    
    if choice == "1" then
        local dataToShow = {}
        if meKnowledge.items then
            for i, item in ipairs(meKnowledge.items) do
                table.insert(dataToShow, string.format("  %s - %d шт. (%s)", 
                    item.name, item.size or 0, item.label or "нет"))
            end
        end
        showPaginated(dataToShow, "📦 ПРЕДМЕТЫ В СИСТЕМЕ", 35)
    elseif choice == "2" then
        local dataToShow = {}
        if meKnowledge.craftables then
            for i, craftable in ipairs(meKnowledge.craftables) do
                if craftable.itemStack then
                    table.insert(dataToShow, string.format("  #%d: %s (%s)", 
                        craftable.index, craftable.itemStack.name, craftable.itemStack.label or "нет"))
                end
            end
        end
        showPaginated(dataToShow, "🛠️ ДОСТУПНЫЕ КРАФТЫ", 35)
    elseif choice == "3" then
        local dataToShow = {}
        if meKnowledge.patterns then
            for itemID, craftableIndex in pairs(meKnowledge.patterns) do
                table.insert(dataToShow, string.format("  %s → крафт #%d", itemID, craftableIndex))
            end
        end
        showPaginated(dataToShow, "🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ", 35)
    elseif choice == "4" then
        local dataToShow = {}
        if meKnowledge.cpus then
            for i, cpu in ipairs(meKnowledge.cpus) do
                local status = cpu.busy and "🟡 ЗАНЯТ" or "🟢 СВОБОДЕН"
                table.insert(dataToShow, string.format("  #%d: %s - %s (%d КБ)", 
                    cpu.index, status, cpu.name or "ЦП", cpu.storage or 0))
            end
        end
        showPaginated(dataToShow, "⚡ ПРОЦЕССОРЫ КРАФТА", 35)
    end
end

-- ДЕТАЛИ CRAFTABLES
local function showCraftableDetails()
    if not meKnowledge.craftables or #meKnowledge.craftables == 0 then
        print("Нет данных о крафтах")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for i, craftable in ipairs(meKnowledge.craftables) do
        local craftableText = "\n🛠️ Крафт #" .. i .. ":\n"
        
        if craftable.itemStack then
            craftableText = craftableText .. "  📦 ItemStack:\n"
            craftableText = craftableText .. "    🆔 ID: " .. (craftable.itemStack.name or "нет") .. "\n"
            craftableText = craftableText .. "    🏷️ Label: " .. (craftable.itemStack.label or "нет") .. "\n"
        end
        
        table.insert(dataToShow, craftableText)
    end
    
    showPaginated(dataToShow, "🔍 ДЕТАЛИ КРАФТОВ", 10)
end

-- ПРОСМОТР ВРЕМЕНИ КРАФТОВ
local function showCraftTimes()
    if not meKnowledge.craftTimes or tableLength(meKnowledge.craftTimes) == 0 then
        print("Нет данных о времени крафта")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for itemID, time in pairs(meKnowledge.craftTimes) do
        local label = itemID
        -- Пытаемся найти label в предметах
        if meKnowledge.items then
            for i, item in ipairs(meKnowledge.items) do
                if item.name == itemID then
                    label = item.label or itemID
                    break
                end
            end
        end
        
        table.insert(dataToShow, string.format("  %s: %.1f сек", label, time))
    end
    
    showPaginated(dataToShow, "⏱️ ВРЕМЯ КРАФТА ПРЕДМЕТОВ", 35)
end

-- ОЧИСТКА ВСЕХ БАЗ ДАННЫХ
local function formatDatabases()
    print("⚠️  ВНИМАНИЕ: Это действие полностью очистит все данные!")
    print("❌ Все автокрафты, исследования и история будут удалены.")
    print("\nПродолжить? (y/n):")
    
    local input = io.read():lower()
    if input ~= "y" and input ~= "yes" and input ~= "да" then
        print("❌ Очистка отменена")
        return
    end
    
    print("🧹 Начало очистки баз данных...")
    
    -- Очищаем оперативную память
    craftDB = {}
    meKnowledge = {
        items = {}, craftables = {}, cpus = {}, 
        patterns = {}, craftTimes = {}, craftHistory = {}, researchDB = {}
    }
    
    -- Удаляем файлы
    local deletedCount = 0
    if os.remove(configFile) then deletedCount = deletedCount + 1 end
    if os.remove(meKnowledgeFile) then deletedCount = deletedCount + 1 end
    
    -- Создаем чистые базы
    if saveConfig() and saveMEKnowledge() then
        print("✅ Очистка завершена!")
        print("🗑️ Удалено файлов: " .. deletedCount)
        print("🆕 Созданы чистые базы данных")
    else
        print("❌ Ошибка создания чистых баз")
    end
    
    print("\nНажмите Enter для продолжения...")
    io.read()
end

-- ГЛАВНОЕ МЕНЮ
local function mainMenu()
    while running do
        term.clear()
        print("=== 🧠 УМНАЯ СИСТЕМА ПОДДЕРЖКИ АВТОКРАФТА ===")
        print()
        
        -- Статус системы (ИСПРАВЛЕННАЯ СТРОКА)
        local statusIcon = craftingEnabled and "🟢" or "🔴"
        print(statusIcon .. " Поддержка автокрафта: " .. (craftingEnabled and "ВКЛЮЧЕНА" or "ВЫКЛЮЧЕНА"))
        print("📊 Автокрафтов: " .. tableLength(craftDB))
        print("📚 База знаний: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов, " .. 
              (meKnowledge.craftables and #meKnowledge.craftables or 0) .. " крафтов")
        print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}) .. " записей")
        
        print("\n" .. string.rep("=", 40))
        print("1. " .. (craftingEnabled and "🛑 Остановить" or "🚀 Запустить") .. " поддержку автокрафта")
        print("2. ➕ Добавить автокрафт")
        print("3. 👁️ Просмотр автокрафтов") 
        print("4. ❌ Удалить автокрафт")
        print("5. 🔍 Анализ ME системы")
        print("6. 📚 База знаний ME")
        print("7. 🔎 Детали крафтов")
        print("8. ⏱️ Время крафтов")
        print("9. 🗑️ Очистить все базы данных")
        print("10. 🚪 Выход")
        print("\nВыберите действие:")
        
        local choice = io.read()
        
        if choice == "1" then
            toggleAutoCraft()
        elseif choice == "2" then
            addAutoCraft()
        elseif choice == "3" then
            viewCraftDB()
        elseif choice == "4" then
            removeAutoCraft()
        elseif choice == "5" then
            analyzeMESystem()
        elseif choice == "6" then
            showMEKnowledge()
        elseif choice == "7" then
            showCraftableDetails()
        elseif choice == "8" then
            showCraftTimes()
        elseif choice == "9" then
            formatDatabases()
        elseif choice == "10" then
            if craftingEnabled then
                craftingEnabled = false
                if craftThread then
                    craftThread:join()
                end
            end
            -- Сохраняем данные перед выходом
            saveMEKnowledge()
            saveConfig()
            print("👋 Выход из системы...")
            break
        end
    end
end

-- ИНИЦИАЛИЗАЦИЯ СИСТЕМЫ
print("Загрузка умной системы поддержки автокрафта...")
loadConfig()
loadMEKnowledge()

-- Автоанализ только если база действительно пуста
if (not meKnowledge.items or #meKnowledge.items == 0) and running then
    print("🔄 База знаний пуста, выполняется первоначальный анализ...")
    analyzeMESystem()
else
    print("✅ Система готова к работе!")
    print("📊 Загружено автокрафтов: " .. tableLength(craftDB))
    print("📚 База знаний: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов")
    print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}) .. " записей")
    os.sleep(2)
end

mainMenu()
