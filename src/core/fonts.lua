-- Pixel font yönetimi. Font: m5x7 (fonts/m5x7/m5x7.ttf).
-- m5x7 16 piksellik bir ızgaraya çizilmiş (1024 birim / 64 = 16): boyut 16'nın tam katı olmalı,
-- yoksa font pikselleri eşitsiz dağılır. Büyük harf/rakam yüksekliği 7 font pikseli.
-- UI ölçeğinde (Screen.uiScale) çizilir: font tam çözünürlükte yüklenir, 1/uiScale ile küçültülür.
local Screen = require("src.core.screen")

local Fonts = {}

Fonts.PATH = "fonts/m5x7/m5x7.ttf"
Fonts.GRID = 16       -- 1 font pikseli için font boyutu
Fonts.CAP = 7         -- büyük harf / rakam yüksekliği (font pikseli)

local cache = {}

-- path: font dosyası, px: piksel boyutu
function Fonts.get(px, path)
    path = path or Fonts.PATH
    local key = path .. ":" .. px
    if not cache[key] then
        local f = love.graphics.newFont(path, px, "mono")
        f:setFilter("nearest", "nearest")
        cache[key] = f
    end
    return cache[key]
end

-- Font pikseli başına kaç gerçek piksel: her zaman tam sayı.
-- mult=1: 1 font pikseli = 1 UI pikseli; mult=0.5: küçük yazı (rozet, açıklama).
local function realPx(mult)
    return math.max(1, math.floor((mult or 1) * Screen.uiScale + 0.5))
end

-- İstenen ölçeğin tam sayıya yuvarlanmış hali (UI birimi cinsinden): 1 font pikseli kaç UI pikseli
function Fonts.effMult(mult)
    return realPx(mult) / Screen.uiScale
end

function Fonts.ui(mult)
    return Fonts.get(Fonts.GRID * realPx(mult))
end

-- UI koordinatlarında metin yazar. x, y: metin kutusunun sol üstü. Dönen: genişlik (UI pikseli).
function Fonts.print(text, x, y, color, shadow, mult)
    local s = Screen.uiScale
    local font = Fonts.ui(mult)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    x, y = math.floor(x * s + 0.5) / s, math.floor(y * s + 0.5) / s   -- gerçek piksele yuvarla
    if shadow then
        love.graphics.setColor(shadow)
        love.graphics.print(text, x, y + Fonts.effMult(mult), 0, 1 / s, 1 / s)   -- 1 font pikseli aşağı
    end
    love.graphics.setColor(color or { 1, 1, 1, 1 })
    love.graphics.print(text, x, y, 0, 1 / s, 1 / s)
    love.graphics.setFont(prev)
    love.graphics.setColor(1, 1, 1, 1)
    return font:getWidth(text) / s
end

function Fonts.width(text, mult)
    return Fonts.ui(mult):getWidth(text) / Screen.uiScale
end

-- Büyük harflerin üst kenarının print y'sine göre kaç UI pikseli aşağıda olduğu.
-- Fontun gerçek yükseliğinden hesaplanır (LÖVE yükseliği ölçeğe göre farklı yuvarlıyor;
-- ölçüldü: 16px'te 4, 32px'te 8, 48px'te 11 gerçek piksel).
function Fonts.capTop(mult)
    return (Fonts.ui(mult):getAscent() - Fonts.CAP * realPx(mult)) / Screen.uiScale
end

-- Büyük harf yüksekliği (UI pikseli)
function Fonts.capHeight(mult)
    return Fonts.CAP * Fonts.effMult(mult)
end

-- Metni h yüksekliğindeki bir kutunun dikey ortasına koymak için print y'si
function Fonts.centerY(boxY, boxH, mult)
    local s = Screen.uiScale
    local top = boxY + (boxH - Fonts.capHeight(mult)) / 2
    top = math.floor(top * s + 0.5) / s
    return top - Fonts.capTop(mult)
end

return Fonts
