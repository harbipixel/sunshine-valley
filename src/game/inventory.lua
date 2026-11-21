-- Envanter: eklenme sırasını koruyan yığınlar listesi { id, count }.
local Items = require("src.game.items")

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
    return setmetatable({ stacks = {}, money = 0 }, Inventory)
end

function Inventory:addMoney(n)
    self.money = math.max(0, self.money + n)
end

-- Yeterli para varsa harcar
function Inventory:spend(n)
    if self.money < n then return false end
    self.money = self.money - n
    return true
end

function Inventory:find(id)
    for i, s in ipairs(self.stacks) do
        if s.id == id then return s, i end
    end
end

function Inventory:add(id, n)
    Items.get(id)   -- tanımsız id'yi erken yakala
    n = n or 1
    local s = self:find(id)
    if s then s.count = s.count + n
    else self.stacks[#self.stacks + 1] = { id = id, count = n } end
end

function Inventory:remove(id, n)
    local s, i = self:find(id)
    if not s then return false end
    s.count = s.count - (n or 1)
    if s.count <= 0 then table.remove(self.stacks, i) end
    return true
end

function Inventory:count(id)
    local s = self:find(id)
    return s and s.count or 0
end

-- Belirli sekmedeki yığınlar (sırasıyla)
function Inventory:list(tab)
    local out = {}
    for _, s in ipairs(self.stacks) do
        if Items.get(s.id).tab == tab then out[#out + 1] = s end
    end
    return out
end

return Inventory
