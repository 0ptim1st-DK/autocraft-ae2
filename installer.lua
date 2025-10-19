[file name]: installer.lua
[file content begin]
local component = require("component")
local internet = require("internet")
local filesystem = require("filesystem")

local VERSION = "5.3"
local GITHUB_USERNAME = "0ptim1st-DK"
local REPO_URL = "https://raw.githubusercontent.com/" .. GITHUB_USERNAME .. "/autocraft-ae2/main/"

local function printHeader()
    term.clear()
    print("🎯 Умная система автокрафта AE2")
    print("================================")
    print("Версия установщика: " .. VERSION)
    print("")
end

local function downloadFile(filename, path)
    print("📥 Загрузка " .. filename)
    local url = REPO_URL .. filename
    local success, response = pcall(internet.request, url)
    
    if not success or not response then
        return false, "Не удалось подключиться к " .. url
    end
    
    local data = ""
    for chunk in response do
        data = data .. chunk
    end
    
    if #data < 100 then
        return false, "Файл слишком маленький, возможно ошибка загрузки"
    end
    
    local file_path = path or ("/home/" .. filename)
    local file = io.open(file_path, "w")
    if file then
        file:write(data)
        file:close()
        return true
    else
        return false, "Ошибка записи файла: " .. file_path
    end
end

local function createLauncher()
    local launcher = [[#!/bin/sh
echo "🚀 Запуск умной системы автокрафта AE2..."
cd /home
lua ac5.lua
]]
    
    local file = io.open("/home/autocraft", "w")
    if file then
        file:write(launcher)
        file:close()
        os.execute("chmod +x /home/autocraft")
        return true
    end
    return false
end

local function checkRequirements()
    print("🔍 Проверка требований...")
    
    if not component.isAvailable("internet") then
        print("❌ Требуется интернет-карта!")
        return false
    end
    
    if not component.isAvailable("me_interface") then
        print("⚠️  ME интерфейс не найден")
        print("   Программа установится, но для работы нужен ME интерфейс")
    end
    
    if filesystem.spaceTotal("/home") < 100000 then
        print("⚠️  Мало места на диске, но установка продолжится")
    end
    
    return true
end

local function installProgram()
    printHeader()
    print("🔄 Начинаем установку...")
    print("")
    
    print("1. Загрузка основной программы...")
    local success, err = downloadFile("ac5.lua")
    if not success then
        print("❌ Ошибка: " .. err)
        return false
    end
    print("   ✅ ac5.lua загружен")
    
    print("2. Создание ярлыка запуска...")
    if createLauncher() then
        print("   ✅ Ярлык 'autocraft' создан")
    else
        print("   ⚠️  Не удалось создать ярлык")
    end
    
    print("3. Загрузка дополнительных файлов...")
    downloadFile("installer.lua") 
    
    return true
end

local function showInstructions()
    print("")
    print("✅ Установка завершена!")
    print("")
    print("🚀 КОМАНДЫ ДЛЯ ЗАПУСКА:")
    print("   autocraft          - быстрый запуск")
    print("   lua /home/ac5.lua  - стандартный запуск")
    print("")
    print("📚 Исходный код: https://github.com/" .. GITHUB_USERNAME .. "/autocraft-ae2")
    print("")
    print("💡 ПЕРВЫЙ ЗАПУСК:")
    print("   1. Запустите программу: autocraft при помощи ввода в коммандную строку "" ac5.lua """)
    print("   2. Выполните 'Анализ ME системы' (пункт 6) Внимание! это запустит все доступные автокрафты по порядку!")
    print("   3. Добавьте нужные автокрафты (пункт 3)")
    print("   4. Запустите автокрафт (пункт 1) систему автоподдержания определённого числа предметов")
    print("")
    print("🔄 ОБНОВЛЕНИЕ:")
    print("   Для обновления запустите: lua /home/installer.lua update")
    print("")
end

local function updateProgram()
    printHeader()
    print("🔄 Обновление системы...")
    print("")
    
    if filesystem.exists("/home/ac5.lua") then
        os.execute("cp /home/ac5.lua /home/ac5_backup.lua 2>/dev/null")
        print("📦 Создана резервная копия: ac5_backup.lua")
    end
    
    local success, err = downloadFile("ac5.lua")
    if not success then
        print("❌ Ошибка обновления: " .. err)
        
        if filesystem.exists("/home/ac5_backup.lua") then
            os.execute("cp /home/ac5_backup.lua /home/ac5.lua 2>/dev/null")
            print("🔄 Восстановлена резервная копия")
        end
        return false
    end
    
    print("✅ Программа успешно обновлена!")
    return true
end

local function showMenu()
    printHeader()
    print("Выберите действие:")
    print("1 - 🚀 Установить программу")
    print("2 - 🔄 Обновить программу") 
    print("3 - ℹ️  Показать инструкции")
    print("4 - 🚪 Выход")
    print("")
    print("Ваш выбор:")
end

local function main()
    if not checkRequirements() then
        print("")
        print("❌ Установка прервана из-за ошибок")
        return
    end
    
    local args = {...}
    
    if args[1] == "install" then
        if installProgram() then
            showInstructions()
        end
        return
    elseif args[1] == "update" then
        updateProgram()
        return
    end
    
    while true do
        showMenu()
        local choice = io.read()
        
        if choice == "1" then
            if installProgram() then
                showInstructions()
            end
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "2" then
            if updateProgram() then
                print("Нажмите Enter для продолжения...")
                io.read()
            end
        elseif choice == "3" then
            printHeader()
            showInstructions()
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "4" then
            print("👋 Выход...")
            break
        else
            print("❌ Неверный выбор!")
            os.sleep(1)
        end
    end
end

local success, err = pcall(main)
if not success then
    print("❌ Критическая ошибка: " .. tostring(err))
    print("Попробуйте перезапустить установщик")
end
[file content end]