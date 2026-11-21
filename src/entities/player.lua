local Input  = require("src.core.input")
local Assets = require("src.core.assets")
local Screen = require("src.core.screen")
local Human  = require("src.entities.human")
local Items  = require("src.game.items")
local Crops  = require("src.game.crops")
local Sfx    = require("src.core.sfx")

local Player = {}
Player.__index = Player

Player.WALK_SPEED = 60   -- piksel/sn
Player.RUN_SPEED  = 100

-- Olta ipinin düştüğü nokta (ayaklara göre, sağa bakarken). Animasyon karelerinden ölçüldü.
Player.CAST_X, Player.CAST_Y = 30, 20

Player.BITE_MIN, Player.BITE_MAX = 2, 6   -- balığın vurması için bekleme süresi (sn)
Player.BITE_WINDOW = 0.9                  -- "!" çıktıktan sonra tepki süresi (sn)
Player.REEL_TIME = 1.2                    -- çekme animasyonu süresi (sn)

-- Kürek: ucun toprağa girdiği nokta (ayaklara göre, sağa bakarken) ve dig animasyonunun kareleri (1 tabanlı).
-- tools_dig_strip13 karelerinden ölçüldü: 3. karede kürek toprakta, 8. karede toprak kaldırılıyor.
Player.DIG_X, Player.DIG_Y = 14, -1
Player.DIG_HIT_FRAME, Player.DIG_LIFT_FRAME = 3, 8
Player.AXE_HIT_FRAME = 7   -- axe animasyonunda baltanın ağaca değdiği kare (darbe yıldızı)
Player.DOING_FRAME = 4   -- doing animasyonunda elin yere değdiği kare (ekme / hasat)

function Player.new(x, y, world)
    local self = setmetatable({ x = x, y = y, world = world }, Player)
    self.sprite = Human.new({ hair = "shorthair" })
    self.mode = "free"        -- free | action | fishing
    self.inventory = nil      -- sahne atar (src.game.inventory)
    self.emote = nil          -- { image, time }
    return self
end

function Player:showEmote(name, duration)
    if name == "confused" then Sfx.play("deny", { volume = 0.6 }) end
    if name == "working" then Sfx.play("move", { pitch = 0.8 }) end
    self.emote = { image = Assets.image("UI/expression_" .. name .. ".png"), time = duration or 1 }
end

function Player:facing() return self.sprite.flip and -1 or 1 end

-------------------------------------------------------------------------------
-- Balık tutma
--   casting -> waiting -> bite -> reeling -> caught
--   waiting sırasında F veya hareket: vazgeç;  bite sırasında F: çek;  süre dolarsa balık kaçar
-------------------------------------------------------------------------------
function Player:castPoint()
    return self.x + self:facing() * Player.CAST_X, self.y + Player.CAST_Y
end

function Player:startFishing()
    local cx, cy = self:castPoint()
    local w, m = self.world, 4   -- m: ipin kıyıya değmemesi için pay
    if not (w and w:isWater(cx, cy) and w:isWater(cx - self:facing() * m, cy)
            and w:isWater(cx, cy - m) and w:isWater(cx, cy + m)) then
        self:showEmote("confused", 0.8)   -- önünde su yok
        return
    end
    self.mode, self.phase = "fishing", "casting"
    self.sprite:play("casting", true)
    Sfx.play("cast")
end

function Player:stopFishing(emote)
    self.mode, self.phase = "free", nil
    self.sprite:play("idle")
    if emote then self:showEmote(emote, 0.8) end
end

