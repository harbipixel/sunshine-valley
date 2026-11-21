-- Yerden toplanan eşya (balık, odun...): bir noktadan kavis çizerek uçar, yere düşer.
-- Oyuncu yaklaşınca ona doğru çekilir (mıknatıs) ve değince toplanır.
local Assets = require("src.core.assets")
local Gfx    = require("src.core.gfx")

local FishItem = {}
FishItem.__index = FishItem

FishItem.FLIGHT_TIME = 0.6
FishItem.ARC_HEIGHT = 28
FishItem.ATTRACT_RADIUS = 18     -- bu mesafede oyuncuya doğru uçmaya başlar
FishItem.COLLECT_RADIUS = 3      -- bu mesafede toplanır
FishItem.ATTRACT_ACCEL = 600     -- piksel/sn²

-- id: envantere girecek eşya (varsayılan "fish"); arc: kavis yüksekliği
function FishItem.new(fromX, fromY, toX, toY, id, arc)
    local Items = require("src.game.items")
    id = id or "fish"
    return setmetatable({
        sx = fromX, sy = fromY, x = toX, y = toY, id = id, arc = arc or FishItem.ARC_HEIGHT,
        t = 0, state = "flying", speed = 0, collected = false,
        image = Assets.image(Items.get(id).icon),
    }, FishItem)
end

-- tx, ty: oyuncunun ayakları; canAttract: oyuncu toplayabilir durumda mı
function FishItem:update(dt, tx, ty, canAttract)
    if self.state == "flying" then
        self.t = self.t + dt
        if self.t >= FishItem.FLIGHT_TIME then self.state = "landed" end
        return
    end

    -- hedef: oyuncunun gövdesi (ayaklardan biraz yukarı)
    local gx, gy = tx, ty - 6
    local dx, dy = gx - self.x, gy - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if self.state == "landed" and canAttract and dist <= FishItem.ATTRACT_RADIUS then
        self.state = "attract"
    end
    if self.state == "attract" then
        self.speed = self.speed + FishItem.ATTRACT_ACCEL * dt
        local step = self.speed * dt
        if dist <= math.max(FishItem.COLLECT_RADIUS, step) then
            self.x, self.y, self.collected = gx, gy, true
        else
            self.x, self.y = self.x + dx / dist * step, self.y + dy / dist * step
        end
    end
end

function FishItem:draw()
    local img = self.image
    local w, h = img:getWidth(), img:getHeight()
    local x, y, shx, shy = self.x, self.y, self.x, self.y
    if self.state == "flying" then
        local p = self.t / FishItem.FLIGHT_TIME
        shx = self.sx + (self.x - self.sx) * p
        shy = self.sy + (self.y - self.sy) * p
        x, y = shx, shy - math.sin(p * math.pi) * self.arc
    end
    if self.state ~= "attract" then
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.ellipse("fill", shx, shy, 5, 2)
    end
    Gfx.drawOutlined(img, x - w / 2, y - h)
end

return FishItem
