-- Envanter ve dükkân pencerelerinin ortak çizim parçaları (UI koordinatları).
local Assets    = require("src.core.assets")
local Fonts     = require("src.core.fonts")
local NineSlice = require("src.ui.nineslice")

local W = {}

W.SMALL = 0.5   -- küçük yazı ölçeği

-- Sunnyside UI paleti
W.C = {
    panel    = { 148 / 255, 85 / 255, 66 / 255 },   -- dt kutusunun iç rengi
    slot     = { 122 / 255, 68 / 255, 56 / 255 },
    slotTop  = { 101 / 255, 54 / 255, 47 / 255 },
    slotSel  = { 184 / 255, 111 / 255, 80 / 255 },
    outline  = { 24 / 255, 20 / 255, 37 / 255 },
    white    = { 1, 1, 1 },
    text     = { 1, 1, 1 },
    shadow   = { 24 / 255, 20 / 255, 37 / 255, 0.8 },
    dark     = { 24 / 255, 20 / 255, 37 / 255 },
    gray     = { 90 / 255, 105 / 255, 136 / 255 },
    light    = { 160 / 255, 170 / 255, 190 / 255 },
    soft     = { 0.85, 0.75, 0.68 },
    red      = { 228 / 255, 59 / 255, 68 / 255 },
    pink     = { 181 / 255, 80 / 255, 136 / 255 },
    yellow   = { 254 / 255, 200 / 255, 62 / 255 },
    yellowHi = { 255 / 255, 231 / 255, 98 / 255 },
    dim      = { 0, 0, 0, 0.35 },
    badge    = { 192 / 255, 203 / 255, 220 / 255 },   -- w kutusunun iç rengi
}
local C = W.C

-- 1 piksel köşeleri kesik dikdörtgen
function W.roundRect(x, y, w, h, color)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x + 1, y, w - 2, h)
    love.graphics.rectangle("fill", x, y + 1, w, h - 2)
end

-- Koyu çerçeveli renkli etiket kutusu (fiyat, rozet vb.)
function W.pill(x, y, w, h, fill)
    W.roundRect(x, y, w, h, C.outline)
    W.roundRect(x + 1, y + 1, w - 2, h - 2, fill)
end

function W.imageCentered(img, x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x + math.floor((w - img:getWidth()) / 2), y + math.floor((h - img:getHeight()) / 2))
end

-- Kutucuk: dolu = çerçeveli kutu (seçiliyse beyaz), boş = düz içe gömük
function W.slot(x, y, size, filled, selected)
    if filled then
        love.graphics.setColor(1, 1, 1)
        NineSlice.get(selected and "w" or "dt"):draw(x, y, size, size)
    else
        W.roundRect(x, y, size, size, selected and C.slotSel or C.slot)
        if not selected then
            love.graphics.setColor(C.slotTop)
            love.graphics.rectangle("fill", x + 1, y, size - 2, 1)
        end
    end
end

-- Kutucuğun sağ üst köşesindeki adet rozeti (referanstaki gibi iki katman):
-- koyu dış çizgi > 1px beyaz kenar > gri-mavi iç (w kutusunun rengi), üstünde koyu rakam
function W.badge(count, sx, sy, size)
    local text = tostring(count)
    local tw = math.ceil(Fonts.width(text, W.SMALL) - Fonts.effMult(W.SMALL))
    local bw, bh = math.max(9, tw + 6), 9
    local bx, by = sx + size - bw + 2, sy - 2
    W.pill(bx, by, bw, bh, C.white)
    W.roundRect(bx + 2, by + 2, bw - 4, bh - 4, C.badge)
    Fonts.print(text, bx + math.floor((bw - tw) / 2), Fonts.centerY(by, bh, W.SMALL), C.dark, nil, W.SMALL)
end

-- Seçim köşeleri (hafif nabız), w x h dikdörtgenin dört köşesine
function W.selectCornersRect(sx, sy, w, h, time)
    local b = math.floor(time * 2.5) % 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(Assets.image("UI/selectbox_tl.png"), sx - 3 - b, sy - 3 - b)
    love.graphics.draw(Assets.image("UI/selectbox_tr.png"), sx + w - 5 + b, sy - 3 - b)
    love.graphics.draw(Assets.image("UI/selectbox_bl.png"), sx - 3 - b, sy + h - 6 + b)
    love.graphics.draw(Assets.image("UI/selectbox_br.png"), sx + w - 5 + b, sy + h - 6 + b)
end

function W.selectCorners(sx, sy, size, time) W.selectCornersRect(sx, sy, size, size, time) end

-- Küçük üçgen ok (UI/indicator.png aşağıyı gösterir). dir: "down" | "up" | "right" | "left"; (x, y) ucun konumu
function W.triangle(x, y, dir)
    local ind = Assets.image("UI/indicator.png")
    local iw, ih = ind:getWidth(), ind:getHeight()
    love.graphics.setColor(1, 1, 1)
    if dir == "down" then love.graphics.draw(ind, x - iw / 2, y - ih)
    elseif dir == "up" then love.graphics.draw(ind, x - iw / 2, y + ih, 0, 1, -1)
    elseif dir == "right" then love.graphics.draw(ind, x - ih, y + iw / 2, -math.pi / 2)
    else love.graphics.draw(ind, x + ih, y - iw / 2, math.pi / 2) end
end

-- Sekme (panelle birleşik aktif sekme veya arkadaki pasif sekme). panelY: panelin üst kenarı
function W.tab(r, icon, name, active, panelY)
    local box = NineSlice.get("dt")
    if active then
        love.graphics.setColor(1, 1, 1)
        box:draw(r.x, r.y, r.w, r.h + 6)
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", r.x, panelY + 3, r.w, 3)
        love.graphics.rectangle("fill", r.x + 3, panelY, r.w - 6, 3)
    else
        love.graphics.setColor(0.72, 0.72, 0.72)
        box:draw(r.x, r.y + 2, r.w, r.h + 1)
    end
    local img = Assets.image(icon)
    local dy = active and 0 or 2
    love.graphics.setColor(active and { 1, 1, 1 } or { 0.8, 0.8, 0.8 })
    love.graphics.draw(img, r.x + 5, r.y + dy + math.floor((r.h - img:getHeight()) / 2) + 1)
    Fonts.print(name, r.x + 5 + 12 + 3, r.y + dy + 4 - Fonts.capTop(),
        active and C.text or { 0.85, 0.8, 0.75 }, C.shadow)
end

function W.tabWidth(name)
    return 5 + 12 + 3 + math.ceil(Fonts.width(name)) + 6
end

return W
