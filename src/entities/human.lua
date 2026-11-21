-- Katmanlı Sunnyside insan karakteri: base (gövde) + saç + aletler.
-- Her animasyon klasöründe aynı kare düzenine sahip katman şeritleri bulunur (96x64 kare).
local Assets    = require("src.core.assets")
local Animation = require("src.core.animation")

local Human = {}
Human.__index = Human

Human.HAIRS = { "bowlhair", "curlyhair", "longhair", "mophair", "shorthair", "spikeyhair" }

-- Sanatçının Aseprite kaynağında (Characters/_Source/Human) tüm karelerin süresi 75 ms.
-- Oyun hissi için tek tek hızlandırmak/yavaşlatmak istersen ANIMS içinde `fps` ver.
Human.FPS = 1000 / 75   -- ~13.3

-- animasyon adı -> klasör, döngü (fps opsiyonel; yoksa Human.FPS)
Human.ANIMS = {
    idle      = { dir = "IDLE" },
    walk      = { dir = "WALKING" },
    run       = { dir = "RUN" },
    jump      = { dir = "JUMP",      loop = false },
    roll      = { dir = "ROLL",      loop = false },
    attack    = { dir = "ATTACK",    loop = false },
    axe       = { dir = "AXE",       loop = false },
    dig       = { dir = "DIG",       loop = false },
    mining    = { dir = "MINING",    loop = false },
    hammering = { dir = "HAMMERING", loop = false },
    watering  = { dir = "WATERING",  loop = false },
    doing     = { dir = "DOING",     loop = false },
    carry     = { dir = "CARRY" },
    casting   = { dir = "CASTING",   loop = false },
    reeling   = { dir = "REELING" },
    caught    = { dir = "CAUGHT",    loop = false },
    waiting   = { dir = "WAITING" },
    swimming  = { dir = "SWIMMING" },
    hurt      = { dir = "HURT",      loop = false },
    death     = { dir = "DEATH",     loop = false },
}

local FRAME_W, FRAME_H = 96, 64
-- Karakterin ayaklarının kare içindeki konumu (pivot). Gerekirse F1 debug ile ince ayar yap.
local PIVOT_X, PIVOT_Y = 48, 42

-- Bir animasyonun tüm katmanlarını yükler. Dosya adları tutarsız olabildiği için
-- (ör. "base_hamering_strip23.png") klasör taranır.
local function loadLayers(anim, layers)
    local def = Human.ANIMS[anim]
    assert(def, "Unknown animation: " .. tostring(anim))
    local dir = "Characters/Human/" .. def.dir
    local result = {}
    for _, layer in ipairs(layers) do
        local rel, n = Assets.find(dir, "^" .. layer .. "_.-_strip(%d+)%.png$")
        if rel then
            result[#result + 1] = Animation.new(rel, {
                frameW = FRAME_W, frameH = FRAME_H, frames = tonumber(n),
                fps = def.fps or Human.FPS, loop = def.loop,
            })
        end
    end
    return result
end

function Human.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Human)
    self.hair = opts.hair or "shorthair"
    self.layers = { "base", self.hair }
    if opts.tools ~= false then self.layers[#self.layers + 1] = "tools" end   -- NPC'ler alet taşımaz
    self.cache = {}
    self.flip = false
    self:play("idle")
    return self
end

-- Yürüme <-> koşma geçişinde adım kaldığı yerden devam eder (ikisi de 8 kare)
local LOCOMOTION = { walk = true, run = true }

function Human:play(name, restart)
    if self.current == name and not restart then return end
    local prevTime = self.anim and self.anim[1] and self.anim[1].time or 0
    local keepPhase = not restart and LOCOMOTION[self.current] and LOCOMOTION[name]
    self.current = name
    if not self.cache[name] then self.cache[name] = loadLayers(name, self.layers) end
    self.anim = self.cache[name]
    for _, a in ipairs(self.anim) do
        a:reset()
        if keepPhase then a:update(prevTime) end
    end
end

function Human:isFinished()
    return self.anim[1] ~= nil and self.anim[1].finished
end

function Human:update(dt)
    for _, a in ipairs(self.anim) do a:update(dt) end
end

function Human:draw(x, y)
    love.graphics.setColor(1, 1, 1)
    for _, a in ipairs(self.anim) do a:draw(x, y, self.flip, PIVOT_X, PIVOT_Y) end
end

return Human
