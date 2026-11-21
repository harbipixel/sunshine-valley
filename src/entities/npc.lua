-- Kasaba halkı: evinin (home) çevresinde rastgele dolaşır.
-- Oyuncu yaklaşınca durur, ona döner ve konuşma balonu gösterir.
local Assets = require("src.core.assets")
local Screen = require("src.core.screen")
local Human  = require("src.entities.human")

local NPC = {}
NPC.__index = NPC

NPC.WALK_SPEED = 28
NPC.TALK_RADIUS = 22

-- opts: x, y, world, hair, name, wander (piksel yarıçap; 0 = yerinden ayrılmaz), facing (-1/1)
function NPC.new(opts)
    local self = setmetatable({
        x = opts.x, y = opts.y, homeX = opts.x, homeY = opts.y,
        world = opts.world, name = opts.name or "Villager",
        wander = opts.wander or 40,
        state = "idle", timer = love.math.random() * 3 + 1,
        talking = false, bubble = 0,
    }, NPC)
    self.sprite = Human.new({ hair = opts.hair, tools = false })
    self.sprite.flip = (opts.facing or 1) < 0
    self.sprite.anim[1].time = love.math.random()   -- herkes aynı anda nefes almasın
    self.defaultFlip = self.sprite.flip
    return self
end

function NPC:pickTarget()
    local w = self.world
    for _ = 1, 10 do
        local a = love.math.random() * math.pi * 2
        local r = love.math.random() * self.wander
        local tx, ty = self.homeX + math.cos(a) * r, self.homeY + math.sin(a) * r * 0.6
        if not w or w:isWalkable(tx, ty) then return tx, ty end
    end
end

function NPC:update(dt, player)
    local dx, dy = player.x - self.x, player.y - self.y
    local near = dx * dx + dy * dy <= NPC.TALK_RADIUS * NPC.TALK_RADIUS

    if near then
        if not self.talking then self.bubble = 2 end   -- yaklaşınca bir kez balon
        self.talking = true
        self.sprite.flip = dx < 0
        self.sprite:play("idle")
    else
        if self.talking then
            self.talking = false
            self.state, self.timer = "idle", 1 + love.math.random() * 2
            if self.wander == 0 then self.sprite.flip = self.defaultFlip end
        end
        if self.state == "idle" then
            self.sprite:play("idle")
            self.timer = self.timer - dt
            if self.timer <= 0 and self.wander > 0 then
                self.tx, self.ty = self:pickTarget()
                if self.tx then self.state = "walk" else self.timer = 1 end
            end
        elseif self.state == "walk" then
            local mx, my = self.tx - self.x, self.ty - self.y
            local dist = math.sqrt(mx * mx + my * my)
            local step = NPC.WALK_SPEED * dt
            if dist <= step then
                self.x, self.y = self.tx, self.ty
                self.state, self.timer = "idle", 1.5 + love.math.random() * 3
            else
                local nx, ny = self.x + mx / dist * step, self.y + my / dist * step
                if self.world and not self.world:isWalkable(nx, ny) then
                    self.state, self.timer = "idle", 1   -- yol kapalı, vazgeç
                else
                    self.x, self.y = nx, ny
                    if math.abs(mx) > 0.5 then self.sprite.flip = mx < 0 end
                    self.sprite:play("walk")
                end
            end
        end
    end

    self.bubble = math.max(0, self.bubble - dt)
    self.sprite:update(dt)
end

function NPC:draw()
    self.sprite:draw(self.x, self.y)
    if self.bubble > 0 then
        local img = Assets.image("UI/expression_chat.png")
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, Screen.snap(self.x - img:getWidth() / 2), Screen.snap(self.y - 26 - img:getHeight()))
    end
end

return NPC
