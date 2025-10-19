локальный компонент = требуется("компонент")
local internet = require("интернет")
 
не если компонент. доступен("в интернете") тогда 
    print("❌ Нужна интернет-карта")
    Возврат 
конец
 
print("🚀 Установка Autocraft AE2...")
 
local url = "https://raw.githubusercontent.com/0ptim1st-DK/autocraft-ae2/main/ac5.lua"
 
.."📥 Загрузка с: "( print url)
 
local success, response = pcall(internet.request, url)
не если успех то 
    (tostring.. "❌ Ошибка загрузки: " (printresponse))
    Возврат 
конец
 
локальные данные = ""
для фрагмента в ответе сделайте
 data = data .. tostring(фрагмент)
конец
 
#.."📊 Размер данных: " ( printdata .. " байт")
 
если данные: соответствуют("<!DOCTYPE") или данные: соответствуют("<html") или данные: соответствуют("404") то
    print("❌ Скачан HTML вместо кода на Lua!")
    print("Первые 200 символов:")
    (printdata:sub(1, 200))
    Возврат
конец
 
# если данные < 10 тогда
    print("❌ Файл слишком маленький")
    Возврат
конец
 
local file = io.open("/home/ac5.lua", "w")
не если файл то 
    print("❌ Ошибка при записи файла")
    Возврат 
конец
файл:запись(данные)
файл:закрыть()
 
print("✅ Файл сохранён")
 
local check = loadfile("/home/ac5.lua")
не если проверка то
    print("❌ Ошибка синтаксиса!")
    — Покажем начало файла для диагностики
    local f = io.open("/home/ac5.lua", "r")
    если f то
        print("Первые 5 строк файла:")
        for i = 1, 5 do
            local line = f:read("*l")
            если строка то 
                (printi .. ": " .. строка:sub(1, 100))
            конец
        конец
 f:close()
    конец
    Возврат
конец
 
print("✅ Синтаксис верный!")
 
local launcher = io.open("/home/autocraft", "w")
если лаунчер то 
 лаунчер:write('lua /home/ac5.lua\n')
 лаунчер:закрыть()
    os.execute("chmod +x /home/autocraft 2>/dev/null")
    print("✅ Скрипт запуска создан")
конец
 
print("🎉 Установка завершена!")
print("Запуск: ac5.lua")
