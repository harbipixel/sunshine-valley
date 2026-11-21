-- Tarla: çimin üstünde toprak alan + kürekle açılan ekim çukurları.
-- Toprak zemini ortak toprak katmanına (src/world/dirt.lua) yuvarlak köşeli dikdörtgen olarak eklenir;
-- böylece kasaba yollarıyla kesintisiz birleşir.
-- Ekim çukurları Elements/Crops/soil_*: 00 = boş sürülmüş, 01 = sulanmış, 03 = küçük çukur, 04 = derin çukur.
local Assets = require("src.core.assets")
local Crops  = require("src.game.crops")

local Farm = {}
Farm.__index = Farm

local S = 16
Farm.MARGIN = 6          -- ekim hücrelerinin çevresindeki toprak payı (px)
Farm.RADIUS = 6          -- köşe yuvarlaklığı (px)

local SOIL = {}
for _, n in ipairs({ "00", "01", "03", "04" }) do SOIL[n] = "Elements/Crops/soil_" .. n .. ".png" end

-- cx, cy: sol üst ekim hücresi; cols x rows ekim hücresi; dirt: ortak toprak katmanı
-- price verilirse tarla kilitli başlar: kesikli çerçeve + ortada fiyat tabelası, Farm:unlock ile açılır.
function Farm.new(map, cx, cy, cols, rows, dirt, price)
    local self = setmetatable({ map = map, cx = cx, cy = cy, cols = cols, rows = rows, plots = {},
                                dirt = dirt, price = price, locked = price ~= nil }, Farm)
    local m = Farm.MARGIN
    self.px, self.py = cx * S - m, cy * S - m
    self.pw, self.ph = cols * S + 2 * m, rows * S + 2 * m
    if self.locked then
        -- tabela tarlanın ortasında; direğinin dibi yürünemez
        self.signX, self.signY = math.floor(self.px + self.pw / 2), math.floor(self.py + self.ph / 2) + 6
        self.signSolid = map:addSolid(self.signX - 3, self.signY - 4, 6, 4)
    else
        dirt:add(self.px, self.py, self.pw, self.ph, Farm.RADIUS)
    end
    -- tarla dekora kapalı (1 hücre pay), üstünde yürünebilir
    map:reserveRect(self.px, self.py, self.pw, self.ph, 1)
    return self
end

-- Kilidi aç: toprak katmanına eklenir ve katman yeniden pişirilir
function Farm:unlock()
    if not self.locked then return end
    self.locked = false
    self.map:removeSolid(self.signSolid)
    self.dirt:add(self.px, self.py, self.pw, self.ph, Farm.RADIUS)
    self.dirt:bake()
end

-- Oyuncu tabelanın yanında mı?
function Farm:nearSign(x, y, r)
    r = r or 20
    return self.locked and math.abs(x - self.signX) <= r and math.abs(y - self.signY) <= r
end

-- Noktanın bulunduğu ekim hücresi (tarla dışında veya kilitliyse nil)
function Farm:cellAt(px, py)
    if self.locked then return nil end
    local x, y = math.floor(px / S), math.floor(py / S)
    if x < self.cx or y < self.cy or x >= self.cx + self.cols or y >= self.cy + self.rows then return nil end
    return x, y
end

local function key(x, y) return x .. "," .. y end

function Farm:plotAt(x, y) return self.plots[key(x, y)] end

-- Noktadaki çukur (yoksa nil)
function Farm:plotAtPoint(px, py)
    local x, y = self:cellAt(px, py)
    return x and self:plotAt(x, y)
end

-- Kazılabilir mi? Tarlada ve hücre boş ya da hasattan kalan sürülmüş toprak (soil_00, ürünsüz).
function Farm:canDig(px, py)
    local x, y = self:cellAt(px, py)
    if not x then return false end
    local p = self:plotAt(x, y)
    return p == nil or (p.soil == "00" and not p.crop)
end

-- Kürek toprağa girdiğinde çukur açar. Dönen: çukur (kazılamıyorsa nil).
function Farm:dig(px, py)
    if not self:canDig(px, py) then return nil end
    local x, y = self:cellAt(px, py)
    local plot = self:plotAt(x, y) or { x = x, y = y }
    plot.soil = "03"
    self.plots[key(x, y)] = plot
    return plot
end

-- Tohum ekilebilir mi? (açık çukur, ürünsüz)
function Farm:canPlant(px, py)
    local p = self:plotAtPoint(px, py)
    return p ~= nil and p.soil == "04" and not p.crop
end

function Farm:plant(px, py, cropId)
    if not self:canPlant(px, py) then return false end
    local p = self:plotAtPoint(px, py)
    p.crop = { id = cropId, stage = 1, timer = 0 }
    p.soil = "00"   -- tohum örtüldü
    return true
end

