-- Dükkân penceresi (referans düzeni), iki mod:
--   "buy"  (dükkâncı): tohum satın al — bilgi kutusunda büyüme aşamaları ve süresi
--   "sell" (pazarcı) : hasat/balık sat — envanterdeki satılabilir eşyalar (Items.sell alanı olanlar)
-- Düzen: sol üst başlık | sol bilgi kutusu | sol alt miktar + toplam fiyat | sağ sekmeli ızgara (rozet = sahip olunan adet)
--   Ok/WASD: seç   Q/E veya tekerlek: miktar   Space/Enter veya ✓: onayla   Esc veya ✗: kapat
-- UI koordinatlarında çizilir (Screen.applyUI içinde).
local Assets    = require("src.core.assets")
local Fonts     = require("src.core.fonts")
local Screen    = require("src.core.screen")
local NineSlice = require("src.ui.nineslice")
local Items     = require("src.game.items")
local Crops     = require("src.game.crops")
local W         = require("src.ui.widgets")
local Sfx       = require("src.core.sfx")

local C, SMALL = W.C, W.SMALL

local ShopUI = {}
ShopUI.__index = ShopUI

ShopUI.MAX_QTY = 99

-- Mod başına görünüm
local MODES = {
    buy  = { title = "Shop",   crate = "kale_05", tab = "Seeds", tabIcon = "UI/plant.png",  action = "BUY",
             verb = "buy",  empty = "Sold out" },
    sell = { title = "Market", crate = "fish",    tab = "Sell",  tabIcon = "UI/basket.png", action = "SELL",
             verb = "sell", empty = "Nothing to sell" },
}

-- Sağ panel (envanterle aynı ölçüler)
local COLS, ROWS = 5, 3
local SLOT, GAP, PAD, TAB_H = 20, 2, 7, 15
local GRID_W = COLS * SLOT + (COLS - 1) * GAP

-- Sol sütun
local LEFT_W, COL_GAP = 96, 4
local TITLE_H, INFO_H, BUY_H, ROW_GAP = 20, 61, 20, 3
-- sağ panel sol sütunla aynı boyda biter
local PANEL_H = TITLE_H + INFO_H + BUY_H + 2 * ROW_GAP - TAB_H

local function inside(x, y, r) return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h end

-- mode: "buy" | "sell"
function ShopUI.new(inventory, mode)
    return setmetatable({
        inventory = inventory, mode = mode or "buy", M = MODES[mode or "buy"],
        open = false, sel = 1, qty = 1, time = 0, fail = 0, done = 0,
    }, ShopUI)
end

function ShopUI:show() self.open, self.sel, self.qty = true, 1, 1 end

