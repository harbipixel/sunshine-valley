-- Hedefi yumuşak takip eden, piksele yuvarlanan kamera.
local Screen = require("src.core.screen")

local Camera = {}
Camera.__index = Camera

function Camera.new(x, y)
    return setmetatable({ x = x or 0, y = y or 0, smooth = 8, bounds = nil }, Camera)
end

-- bounds: { x, y, w, h } dünya sınırları (opsiyonel)
function Camera:setBounds(x, y, w, h) self.bounds = { x = x, y = y, w = w, h = h } end

function Camera:follow(tx, ty, dt)
    local k = 1 - math.exp(-self.smooth * dt)
    self.x = self.x + (tx - self.x) * k
    self.y = self.y + (ty - self.y) * k
    local b = self.bounds
    if b then
        local hw, hh = Screen.w / 2, Screen.h / 2
        self.x = math.max(b.x + hw, math.min(b.x + b.w - hw, self.x))
        self.y = math.max(b.y + hh, math.min(b.y + b.h - hh, self.y))
    end
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(Screen.snap(Screen.w / 2 - self.x), Screen.snap(Screen.h / 2 - self.y))
end

function Camera:detach() love.graphics.pop() end

-- Görünen dünya dikdörtgeni (culling için)
function Camera:view()
    return self.x - Screen.w / 2, self.y - Screen.h / 2, Screen.w, Screen.h
end

function Camera:toWorld(gx, gy)
    return gx + self.x - Screen.w / 2, gy + self.y - Screen.h / 2
end

return Camera
