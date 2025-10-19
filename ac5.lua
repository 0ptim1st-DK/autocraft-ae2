local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local thread = require("thread")
local computer = require("computer")

-- Конфигурация оптимизации памяти и внешнего хранилища
local STORAGE_CONFIG = {
    primaryStorage = "/home/",
    externalStorage = "/mnt/raid/",
    maxMemoryItems = 500,
    chunkSize = 100,
    useExternalStorage = false
}

if not component.isAvailable("me_interface") then
  print("Ошибка: ME интерфейс не найден!")
  print("Убедитесь что ME интерфейс подключен к компьютеру")
  return
end

local me = component.me_interface
local running = true
local monitoring = false
local monitorThread = nil

local craftDB = {}  
local configFile = "/home/craft_config.dat"

local meKnowledgeFile = "/home/me_knowledge.dat"
local meKnowledge = {
    items = {},          
    craftables = {},     
    cpus = {},           
    patterns = {},       
    craftTimes = {},     
    craftHistory = {},   
    researchDB = {}      
}

-- Функция инициализации внешнего хранилища
local function initExternalStorage()
    -- Проверяем доступные точки монтирования
    local mounts = {"/mnt/raid", "/mnt/external", "/mnt/disk", "/mnt"}
    for _, mount in ipairs(mounts) do
        local checkCmd = "test -d " .. mount .. " 2>/dev/null"
        if os.execute(checkCmd) then
            STORAGE_CONFIG.externalStorage = mount .. "/"
            STORAGE_CONFIG.useExternalStorage = true
            print("✅ Внешнее хранилище: " .. mount)
            return true
        end
    end
    
    -- Создаем точку монтирования
    os.execute("mkdir -p /mnt/raid 2>/dev/null")
    print("⚠️ Внешнее хранилище не найдено, используем основное")
    return false
end

-- Функция получения пути с учетом внешнего хранилища
local function getStoragePath(filename)
    if STORAGE_CONFIG.useExternalStorage then
        return STORAGE_CONFIG.externalStorage .. filename
    else
        return STORAGE_CONFIG.primaryStorage .. filename
    end
end