function Player:updateFishing(dt)
    local s, phase = self.sprite, self.phase
    local fishPressed = Input.pressed("fish")

    if phase == "casting" then
        if s:isFinished() then
            self.phase = "waiting"
            Sfx.play("splash", { volume = 0.45, pitch = 1.3 })   -- şamandıra suya
            self.timer = love.math.random() * (Player.BITE_MAX - Player.BITE_MIN) + Player.BITE_MIN
            s:play("waiting")
        end
    elseif phase == "waiting" then
        local dx, dy = Input.axis()
        if fishPressed or dx ~= 0 or dy ~= 0 then return self:stopFishing() end
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.phase, self.timer = "bite", Player.BITE_WINDOW
            self:showEmote("alerted", Player.BITE_WINDOW)
            Sfx.play("bite")
        end
    elseif phase == "bite" then
        if fishPressed then
            self.phase, self.timer = "reeling", Player.REEL_TIME
            self.emote = nil
            s:play("reeling")
            Sfx.play("confirm", { volume = 0.6 })
        else
            self.timer = self.timer - dt
            if self.timer <= 0 then self:stopFishing("confused") end   -- kaçtı
        end
    elseif phase == "reeling" then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.phase = "caught"
            s:play("caught", true)
            Sfx.play("splash")
        end
    elseif phase == "caught" then
        if s:isFinished() then
            -- Balık sudan kıyıya, oyuncunun arkasına fırlar (sahne yerden toplanacak eşya oluşturur)
            local cx, cy = self:castPoint()
            if self.onCatch then self.onCatch(cx, cy) end
            self:stopFishing()
        end
    end
end

-------------------------------------------------------------------------------
-- Kullan (Space/E), öncelik sırasıyla:
--   1) sahne etkileşimi (ör. dükkâncıyla konuşma) -> self.interact() true dönerse
--   2) önündeki olgun ürünü topla   3) açık çukura tohum ek   4) tarlada kürekle çukur aç
--   5) önündeki ağacı baltayla kes (self.findTree(x, y) sahneden gelir)
-------------------------------------------------------------------------------
function Player:digPoint()
    return self.x + self:facing() * Player.DIG_X, self.y + Player.DIG_Y
end

