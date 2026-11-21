-- Ekilebilir ürünler (ucuzdan pahalıya). Görseller Elements/Crops/<id>_00..05:
--   00 = toprağa düşmüş tohum (tohum eşyasının ikonu), 01..04 = büyüme aşamaları (04 olgun), 05 = hasat ikonu.
-- Her ürün için Items içinde iki eşya üretilir: "<id>_seed" (dükkânda seedPrice) ve "<id>" (pazarda sellPrice).
--   stageTime: bir aşama kaç saniye (toplam büyüme = 4 * stageTime)
local Crops = {}

Crops.LIST = {
    { id = "carrot",      name = "Carrot",      seedPrice = 1,  sellPrice = 3,  stageTime = 6 },
    { id = "radish",      name = "Radish",      seedPrice = 2,  sellPrice = 5,  stageTime = 7 },
    { id = "parsnip",     name = "Parsnip",     seedPrice = 3,  sellPrice = 7,  stageTime = 8 },
    { id = "potato",      name = "Potato",      seedPrice = 4,  sellPrice = 9,  stageTime = 9 },
    { id = "beetroot",    name = "Beetroot",    seedPrice = 5,  sellPrice = 12, stageTime = 10 },
    { id = "wheat",       name = "Wheat",       seedPrice = 6,  sellPrice = 14, stageTime = 10 },
    { id = "cabbage",     name = "Cabbage",     seedPrice = 8,  sellPrice = 18, stageTime = 12 },
    { id = "kale",        name = "Kale",        seedPrice = 10, sellPrice = 22, stageTime = 13 },
    { id = "cauliflower", name = "Cauliflower", seedPrice = 15, sellPrice = 32, stageTime = 15 },
    { id = "sunflower",   name = "Sunflower",   seedPrice = 20, sellPrice = 45, stageTime = 17 },
    { id = "pumpkin",     name = "Pumpkin",     seedPrice = 30, sellPrice = 70, stageTime = 20 },
}

Crops.defs = {}
for _, c in ipairs(Crops.LIST) do
    c.stages = {}
    for i = 0, 4 do c.stages[#c.stages + 1] = ("%s_%02d"):format(c.id, i) end
    c.harvest = c.id
    c.seed = c.id .. "_seed"
    Crops.defs[c.id] = c
end

function Crops.get(id)
    return assert(Crops.defs[id], "Unknown crop: " .. tostring(id))
end

function Crops.image(crop)
    local Assets = require("src.core.assets")
    return Assets.image("Elements/Crops/" .. Crops.get(crop.id).stages[crop.stage] .. ".png")
end

function Crops.isRipe(crop)
    return crop.stage >= #Crops.get(crop.id).stages
end

return Crops
