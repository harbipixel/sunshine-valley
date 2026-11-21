-- Envanter ekranı: sekmeler, 5x3 kutucuk ızgarası, sayfalar, seçili eşya için bilgi kutusu.
-- Tamamı oyun pikseli (sanal çözünürlük) koordinatlarında çizilir; Play:drawUI ölçekli dönüşümü kurar.
local Assets    = require("src.core.assets")
local Fonts     = require("src.core.fonts")
local Screen    = require("src.core.screen")
local NineSlice = require("src.ui.nineslice")
local Items     = require("src.game.items")
local W         = require("src.ui.widgets")
local Sfx       = require("src.core.sfx")

local InventoryUI = {}
InventoryUI.__index = InventoryUI

local COLS, ROWS = 5, 3
local PER_PAGE = COLS * ROWS
local SLOT, GAP, PAD = 20, 2, 7
local TAB_H = 15
local GRID_W = COLS * SLOT + (COLS - 1) * GAP
local GRID_H = ROWS * SLOT + (ROWS - 1) * GAP
local PANEL_W = GRID_W + PAD * 2
local PANEL_H = GRID_H + PAD + 14

local C = W.C

function InventoryUI.new(inventory)
    return setmetatable({
        inventory = inventory, open = false,
        tab = 1, page = 1, sel = 1, time = 0,
    }, InventoryUI)
end

function InventoryUI:toggle()
    self.open = not self.open
    Sfx.play(self.open and "open" or "close")
end

local TAB_GAP, TAB_MARGIN = 2, 6

local function tabWidth(t) return W.tabWidth(t.name) end

-- Panel genişliği: ızgara ya da sekmeler (hangisi genişse). Sekmeler asla dışarı taşmaz.
function InventoryUI:panelWidth()
    local tabs = TAB_MARGIN * 2 - TAB_GAP
    for _, t in ipairs(Items.TABS) do tabs = tabs + tabWidth(t) + TAB_GAP end
    return math.max(PANEL_W, tabs)
end

-- Panelin sol üstü (sekmelerin altı)
function InventoryUI:layout()
    local pw = self:panelWidth()
    local px = math.floor((Screen.uiW - pw) / 2)
    local py = math.floor((Screen.uiH - PANEL_H - TAB_H) / 2) + TAB_H
    return px, py, pw
end

function InventoryUI:stacks()
    return self.inventory:list(Items.TABS[self.tab].id)
end