-- Функция оптимизации памяти (без collectgarbage)
local function optimizeMemory()
    -- В OpenComputers нет collectgarbage, поэтому просто ограничиваем данные
    -- Очищаем историю, если она слишком большая
    if meKnowledge.craftHistory and #meKnowledge.craftHistory > 100 then
        local newHistory = {}
        for i = math.max(1, #meKnowledge.craftHistory - 99), #meKnowledge.craftHistory do
            table.insert(newHistory, meKnowledge.craftHistory[i])
        end
        meKnowledge.craftHistory = newHistory
    end
end

local function tableLength(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function getTableKeys(tbl)
    if not tbl then return {} end
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

local function loadMEKnowledge()
    local paths = {
        getStoragePath("me_knowledge.dat"),
        STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat"
    }
    
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            file:close()
            local success, loaded = pcall(serialization.unserialize, data)
            if success and loaded then
                meKnowledge = loaded
                print("📚 Загружена база знаний ME системы")
                print("   Предметы: " .. (meKnowledge.items and #meKnowledge.items or 0))
                print("   Craftables: " .. (meKnowledge.craftables and #meKnowledge.craftables or 0))
                print("   ЦП: " .. (meKnowledge.cpus and #meKnowledge.cpus or 0))
                print("   Паттерны: " .. tableLength(meKnowledge.patterns))
                print("   Время крафта: " .. tableLength(meKnowledge.craftTimes))
                print("   История крафтов: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
                return true
            end
        end
    end
    
    print("📚 Создаем новую базу знаний ME системы")
    meKnowledge = {items = {}, craftables = {}, cpus = {}, patterns = {}, craftTimes = {}, craftHistory = {}, researchDB = {}}
    return false
end

local function saveMEKnowledge()
    -- Ограничиваем размер данных в памяти
    if meKnowledge.items and #meKnowledge.items > STORAGE_CONFIG.maxMemoryItems then
        local trimmedItems = {}
        for i = 1, math.min(STORAGE_CONFIG.maxMemoryItems, #meKnowledge.items) do
            table.insert(trimmedItems, meKnowledge.items[i])
        end
        meKnowledge.items = trimmedItems
    end
    
    local path = getStoragePath("me_knowledge.dat")
    local file = io.open(path, "w")
    if file then
        file:write(serialization.serialize(meKnowledge))
        file:close()
        
        -- Дополнительная копия в основное хранилище
        if STORAGE_CONFIG.useExternalStorage then
            local backupFile = io.open(STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat", "w")
            if backupFile then
                backupFile:write(serialization.serialize(meKnowledge))
                backupFile:close()
            end
        end
        
        return true
    end
    return false
end

local function loadConfig()
    local file = io.open(configFile, "r")
    if file then
        local data = file:read("*a")
        file:close()
        local success, loaded = pcall(serialization.unserialize, data)
        if success and loaded then
            craftDB = loaded
        else
            craftDB = {}
        end
        print("Загружено автокрафтов: " .. tableLength(craftDB))
    else
        print("Конфиг не найден, создаем новую базу")
        craftDB = {}
    end
end

local function saveConfig()
    local file = io.open(configFile, "w")
    if file then
        file:write(serialization.serialize(craftDB))
        file:close()
        return true
    end
    return false
end

local function showPaginated(data, title, itemsPerPage)
    if not data or #data == 0 then
        print("   Нет данных для отображения")
        print("\nНажмите Enter для продолжения...")
        io.read()
        return
    end
    
    itemsPerPage = itemsPerPage or 20
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
                if type(data[i]) == "string" then
                    print(data[i])
                elseif title:find("ПРЕДМЕТЫ") then
                    local item = data[i]
                    print(string.format("  %s - %d шт. (label: %s)", 
                          item.name or "unknown", item.size or 0, item.label or "нет"))
                elseif title:find("CRAFTABLES") then
                    local craftable = data[i]
                    local itemName = craftable.itemStack and craftable.itemStack.name or "неизвестно"
                    local label = craftable.itemStack and craftable.itemStack.label or "нет"
                    print(string.format("  #%d: %s (label: %s)", i, itemName, label))
                elseif title:find("ЦП") then
                    local cpu = data[i]
                    local status = cpu.busy and "ЗАНЯТ" or "СВОБОДЕН"
                    print(string.format("  #%d: %s (%d КБ)", i, status, cpu.storage or 0))
                else
                    print("  " .. tostring(data[i]))
                end
            end
        end
        
        print("\nНавигация:")
        if currentPage > 1 then
            print("P - Предыдущая страница")
        end
        if currentPage < totalPages then
            print("N - Следующая страница")
        end
        print("E - Выход в меню")
        
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

-- ОПТИМИЗИРОВАННАЯ функция анализа ME системы
local function analyzeMESystem()
    print("🔍 Анализ ME системы...")
    initExternalStorage()
    optimizeMemory()
    
    if not meKnowledge.items then meKnowledge.items = {} end
    if not meKnowledge.craftables then meKnowledge.craftables = {} end
    if not meKnowledge.cpus then meKnowledge.cpus = {} end
    if not meKnowledge.patterns then meKnowledge.patterns = {} end
    if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
    if not meKnowledge.craftHistory then meKnowledge.craftHistory = {} end
    
    -- Анализ предметов по чанкам
    local success, items = pcall(me.getItemsInNetwork)
    if success and items then
        meKnowledge.items = {}
        local itemCount = #items
        print("   📦 Всего предметов: " .. itemCount)
        
        -- Обрабатываем предметы чанками
        for chunkStart = 1, itemCount, STORAGE_CONFIG.chunkSize do
            local chunkEnd = math.min(chunkStart + STORAGE_CONFIG.chunkSize - 1, itemCount)
            print("   Обработка чанка: " .. chunkStart .. "-" .. chunkEnd)
            
            for i = chunkStart, chunkEnd do
                local item = items[i]
                if item and item.name then
                    local itemInfo = {
                        name = item.name,
                        size = item.size or 0,
                        label = item.label or "нет"
                    }
                    table.insert(meKnowledge.items, itemInfo)
                end
                
                -- Даем системе передохнуть вместо сборки мусора
                if i % 50 == 0 then
                    os.sleep(0.1)
                end
            end
            
            -- Сохраняем промежуточные результаты
            if chunkEnd % 200 == 0 then
                saveMEKnowledge()
                print("   💾 Промежуточное сохранение...")
            end
        end
        print("   ✅ Предметов анализировано: " .. #meKnowledge.items)
    else
        print("   ❌ Ошибка анализа предметов")
    end
    
    -- Анализ craftables с оптимизацией
    local success, craftables = pcall(me.getCraftables)
    if success and craftables then
        meKnowledge.craftables = {}
        for i, craftable in ipairs(craftables) do
            if craftable then
                local craftableInfo = {
                    index = i,
                    methods = {},
                    fields = {}
                }
                
                if craftable.request then craftableInfo.methods.request = true end
                if craftable.getItemStack then craftableInfo.methods.getItemStack = true end
                
                -- Только базовая информация, без глубокого анализа
                if craftable.getItemStack then
                    local itemSuccess, itemStack = pcall(craftable.getItemStack)
                    if itemSuccess and itemStack then
                        craftableInfo.itemStack = {
                            name = itemStack.name or "unknown",
                            label = itemStack.label or "нет",
                            size = itemStack.size or 1
                        }
                        
                        if itemStack.name then
                            meKnowledge.patterns[itemStack.name] = i
                        end
                    end
                end
                
                table.insert(meKnowledge.craftables, craftableInfo)
                
                -- Даем системе передохнуть
                if i % 50 == 0 then
                    os.sleep(0.1)
                end
            end
        end
        print("   🛠️ Craftables анализировано: " .. #meKnowledge.craftables)
    else
        print("   ❌ Ошибка анализа craftables")
    end
    
    -- Анализ ЦП (обычно их немного)
    local success, cpus = pcall(me.getCraftingCPUs)
    if success and cpus then
        meKnowledge.cpus = {}
        for i, cpu in ipairs(cpus) do
            if cpu then
                local cpuInfo = {
                    index = i,
                    busy = cpu.busy or false,
                    storage = cpu.storage or 0,
                    name = cpu.name or "Без названия"
                }
                
                table.insert(meKnowledge.cpus, cpuInfo)
            end
        end
        print("   ⚡ ЦП анализировано: " .. #meKnowledge.cpus)
    else
        print("   ❌ Ошибка анализа ЦП")
    end
    
    if saveMEKnowledge() then
        print("✅ Анализ ME системы завершен!")
    else
        print("❌ Ошибка сохранения базы знаний")
    end
end

-- Остальные функции остаются без изменений (researchAllCrafts, showResearchDB, getItemCount, и т.д.)
local function researchAllCrafts()
    print("🔬 Интеллектуальное исследование всех крафтов...")
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables then
        print("❌ Не удалось получить список craftables")
        return
    end
    
    local researched = 0
    local tempResearchDB = {}
    
    for i, craftable in ipairs(craftables) do
        if craftable and craftable.getItemStack then
            local itemSuccess, itemStack = pcall(craftable.getItemStack)
            if itemSuccess and itemStack and itemStack.name then
                local itemInfo = {
                    craftableIndex = i,
                    itemID = itemStack.name,
                    label = itemStack.label or "Без названия",
                    size = itemStack.size or 1
                }
                
                table.insert(tempResearchDB, itemInfo)
                researched = researched + 1
                
                meKnowledge.patterns[itemStack.name] = i
                
                print("   ✅ Исследован: " .. (itemStack.label or itemStack.name) .. " -> craftable #" .. i)
            end
        end
    end
    
    meKnowledge.researchDB = tempResearchDB
    if saveMEKnowledge() then
        print("✅ Исследование завершено! Найдено крафтов: " .. researched)
    else
        print("❌ Ошибка сохранения исследований")
    end
    return tempResearchDB
end

local function showResearchDB()
    if not meKnowledge.researchDB or #meKnowledge.researchDB == 0 then
        print("❌ База исследований пуста! Сначала выполните исследование.")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for i, research in ipairs(meKnowledge.researchDB) do
        table.insert(dataToShow, string.format("Craftable #%d: %s (ID: %s)", 
            research.craftableIndex, research.label, research.itemID))
    end
    
    showPaginated(dataToShow, "🔬 БАЗА ИССЛЕДОВАНИЙ КРАФТОВ", 15)
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

local function getItemInfo(itemID)
    if not meKnowledge.items then return nil end
    for i, item in ipairs(meKnowledge.items) do
        if item.name == itemID then
            return item
        end
    end
    return nil
end

local function measureCraftTime(itemID, craftName, craftableIndex)
    print("⏱️ Измерение времени крафта для: " .. craftName)
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден для измерения времени")
        return nil
    end
    
    local craftable = craftables[craftableIndex]
    local totalTime = 0
    local successfulMeasurements = 0
    
    for attempt = 1, 4 do
        print("   Попытка " .. attempt .. "/4...")
        
        local startCount = getItemCount(itemID)
        local startTime = computer.uptime()
        
        local craftSuccess, result = pcall(craftable.request, 1)
        
        if craftSuccess and result then
            local timeout = 35
            local craftCompleted = false
            
            for i = 1, timeout do
                os.sleep(1)
                local currentCount = getItemCount(itemID)
                
                if currentCount > startCount then
                    local endTime = computer.uptime()
                    local craftTime = endTime - startTime
                    totalTime = totalTime + craftTime
                    successfulMeasurements = successfulMeasurements + 1
                    craftCompleted = true
                    print("     ✅ Крафт завершен за " .. string.format("%.1f", craftTime) .. " сек")
                    break
                end
            end
            
            if not craftCompleted then
                print("     ❌ Таймаут измерения попытки " .. attempt)
            end
        else
            print("     ❌ Ошибка заказа крафта")
        end
        
        os.sleep(2) 
    end
    
    if successfulMeasurements > 0 then
        local averageTime = totalTime / successfulMeasurements
        meKnowledge.craftTimes[itemID] = averageTime
        if saveMEKnowledge() then
            print("   📊 Среднее время крафта: " .. string.format("%.1f", averageTime) .. " сек")
        else
            print("   ❌ Ошибка сохранения времени крафта")
        end
        return averageTime
    else
        print("   ❌ Не удалось измерить время крафта")
        return nil
    end
end

local function showCraftTimes()
    if not meKnowledge.craftTimes or tableLength(meKnowledge.craftTimes) == 0 then
        print("❌ Нет данных о времени крафта")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for itemID, time in pairs(meKnowledge.craftTimes) do
        local label = itemID
        local itemInfo = getItemInfo(itemID)
        if itemInfo and itemInfo.label then
            label = itemInfo.label
        end
        
        table.insert(dataToShow, string.format("%s: %.1f сек", label, time))
    end
    
    showPaginated(dataToShow, "⏱️ БАЗА ВРЕМЕНИ КРАФТА", 15)
end

local function monitorActiveCrafts()
    print("🎯 Запуск мониторинга активных крафтов...")
    
    local lastCpuState = {}
    local currentObservations = {}
    
    if meKnowledge.cpus then
        for i, cpu in ipairs(meKnowledge.cpus) do
            lastCpuState[i] = {busy = cpu.busy or false, name = cpu.name or "Без названия"}
        end
    end
    
    while monitoring do
        local success, cpus = pcall(me.getCraftingCPUs)
        if success and cpus then
            for i, cpu in ipairs(cpus) do
                if cpu then
                    local currentBusy = cpu.busy or false
                    local lastBusy = lastCpuState[i] and lastCpuState[i].busy or false
                    
                    if currentBusy and not lastBusy then
                        print("🔍 Обнаружен новый крафт на ЦП #" .. i)
                        
                        local observation = {
                            cpuIndex = i,
                            cpuName = cpu.name or "Без названия",
                            startTime = computer.uptime(),
                            startItems = {},
                            status = "active"
                        }
                        
                        if meKnowledge.items then
                            for _, item in ipairs(meKnowledge.items) do
                                observation.startItems[item.name] = item.size or 0
                            end
                        end
                        
                        currentObservations[i] = observation
                        
                    elseif not currentBusy and lastBusy and currentObservations[i] then
                        local observation = currentObservations[i]
                        observation.endTime = computer.uptime()
                        observation.duration = observation.endTime - observation.startTime
                        observation.status = "completed"
                        
                        local craftedItems = {}
                        if meKnowledge.items then
                            for _, item in ipairs(meKnowledge.items) do
                                local startCount = observation.startItems[item.name] or 0
                                local endCount = item.size or 0
                                if endCount > startCount then
                                    table.insert(craftedItems, {
                                        itemID = item.name,
                                        itemLabel = item.label or item.name,
                                        amount = endCount - startCount
                                    })
                                end
                            end
                        end
                        
                        observation.craftedItems = craftedItems
                        
                        if not meKnowledge.craftHistory then
                            meKnowledge.craftHistory = {}
                        end
                        table.insert(meKnowledge.craftHistory, observation)
                        
                        if #craftedItems > 0 then
                            local mainItem = craftedItems[1]
                            meKnowledge.craftTimes[mainItem.itemID] = observation.duration
                            print("📊 Записано время крафта для " .. mainItem.itemLabel .. ": " .. string.format("%.1f", observation.duration) .. " сек")
                        end
                        
                        saveMEKnowledge()
                        
                        print("✅ Завершен крафт на ЦП #" .. i .. ", длительность: " .. string.format("%.1f", observation.duration) .. " сек")
                        currentObservations[i] = nil
                    end
                    
                    lastCpuState[i] = {busy = currentBusy, name = cpu.name or "Без названия"}
                end
            end
        end
        
        os.sleep(2) 
    end
end

local function toggleCraftMonitoring()
    if monitoring then
        monitoring = false
        if monitorThread then
            monitorThread:join()
            monitorThread = nil
        end
        print("🛑 Мониторинг крафтов остановлен")
    else
        monitoring = true
        monitorThread = thread.create(monitorActiveCrafts)
        print("🎯 Мониторинг крафтов запущен")
    end
    os.sleep(2)
end

local function showMonitoringStatus()
    term.clear()
    print("=== 🎯 СТАТУС МОНИТОРИНГА КРАФТОВ ===")
    
    if monitoring then
        print("📊 Статус: 🟢 АКТИВЕН")
        print("👁️  Наблюдение за активными крафтами...")
    else
        print("📊 Статус: 🔴 ВЫКЛЮЧЕН")
    end
    
    print("\n⚡ АКТИВНЫЕ ЦП:")
    local success, cpus = pcall(me.getCraftingCPUs)
    local activeCount = 0
    if success and cpus then
        for i, cpu in ipairs(cpus) do
            if cpu and cpu.busy then
                print("   ЦП #" .. i .. ": 🟡 ЗАНЯТ - " .. (cpu.name or "Без названия"))
                activeCount = activeCount + 1
            end
        end
    end
    if activeCount == 0 then
        print("   Нет активных крафтов")
    end
    
    print("\n📋 ПОСЛЕДНИЕ 3 НАБЛЮДЕНИЯ:")
    local recentObservations = {}
    if meKnowledge.craftHistory then
        for i = #meKnowledge.craftHistory, math.max(1, #meKnowledge.craftHistory - 2), -1 do
            table.insert(recentObservations, meKnowledge.craftHistory[i])
        end
    end
    
    if #recentObservations == 0 then
        print("   Нет данных о прошлых крафтах")
    else
        for i, obs in ipairs(recentObservations) do
            print("   " .. i .. ". ЦП #" .. obs.cpuIndex .. " (" .. (obs.cpuName or "Без названия") .. ")")
            print("      Время: " .. string.format("%.1f", obs.duration or 0) .. " сек")
            if obs.craftedItems and #obs.craftedItems > 0 then
                for j, item in ipairs(obs.craftedItems) do
                    if j <= 3 then 
                        print("      📦 " .. (item.itemLabel or item.itemID) .. " x" .. item.amount)
                    end
                end
                if #obs.craftedItems > 3 then
                    print("      ... и еще " .. (#obs.craftedItems - 3) .. " предметов")
                end
            end
            print("      ---")
        end
    end
    
    print("\n📊 Всего записей в истории: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
    print("\nНажмите Enter для продолжения...")
    io.read()
end

-- Умный поиск craftable по данным анализа (без физического крафта)
local function findCraftableSmart(itemID, itemName)
    print("🔍 Умный поиск craftable для: " .. itemName)
    
    -- Проверяем выявленные паттерны
    if meKnowledge.patterns and meKnowledge.patterns[itemID] then
        local craftableIndex = meKnowledge.patterns[itemID]
        print("   ✅ Найден в паттернах: craftable #" .. craftableIndex)
        return craftableIndex
    end
    
    -- Ищем через анализ itemStack в craftables
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack and craftableInfo.itemStack.name == itemID then
                print("   ✅ Найден через itemStack: craftable #" .. i)
                meKnowledge.patterns[itemID] = i
                saveMEKnowledge()
                return i
            end
        end
    end
    
    -- Ищем по совпадению label или имени
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack then
                local stack = craftableInfo.itemStack
                if stack.label and stack.label:lower():find(itemName:lower(), 1, true) then
                    print("   ✅ Найден по совпадению label: craftable #" .. i)
                    meKnowledge.patterns[itemID] = i
                    saveMEKnowledge()
                    return i
                end
            end
        end
    end
    
    print("   ❌ Craftable не найден в базе знаний")
    return nil
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

local function requestCraft(itemID, amount, cpuIndex, craftName)
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
            print("❌ Не удалось найти craftable для " .. craftName)
            return false
        end
    end
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден: #" .. craftableIndex)
        return false
    end
    
    local craftable = craftables[craftableIndex]
    local craftSuccess, result = pcall(craftable.request, amount)
    
    if craftSuccess then
        if result then
            print("✅ Крафт заказан: " .. craftName .. " x" .. amount)
            return true
        else
            print("❌ Крафт вернул false: " .. craftName)
            return false
        end
    else
        print("❌ Ошибка при заказе крафта: " .. tostring(result))
        return false
    end
end

local function waitForCraft(itemID, targetAmount, craftName)
    print("⏳ Ожидание крафта " .. craftName .. "...")
    
    local averageTime = meKnowledge.craftTimes and meKnowledge.craftTimes[itemID]
    local timeout = averageTime and (averageTime * 2 + 60) or 300
    local startTime = computer.uptime()
    
    if averageTime then
        print("   📊 Ожидаемое время: ~" .. string.format("%.1f", averageTime) .. " сек")
    end
    
    while computer.uptime() - startTime < timeout do
        updateItemCounts()  
        local currentCount = getItemCount(itemID)
        local elapsed = math.floor(computer.uptime() - startTime)
        print("   Прогресс: " .. currentCount .. "/" .. targetAmount .. " (" .. elapsed .. "с)")
        
        if currentCount >= targetAmount then
            print("✅ Крафт завершен! " .. craftName)
            
            if not meKnowledge.craftTimes or not meKnowledge.craftTimes[itemID] then
                local actualTime = computer.uptime() - startTime
                if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
                meKnowledge.craftTimes[itemID] = actualTime
                saveMEKnowledge()
                print("   💾 Сохранено время крафта: " .. string.format("%.1f", actualTime) .. " сек")
            end
            
            return true
        end
        
        os.sleep(5)
    end
    
    print("❌ Таймаут ожидания крафта!")
    return false
end

local function craftLoop()
    print("🚀 Запуск умного автокрафта...")
    
    while running do
        for name, craftData in pairs(craftDB) do
            if not running then break end
            
            print("\n🔍 Проверка: " .. name)
            updateItemCounts()
            local currentCount = getItemCount(craftData.itemID)
            print("📦 Количество: " .. currentCount .. "/" .. craftData.targetAmount)
            
            if currentCount < craftData.targetAmount then
                local needed = craftData.targetAmount - currentCount
                print("🛠️ Необходимо крафтить: " .. needed .. " шт.")
                
                if requestCraft(craftData.itemID, needed, craftData.cpuIndex, name) then
                    waitForCraft(craftData.itemID, craftData.targetAmount, name)
                else
                    print("❌ Не удалось заказать крафт")
                end
            else
                print("✅ Достаточное количество")
            end
            
            print("⏰ Ожидание " .. craftData.checkTimeout .. " сек...")
            os.sleep(craftData.checkTimeout)
        end
        
        if running then
            print("\n--- 🔄 Цикл завершен ---")
            os.sleep(10)
        end
    end
end

local function showMEKnowledge()
    term.clear()
    print("=== 📚 БАЗА ЗНАНИЙ ME СИСТЕМЫ ===")
    
    print("\n📦 ПРЕДМЕТЫ В СИСТЕМЕ (" .. (meKnowledge.items and #meKnowledge.items or 0) .. "):")
    showPaginated(meKnowledge.items or {}, "📦 ПРЕДМЕТЫ В СИСТЕМЕ", 15)
    
    print("\n🛠️ CRAFTABLES (" .. (meKnowledge.craftables and #meKnowledge.craftables or 0) .. "):")
    showPaginated(meKnowledge.craftables or {}, "🛠️ CRAFTABLES", 15)
    
    print("\n🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ:")
    local patternsList = {}
    if meKnowledge.patterns then
        for itemID, craftableIndex in pairs(meKnowledge.patterns) do
            table.insert(patternsList, "  " .. itemID .. " -> craftable #" .. craftableIndex)
        end
    end
    showPaginated(patternsList, "🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ", 15)
    
    print("\n⚡ ЦП (" .. (meKnowledge.cpus and #meKnowledge.cpus or 0) .. "):")
    showPaginated(meKnowledge.cpus or {}, "⚡ ЦП", 10)
    
    print("\nНажмите Enter для продолжения...")
    io.read()
end

local function showCraftableDetails()
    if not meKnowledge.craftables or #meKnowledge.craftables == 0 then
        print("Нет данных о craftables")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    
    for i, craftable in ipairs(meKnowledge.craftables) do
        local craftableText = "\nCraftable #" .. i .. ":\n"
        
        if craftable.itemStack then
            craftableText = craftableText .. "  ItemStack:\n"
            craftableText = craftableText .. "    ID: " .. (craftable.itemStack.name or "нет") .. "\n"
            craftableText = craftableText .. "    Label: " .. (craftable.itemStack.label or "нет") .. "\n"
            craftableText = craftableText .. "    Size: " .. (craftable.itemStack.size or "нет") .. "\n"
        end
        
        craftableText = craftableText .. "  Методы: " .. table.concat(getTableKeys(craftable.methods or {}), ", ") .. "\n"
        
        if craftable.fields and next(craftable.fields) ~= nil then
            craftableText = craftableText .. "  Поля:\n"
            for key, value in pairs(craftable.fields) do
                craftableText = craftableText .. "    " .. key .. ": " .. tostring(value) .. "\n"
            end
        end
        
        table.insert(dataToShow, craftableText)
    end
    
    showPaginated(dataToShow, "🔍 ДЕТАЛЬНЫЙ АНАЛИЗ CRAFTABLE", 3)
end

local function showAvailableCPUs()
    print("\n=== ⚡ ДОСТУПНЫЕ ЦП ===")
    if not meKnowledge.cpus or #meKnowledge.cpus == 0 then
        print("   Нет данных о ЦП")
        return
    end
    
    for i, cpu in ipairs(meKnowledge.cpus) do
        local status = cpu.busy and "🟡 ЗАНЯТ" or "🟢 СВОБОДЕН"
        local storageMB = string.format("%.1f", (cpu.storage or 0) / 1024)
        
        print("ЦП #" .. i .. ":")
        print("  Статус: " .. status)
        print("  Память: " .. storageMB .. " МБ (" .. (cpu.storage or 0) .. " КБ)")
    end
end

local function addAutoCraft()
    term.clear()
    print("=== ➕ ДОБАВЛЕНИЕ АВТОКРАФТА ===")
    
    showAvailableCPUs()
    print()
    
    print("📦 ПОСЛЕДНИЕ 15 ПРЕДМЕТОВ В СИСТЕМЕ:")
    local recentItems = {}
    if meKnowledge.items and #meKnowledge.items > 0 then
        local startIndex = math.max(1, #meKnowledge.items - 14)
        for i = startIndex, #meKnowledge.items do
            if meKnowledge.items[i] then
                local item = meKnowledge.items[i]
                print("  " .. item.name .. " - " .. (item.size or 0) .. " шт. (" .. (item.label or "нет") .. ")")
                table.insert(recentItems, item)
            end
        end
    else
        print("  Нет предметов для отображения")
    end
    
    print("\nВведите название автокрафта:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        print("Ошибка: автокрафт с таким именем уже существует!")
        os.sleep(3)
        return
    end
    
    print("Введите ID предмета (см. список выше):")
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
        print("Ошибка: предмет " .. itemID .. " не найден в ME системе!")
        os.sleep(3)
        return
    end
    
    print("Введите количество для поддержания:")
    local targetAmount = tonumber(io.read())
    
    if not targetAmount or targetAmount <= 0 then
        print("Ошибка: неверное количество!")
        os.sleep(2)
        return
    end
    
    print("Введите №ЦП для обработки (1-" .. (meKnowledge.cpus and #meKnowledge.cpus or 0) .. "):")
    local cpuIndex = tonumber(io.read())
    
    local maxCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    if not cpuIndex or cpuIndex < 1 or cpuIndex > maxCPUs then
        print("Ошибка: неверный номер ЦП! Доступны: 1-" .. maxCPUs)
        os.sleep(2)
        return
    end
    
    print("Введите таймаут проверки (в секундах, минимум 5):")
    local timeout = tonumber(io.read())
    
    if not timeout or timeout < 5 then
        timeout = 5
        print("Таймаут установлен на минимум 5 секунд")
    end
    
    local craftableIndex = findCraftableSmart(itemID, craftName)
    
    craftDB[craftName] = {
        itemID = itemID,
        targetAmount = targetAmount,
        cpuIndex = cpuIndex,
        checkTimeout = timeout,
        craftableIndex = craftableIndex
    }
    
    print("Измерить среднее время крафта? (y/n):")
    local measure = io.read():lower()
    if measure == "y" and craftableIndex then
        measureCraftTime(itemID, craftName, craftableIndex)
    end
    
    if saveConfig() then
        print("✅ Автокрафт '" .. craftName .. "' успешно добавлен!")
        print("   Предмет: " .. itemLabel)
        if craftableIndex then
            print("   Craftable: #" .. craftableIndex)
        else
            print("   ⚠️ Craftable не найден, потребуется ручная настройка")
        end
    else
        print("❌ Ошибка сохранения автокрафта")
    end
    os.sleep(3)
end

local function viewCraftDB()
    if tableLength(craftDB) == 0 then
        print("База пуста!")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for name, data in pairs(craftDB) do
        local current = getItemCount(data.itemID)
        local status = current >= data.targetAmount and "✅" or "❌"
        local craftableInfo = data.craftableIndex and ("Craftable: #" .. data.craftableIndex) or "Craftable: не найден"
        
        local craftTime = meKnowledge.craftTimes and meKnowledge.craftTimes[data.itemID]
        local timeInfo = craftTime and string.format("Время крафта: %.1f сек", craftTime) or "Время крафта: не измерено"
        
        local entry = string.format("%s %s: %d/%d\n  ID: %s\n  ЦП: #%d\n  Таймаут: %d сек\n  %s\n  %s\n---",
            status, name, current, data.targetAmount, data.itemID, data.cpuIndex, 
            data.checkTimeout, craftableInfo, timeInfo)
        
        table.insert(dataToShow, entry)
    end
    
    showPaginated(dataToShow, "📊 БАЗА АВТОКРАФТОВ", 5)
end

local function removeAutoCraft()
    term.clear()
    print("=== ❌ УДАЛЕНИЕ АВТОКРАФТА ===")
    
    if tableLength(craftDB) == 0 then
        print("База пуста!")
        os.sleep(2)
        return
    end
    
    local craftNames = {}
    for name in pairs(craftDB) do
        table.insert(craftNames, name)
    end
    
    showPaginated(craftNames, "СПИСОК АВТОКРАФТОВ", 20)
    
    print("\nВведите название для удаления:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        craftDB[craftName] = nil
        if saveConfig() then
            print("✅ Удалено!")
        else
            print("❌ Ошибка сохранения изменений")
        end
    else
        print("❌ Не найдено!")
    end
    os.sleep(2)
end

local function mainMenu()
    local craftThread = nil
    
    while running do
        term.clear()
        print("=== 🧠 УМНАЯ СИСТЕМА АВТОКРАФТА ===")
        print("📊 Автокрафтов: " .. tableLength(craftDB))
        print("📚 Знаний ME: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов, " .. 
              (meKnowledge.craftables and #meKnowledge.craftables or 0) .. " craftables")
        print("⚡ ЦП: " .. (meKnowledge.cpus and #meKnowledge.cpus or 0))
        print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}))
        print("📋 История крафтов: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
        print("🎯 Мониторинг: " .. (monitoring and "🟢 ВКЛ" or "🔴 ВЫКЛ"))
        print()
        print("1 - 🚀 Запуск автокрафта")
        print("2 - 🛑 Остановка автокрафта")
        print("3 - ➕ Добавить автокрафт")
        print("4 - 👁️ Просмотр автокрафтов")
        print("5 - ❌ Удалить автокрафт")
        print("6 - 🔍 Анализ ME системы")
        print("7 - 📚 Просмотр базы знаний ME")
        print("8 - 🔎 Детали craftables")
        print("9 - 🧹 Обновить данные ME")
        print("10 - 🔬 Исследовать все крафты")
        print("11 - 📋 Просмотр исследований")
        print("12 - ⏱️ Просмотр времени крафта")
        print("13 - 🎯 Мониторинг крафтов")
        print("14 - 📊 Статус мониторинга")
        print("15 - 🧹 Оптимизировать память")
        print("16 - 🚪 Выход")
        print()
        print("Выберите действие:")
        
        local choice = io.read()
        
        if choice == "1" and not craftThread then
            if tableLength(craftDB) == 0 then
                print("❌ Нет автокрафтов в базе!")
                os.sleep(2)
            else
                craftThread = thread.create(craftLoop)
                print("✅ Автокрафт запущен!")
                os.sleep(1)
            end
        elseif choice == "2" and craftThread then
            running = false
            craftThread:join()
            craftThread = nil
            running = true
            print("✅ Автокрафт остановлен!")
            os.sleep(1)
        elseif choice == "3" then
            addAutoCraft()
        elseif choice == "4" then
            viewCraftDB()
        elseif choice == "5" then
            removeAutoCraft()
        elseif choice == "6" then
            analyzeMESystem()
            print("\nНажмите Enter...")
            io.read()
        elseif choice == "7" then
            showMEKnowledge()
        elseif choice == "8" then
            showCraftableDetails()
        elseif choice == "9" then
            analyzeMESystem()
            print("✅ Данные обновлены!")
            os.sleep(2)
        elseif choice == "10" then
            researchAllCrafts()
            print("\nНажмите Enter...")
            io.read()
        elseif choice == "11" then
            showResearchDB()
        elseif choice == "12" then
            showCraftTimes()
        elseif choice == "13" then
            toggleCraftMonitoring()
        elseif choice == "14" then
            showMonitoringStatus()
        elseif choice == "15" then
            optimizeMemory()
            print("✅ Память оптимизирована!")
            os.sleep(1)
        elseif choice == "16" then
            running = false
            if craftThread then
                craftThread:join()
            end
            if monitorThread then
                monitoring = false
                monitorThread:join()
            end
            print("👋 Выход...")
            break
        end
    end
end

print("Загрузка умной системы автокрафта...")
loadMEKnowledge()
loadConfig()

if not meKnowledge.items or #meKnowledge.items == 0 then
    print("🔄 Первоначальный анализ ME системы...")
    analyzeMESystem()
end

print("✅ Умная система готова!")
print("📊 Автокрафтов: " .. tableLength(craftDB))
print("📚 Знаний ME: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов")
print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}))
print("📋 История крафтов: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
os.sleep(2)

mainMenu()
