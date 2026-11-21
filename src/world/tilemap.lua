-- Sunnyside 16px tileset üzerinde grid harita: kara + deniz + iskele.
-- Görünüm örnek sahnedeki gibi: çim -> toprak yar -> beyaz köpük -> koyu mavi deniz.
-- İki SpriteBatch kullanılır: zemin (ground) ve onun üstüne bindirilen katman (overlay).
-- İleride Tiled + STI'ye geçilebilir.
local Assets = require("src.core.assets")
local Gfx    = require("src.core.gfx")

local Tilemap = {}
Tilemap.__index = Tilemap

Tilemap.TILE = 16
Tilemap.TILESET = "Tileset/spr_tileset_sunnysideworld_16px.png"

-- Tileset içindeki (kolon, satır) konumları - 0 tabanlı
local T = {
    grass        = { 2, 1 },   -- (1,1) bir ton koyu, detay karolarıyla uyuşmuyor
    grass_detail = { { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 }, { 5, 2 }, { 6, 2 } },
    grass_edge_s = { 25, 7 },  -- alt kenarında koyu çizgi: yarın hemen üstündeki çim
    grass_edge_e = { 27, 7 },  -- sağ kenarında koyu çizgi: doğusu su
    grass_edge_w = { 24, 8 },  -- sol kenarında koyu çizgi: batısı su
    cliff        = { 11, 3 },  -- toprak yar yüzü

    sea0         = { 11, 18 }, -- dokulu deniz (4x4 blok). Kullanılmıyor: deniz shader ile çiziliyor

    -- deniz üstüne bindirilen yarı saydam karolar
    foam_n       = { 23, 2 },  -- kuzeyde yar varken köpük + gölge
    shade_w      = { 19, 3 },  -- batıda kara varken koyu şerit
    shade_e      = { 24, 3 },  -- doğuda kara varken koyu şerit
    shade_we     = { 25, 2 },  -- iki yanda kara
}
Tilemap.TILES = T

-- İskele: tileset'te 2 satırlık parça (tahta + iki yanda direkler). Piksel bölgeleri.
-- Direkli 2 satırlık parça (632,80,32,32) üçe bölünür: sol kazık | tahta | sağ kazık
local DOCK_SEG_POST_L = { 632, 80, 8, 32 }
local DOCK_SEG_PLANK  = { 640, 80, 16, 32 }
local DOCK_SEG_POST_R = { 656, 80, 8, 32 }
local DOCK_PLANK      = { 640, 96, 16, 16 }   -- tek tahta

-- Hareketli deniz: düz taban mavisi + kayan koyu dalga lekeleri (referans görünümün renkleri).
-- Desen oyun pikseline yuvarlanır, böylece pixel art gibi keskin görünür.
local seaShader = love.graphics.newShader([[
    extern float time;
    extern vec2 size;
    const vec3 BASE = vec3(0.0, 153.0, 219.0) / 255.0;
    const vec3 DARK = vec3(30.0, 109.0, 213.0) / 255.0;

    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float noise(vec2 p) {
        vec2 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
    }

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec2 p = floor(uv * size);                       // dünya pikseli
        float row = floor(p.y / 3.0);
        float x = p.x + floor(time * 3.0)                // yavaş akıntı
                + floor(sin(row * 0.9 + time * 1.3) * 2.0); // satır satır dalgalanma
        float n = noise(vec2(x / 16.0, p.y / 5.0)) * 0.85
                + noise(vec2(x / 6.0, p.y / 3.0) + 17.0) * 0.15;
        return vec4(n > 0.70 ? DARK : BASE, 1.0);
    }
]])