function InventoryUI:pageCount()
    return math.max(1, math.ceil(#self:stacks() / PER_PAGE))
end

function InventoryUI:slotRect(i)
    local px, py, pw = self:layout()
    local gx = px + math.floor((pw - GRID_W) / 2)   -- ızgara panelde ortalı
    local c, r = (i - 1) % COLS, math.floor((i - 1) / COLS)
    return gx + c * (SLOT + GAP), py + PAD + r * (SLOT + GAP), SLOT, SLOT
end

function InventoryUI:tabRects()
    local px, py = self:layout()
    local rects, x = {}, px + TAB_MARGIN
    for i, t in ipairs(Items.TABS) do
        local w = tabWidth(t)
        rects[i] = { x = x, y = py - TAB_H, w = w, h = TAB_H }
        x = x + w + TAB_GAP
    end
    return rects
end

function InventoryUI:arrowRects()
    local px, py, pw = self:layout()
    local ay = py + math.floor(PANEL_H / 2) - 6
    return { x = px - 14, y = ay, w = 11, h = 12 }, { x = px + pw + 3, y = ay, w = 11, h = 12 }
end

local function inside(r, x, y) return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h end

-- Seçili kutucuktaki yığın (yoksa nil)
function InventoryUI:selected()
    return self:stacks()[(self.page - 1) * PER_PAGE + self.sel]
end

function InventoryUI:setTab(i)
    if i < 1 or i > #Items.TABS or i == self.tab then return end
    self.tab, self.page, self.sel = i, 1, 1
    Sfx.play("move", { pitch = 0.8 })
end

function InventoryUI:setPage(p)
    self.page = math.max(1, math.min(self:pageCount(), p))
end

---------------------------------------------------------------------------
-- Girdi
---------------------------------------------------------------------------

function InventoryUI:move(dx, dy)
    local c, r = (self.sel - 1) % COLS, math.floor((self.sel - 1) / COLS)
    c, r = c + dx, r + dy
    if c < 0 then
        if self.page > 1 then self:setPage(self.page - 1); c = COLS - 1 else c = 0 end
    elseif c >= COLS then
        if self.page < self:pageCount() then self:setPage(self.page + 1); c = 0 else c = COLS - 1 end
    end
    r = math.max(0, math.min(ROWS - 1, r))
    local sel = r * COLS + c + 1
    if sel ~= self.sel then Sfx.play("move") end
    self.sel = sel
end

-- true dönerse tuş envanter tarafından kullanıldı
function InventoryUI:keypressed(key)
    if key == "tab" or key == "i" then self:toggle(); return true end
    if not self.open then return false end
    if key == "escape" then self:toggle()
    elseif key == "left" or key == "a" then self:move(-1, 0)
    elseif key == "right" or key == "d" then self:move(1, 0)
    elseif key == "up" or key == "w" then self:move(0, -1)
    elseif key == "down" or key == "s" then self:move(0, 1)
    elseif key == "q" then self:setTab(self.tab - 1)
    elseif key == "e" then self:setTab(self.tab + 1)
    end
    return true
end

function InventoryUI:mousemoved(x, y)
    if not self.open then return end
    for i = 1, PER_PAGE do
        local sx, sy, w, h = self:slotRect(i)
        if x >= sx and y >= sy and x < sx + w and y < sy + h and self.sel ~= i then
            self.sel = i
            Sfx.play("move", { volume = 0.6 })
        end
    end
end

function InventoryUI:mousepressed(x, y, button)
    if not self.open then return false end
    if button ~= 1 then return true end
    for i, r in ipairs(self:tabRects()) do
        if inside(r, x, y) then self:setTab(i); return true end
    end
    local l, r = self:arrowRects()
    if self:pageCount() > 1 then
        if inside(l, x, y) then self:setPage(self.page - 1) end
        if inside(r, x, y) then self:setPage(self.page + 1) end
    end
    return true
end

function InventoryUI:wheelmoved(_, dy)
    if not self.open then return end
    if dy > 0 then self:setPage(self.page - 1) elseif dy < 0 then self:setPage(self.page + 1) end
end

function InventoryUI:update(dt)
    self.time = self.time + dt
end

---------------------------------------------------------------------------
-- Çizim
---------------------------------------------------------------------------


function InventoryUI:drawTab(i, r, active)
    local t = Items.TABS[i]
    local _, py = self:layout()
    W.tab(r, t.icon, t.name, active, py)
end

local SMALL = 0.5   -- küçük yazı ölçeği

function InventoryUI:drawBadge(count, sx, sy) W.badge(count, sx, sy, SLOT) end

function InventoryUI:drawTooltip(stack, sx, sy)
    local def = Items.get(stack.id)
    local nameW, descW = Fonts.width(def.name), Fonts.width(def.desc, SMALL)
    local tagW = math.ceil(Fonts.width(def.tag, SMALL)) + 8
    local w = math.ceil(math.max(nameW, descW, tagW)) + 12
    local h = 6 + 7 + 4 + 4 + 4 + 13 + 4
    local x, y = sx + SLOT + 7, sy - 6
    local pointLeft = true
    if x + w > Screen.uiW - 2 then x, pointLeft = sx - w - 7, false end
    y = math.max(2, math.min(Screen.uiH - h - 2, y))

    love.graphics.setColor(1, 1, 1)
    NineSlice.get("w"):draw(x, y, w, h)
    -- kutucuğu gösteren üçgen: kutunun dışına taşar. indicator.png aşağıyı gösterir, döndürülür.
    -- (0, h) orijiniyle +90° → uç solda (X), taban X+h'de; -90° → uç sağda (X), taban X-h'de.
    local ind = Assets.image("UI/indicator.png")
    local ih, iw = ind:getHeight(), ind:getWidth()
    local cy = sy + math.floor(SLOT / 2)
    if pointLeft then
        love.graphics.draw(ind, x - ih + 2, cy - iw / 2, math.pi / 2, 1, 1, 0, ih)
    else
        love.graphics.draw(ind, x + w + ih - 2, cy + iw / 2, -math.pi / 2, 1, 1, 0, ih)
    end

    local cx = x + 6
    Fonts.print(def.name, cx, y + 6 - Fonts.capTop(), C.dark)
    Fonts.print(def.desc, cx, y + 6 + 7 + 4 - Fonts.capTop(SMALL), C.gray, nil, SMALL)

    -- etiket (label_left / middle / right)
    local ly = y + h - 4 - 13
    local L, M, R = Assets.image("UI/label_left.png"), Assets.image("UI/label_middle.png"), Assets.image("UI/label_right.png")
    local mw = tagW - L:getWidth() - R:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(L, cx, ly)
    love.graphics.draw(M, cx + L:getWidth(), ly, 0, mw / M:getWidth(), 1)
    love.graphics.draw(R, cx + L:getWidth() + mw, ly)
    Fonts.print(def.tag, cx + 4, ly + 4 - Fonts.capTop(SMALL), C.white, C.shadow, SMALL)
end

function InventoryUI:draw()
    if not self.open then return end
    local px, py, pw = self:layout()

    love.graphics.setColor(C.dim)
    love.graphics.rectangle("fill", 0, 0, Screen.uiW, Screen.uiH)

    -- pasif sekmeler panelin arkasında
    local tabs = self:tabRects()
    for i, r in ipairs(tabs) do
        if i ~= self.tab then self:drawTab(i, r, false) end
    end

    love.graphics.setColor(1, 1, 1)
    NineSlice.get("dt"):draw(px, py, pw, PANEL_H)
    self:drawTab(self.tab, tabs[self.tab], true)

    -- kutucuklar
    local stacks = self:stacks()
    local first = (self.page - 1) * PER_PAGE
    for i = 1, PER_PAGE do
        local sx, sy = self:slotRect(i)
        local selected = i == self.sel
        local st = stacks[first + i]
        W.slot(sx, sy, SLOT, st ~= nil, selected)
        if st then W.imageCentered(Assets.image(Items.get(st.id).icon), sx, sy, SLOT, SLOT) end
    end
    -- seçim köşeleri (hafif nabız)
    local sx, sy = self:slotRect(self.sel)
    W.selectCorners(sx, sy, SLOT, self.time)

    -- rozetler en üstte (seçim köşelerinin ve komşu kutucukların üstüne taşabilir)
    for i = 1, PER_PAGE do
        local st = stacks[first + i]
        if st and st.count > 1 then
            local bx, by = self:slotRect(i)
            self:drawBadge(st.count, bx, by)
        end
    end

    -- sayfa bilgisi ve oklar
    local pages = self:pageCount()
    local ptext = self.page .. "/" .. pages
    local ty = py + PANEL_H - 10 - Fonts.capTop(SMALL)
    Fonts.print(ptext, px + pw - PAD - Fonts.width(ptext, SMALL), ty, C.text, C.shadow, SMALL)
    if #stacks == 0 then
        Fonts.print("Nothing here yet", px + PAD, ty, { 0.85, 0.75, 0.68 }, C.shadow, SMALL)
    end
    if pages > 1 then
        local l, r = self:arrowRects()
        love.graphics.setColor(1, 1, 1, self.page > 1 and 1 or 0.35)
        love.graphics.draw(Assets.image("UI/arrow_left.png"), l.x, l.y)
        love.graphics.setColor(1, 1, 1, self.page < pages and 1 or 0.35)
        love.graphics.draw(Assets.image("UI/arrow_right.png"), r.x, r.y)
    end

    local st = self:selected()
    if st then self:drawTooltip(st, sx, sy) end
    love.graphics.setColor(1, 1, 1)
end

return InventoryUI
