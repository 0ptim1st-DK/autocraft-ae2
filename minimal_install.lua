-- Минимальный установщик Autocraft AE2
local i=require("internet")local c=component
if not c.isAvailable("internet")then print("❌ Нужна интернет-карта")return end
print("🚀 Установка Autocraft AE2...")
local u="https://raw.githubusercontent.com/YOUR_USERNAME/autocraft-ae2/main/ac5.lua"
local s,r=pcall(i.request,u)if not s then print("❌ Ошибка загрузки")return end
local d=""for c in r do d=d..c end
local f=io.open("/home/ac5.lua","w")if not f then print("❌ Ошибка записи")return end
f:write(d)f:close()
local L=io.open("/home/autocraft","w")if L then L:write('lua /home/ac5.lua\n')L:close()end
os.execute("chmod +x /home/autocraft 2>/dev/null")
print("✅ Установлено! Запуск: lua /home/ac5.lua")