-- Olgun ürünü toplar. Dönen: envantere girecek eşya id'si (yoksa nil). Hücre sürülmüş toprak olarak kalır.
function Farm:harvest(px, py)
    local p = self:plotAtPoint(px, py)
    if not (p and p.crop and Crops.isRipe(p.crop)) then return nil end
    local item = Crops.get(p.crop.id).harvest
    p.crop = nil
    return item, p
end

function Farm:update(dt)
    for _, p in pairs(self.plots) do
        local c = p.crop
        if c and not Crops.isRipe(c) then
            c.timer = c.timer + dt
            if c.timer >= Crops.get(c.id).stageTime then
                c.timer, c.stage = 0, c.stage + 1
            end
        end
    end
end

-- Tabela: çit direği (tileset 656,48) üstünde tahta pano (tileset 718,162)
local SIGN_POST  = { 656, 48, 16, 16 }
local SIGN_BOARD = { 718, 162, 20, 13 }
local quads = {}
local function tq(r)
    local img = Assets.image("Tileset/spr_tileset_sunnysideworld_16px.png")
    local k = r[1] .. "," .. r[2]
    quads[k] = quads[k] or love.graphics.newQuad(r[1], r[2], r[3], r[4], img:getDimensions())
    return img, quads[k]
end

function Farm:drawSign()
    love.graphics.setColor(1, 1, 1)
    local img, q = tq(SIGN_POST)
    love.graphics.draw(img, q, self.signX - 8, self.signY - 13)
    img, q = tq(SIGN_BOARD)
    love.graphics.draw(img, q, self.signX - 10, self.signY - 20)
end

-- Ürünler y-sort'a girer (oyuncu arkalarından geçebilsin). Dip noktası çukurun ortası.
function Farm:addDrawables(list)
    if self.locked then
        list[#list + 1] = { y = self.signY, draw = function() self:drawSign() end }
        return
    end
    for _, p in pairs(self.plots) do
        if p.crop then
            local bx, by = p.x * S + S / 2, p.y * S + 10
            list[#list + 1] = { y = by, draw = function()
                local img = Crops.image(p.crop)
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(img, bx - math.floor(img:getWidth() / 2), by - img:getHeight())
            end }
        end
    end
end

-- Kilitli tarlanın sınırı: kesikli çizgi (toprak kenarı renginde)
local DASH, GAP = 4, 3
function Farm:drawOutline()
    love.graphics.setColor(188 / 255, 121 / 255, 92 / 255, 0.85)
    local x0, y0, x1, y1 = self.px, self.py, self.px + self.pw - 1, self.py + self.ph - 1
    for x = x0 + 2, x1 - 2, DASH + GAP do
        local w = math.min(DASH, x1 - 1 - x)
        love.graphics.rectangle("fill", x, y0, w, 1)
        love.graphics.rectangle("fill", x, y1, w, 1)
    end
    for y = y0 + 2, y1 - 2, DASH + GAP do
        local h = math.min(DASH, y1 - 1 - y)
        love.graphics.rectangle("fill", x0, y, 1, h)
        love.graphics.rectangle("fill", x1, y, 1, h)
    end
end

-- Zemin katmanı: dünya zemininden sonra, y-sort'tan önce çizilir
function Farm:draw()
    if self.locked then return self:drawOutline() end
    love.graphics.setColor(1, 1, 1)
    for _, p in pairs(self.plots) do
        local img = Assets.image(SOIL[p.soil])
        -- 16x12 sprite hücrenin dikey ortasında
        love.graphics.draw(img, p.x * S, p.y * S + math.floor((S - img:getHeight()) / 2))
    end
end

-------------------------------------------------------------------------------
-- Tarla grubu: birden çok tarlayı tek tarla gibi gösterir (oyuncu tek nesneyle konuşur).
-- Noktalı çağrılar o noktadaki tarlaya gider.
-------------------------------------------------------------------------------
local Group = {}
Group.__index = Group

function Farm.group(list) return setmetatable({ list = list }, Group) end

function Group:at(px, py)
    for _, f in ipairs(self.list) do
        if f:cellAt(px, py) then return f end
    end
end

for _, name in ipairs({ "plotAtPoint", "canDig", "dig", "canPlant", "plant", "harvest" }) do
    Group[name] = function(self, px, py, ...)
        local f = self:at(px, py)
        if f then return f[name](f, px, py, ...) end
    end
end

for _, name in ipairs({ "update", "addDrawables", "draw" }) do
    Group[name] = function(self, ...)
        for _, f in ipairs(self.list) do f[name](f, ...) end
    end
end

-- Oyuncunun yanında durduğu kilitli tarla (yoksa nil)
function Group:lockedNear(x, y)
    for _, f in ipairs(self.list) do
        if f:nearSign(x, y) then return f end
    end
end

return Farm
