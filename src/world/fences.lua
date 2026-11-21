-- Çitler: hücre tabanlı, komşulara göre otomatik bağlanır.
-- Tüm çitler önce bir canvas'a çizilir, sonra birleşik şeklin etrafına koyu dış çizgi eklenir
-- (referans görünümdeki gibi). Y-sort için canvas satır satır dilimlenerek çizilir.
local Assets = require("src.core.assets")
local Gfx    = require("src.core.gfx")

local Fences = {}
Fences.__index = Fences

local TILE = 16

-- Tileset parçaları (kolon, satır). Her parçada ortada direk + belirtilen yönlere ray var.
-- Köşe/T bağlantıları yatay ve dikey parçalar üst üste çizilerek elde edilir.
local H = { e = { 38, 2 }, w = { 42, 2 }, ew = { 39, 2 } }
local V = { s = { 40, 1 }, n = { 40, 4 }, ns = { 40, 3 } }
local POST = { 41, 3 }

function Fences.new(map)
    local self = setmetatable({ map = map, cells = {} }, Fences)
    for y = 0, map.rows - 1 do self.cells[y] = {} end
    return self
end

function Fences:has(x, y)
    return self.cells[y] ~= nil and self.cells[y][x] == true
end

function Fences:add(x, y)
    if self.map:inBounds(x, y) then self.cells[y][x] = true end
end

-- Kıyı boyunca çit: yar veya suya (çapraz dahil) komşu olan her çim hücresi.
-- İskelenin başına komşu hücreler atlanır, böylece iskeleye geçiş açık kalır.
function Fences:autoShore()
    local map = self.map
    for y = 0, map.rows - 1 do
        for x = 0, map.cols - 1 do
            if map.kind[y][x] == "grass" and not map.dock[y][x] then
                local nearShore, nearDock = false, false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx, ny = x + dx, y + dy
                        if map:inBounds(nx, ny) then
                            local k = map.kind[ny][nx]
                            if map.dock[ny][nx] then nearDock = true end
                            if k == "cliff" or k == "sea" then nearShore = true end
                        end
                    end
                end
                if nearShore and not nearDock then self:add(x, y) end
            end
        end
    end
end

-- Çarpışma görselin dibine oturur (bütün hücre değil): direk dibi + bağlı yönlere raylar.
-- Parçalar ölçüldü: direk x 5..11, yatay rayların dibi y 7..12, dikey ray tüm yükseklik.
local POST_X, POST_W = 5, 6
local BAND_Y, BAND_H = 7, 5
function Fences:addCollision(x, y, n, s, w, e)
    local map, px, py = self.map, x * TILE, y * TILE
    map:addSolid(px + POST_X, py + BAND_Y, POST_W, BAND_H)                                   -- direk
    if w then map:addSolid(px, py + BAND_Y, POST_X, BAND_H) end                              -- batı rayı
    if e then map:addSolid(px + POST_X + POST_W, py + BAND_Y, TILE - POST_X - POST_W, BAND_H) end
    if n then map:addSolid(px + POST_X, py, POST_W, BAND_Y) end                              -- kuzey rayı
    if s then map:addSolid(px + POST_X, py + BAND_Y + BAND_H, POST_W, TILE - BAND_Y - BAND_H) end
    map:reserve(x, y)   -- çit hücresine dekor konmaz
end

function Fences:build()
    local map = self.map
    local tileset = Assets.image(map.TILESET)
    self.rows = {}

    self.canvas = Gfx.bakeOutlined(map.width, map.height, function()
        for y = 0, map.rows - 1 do
            for x = 0, map.cols - 1 do
                if self:has(x, y) then
                    self.rows[y] = true
                    local n, s = self:has(x, y - 1), self:has(x, y + 1)
                    local w, e = self:has(x - 1, y), self:has(x + 1, y)
                    local v = (n and s and V.ns) or (s and V.s) or (n and V.n)
                    local h = (e and w and H.ew) or (e and H.e) or (w and H.w)
                    local px, py = x * TILE, y * TILE
                    -- Önce yatay, sonra dikey: yatay parçanın yarı saydam gölgesi köşede
                    -- dikey rayın üstüne düşüp koyu çizgi bırakmasın
                    if h then love.graphics.draw(tileset, map:quad(h), px, py) end
                    if v then love.graphics.draw(tileset, map:quad(v), px, py) end
                    if not v and not h then love.graphics.draw(tileset, map:quad(POST), px, py) end
                    self:addCollision(x, y, n, s, w, e)
                end
            end
        end
    end)

    -- Her çit satırı için bir dilim (y-sort için)
    self.slices = {}
    for y in pairs(self.rows) do
        self.slices[#self.slices + 1] = {
            y = y * TILE + 12,   -- direğin dibi
            quad = love.graphics.newQuad(0, y * TILE, map.width, TILE, map.width, map.height),
            py = y * TILE,
        }
    end
end

-- Y-sort listesine her çit satırını ayrı çizilebilir olarak ekler
function Fences:addDrawables(list)
    for _, s in ipairs(self.slices) do
        list[#list + 1] = { y = s.y, draw = function()
            love.graphics.setBlendMode("alpha", "premultiplied")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.canvas, s.quad, 0, s.py)
            love.graphics.setBlendMode("alpha")
        end }
    end
end

return Fences
