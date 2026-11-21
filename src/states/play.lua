-- Test sahnesi: kıyı, yar, deniz, iskele, dekorlar ve balık tutabilen karakter.
local Camera    = require("src.core.camera")
local Animation = require("src.core.animation")
local Assets    = require("src.core.assets")
local Screen    = require("src.core.screen")
local Inventory   = require("src.game.inventory")
local InventoryUI = require("src.ui.inventory_ui")
local Hud         = require("src.ui.hud")
local ShopUI      = require("src.ui.shop_ui")
local Fonts       = require("src.core.fonts")
local NPC         = require("src.entities.npc")
local Tilemap   = require("src.world.tilemap")
local Fences    = require("src.world.fences")
local Farm      = require("src.world.farm")
local Dirt      = require("src.world.dirt")
local Sfx       = require("src.core.sfx")
local Player    = require("src.entities.player")
local FishItem  = require("src.entities.fishitem")
local Tree      = require("src.entities.tree")

local Play = {}

Play.START_MONEY = 10

-- Parayla açılan ek tarlalar (sol üst ekim hücresi, boyut, fiyat)
Play.FIELDS = {
    { cx = 15, cy = 2, cols = 6, rows = 3, price = 50 },    -- kırmızı evin sağı
    { cx = 34, cy = 2, cols = 5, rows = 4, price = 150 },   -- mavi evin sağı
}

-- Tileset içindeki dekor sprite'ları (piksel bölgeleri: x, y, w, h)
local PROPS = {
    bush       = { 788, 22, 24, 21 },
    bush_berry = { 788, 54, 24, 21 },
    bush_2     = { 788, 86, 24, 21 },
    rock_big   = { 512, 65, 16, 11 },
    rock_small = { 530, 69, 11, 8 },
    rock_tiny  = { 546, 66, 9, 6 },
    stump      = { 512, 81, 16, 15 },
    plant_1    = { 977, 163, 14, 11 },
    plant_2    = { 977, 272, 14, 11 },
}

-- Küçük zemin süsleri (tileset piksel bölgeleri). Öbek öbek dağıtılır.
local FLOWERS = {
    blue  = { { 524, 18, 4, 5 }, { 533, 18, 5, 6 }, { 552, 19, 7, 8 }, { 501, 21, 7, 7 }, { 540, 23, 4, 6 } },
    red   = { { 524, 34, 4, 5 }, { 533, 34, 5, 6 }, { 552, 35, 7, 8 }, { 501, 37, 7, 7 }, { 540, 39, 4, 6 } },
    white = { { 563, 50, 11, 11 }, { 524, 51, 4, 6 }, { 532, 51, 7, 6 }, { 551, 52, 9, 8 },
              { 501, 55, 7, 6 }, { 538, 57, 6, 6 }, { 869, 513, 8, 12 } },
}
local GRASS = {
    { 454, 38, 8, 9 }, { 470, 38, 8, 9 }, { 438, 39, 8, 8 }, { 486, 39, 8, 8 },
    { 450, 49, 8, 10 }, { 466, 49, 8, 10 }, { 434, 50, 8, 9 }, { 482, 50, 8, 9 },
    { 451, 65, 13, 10 }, { 467, 65, 13, 10 }, { 435, 66, 13, 9 }, { 483, 66, 13, 9 },
}
local MUSHROOMS = {
    "Elements/Plants/spr_deco_mushroom_blue_01_strip4.png", "Elements/Plants/spr_deco_mushroom_blue_02_strip4.png",
    "Elements/Plants/spr_deco_mushroom_blue_03_strip4.png", "Elements/Plants/spr_deco_mushroom_red_01_strip4.png",
}

-- Kıyı şekli: her kolon için denizin başladığı satır
local function coast(x)
    if x <= 7  then return 19 end
    if x <= 13 then return 18 end
    if x <= 17 then return 15 end   -- koy
    if x <= 27 then return 18 end
    if x <= 33 then return 19 end
    return 18
end

