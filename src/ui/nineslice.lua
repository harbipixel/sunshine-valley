-- Sunnyside UI 9-dilimli kutuları (UI/9slice_box_white/<prefix>_box_9slice_*.png, her parça 3x3).
--   "dt": koyu kahve panel, "lt": açık kahve, "w": beyaz
local Assets = require("src.core.assets")

local NineSlice = {}
NineSlice.__index = NineSlice

local cache = {}

function NineSlice.get(prefix)
    if cache[prefix] then return cache[prefix] end
    local self = setmetatable({ parts = {} }, NineSlice)
    for _, p in ipairs({ "tl", "tc", "tr", "lc", "c", "rc", "bl", "bc", "br" }) do
        self.parts[p] = Assets.image(("UI/9slice_box_white/%s_box_9slice_%s.png"):format(prefix, p))
    end
    cache[prefix] = self
    return self
end

-- Kenar parçaları tek renk şeritler olduğu için esnetilerek çizilir
function NineSlice:draw(x, y, w, h)
    local P, c = self.parts, 3
    local iw, ih = w - 2 * c, h - 2 * c
    love.graphics.draw(P.tl, x, y)
    love.graphics.draw(P.tr, x + w - c, y)
    love.graphics.draw(P.bl, x, y + h - c)
    love.graphics.draw(P.br, x + w - c, y + h - c)
    love.graphics.draw(P.tc, x + c, y, 0, iw / c, 1)
    love.graphics.draw(P.bc, x + c, y + h - c, 0, iw / c, 1)
    love.graphics.draw(P.lc, x, y + c, 0, 1, ih / c)
    love.graphics.draw(P.rc, x + w - c, y + c, 0, 1, ih / c)
    love.graphics.draw(P.c, x + c, y + c, 0, iw / c, ih / c)
end

return NineSlice
