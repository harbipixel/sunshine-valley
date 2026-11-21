-- Toprak zemin katmanı: tarla + kasaba yolları tek görüntü olarak üretilir (birleşim yerlerinde iç kenar çizgisi olmaz).
-- Şekiller yuvarlak köşeli dikdörtgenler; birleşimleri tek maske olur.
-- Görünüm (örnek sahnedeki gibi): toprak karosu (1,7) + 16px bloklarda benekli varyasyonlar,
-- toprak tarafında 1px koyu toprak (188,121,92), çim tarafında 1px koyu yeşil (84,178,99) kenar.
local Assets = require("src.core.assets")

local Dirt = {}
Dirt.__index = Dirt

local S = 16
local DIRT       = { 1, 7 }
local SPECKLED   = { { 9, 7 }, { 10, 7 }, { 11, 7 }, { 9, 8 }, { 10, 8 } }
local EDGE_DIRT  = { 188 / 255, 121 / 255, 92 / 255, 1 }
local EDGE_GRASS = { 84 / 255, 178 / 255, 99 / 255, 1 }
Dirt.SPECKLE_CHANCE = 0.3

function Dirt.new(seed)
    return setmetatable({ shapes = {}, seed = seed or 1 }, Dirt)
end

-- Piksel dikdörtgeni (x, y, w, h), köşe yarıçapı r
function Dirt:add(x, y, w, h, r)
    self.shapes[#self.shapes + 1] = { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h), r = r or 0 }
end

local function insideShape(s, x, y)
    x, y = x - s.x, y - s.y
    if x < 0 or y < 0 or x >= s.w or y >= s.h then return false end
    local r = s.r
    if r <= 0 then return true end
    local dx = (x < r) and (r - x - 0.5) or (x >= s.w - r) and (x - (s.w - r) + 0.5) or 0
    local dy = (y < r) and (r - y - 0.5) or (y >= s.h - r) and (y - (s.h - r) + 0.5) or 0
    return dx * dx + dy * dy <= r * r
end

-- Tüm şekilleri tek görüntüye pişirir. self.image, self.ox, self.oy (dünya konumu)
function Dirt:bake()
    if #self.shapes == 0 then return end
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, s in ipairs(self.shapes) do
        x0, y0 = math.min(x0, s.x), math.min(y0, s.y)
        x1, y1 = math.max(x1, s.x + s.w), math.max(y1, s.y + s.h)
    end
    x0, y0, x1, y1 = x0 - 1, y0 - 1, x1 + 1, y1 + 1   -- dış kenar için 1px pay
    local w, h = x1 - x0, y1 - y0

    -- maske (dünya koordinatından bağımsız dizi)
    local mask = {}
    for y = 0, h - 1 do
        local row = {}
        for x = 0, w - 1 do
            local wx, wy, v = x0 + x, y0 + y, false
            for _, s in ipairs(self.shapes) do
                if insideShape(s, wx, wy) then v = true; break end
            end
            row[x] = v
        end
        mask[y] = row
    end
    local function m(x, y) return y >= 0 and y < h and x >= 0 and x < w and mask[y][x] end

    -- 16px bloklar (dünya ızgarasına hizalı) için kararlı rastgele seçim
    local tiles = love.image.newImageData(Assets.path("Tileset/spr_tileset_sunnysideworld_16px.png"))
    local blocks = {}
    local rng = love.math.newRandomGenerator(self.seed)
    local function block(bx, by)
        local k = bx .. "," .. by
        if not blocks[k] then
            blocks[k] = rng:random() < Dirt.SPECKLE_CHANCE and SPECKLED[rng:random(#SPECKLED)] or DIRT
        end
        return blocks[k]
    end

    local img = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if mask[y][x] then
                if not (m(x - 1, y) and m(x + 1, y) and m(x, y - 1) and m(x, y + 1)) then
                    img:setPixel(x, y, unpack(EDGE_DIRT))
                else
                    local wx, wy = x0 + x, y0 + y
                    local t = block(math.floor(wx / S), math.floor(wy / S))
                    img:setPixel(x, y, tiles:getPixel(t[1] * S + wx % S, t[2] * S + wy % S))
                end
            else
                local near = false
                for oy = -1, 1 do
                    for ox = -1, 1 do
                        if m(x + ox, y + oy) then near = true end
                    end
                end
                if near then img:setPixel(x, y, unpack(EDGE_GRASS)) end
            end
        end
    end
    self.image, self.ox, self.oy = love.graphics.newImage(img), x0, y0
end

function Dirt:draw()
    if not self.image then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, self.ox, self.oy)
end

return Dirt
