-- Ekranda sürekli görünen bilgiler. Şimdilik: sol üstte para.
-- UI koordinatlarında çizilir (Screen.applyUI içinde).
local Assets    = require("src.core.assets")
local Fonts     = require("src.core.fonts")
local NineSlice = require("src.ui.nineslice")
local Items     = require("src.game.items")

local Hud = {}
Hud.__index = Hud

-- Altın para ikonu (tileset 883,451, 10x10)
local COIN = { 883, 451, 10, 10 }
local TILESET = "Tileset/spr_tileset_sunnysideworld_16px.png"

local SHADOW = { 24 / 255, 20 / 255, 37 / 255, 0.8 }

function Hud.new(inventory)
    local self = setmetatable({ inventory = inventory, shown = inventory.money, bump = 0 }, Hud)
    local img = Assets.image(TILESET)
    self.coinImg = img
    self.coinQuad = love.graphics.newQuad(COIN[1], COIN[2], COIN[3], COIN[4], img:getDimensions())
    return self
end

function Hud:update(dt)
    -- para değişince sayı hızlıca sayarak yaklaşır ve kutu bir an zıplar
    local target = self.inventory.money
    if self.shown ~= target then
        local diff = target - self.shown
        local step = math.max(1, math.floor(math.abs(diff) * dt * 8))
        self.shown = self.shown + (diff > 0 and math.min(step, diff) or math.max(-step, diff))
        self.bump = 0.15
    end
    self.bump = math.max(0, self.bump - dt)
end

-- Para biçimi:
--   0 - 9,999          -> "9,999" (binlik ayraç)
--   10,000 - 999,999   -> "10.5K", 100K üstünde ondalıksız "250K"
--   1,000,000 ve üstü  -> "1.2M" (aynı kural)
function Hud.formatMoney(n)
    local function short(v, suffix)
        local s = v < 100 and ("%.1f"):format(math.floor(v * 10) / 10) or tostring(math.floor(v))
        return (s:gsub("%.0$", "")) .. suffix
    end
    if n >= 1000000 then return short(n / 1000000, "M") end
    if n >= 10000 then return short(n / 1000, "K") end
    local s = tostring(math.floor(n))
    return (s:reverse():gsub("(%d%d%d)(%d)", "%1,%2"):reverse())
end

local PAD = 4

function Hud:draw()
    local text = Hud.formatMoney(self.shown)
    -- font son harften sonra 1 font pikseli boşluk bırakır; çıkarınca iki yan eşit olur
    local tw = math.ceil(Fonts.width(text) - Fonts.effMult())
    local x, y = 4, 4 - (self.bump > 0 and 1 or 0)
    local w, h = PAD + COIN[3] + 3 + tw + PAD, 16

    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(x, y, w, h)
    local iy = y + math.floor((h - COIN[4]) / 2)
    love.graphics.draw(self.coinImg, self.coinQuad, x + PAD, iy)
    -- rakamlar ikonla aynı dikey merkezde
    Fonts.print(text, x + PAD + COIN[3] + 3, Fonts.centerY(iy, COIN[4]), { 1, 1, 1 }, SHADOW)

    self:drawSeed(4, 4 + h + 3)
end

-- Paranın altında: ekilecek tohum (C ile değişir) ve adedi. Tohum yoksa gizli.
function Hud:drawSeed(x, y)
    local id = self.player and self.player:seed()
    if not id then return end
    local icon = Assets.image(Items.get(id).icon)
    local text = "x" .. self.inventory:count(id)
    local tw = math.ceil(Fonts.width(text) - Fonts.effMult())
    local w, h = PAD + 10 + 3 + tw + PAD, 16
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(x, y, w, h)
    love.graphics.draw(icon, x + PAD + math.floor((10 - icon:getWidth()) / 2), y + math.floor((h - icon:getHeight()) / 2))
    Fonts.print(text, x + PAD + 10 + 3, Fonts.centerY(y + 3, 10), { 1, 1, 1 }, SHADOW)
end

return Hud