-- Kısa yar karosu (referanstaki gibi ~yarım karo yüksekliğinde). Tileset'te hazırı yok;
-- yüklenirken tileset piksellerinden üretilir:
--   satır 0   : kırmızı üst çizgi (tileset'in yar kenarlarındaki renk)
--   satır 1-5 : toprak dalga deseni (yar karosu (11,3) satır 2-6)
--   satır 6-7 : köpük (köpük karosu (23,2) satır 2-3)
--   satır 8   : koyu su şeridi
--   satır 9+  : saydam -> altındaki deniz görünür
Tilemap.CLIFF_WATER_Y = 9
local CLIFF_RED  = { 171 / 255, 53 / 255, 32 / 255 }
local CLIFF_DARK = { 30 / 255, 109 / 255, 213 / 255 }

local function makeShortCliff()
    local src = love.image.newImageData(Assets.path(Tilemap.TILESET))
    local S = Tilemap.TILE
    local d = love.image.newImageData(S, S)
    local function copyRow(srcTile, srcRow, dstRow)
        for x = 0, S - 1 do
            d:setPixel(x, dstRow, src:getPixel(srcTile[1] * S + x, srcTile[2] * S + srcRow))
        end
    end
    for x = 0, S - 1 do
        d:setPixel(x, 0, CLIFF_RED[1], CLIFF_RED[2], CLIFF_RED[3], 1)
        d:setPixel(x, 8, CLIFF_DARK[1], CLIFF_DARK[2], CLIFF_DARK[3], 1)
    end
    for i = 0, 4 do copyRow({ 11, 3 }, 2 + i, 1 + i) end
    for i = 0, 1 do copyRow({ 23, 2 }, 2 + i, 6 + i) end
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    return img
end

function Tilemap.new(cols, rows, seed)
    local self = setmetatable({ cols = cols, rows = rows, seed = seed or 1 }, Tilemap)
    self.image = Assets.image(Tilemap.TILESET)
    self.quadCache = {}
    self.ground  = love.graphics.newSpriteBatch(self.image, cols * rows, "static")
    self.overlay = love.graphics.newSpriteBatch(self.image, cols * rows, "static")
    self.cliffs  = love.graphics.newSpriteBatch(makeShortCliff(), cols * rows, "static")
    self.width, self.height = cols * Tilemap.TILE, rows * Tilemap.TILE
    self.land, self.dock, self.kind, self.blocked, self.reserved = {}, {}, {}, {}, {}
    self.solids = {}   -- hücreden bağımsız engeller (ağaç gövdeleri): { x, y, w, h }
    for y = 0, rows - 1 do
        self.land[y], self.dock[y], self.kind[y], self.blocked[y], self.reserved[y] = {}, {}, {}, {}, {}
        for x = 0, cols - 1 do self.land[y][x] = true end
    end
    self.docks = {}
    self.time = 0
    local px = love.image.newImageData(1, 1)
    px:setPixel(0, 0, 1, 1, 1, 1)
    self.pixel = love.graphics.newImage(px)   -- 1x1 beyaz: deniz shader'ı ve dama deseni için
    self.checker = love.graphics.newSpriteBatch(self.pixel, cols * rows, "static")
    return self
end

-- Damalı zemin: çim hücrelerinin yarısı bir ton koyu. Oran, tileset'in iki düz çim karosu
-- (1,1)=(95,193,76) ve (2,1)=(99,199,77) arasındaki farkla aynı (referans görseldeki desen).
Tilemap.CHECKER_TINT = { 95 / 99, 193 / 199, 76 / 77, 1 }
Tilemap.CHECKER = true    -- false yapınca düz zemin

function Tilemap:update(dt)
    self.time = self.time + dt
end

function Tilemap:quad(t)
    local key = t[1] .. "," .. t[2]
    local q = self.quadCache[key]
    if not q then
        local s = Tilemap.TILE
        q = love.graphics.newQuad(t[1] * s, t[2] * s, s, s, self.image:getDimensions())
        self.quadCache[key] = q
    end
    return q
end

function Tilemap:pixelQuad(r)
    local key = table.concat(r, ",")
    local q = self.quadCache[key]
    if not q then
        q = love.graphics.newQuad(r[1], r[2], r[3], r[4], self.image:getDimensions())
        self.quadCache[key] = q
    end
    return q
end

function Tilemap:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.cols and y < self.rows
end

-- Harita dışı kara sayılır (kenarlarda yar oluşmasın diye)
function Tilemap:isLand(x, y)
    if not self:inBounds(x, y) then return true end
    return self.land[y][x] == true
end

---------------------------------------------------------------------------
-- Harita kurma
---------------------------------------------------------------------------

-- Her x kolonu için suyun başladığı satırı verir: coast(x) -> satır.
-- O satırdan aşağısı deniz olur. Yar için suyun üstünde en az 2 kara satırı kalmalı.
function Tilemap:setCoast(coast)
    for x = 0, self.cols - 1 do
        local c = coast(x)
        for y = 0, self.rows - 1 do self.land[y][x] = y < c end
    end
end

-- x kolonunda, yardan başlayıp `length` hücre denize uzanan iskele
function Tilemap:addDock(x, length)
    local top
    for y = 0, self.rows - 1 do
        if not self.land[y][x] then top = y - 1; break end
    end
    assert(top and top >= 1, "addDock: no shoreline found in this column")
    for y = top, math.min(self.rows - 1, top + length) do self.dock[y][x] = true end
    self.docks[#self.docks + 1] = { x = x, y0 = top, y1 = math.min(self.rows - 1, top + length) }
end

-- Hücreyi yürünemez yap (çit, kaya vb.)
function Tilemap:block(x, y)
    if self:inBounds(x, y) then self.blocked[y][x] = true end
end

-- Hücreyi dekor yerleştirmeye kapat (yürünebilir kalır; bina çatısı, yol vb.)
function Tilemap:reserve(x, y)
    if self:inBounds(x, y) then self.reserved[y][x] = true end
end

-- Piksel dikdörtgenini kaplayan hücreleri ayır; margin: hücre cinsinden pay
function Tilemap:reserveRect(px, py, w, h, margin)
    margin = margin or 0
    local S = Tilemap.TILE
    for y = math.floor(py / S) - margin, math.floor((py + h - 1) / S) + margin do
        for x = math.floor(px / S) - margin, math.floor((px + w - 1) / S) + margin do
            self:reserve(x, y)
        end
    end
end

local function classify(self, x, y)
    if not self.land[y][x] then return "sea" end
    if not self:isLand(x, y + 1) then return "cliff" end
    return "grass"
end

function Tilemap:build()
    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do self.kind[y][x] = classify(self, x, y) end
    end

    local rng = love.math.newRandomGenerator(self.seed)
    local g, o, c = self.ground, self.overlay, self.cliffs
    g:clear(); o:clear(); c:clear(); self.checker:clear()
    local S, HALF = Tilemap.TILE, Tilemap.TILE / 2

    -- Kara kenarına bitişik suya koyu şerit. Komşu tam karaysa tüm yükseklik,
    -- kısa yarsa sadece üst yarı (yarın alt yarısı zaten su). y0..y1: hücre içi piksel aralığı.
    local function shade(x, y, px, py, y0, y1)
        for _, side in ipairs({ { x - 1, T.shade_w }, { x + 1, T.shade_e } }) do
            local k = self:inBounds(side[1], y) and self.kind[y][side[1]] or "grass"
            local limit = (k == "grass" and S) or (k == "cliff" and HALF) or 0   -- komşunun kara olduğu derinlik
            local bottom = math.min(y1, limit)
            if bottom > y0 then
                local t = side[2]
                o:add(self:pixelQuad({ t[1] * S, t[2] * S + y0, S, bottom - y0 }), px, py + y0)
            end
        end
    end

    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do
            local k, px, py = self.kind[y][x], x * S, y * S
            if k == "sea" then
                -- deniz zemini shader ile çiziliyor (draw); burada sadece kenar gölgeleri
                shade(x, y, px, py, 0, S)
            elseif k == "cliff" then
                -- kısa yar: hücrenin üst yarısı toprak + köpük, alt yarısı deniz
                c:add(px, py)
                shade(x, y, px, py, HALF, S)
            else
                local t
                if self.kind[y + 1] and self.kind[y + 1][x] == "cliff" then t = T.grass_edge_s
                elseif not self:isLand(x + 1, y) then t = T.grass_edge_e
                elseif not self:isLand(x - 1, y) then t = T.grass_edge_w
                else
                    t = T.grass
                    -- referans görünüm çoğunlukla düz damalı çim; noktalı karolar seyrek
                    if rng:random() < 0.04 then t = T.grass_detail[rng:random(#T.grass_detail)] end
                end
                g:add(self:quad(t), px, py)
                if (x + y) % 2 == 1 then self.checker:add(px, py, 0, S, S) end
            end
        end
    end

    -- İskeleler en üstte: tahtalar overlay'e; kazıklar ayrı katmanda, çitler gibi koyu dış çizgiyle.
    -- Direkli parça 2 satırlık; artan tek satır için düz tahta.
    local posts = {}
    for _, d in ipairs(self.docks) do
        local y = d.y0
        while y <= d.y1 do
            local px, py = d.x * S, y * S
            if y + 1 <= d.y1 then
                o:add(self:pixelQuad(DOCK_SEG_PLANK), px, py)
                posts[#posts + 1] = { DOCK_SEG_POST_L, px - 8, py }
                posts[#posts + 1] = { DOCK_SEG_POST_R, px + S, py }
                y = y + 2
            else
                o:add(self:pixelQuad(DOCK_PLANK), px, py)
                y = y + 1
            end
        end
    end
    self.postCanvas = Gfx.bakeOutlined(self.width, self.height, function()
        for _, p in ipairs(posts) do love.graphics.draw(self.image, self:pixelQuad(p[1]), p[2], p[3]) end
    end)
end

---------------------------------------------------------------------------
-- Sorgular
---------------------------------------------------------------------------

function Tilemap:cellAt(px, py)
    return math.floor(px / Tilemap.TILE), math.floor(py / Tilemap.TILE)
end

-- Bu noktada olta atılabilecek su var mı? (iskele altı sayılmaz)
function Tilemap:isWater(px, py)
    local x, y = self:cellAt(px, py)
    if not self:inBounds(x, y) or self.dock[y][x] then return false end
    local k = self.kind[y][x]
    if k == "cliff" then return py - y * Tilemap.TILE >= Tilemap.CLIFF_WATER_Y end   -- kısa yarın alt yarısı
    return k == "sea"
end

function Tilemap:isWalkableCell(x, y)
    if not self:inBounds(x, y) then return false end
    if self.dock[y][x] then return true end
    if self.blocked[y][x] then return false end
    return self.kind[y][x] == "grass"
end

-- Piksel dikdörtgeni engel (ağaç gövdesi gibi). Dönen kayıt removeSolid ile kaldırılır.
function Tilemap:addSolid(x, y, w, h)
    local r = { x = x, y = y, w = w, h = h }
    self.solids[r] = true
    return r
end

function Tilemap:removeSolid(r) if r then self.solids[r] = nil end end

-- Bir karakterin ayakları (px, py) noktasında durabilir mi? (ayak kutusu: px-4..px+4, py-3..py)
function Tilemap:isWalkable(px, py)
    for _, o in ipairs({ { -4, 0 }, { 4, 0 }, { -4, -3 }, { 4, -3 } }) do
        if not self:isWalkableCell(self:cellAt(px + o[1], py + o[2])) then return false end
    end
    for r in pairs(self.solids) do
        if px + 4 > r.x and px - 4 < r.x + r.w and py > r.y and py - 3 < r.y + r.h then return false end
    end
    return true
end

-- Etrafı r piksel boyunca düz çim mi? (dekor yerleştirmek için)
function Tilemap:isOpenGrass(px, py, r)
    for _, o in ipairs({ { 0, 0 }, { -r, 0 }, { r, 0 }, { 0, -r }, { 0, r } }) do
        local x, y = self:cellAt(px + o[1], py + o[2])
        if not self:inBounds(x, y) or self.kind[y][x] ~= "grass" or self.dock[y][x] or self.blocked[y][x]
            or self.reserved[y][x] then
            return false
        end
        if self.kind[y + 1] and self.kind[y + 1][x] == "cliff" then return false end
    end
    return true
end

function Tilemap:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setShader(seaShader)
    seaShader:send("time", self.time)
    seaShader:send("size", { self.width, self.height })
    love.graphics.draw(self.pixel, 0, 0, 0, self.width, self.height)
    love.graphics.setShader()
    love.graphics.draw(self.ground)
    if Tilemap.CHECKER then
        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setColor(Tilemap.CHECKER_TINT)
        love.graphics.draw(self.checker)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.draw(self.cliffs)
    love.graphics.draw(self.overlay)
    if self.postCanvas then
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(self.postCanvas)
        love.graphics.setBlendMode("alpha")
    end
end

return Tilemap
