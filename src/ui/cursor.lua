-- Donanım fare imleci: tileset'teki ok (UI/cursor_02.png ile aynı, 11x14).
-- İşletim sistemi imleci ölçeklemediği için UI ölçeğine göre büyütülmüş kopyası üretilir.
-- Donanım imleci gecikmesizdir (yazılımsal imleç bir kare geriden gelir).
local Assets = require("src.core.assets")
local Screen = require("src.core.screen")

local Cursor = {}

Cursor.IMAGE = "UI/cursor_02.png"
Cursor.HOT_X, Cursor.HOT_Y = 0, 0   -- okun ucu sol üst pikselde

local current = {}

function Cursor.apply()
    local s = Screen.uiScale   -- imleç UI ile aynı ölçekte
    if current.scale == s then return end
    local src = love.image.newImageData(Assets.path(Cursor.IMAGE))
    local w, h = src:getDimensions()
    local big = love.image.newImageData(w * s, h * s)
    big:mapPixel(function(x, y) return src:getPixel(math.floor(x / s), math.floor(y / s)) end)
    local ok, cur = pcall(love.mouse.newCursor, big, Cursor.HOT_X * s, Cursor.HOT_Y * s)
    if not ok then
        print("Cursor: newCursor failed: " .. tostring(cur))
        return
    end
    love.mouse.setCursor(cur)
    current = { scale = s, cursor = cur }end

return Cursor