-- Envanterdeki ilk tohum (Items.crop alanı olan eşya)
-- Eldeki tohumlar (Crops.LIST sırasıyla)
function Player:ownedSeeds()
    local out = {}
    if not self.inventory then return out end
    for _, c in ipairs(Crops.LIST) do
        if self.inventory:count(c.seed) > 0 then out[#out + 1] = c.seed end
    end
    return out
end

-- Ekilecek tohum: seçili tohum (C ile değişir); bittiyse eldeki ilk tohuma geçer
function Player:seed()
    if not (self.activeSeed and self.inventory and self.inventory:count(self.activeSeed) > 0) then
        self.activeSeed = self:ownedSeeds()[1]
    end
    if self.activeSeed then return self.activeSeed, Items.get(self.activeSeed).crop end
end

function Player:cycleSeed()
    local owned = self:ownedSeeds()
    if #owned == 0 then return end
    local cur = self:seed()
    for i, id in ipairs(owned) do
        if id == cur then self.activeSeed = owned[i % #owned + 1]; return end
    end
end

function Player:startTask(kind, anim)
    local tx, ty = self:digPoint()
    self.mode = "action"
    self.task = { kind = kind, x = tx, y = ty, stage = 0 }
    self.sprite:play(anim, true)
end

function Player:use()
    if self.interact and self.interact() then return end
    local tx, ty = self:digPoint()
    local farm = self.farm
    if farm then
        local plot = farm:plotAtPoint(tx, ty)
        if plot and plot.crop then
            -- büyüyen ürün: olgunsa topla, değilse bekle
            if Crops.isRipe(plot.crop) then return self:startTask("harvest", "doing") end
            return self:showEmote("working", 0.8)
        end
        if farm:canPlant(tx, ty) then
            if self:seed() then return self:startTask("plant", "doing") end
            return self:showEmote("confused", 0.8)   -- tohum yok
        end
        local hasShovel = self.inventory == nil or self.inventory:count("shovel") > 0
        if hasShovel and farm:canDig(tx, ty) then return self:startTask("dig", "dig") end
    end
    local tree = self.findTree and self.findTree(tx, ty)
    if tree and (self.inventory == nil or self.inventory:count("axe") > 0) then
        self:startTask("chop", "axe")
        self.task.tree = tree
        return
    end
    self:showEmote("confused", 0.8)   -- önünde yapılacak bir şey yok
end

function Player:updateTask()
    local t, frame, farm = self.task, self.sprite.anim[1].frame, self.farm
    if t.kind == "chop" then
        if t.stage == 0 and frame >= Player.AXE_HIT_FRAME then
            t.stage = 1
            Sfx.play("chop")
            if t.tree:hit() then
                Sfx.play("fell")
                if self.onFell then self.onFell(t.tree) end
            end
        end
    elseif t.kind == "dig" then
        -- çukur animasyonla derinleşir: küçük çukur -> derin çukur (açık kalır, ekime hazır)
        if t.stage == 0 and frame >= Player.DIG_HIT_FRAME then
            t.plot, t.stage = farm:dig(t.x, t.y), 1
            Sfx.play("dig")
        elseif t.stage == 1 and frame >= Player.DIG_LIFT_FRAME then
            if t.plot then t.plot.soil = "04" end
            Sfx.play("dig", { pitch = 1.4, volume = 0.6 })
            t.stage = 2
        end
    elseif t.stage == 0 and frame >= Player.DOING_FRAME then
        t.stage = 1
        if t.kind == "plant" then
            local seedId, cropId = self:seed()
            if seedId and farm:plant(t.x, t.y, cropId) then
                self.inventory:remove(seedId)
                Sfx.play("plant")
            end
        elseif t.kind == "harvest" then
            local item, plot = farm:harvest(t.x, t.y)
            if item then
                self.inventory:add(item)
                Sfx.play("harvest")
                if self.onHarvest then self.onHarvest(plot.x * 16 + 8, plot.y * 16 + 4) end
            end
        end
    end
    if self.sprite:isFinished() then self.task = nil end
end

-------------------------------------------------------------------------------

function Player:keypressed(key)
    if key == "c" then
        if #self:ownedSeeds() > 1 then Sfx.play("move") end
        return self:cycleSeed()
    end
end

function Player:move(dx, dy, speed, dt)
    local w = self.world
    local nx, ny = self.x + dx * speed * dt, self.y + dy * speed * dt
    -- eksenleri ayrı dene: kıyı boyunca kayabilsin
    if not w or w:isWalkable(nx, self.y) then self.x = nx end
    if not w or w:isWalkable(self.x, ny) then self.y = ny end
end

function Player:update(dt)
    if self.mode == "action" then
        if self.task then self:updateTask() end
        if self.sprite:isFinished() then self.mode = "free" end
    elseif self.mode == "fishing" then
        self:updateFishing(dt)
    else
        local dx, dy = Input.axis()
        local running = Input.down("run")
        if dx ~= 0 or dy ~= 0 then
            if dx ~= 0 then self.sprite.flip = dx < 0 end
            self:move(dx, dy, running and Player.RUN_SPEED or Player.WALK_SPEED, dt)
            self.sprite:play(running and "run" or "walk")
        else
            self.sprite:play("idle")
        end
        if Input.pressed("fish") then self:startFishing()
        elseif Input.pressed("action") then self:use() end
    end

    self.sprite:update(dt)
    if self.emote then
        self.emote.time = self.emote.time - dt
        if self.emote.time <= 0 then self.emote = nil end
    end
end

function Player:draw()
    self.sprite:draw(self.x, self.y)

    local headY = self.y - 26
    love.graphics.setColor(1, 1, 1)

    -- Çekerken ayakların altında dolan çubuk (greenbar_00..06)
    if self.mode == "fishing" and self.phase == "reeling" then
        local p = math.max(0, math.min(1, 1 - self.timer / Player.REEL_TIME))
        local i = math.floor(p * 6)
        local bar = Assets.image(("UI/greenbar_%02d.png"):format(i))
        love.graphics.draw(bar, Screen.snap(self.x - bar:getWidth() / 2), Screen.snap(self.y + 3))
    end

    if self.emote then
        local img = self.emote.image
        love.graphics.draw(img, Screen.snap(self.x - img:getWidth() / 2), Screen.snap(headY - img:getHeight()))
    end

    if DEBUG then
        local dx, dy = self:digPoint()
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("fill", math.floor(dx), math.floor(dy), 1, 1)
        local cx, cy = self:castPoint()
        local ok = self.world and self.world:isWater(cx, cy)
        love.graphics.setColor(ok and 0 or 1, ok and 1 or 0, 0)
        love.graphics.rectangle("fill", math.floor(cx), math.floor(cy), 1, 1)
        love.graphics.setColor(1, 1, 1)
    end
end

return Player