-- Izgaradaki girdiler: { id, price, icon }
function ShopUI:entries()
    local out = {}
    if self.mode == "buy" then
        for _, c in ipairs(Crops.LIST) do
            out[#out + 1] = { id = c.seed, price = c.seedPrice, crop = c,
                              icon = "Elements/Crops/" .. c.id .. "_05.png" }
        end
    else
        for _, st in ipairs(self.inventory.stacks) do
            local def = Items.get(st.id)
            if def.sell then out[#out + 1] = { id = st.id, price = def.sell, icon = def.icon } end
        end
    end
    return out
end

function ShopUI:entry() return self:entries()[self.sel] end

function ShopUI:panelWidth()
    return math.max(GRID_W + PAD * 2, W.tabWidth(self.M.tab) + 12)
end

-- Tüm parçaların konumları
function ShopUI:layout()
    local pw = self:panelWidth()
    local totalW, totalH = LEFT_W + COL_GAP + pw, TAB_H + PANEL_H
    local ox = math.floor((Screen.uiW - totalW) / 2)
    local oy = math.floor((Screen.uiH - totalH) / 2)
    local L = { all = { x = ox, y = oy, w = totalW, h = totalH } }
    L.title = { x = ox, y = oy, w = LEFT_W, h = TITLE_H }
    L.info  = { x = ox, y = oy + TITLE_H + ROW_GAP, w = LEFT_W, h = INFO_H }
    L.buy   = { x = ox, y = oy + totalH - BUY_H, w = LEFT_W, h = BUY_H }
    L.panel = { x = ox + LEFT_W + COL_GAP, y = oy + TAB_H, w = pw, h = PANEL_H }
    L.tab   = { x = L.panel.x + 6, y = oy, w = W.tabWidth(self.M.tab), h = TAB_H }
    -- bilgi kutusundaki onay / iptal düğmeleri
    L.confirm = { x = L.info.x + LEFT_W - 6 - 12, y = L.info.y + 31, w = 12, h = 11 }
    L.cancel  = { x = L.info.x + LEFT_W - 6 - 12, y = L.info.y + 45, w = 11, h = 11 }
    -- miktar kutusu ve okları
    L.qty   = { x = L.buy.x + 31, y = L.buy.y, w = 22, h = BUY_H }
    L.up    = { x = L.qty.x, y = L.qty.y - 4, w = L.qty.w, h = 8 }
    L.down  = { x = L.qty.x, y = L.qty.y + L.qty.h - 4, w = L.qty.w, h = 8 }
    L.price = { x = L.qty.x + L.qty.w + 4, y = L.buy.y + 4, w = LEFT_W - (L.qty.x - ox) - L.qty.w - 4 - 5, h = 12 }
    return L
end

function ShopUI:slotRect(i)
    local P = self:layout().panel
    local gx = P.x + math.floor((P.w - GRID_W) / 2)
    local c, r = (i - 1) % COLS, math.floor((i - 1) / COLS)
    return { x = gx + c * (SLOT + GAP), y = P.y + PAD + r * (SLOT + GAP), w = SLOT, h = SLOT }
end

function ShopUI:select(i)
    if self:entries()[i] and i ~= self.sel then
        self.sel, self.qty = i, 1
        Sfx.play("move")
    end
end

-- En çok: alımda 99, satışta eldeki adet
function ShopUI:maxQty()
    local e = self:entry()
    if self.mode == "sell" then return e and self.inventory:count(e.id) or 1 end
    return ShopUI.MAX_QTY
end

function ShopUI:setQty(n)
    local q = math.max(1, math.min(self:maxQty(), n))
    if q ~= self.qty then Sfx.play("move", { pitch = q > self.qty and 1.25 or 0.9 }) end
    self.qty = q
end

function ShopUI:close()
    self.open = false
    Sfx.play("close")
end

function ShopUI:total()
    local e = self:entry()
    return e and e.price * self.qty or 0
end

-- Onay: alımda para yetmezse fiyat kırmızı yanıp sallanır; satışta eşya envanterden çıkar, para gelir.
function ShopUI:confirm()
    local e = self:entry()
    if not e then return end
    if self.mode == "buy" then
        if not self.inventory:spend(self:total()) then self.fail = 0.35; Sfx.play("deny"); return end
        self.inventory:add(e.id, self.qty)
    else
        local n = math.min(self.qty, self.inventory:count(e.id))
        if n <= 0 then return end
        self.inventory:remove(e.id, n)
        self.inventory:addMoney(e.price * n)
        -- eşya bittiyse seçim kayar
        local count = #self:entries()
        if self.sel > count then self.sel = math.max(1, count) end
        self.qty = 1
    end
    self.done = 0.15
    Sfx.play("coin")
    if self.onDone then self.onDone() end
end

function ShopUI:move(dx, dy)
    local c, r = (self.sel - 1) % COLS + dx, math.floor((self.sel - 1) / COLS) + dy
    if c < 0 or c >= COLS or r < 0 or r >= ROWS then return end
    self:select(r * COLS + c + 1)   -- boş kutucuğa geçilmez
end

---------------------------------------------------------------------------
-- Girdi (açıkken tüm tuşlar kullanılır)
---------------------------------------------------------------------------

function ShopUI:keypressed(key)
    if not self.open then return false end
    if key == "escape" or key == "tab" or key == "i" then self:close()
    elseif key == "left" or key == "a" then self:move(-1, 0)
    elseif key == "right" or key == "d" then self:move(1, 0)
    elseif key == "up" or key == "w" then self:move(0, -1)
    elseif key == "down" or key == "s" then self:move(0, 1)
    elseif key == "q" then self:setQty(self.qty - 1)
    elseif key == "e" then self:setQty(self.qty + 1)
    elseif key == "space" or key == "return" then self:confirm()
    end
    return true
end

function ShopUI:mousemoved(x, y)
    if not self.open then return end
    for i = 1, #self:entries() do
        if inside(x, y, self:slotRect(i)) then self:select(i) end
    end
end

function ShopUI:mousepressed(x, y, button)
    if not self.open then return false end
    if button ~= 1 then return true end
    local L = self:layout()
    if inside(x, y, L.up) then self:setQty(self.qty + 1)
    elseif inside(x, y, L.down) then self:setQty(self.qty - 1)
    elseif inside(x, y, L.confirm) or inside(x, y, L.price) then self:confirm()
    elseif inside(x, y, L.cancel) then self:close()
    elseif not inside(x, y, L.all) then self:close()   -- dışarı tıklayınca kapanır
    end
    return true
end

function ShopUI:wheelmoved(_, dy)
    if not self.open then return end
    self:setQty(self.qty + (dy > 0 and 1 or dy < 0 and -1 or 0))
end

function ShopUI:update(dt)
    self.time = self.time + dt
    self.fail = math.max(0, self.fail - dt)
    self.done = math.max(0, self.done - dt)
end

---------------------------------------------------------------------------
-- Çizim
---------------------------------------------------------------------------

function ShopUI:drawTitle(r)
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(r.x, r.y, r.w, r.h)
    -- ikon kutusu: ürünlü kasa. Kasanın dibi gri kutunun iç tabanına oturur, ürün kutunun üstüne taşar.
    local bx, by, bw, bh = r.x + 3, r.y + 3, 22, r.h - 6
    NineSlice.get("w"):draw(bx, by, bw, bh)
    local base, top = Assets.image("Elements/Crops/crate_base.png"), Assets.image("Elements/Crops/crate_top.png")
    local produce = Assets.image("Elements/Crops/" .. self.M.crate .. ".png")
    local cx, cb = bx + bw / 2, by + bh - 2
    love.graphics.draw(base, cx - 8, cb - 16)
    love.graphics.draw(produce, cx - math.floor(produce:getWidth() / 2), cb - 13 - math.floor(produce:getHeight() / 2))
    love.graphics.draw(top, cx - 8, cb - top:getHeight())
    Fonts.print(self.M.title, bx + bw + 6, Fonts.centerY(r.y, r.h), C.dark)
end

-- Sağ üstteki renkli etiket (büyüme süresi / birim fiyat)
local function pillText(r, text, fill)
    local tw = math.ceil(Fonts.width(text) - Fonts.effMult())
    local pw, ph = tw + 8, 11
    local px, py = r.x + r.w - 6 - pw, r.y + 13
    W.pill(px, py, pw, ph, fill)
    Fonts.print(text, px + 4, Fonts.centerY(py, ph), fill == C.yellow and C.dark or C.white)
end

function ShopUI:drawStages(r, crop)
    local x = r.x + 6
    local stages = {}
    for i, name in ipairs(crop.stages) do stages[i] = Assets.image("Elements/Crops/" .. name .. ".png") end

    -- aşama noktaları (kaç aşamada büyüdüğü)
    local dot = Assets.image("UI/select_dots.png")
    love.graphics.setColor(0.72, 0.75, 0.82)
    for i = 1, #stages do love.graphics.draw(dot, x + (i - 1) * 8, r.y + 5) end

    Fonts.print(crop.name, x, r.y + 15 - Fonts.capTop(), C.dark)
    Fonts.print("Stages", x, r.y + 25 - Fonts.capTop(), C.light)
    pillText(r, (crop.stageTime * (#stages - 1)) .. "s", C.pink)

    -- tohum > filiz > olgun
    local picks = { stages[1], stages[2], stages[#stages] }
    local size, step, by = 18, 20, r.y + r.h - 4 - 18
    for i, img in ipairs(picks) do
        local bx = x - 1 + (i - 1) * step
        W.pill(bx, by, size, size, C.white)
        love.graphics.setColor(1, 1, 1)
        -- olgun ürün kutunun üstüne taşabilir, dibi kutunun içinde kalır
        local iy = math.min(by + math.floor((size - img:getHeight()) / 2), by + size - 3 - img:getHeight())
        love.graphics.draw(img, bx + math.floor((size - img:getWidth()) / 2), iy)
    end
    for i = 1, #picks - 1 do
        W.triangle(x - 1 + i * step + 3, by + size / 2, "right")
    end
end

-- Satış: ad, eldeki adet, birim fiyat, büyük ikon
function ShopUI:drawSellInfo(r, e)
    local x, def = r.x + 6, Items.get(e.id)
    Fonts.print(def.name, x, r.y + 15 - Fonts.capTop(), C.dark)
    Fonts.print("You have " .. self.inventory:count(e.id), x, r.y + 25 - Fonts.capTop(), C.light)
    pillText(r, e.price .. "G", C.yellow)
    local size, by = 22, r.y + r.h - 4 - 22
    W.pill(x - 1, by, size, size, C.white)
    W.imageCentered(Assets.image(e.icon), x - 1, by, size, size)
    Fonts.print("each", x - 1 + size + 4, by + size - 4 - Fonts.capHeight(SMALL) - Fonts.capTop(SMALL), C.light, nil, SMALL)
end

function ShopUI:drawInfo(L)
    local r = L.info
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("w"):draw(r.x, r.y, r.w, r.h)
    local e = self:entry()
    if not e then
        Fonts.print(self.mode == "sell" and "Bring crops" or "", r.x + 6, r.y + 15 - Fonts.capTop(), C.light)
        Fonts.print(self.mode == "sell" and "or fish" or "", r.x + 6, r.y + 25 - Fonts.capTop(), C.light)
        return
    end
    if self.mode == "buy" then self:drawStages(r, e.crop) else self:drawSellInfo(r, e) end

    love.graphics.setColor(1, 1, 1)
    local pulse = self.done > 0 and -1 or 0
    love.graphics.draw(Assets.image("UI/confirm.png"), L.confirm.x, L.confirm.y + pulse)
    love.graphics.draw(Assets.image("UI/cancel.png"), L.cancel.x, L.cancel.y)
end

function ShopUI:drawAmount(L)
    local r = L.buy
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(r.x, r.y, r.w, r.h)
    Fonts.print(self.M.action, r.x + 6, Fonts.centerY(r.y, r.h), C.dark)

    -- miktar kutusu (okları kutunun kenarından taşar)
    local q = L.qty
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("w"):draw(q.x, q.y, q.w, q.h)
    local qt = tostring(self:entry() and self.qty or 0)
    local qw = math.ceil(Fonts.width(qt) - Fonts.effMult())
    Fonts.print(qt, q.x + math.floor((q.w - qw) / 2), Fonts.centerY(q.y, q.h), C.dark)
    W.triangle(q.x + q.w / 2, q.y - 3, "up")
    W.triangle(q.x + q.w / 2, q.y + q.h + 3, "down")

    -- toplam: sarı etiket. Alımda para yetmezse kırmızı yazı, başarısız denemede sallanır. Satışta "+".
    local p = L.price
    local shake = self.fail > 0 and (math.floor(self.time * 40) % 2 == 0 and -1 or 1) or 0
    W.pill(p.x + shake, p.y, p.w, p.h, C.yellow)
    love.graphics.setColor(C.yellowHi)
    love.graphics.rectangle("fill", p.x + shake + 2, p.y + 1, p.w - 4, 1)
    local text = (self.mode == "sell" and "+" or "") .. self:total() .. "G"
    local tw = math.ceil(Fonts.width(text) - Fonts.effMult())
    local ok = self.mode == "sell" or (self.inventory.money >= self:total() and self.fail == 0)
    Fonts.print(text, p.x + shake + math.floor((p.w - tw) / 2), Fonts.centerY(p.y, p.h), ok and C.dark or C.red)
end

function ShopUI:drawPanel(L)
    local P = L.panel
    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(P.x, P.y, P.w, P.h)
    W.tab(L.tab, self.M.tabIcon, self.M.tab, true, P.y)

    local entries = self:entries()
    for i = 1, COLS * ROWS do
        local s = self:slotRect(i)
        local e = entries[i]
        W.slot(s.x, s.y, SLOT, e ~= nil, i == self.sel and e ~= nil)
        if e then W.imageCentered(Assets.image(e.icon), s.x, s.y, SLOT, SLOT) end
    end
    if entries[self.sel] then
        local s = self:slotRect(self.sel)
        W.selectCorners(s.x, s.y, SLOT, self.time)
    end
    -- her kutucukta sahip olunan adet (alımda tohum; 0 dahil)
    for i, e in ipairs(entries) do
        local r = self:slotRect(i)
        W.badge(self.inventory:count(e.id), r.x, r.y, SLOT)
    end

    local ty = P.y + P.h - 10 - Fonts.capTop(SMALL)
    if #entries == 0 then Fonts.print(self.M.empty, P.x + PAD, ty, C.soft, C.shadow, SMALL) end
    local ptext = "1/1"
    Fonts.print(ptext, P.x + P.w - PAD - Fonts.width(ptext, SMALL), ty, C.text, C.shadow, SMALL)
end

function ShopUI:draw()
    if not self.open then return end
    local L = self:layout()

    love.graphics.setColor(C.dim)
    love.graphics.rectangle("fill", 0, 0, Screen.uiW, Screen.uiH)

    self:drawPanel(L)
    self:drawTitle(L.title)
    self:drawInfo(L)
    self:drawAmount(L)

    local hint = "Arrows: select   Q/E: amount   Space: " .. self.M.verb .. "   Esc: close"
    Fonts.print(hint, math.floor(L.all.x + (L.all.w - Fonts.width(hint, SMALL)) / 2), L.all.y + L.all.h + 7 - Fonts.capTop(SMALL),
        C.white, C.shadow, SMALL)
    love.graphics.setColor(1, 1, 1)
end

return ShopUI