-- Dünya bir kez kurulur: başlangıç ekranı arka plan için önceden kurar, Start'ta oyun kaldığı yerden başlar.
function Play:enter()
    if self.built then return end
    self.built = true
    local map = Tilemap.new(40, 30, 42)
    map:setCoast(coast)
    map:addDock(23, 6)
    self.map = map

    self.props = {}
    self.items = {}
    self.effects = {}
    local tileset = Assets.image(Tilemap.TILESET)
    local quads = {}
    local function rectQuad(r)
        local key = table.concat(r, ",")
        if not quads[key] then
            quads[key] = love.graphics.newQuad(r[1], r[2], r[3], r[4], tileset:getDimensions())
        end
        return quads[key]
    end

    -- Tileset'ten statik dekor; (x, y) alt-orta noktası. `what`: PROPS adı veya {x,y,w,h}
    local function addStatic(what, x, y)
        local r = type(what) == "string" and PROPS[what] or what
        local q = rectQuad(r)
        x, y = math.floor(x), math.floor(y)
        self.props[#self.props + 1] = { x = x, y = y, draw = function()
            love.graphics.draw(tileset, q, x - math.floor(r[3] / 2), y - r[4])
        end }
    end
    -- Animasyonlu dekor
    local rng = love.math.newRandomGenerator(7)
    local function addAnim(anim, x, y)
        anim.time = rng:random() * 2
        self.props[#self.props + 1] = { x = x, y = y, anim = anim, draw = function() anim:draw(x, y) end }
    end

    map:build()

    -- Kıyı boyunca çitler (iskele girişi açık kalır); çit hücreleri yürünemez
    self.fences = Fences.new(map)
    self.fences:autoShore()
    self.fences:build()
    self.fences:addDrawables(self.props)

    -- Oyuncu iskelenin başında başlar
    self.player = Player.new(23 * 16 + 8, 16 * 16 + 10, map)
    self.player.sprite.flip = false
    self.player.onCatch = function(fx, fy) self:spawnFish(fx, fy) end

    -- Envanter: başlangıçta sahip olunan aletler
    self.inventory = Inventory.new()
    for _, id in ipairs({ "rod", "axe", "pickaxe", "shovel", "water", "hammer", "sword" }) do
        self.inventory:add(id)
    end
    self.inventory.money = Play.START_MONEY
    self.player.inventory = self.inventory
    self.inventoryUI = InventoryUI.new(self.inventory)
    -- dükkân (tohum al) ve pazar (hasat / balık sat) aynı pencerenin iki modu
    self.shops = { buy = ShopUI.new(self.inventory, "buy"), sell = ShopUI.new(self.inventory, "sell") }
    self.hud = Hud.new(self.inventory)
    self.hud.player = self.player
    self.camera = Camera.new(self.player.x, self.player.y)
    self.camera:setBounds(0, 0, map.width, map.height)

    -- Kasaba: binalar dekordan önce yerleşir (çevreleri dekora kapatılır)
    self.npcs = {}
    self.dirt = Dirt.new(5)   -- tarla + yollar tek toprak katmanı
    self:buildTown(addStatic, tileset, rectQuad)
    -- Tarla: yeşil evin altındaki boş alan (7x3 ekim hücresi); dekordan önce yerleşir
    -- Ek tarlalar kilitli başlar, tabelasının yanında parayla açılır (FIELDS)
    local fields = { Farm.new(map, 2, 11, 7, 3, self.dirt) }
    for _, f in ipairs(Play.FIELDS) do
        fields[#fields + 1] = Farm.new(map, f.cx, f.cy, f.cols, f.rows, self.dirt, f.price)
    end
    self.farm = Farm.group(fields)
    self.dirt:bake()
    self.player.farm = self.farm
    self.player.onHarvest = function(x, y) self:spawnGlint(x, y) end
    -- Space/E: dükkâncının yanındaysa dükkân, pazarcının yanındaysa pazar açılır
    self.player.interact = function()
        -- kilitli tarla tabelası: parası yetiyorsa aç
        local field = self.farm:lockedNear(self.player.x, self.player.y)
        if field then
            if self.inventory:spend(field.price) then
                field:unlock()
                Sfx.play("unlock")
                for i = 0, 3 do
                    self:spawnGlint(field.px + 8 + i * (field.pw - 16) / 3, field.py + field.ph / 2 + (i % 2 == 0 and -6 or 6))
                end
            else
                self.player:showEmote("confused", 0.8)
                self.priceFail = { field = field, time = 0.35 }
            end
            return true
        end
        local shop = self.shopkeeper.talking and self.shops.buy or self.merchant.talking and self.shops.sell
        if shop then
            shop:show()
            Sfx.play("open")
            self.player.sprite:play("idle")
            return true
        end
    end
    local function freeSpot(margin)
        for _ = 1, 200 do
            local x, y = rng:random(16, map.width - 16), rng:random(24, map.height - 8)
            local far = math.abs(x - self.player.x) > 30 or math.abs(y - self.player.y) > 30
            if far and map:isOpenGrass(x, y, margin) then return x, y end
        end
    end

    -- Kesilebilir ağaçlar (iki tür)
    self.trees = {}
    for _ = 1, 18 do
        local x, y = freeSpot(18)
        if x then
            self.trees[#self.trees + 1] = Tree.new(x, y, map, rng:random(#Tree.KINDS), rng:random() * 2)
            map:reserveRect(x - 8, y - 8, 16, 8, 0)
        end
    end
    self.player.findTree = function(x, y)
        for _, t in ipairs(self.trees) do if t:hitTest(x, y) then return t end end
    end
    self.player.onFell = function(tree) self:spawnWood(tree) end
    for _, name in ipairs({ "bush", "bush_berry", "bush_2", "bush", "bush_berry" }) do
        local x, y = freeSpot(12)
        if x then addStatic(name, x, y) end
    end
    for _, name in ipairs({ "rock_big", "rock_small", "rock_tiny", "rock_big", "rock_small", "rock_tiny" }) do
        local x, y = freeSpot(8)
        if x then addStatic(name, x, y) end
    end
    for _ = 1, 5 do
        local x, y = freeSpot(8)
        if x then addAnim(Animation.fromStrip("Elements/Animals/spr_deco_chicken_01_strip4.png", { fps = 6 }), x, y) end
    end

    -- Zemin süsleri: çiçek öbekleri (aynı renkten 2-4 çiçek), ot öbekleri, kütük, mantar, bitki
    local function pick(list) return list[rng:random(#list)] end
    local function cluster(count, spread, chooser)
        local cx, cy = freeSpot(6)
        if not cx then return end
        for _ = 1, count do
            local x, y = cx + rng:random(-spread, spread), cy + rng:random(-spread, spread)
            if map:isOpenGrass(x, y, 3) then addStatic(chooser(), x, y) end
        end
    end
    local colors = { "white", "white", "white", "blue", "red" }   -- referanstaki gibi çoğunluk papatya
    for _ = 1, 22 do
        local set = FLOWERS[pick(colors)]
        cluster(rng:random(1, 4), 10, function() return pick(set) end)
    end
    for _ = 1, 26 do cluster(rng:random(1, 3), 8, function() return pick(GRASS) end) end
    for _ = 1, 5 do
        local x, y = freeSpot(10)
        if x then addStatic("stump", x, y) end
    end
    for _ = 1, 4 do
        local x, y = freeSpot(8)
        if x then addStatic(pick({ "plant_1", "plant_2" }), x, y) end
    end
    for _ = 1, 5 do
        local x, y = freeSpot(8)
        if x then addAnim(Animation.fromStrip(pick(MUSHROOMS), { fps = 4 }), x, y) end
    end

    -- Doldurma: boş kalan çim hücrelerine ot öbeği / çiçek (yakınında başka süs, ağaç veya NPC evi yoksa)
    local taken = {}
    for _, p in ipairs(self.props) do if p.x then taken[#taken + 1] = p end end
    for _, t in ipairs(self.trees) do taken[#taken + 1] = t end
    local function free(x, y, d)
        for _, p in ipairs(taken) do
            if math.abs(p.x - x) < d and math.abs(p.y - y) < d then return false end
        end
        return true
    end
    for cy = 0, map.rows - 1 do
        for cx = 0, map.cols - 1 do
            local x, y = cx * 16 + rng:random(3, 13), cy * 16 + rng:random(5, 15)
            if rng:random() < 0.8 and map:isOpenGrass(x, y, 4) and free(x, y, 11) then
                local set = rng:random() < 0.6 and GRASS or FLOWERS[pick(colors)]
                local n = set == GRASS and rng:random(1, 3) or rng:random(1, 2)
                for _ = 1, n do
                    local jx, jy = x + rng:random(-5, 5), y + rng:random(-4, 4)
                    if map:isOpenGrass(jx, jy, 3) then
                        addStatic(pick(set), jx, jy)
                        taken[#taken + 1] = self.props[#self.props]
                    end
                end
            end
        end
    end

    -- Denizde parıltılar (tileset 11..14, 22) ve ördekler
    for _ = 1, 14 do
        local x, y = rng:random(8, map.width - 8), rng:random(20 * 16, map.height - 8)
        if map:isWater(x, y) then
            addAnim(Animation.new(tileset, { x = 176, y = 352, w = 64, h = 16, frameW = 16, fps = 5 }), x, y)
        end
    end
    addAnim(Animation.fromStrip("Elements/Animals/spr_deco_duck_01_strip4.png", { fps = 5 }), 10 * 16, 23 * 16)
    addAnim(Animation.fromStrip("Elements/Animals/spr_deco_duck_01_strip4.png", { fps = 5 }), 31 * 16, 24 * 16)

end

---------------------------------------------------------------------------
-- Kasaba
---------------------------------------------------------------------------

-- Tileset'teki hazır küçük evler (çatı + duvar, 32x56). Çatı sırtı ayrı parça, kullanılmıyor.
local HOUSES = {
    blue   = { 520, 168, 32, 56 },
    green  = { 520, 296, 32, 56 },
    orange = { 520, 424, 32, 56 },
    red    = { 520, 552, 32, 56 },
    purple = { 520, 680, 32, 56 },
}

-- Binalar: renk, sol hücre, alt satır (duvarın dibi bu satırın üst kenarında)
local TOWN = {
    shop  = { house = "orange", cx = 25, bottom = 13 },
    homes = {
        { house = "green",  cx = 4,  bottom = 9,  hair = "curlyhair" },
        { house = "red",    cx = 12, bottom = 7,  hair = "mophair" },
        { house = "purple", cx = 18, bottom = 11, hair = "spikeyhair" },
        { house = "blue",   cx = 31, bottom = 8,  hair = "longhair" },
    },
}

-- Dükkân önündeki ürün kasaları (Elements/Crops: kasa + ürün + kasa ön kapağı)
local SHOP_CRATES = { "carrot_05", "pumpkin_05", "cabbage_05" }
-- Pazar tezgâhı: haritanın sağındaki boş alan. Kasalar (ortadaki kasa merkezi cx, alt kenarı bottom satırı),
-- pazarcı kasaların arkasında durur.
local MARKET = { cx = 35, bottom = 12, crates = { "fish", "wood", "sunflower_05" } }

function Play:buildTown(addStatic, tileset, rectQuad)
    local map, S = self.map, Tilemap.TILE

    local function placeHouse(color, cx, bottom)
        local r = HOUSES[color]
        local px, by = cx * S + S, bottom * S      -- alt-orta noktası
        addStatic(r, px, by)
        -- duvarın alt iki satırı yürünemez; tüm bina (+1 hücre pay) dekora kapalı
        for y = bottom - 2, bottom - 1 do
            for x = cx, cx + 1 do map:block(x, y) end
        end
        map:reserveRect(cx * S, by - r[4], r[3], r[4], 1)
        return px, by
    end

    -- Ürünlü kasa: (cx, cy) alt-orta. Kasanın hücresi yürünemez.
    local base, top = Assets.image("Elements/Crops/crate_base.png"), Assets.image("Elements/Crops/crate_top.png")
    local function placeCrate(cx, cy, produceName)
        local produce = Assets.image("Elements/Crops/" .. produceName .. ".png")
        self.props[#self.props + 1] = { y = cy, draw = function()
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(base, cx - 8, cy - 16)
            love.graphics.draw(produce, cx - math.floor(produce:getWidth() / 2), cy - 13 - math.floor(produce:getHeight() / 2))
            love.graphics.draw(top, cx - 8, cy - top:getHeight())
        end }
        map:block(math.floor(cx / S), math.floor((cy - 1) / S))
        map:reserveRect(cx - 8, cy - 16, 16, 16, 1)
    end

    -- Dükkân + kasalar + dükkâncı
    local sx, sy = placeHouse(TOWN.shop.house, TOWN.shop.cx, TOWN.shop.bottom)
    local houseRight = sx + HOUSES[TOWN.shop.house][3] / 2
    local firstCrate = houseRight + 2 + 8          -- duvardan 2px boşluk, kasa merkezi
    for i, crop in ipairs(SHOP_CRATES) do
        placeCrate(firstCrate + (i - 1) * 16, sy, crop)   -- evin sağında yan yana
    end
    self.shopkeeper = NPC.new({
        x = firstCrate + 16, y = sy + 14, world = map, hair = "bowlhair", name = "Shopkeeper", wander = 0, facing = -1,
    })
    self.npcs[#self.npcs + 1] = self.shopkeeper
    map:reserveRect(firstCrate + 8, sy, 16, 16, 0)

    -- Pazar: tezgâh kasaları + arkalarında pazarcı (hasat ve balık alır)
    local mx, my = MARKET.cx * S + S / 2, MARKET.bottom * S
    for i, produce in ipairs(MARKET.crates) do
        placeCrate(mx + (i - 2) * 16, my, produce)
    end
    self.merchant = NPC.new({
        x = mx, y = my - 12, world = map, hair = "mophair", name = "Merchant", wander = 0, facing = -1,
    })
    self.npcs[#self.npcs + 1] = self.merchant
    map:reserveRect(mx - 24, my, 48, 16, 0)   -- tezgâhın önü boş kalsın
    self.marketFront = { x = mx, y = my }
    self.shopDoor = { x = sx, y = sy }

    -- Evler ve sakinleri (evin önünde dolaşırlar)
    local doors = {}
    for _, h in ipairs(TOWN.homes) do
        local hx, hy = placeHouse(h.house, h.cx, h.bottom)
        doors[h.house] = { x = hx, y = hy }
        self.npcs[#self.npcs + 1] = NPC.new({
            x = hx, y = hy + 14, world = map, hair = h.hair, wander = 40,
            facing = love.math.random() < 0.5 and -1 or 1,
        })
    end

    self:buildPaths(doors)
end

-- Kasaba yolları (toprak katmanına eklenir, dekora kapatılır). 1 karo genişliğinde.
--   ana yol (y=14. satır): dükkânın önünden pazara ve harita kenarına; iskeleye inen kol
--   batı yolu (12. satır): tarladan mor evin önüne, ana yola bağlanır
--   kapı kolları: her evin kapısından en yakın yola
local PATH_W, PATH_R = 16, 3
function Play:buildPaths(doors)
    local map, S, dirt = self.map, Tilemap.TILE, self.dirt
    local half = PATH_W / 2
    local function road(x, y, w, h)
        dirt:add(x, y, w, h, PATH_R)
        map:reserveRect(x, y, w, h, 0)
    end
    local function hRoad(x1, x2, row) road(x1, row * S, x2 - x1, PATH_W) end           -- yatay: piksel x aralığı
    local function vRoad(cx, y1, y2) road(cx - half, y1, PATH_W, y2 - y1) end          -- dikey: merkez x, piksel y aralığı

    local mainY, westY = 14, 12
    local purple, red, green, blue = doors.purple, doors.red, doors.green, doors.blue

    hRoad(purple.x - half, map.width + 8, mainY)                       -- ana yol (sağda harita dışına uzanır)
    vRoad(23 * S + 8, mainY * S, 17 * S)                                -- iskeleye
    vRoad(self.shopDoor.x, self.shopDoor.y, mainY * S + PATH_W)         -- dükkân kapısı
    vRoad(self.marketFront.x, self.marketFront.y, mainY * S + PATH_W)   -- pazar tezgâhı
    vRoad(blue.x, blue.y, mainY * S + PATH_W)                           -- mavi ev

    hRoad(9 * S, purple.x + half, westY)                                -- batı yolu (tarlanın sağ kenarından)
    vRoad(purple.x, purple.y, mainY * S + PATH_W)                       -- mor ev, ana yola bağlantı
    vRoad(red.x, red.y, westY * S + PATH_W)                             -- kırmızı ev
    hRoad(green.x - half, red.x + half, 9)                              -- yeşil ev -> kırmızı evin kolu
end

-- Açık dükkân penceresi (yoksa nil)
function Play:openShop()
    for _, shop in pairs(self.shops) do if shop.open then return shop end end
end

-- Küçük parlama efekti (Elements/VFX/Glint, 4 kare yıldız)
function Play:spawnGlint(x, y)
    local anim = Animation.fromStrip("Elements/VFX/Glint/spr_deco_glint_02_strip4.png", { fps = 16, loop = false })
    self.effects[#self.effects + 1] = { anim = anim, x = x, y = y }
end

-- Devrilen ağaçtan odunlar çevreye saçılır (yerden toplanır)
function Play:spawnWood(tree)
    local n = love.math.random(Tree.WOOD_MIN, Tree.WOOD_MAX)
    for i = 1, n do
        local tx, ty = tree.x, tree.y + 6
        for _ = 1, 10 do
            local a = (i / n + love.math.random() * 0.3) * math.pi * 2
            local jx, jy = tree.x + math.cos(a) * 14, tree.y + 3 + math.sin(a) * 8
            if self.map:isWalkable(jx, jy) then tx, ty = jx, jy; break end
        end
        self.items[#self.items + 1] = FishItem.new(tree.x, tree.y - 10, tx, ty, "wood", 14)
    end
end

-- Balık sudan, oyuncunun arkasındaki yürünebilir bir noktaya fırlar
function Play:spawnFish(fx, fy)
    local p, map = self.player, self.map
    local back = -p:facing()
    local candidates = {
        { p.x + back * 18, p.y - 2 }, { p.x, p.y - 18 }, { p.x + back * 12, p.y + 10 }, { p.x + back * 6, p.y },
    }
    local tx, ty = p.x, p.y
    for _, c in ipairs(candidates) do
        local jx, jy = c[1] + love.math.random(-3, 3), c[2] + love.math.random(-3, 3)
        if map:isWalkable(jx, jy) then tx, ty = jx, jy; break end
    end
    self.items[#self.items + 1] = FishItem.new(fx, fy, tx, ty)
end

-- Oyuncudan bağımsız dünya güncellemesi (başlangıç ekranının arka planı da kullanır)
function Play:updateWorld(dt)
    self.map:update(dt)
    for _, p in ipairs(self.props) do if p.anim then p.anim:update(dt) end end
    self.farm:update(dt)
    for _, n in ipairs(self.npcs) do n:update(dt, self.player) end
    for _, t in ipairs(self.trees) do t:update(dt, self.player) end
end

function Play:update(dt)
    self:updateWorld(dt)
    self.inventoryUI:update(dt)
    for _, shop in pairs(self.shops) do shop:update(dt) end
    if self.priceFail then
        self.priceFail.time = self.priceFail.time - dt
        if self.priceFail.time <= 0 then self.priceFail = nil end
    end
    self.hud:update(dt)
    if self.inventoryUI.open or self:openShop() then
        self.player.sprite:update(dt)   -- envanter açıkken oyuncu girdisi yok, animasyon sürer
    else
        self.player:update(dt)
    end

    -- Yerdeki balıklar: yaklaşınca oyuncuya uçar, değince toplanır + parlama
    local p = self.player
    local canPick = p.mode == "free" and not self.inventoryUI.open and not self:openShop()
    for i = #self.items, 1, -1 do
        local it = self.items[i]
        it:update(dt, p.x, p.y, canPick)
        if it.collected then
            self.inventory:add(it.id)
            Sfx.play("pickup")
            self:spawnGlint(it.x, it.y - 4)
            table.remove(self.items, i)
        end
    end

    for i = #self.effects, 1, -1 do
        local e = self.effects[i]
        e.anim:update(dt)
        if e.anim.finished then table.remove(self.effects, i) end
    end

    self.camera:follow(self.player.x, self.player.y, dt)
end

-- true dönerse tuş kullanıldı (main.lua Esc ile çıkmaz)
function Play:keypressed(key)
    local shop = self:openShop()
    if shop then return shop:keypressed(key) end
    local wasOpen = self.inventoryUI.open
    if self.inventoryUI:keypressed(key) then
        -- açılırken yürüyorsa yerinde yürümesin
        if not wasOpen and self.player.mode == "free" then self.player.sprite:play("idle") end
        return true
    end
    self.player:keypressed(key)
end

-- main.lua oyun koordinatı verir; UI kendi ölçeğinde çalışır
local function toUI(x, y)
    local k = Screen.scale / Screen.uiScale
    return x * k, y * k
end
function Play:mousemoved(x, y)
    self.inventoryUI:mousemoved(toUI(x, y))
    local shop = self:openShop()
    if shop then shop:mousemoved(toUI(x, y)) end
end
function Play:mousepressed(x, y, button)
    local ux, uy = toUI(x, y)
    local shop = self:openShop()
    if shop then return shop:mousepressed(ux, uy, button) end
    return self.inventoryUI:mousepressed(ux, uy, button)
end
function Play:wheelmoved(x, y)
    local shop = self:openShop()
    if shop then return shop:wheelmoved(x, y) end
    self.inventoryUI:wheelmoved(x, y)
end

function Play:draw()
    self.camera:attach()
    self.map:draw()
    self.dirt:draw()   -- tarla + yollar
    self.farm:draw()   -- zemin katmanı (toprak + çukurlar)

    -- y-sort: oyuncu, eşyalar ve dekorlar birlikte sıralanır
    local drawables = { { y = self.player.y, draw = function() self.player:draw() end } }
    for _, p in ipairs(self.props) do drawables[#drawables + 1] = p end
    for _, n in ipairs(self.npcs) do
        drawables[#drawables + 1] = { y = n.y, draw = function() n:draw() end }
    end
    self.farm:addDrawables(drawables)
    for _, t in ipairs(self.trees) do
        drawables[#drawables + 1] = { y = t.y, draw = function() t:draw() end }
    end
    for _, it in ipairs(self.items) do
        drawables[#drawables + 1] = { y = it.y, draw = function() it:draw() end }
    end
    -- table.sort kararlı değil: aynı y'deki iki şeyin sırası kareden kareye değişip titriyordu.
    -- Eşitlikte listeye eklenme sırası belirler.
    for i, d in ipairs(drawables) do d.order = i end
    table.sort(drawables, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.order < b.order
    end)
    for _, d in ipairs(drawables) do d.draw() end

    -- efektler her şeyin üstünde (ortadan çizilir)
    for _, e in ipairs(self.effects) do
        e.anim:draw(e.x, e.y, false, e.anim.frameW / 2, e.anim.frameH / 2)
    end

    if DEBUG then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", math.floor(self.player.x), math.floor(self.player.y), 1, 1)
        love.graphics.setColor(1, 1, 1)
    end
    self.camera:detach()
end

-- Kilitli tarlaların tabelası üstünde fiyat etiketi (UI ölçeğinde, dünyayı takip eder).
-- Yanındayken üstünde "Space: unlock" yazar; para yetmezse etiket kırmızı yanıp sallanır.
function Play:drawFieldPrices()
    local W = require("src.ui.widgets")
    local cam, k = self.camera, Screen.scale / Screen.uiScale
    local ox, oy = Screen.snap(Screen.w / 2 - cam.x), Screen.snap(Screen.h / 2 - cam.y)
    for _, f in ipairs(self.farm.list) do
        if f.locked then
            local ux, uy = (f.signX + ox) * k, (f.signY - 24 + oy) * k
            local text = f.price .. "G"
            local tw = math.ceil(Fonts.width(text) - Fonts.effMult())
            local w, h = 4 + 10 + 3 + tw + 4, 13
            local fail = self.priceFail and self.priceFail.field == f
            local shake = fail and (math.floor(self.priceFail.time * 40) % 2 == 0 and -1 or 1) or 0
            local x, y = math.floor(ux - w / 2) + shake, math.floor(uy - h)
            W.pill(x, y, w, h, W.C.yellow)
            love.graphics.setColor(W.C.yellowHi)
            love.graphics.rectangle("fill", x + 2, y + 1, w - 4, 1)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(self.hud.coinImg, self.hud.coinQuad, x + 4, y + math.floor((h - 10) / 2))
            local afford = self.inventory.money >= f.price
            Fonts.print(text, x + 4 + 10 + 3, Fonts.centerY(y, h), (afford and not fail) and W.C.dark or W.C.red)
            if f:nearSign(self.player.x, self.player.y) then
                local hint = "Space: unlock"
                Fonts.print(hint, math.floor(ux - Fonts.width(hint, 0.5) / 2), y - 3 - Fonts.capHeight(0.5) - Fonts.capTop(0.5),
                    W.C.white, W.C.shadow, 0.5)
            end
        end
    end
end

function Play:drawUI()
    -- UI kendi ölçeğinde (Screen.uiScale, dünyadan biraz küçük)
    love.graphics.push()
    Screen.applyUI()
    self:drawFieldPrices()
    self.inventoryUI:draw()
    local shop = self:openShop()
    if shop then shop:draw() end
    self.hud:draw()   -- envanter karartmasının üstünde, hep görünür

    love.graphics.pop()
end

return Play
