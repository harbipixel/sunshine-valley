-- Sprite sheet animasyonu. Hem tek satırlık şeritleri (strip) hem de çok satırlı grid'leri destekler.
local Assets = require("src.core.assets")
local Screen = require("src.core.screen")

local Animation = {}
Animation.__index = Animation

-- image: Image | asset yolu
-- opts: frameW, frameH, frames (kare sayısı), fps (varsayılan 10), loop (varsayılan true)
--       x, y, w, h: görselin yalnızca bir bölgesini kullan (ör. tileset içindeki animasyon)
function Animation.new(image, opts)
    if type(image) == "string" then image = Assets.image(image) end
    local iw, ih = image:getDimensions()
    local rx, ry = opts.x or 0, opts.y or 0
    local rw, rh = opts.w or (iw - rx), opts.h or (ih - ry)
    local fw, fh = opts.frameW, opts.frameH or rh
    local cols = math.floor(rw / fw)
    local count = opts.frames or cols * math.floor(rh / fh)

    local quads = {}
    for i = 0, count - 1 do
        local cx, cy = i % cols, math.floor(i / cols)
        quads[#quads + 1] = love.graphics.newQuad(rx + cx * fw, ry + cy * fh, fw, fh, iw, ih)
    end

    return setmetatable({
        image = image, quads = quads, frameW = fw, frameH = fh,
        fps = opts.fps or 10, loop = opts.loop ~= false,
        time = 0, frame = 1, finished = false,
    }, Animation)
end

-- Yalnızca kare sayısı dosya adında yazan ve tek satır olan şeritler için kısayol.
function Animation.fromStrip(rel, opts)
    opts = opts or {}
    local img = Assets.image(rel)
    local n = Assets.stripCount(rel)
    opts.frameW = opts.frameW or img:getWidth() / n
    opts.frames = opts.frames or n
    return Animation.new(img, opts)
end

function Animation:reset()
    self.time, self.frame, self.finished = 0, 1, false
end

function Animation:update(dt)
    if self.finished then return end
    self.time = self.time + dt
    local f = math.floor(self.time * self.fps) + 1
    if f > #self.quads then
        if self.loop then
            self.time = self.time % (#self.quads / self.fps)
            f = math.floor(self.time * self.fps) + 1
        else
            f, self.finished = #self.quads, true
        end
    end
    self.frame = f
end

-- x, y: çizim noktası; ox, oy: karenin içindeki pivot (varsayılan alt-orta); flip: yatay çevirme
function Animation:draw(x, y, flip, ox, oy)
    ox = ox or self.frameW / 2
    oy = oy or self.frameH
    love.graphics.draw(self.image, self.quads[self.frame],
        Screen.snap(x), Screen.snap(y), 0, flip and -1 or 1, 1, ox, oy)
end

return Animation
