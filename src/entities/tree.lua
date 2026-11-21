-- Kesilebilir ağaç: baltayla HITS vuruşta devrilir, kütük kalır, REGROW saniye sonra yeniden büyür.
-- Gövdesi yürünemez (Tilemap:addSolid). Vurulunca kısa süre sallanır.
local Animation = require("src.core.animation")
local Assets    = require("src.core.assets")

local Tree = {}
Tree.__index = Tree

Tree.HITS = 3
Tree.REGROW = 90          -- sn
Tree.SHAKE_TIME = 0.25
Tree.WOOD_MIN, Tree.WOOD_MAX = 2, 3   -- devrilince düşen odun

Tree.KINDS = {
    "Elements/Plants/spr_deco_tree_01_strip4.png",   -- yuvarlak
    "Elements/Plants/spr_deco_tree_02_strip4.png",   -- çam
}

-- Kütük (tileset 512,81,16,15)
local STUMP = { 512, 81, 16, 15 }
local stumpQuad

-- x, y: gövdenin dibi (alt-orta)
function Tree.new(x, y, map, kind, phase)
    local self = setmetatable({ x = math.floor(x), y = math.floor(y), map = map, hp = Tree.HITS,
                                state = "standing", shake = 0, timer = 0 }, Tree)
    self.anim = Animation.fromStrip(Tree.KINDS[kind or 1], { fps = 4 })
    self.anim.time = phase or 0
    self:addSolid()
    return self
end

function Tree:addSolid()
    self.solid = self.map:addSolid(self.x - 4, self.y - 5, 8, 5)
end

-- Bu nokta ağacın vurulabilir bölgesinde mi? (gövde ve çevresi)
function Tree:hitTest(px, py)
    return self.state == "standing" and math.abs(px - self.x) <= 10 and py >= self.y - 12 and py <= self.y + 3
end

-- Baltayla vur. Dönen: true = devrildi
function Tree:hit()
    if self.state ~= "standing" then return false end
    self.hp = self.hp - 1
    self.shake = Tree.SHAKE_TIME
    if self.hp > 0 then return false end
    self.state, self.timer = "stump", Tree.REGROW
    self.map:removeSolid(self.solid)
    return true
end

-- player: yeniden büyürken oyuncu gövdenin üstündeyse bekler
function Tree:update(dt, player)
    self.anim:update(dt)
    self.shake = math.max(0, self.shake - dt)
    if self.state == "stump" then
        self.timer = self.timer - dt
        local onTop = player and math.abs(player.x - self.x) < 9 and math.abs(player.y - self.y) < 8
        if self.timer <= 0 and not onTop then
            self.state, self.hp = "standing", Tree.HITS
            self:addSolid()
        end
    end
end

function Tree:draw()
    love.graphics.setColor(1, 1, 1)
    if self.state == "stump" then
        local img = Assets.image("Tileset/spr_tileset_sunnysideworld_16px.png")
        stumpQuad = stumpQuad or love.graphics.newQuad(STUMP[1], STUMP[2], STUMP[3], STUMP[4], img:getDimensions())
        love.graphics.draw(img, stumpQuad, self.x - 8, self.y - STUMP[4] + 2)
        return
    end
    -- sallanma: 1 piksellik sağ-sol titreşim
    local dx = self.shake > 0 and ((math.floor(self.shake * 30) % 2 == 0) and 1 or -1) or 0
    self.anim:draw(self.x + dx, self.y)
end

return Tree
