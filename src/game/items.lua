-- Eşya tanımları. Envanter yalnızca id + adet tutar; görünen bilgiler buradan gelir.
--   name: görünen ad, desc: ikinci satır (gri), tag: etiket metni, tab: hangi sekmede
--   icon: asset yolu (Sprites/Sunnyside_World_Assets/ altına göre)
local Items = {}

Items.TABS = {
    { id = "items", name = "Items", icon = "UI/basket.png" },
    { id = "tools", name = "Tools", icon = "UI/hand_open_01.png" },
}

Items.defs = {
    -- sell: pazarda birim satış fiyatı (yoksa satılmaz)
    fish     = { name = "Fish",         desc = "Caught from the sea", tag = "FOOD",   tab = "items", icon = "Elements/Crops/fish.png", sell = 1 },
    wood     = { name = "Wood",         desc = "Chopped from trees",  tag = "MATERIAL", tab = "items", icon = "Elements/Crops/wood.png", sell = 2 },

    rod      = { name = "Fishing Rod",  desc = "For catching fish",   tag = "TOOL",   tab = "tools", icon = "UI/rod.png" },
    axe      = { name = "Axe",          desc = "Chops trees",         tag = "TOOL",   tab = "tools", icon = "UI/axe.png" },
    pickaxe  = { name = "Pickaxe",      desc = "Breaks rocks",        tag = "TOOL",   tab = "tools", icon = "UI/pickaxe.png" },
    shovel   = { name = "Shovel",       desc = "Digs the soil",       tag = "TOOL",   tab = "tools", icon = "UI/shovel.png" },
    water    = { name = "Watering Can", desc = "Waters your crops",   tag = "TOOL",   tab = "tools", icon = "UI/water.png" },
    hammer   = { name = "Hammer",       desc = "Builds and repairs",  tag = "TOOL",   tab = "tools", icon = "UI/hammer.png" },
    sword    = { name = "Sword",        desc = "Keeps you safe",      tag = "WEAPON", tab = "tools", icon = "UI/sword.png" },
}

-- Ürünler ve tohumları src/game/crops.lua tablosundan üretilir.
--   crop: ekilince büyüyen ürün (tohumlarda)
for _, c in ipairs(require("src.game.crops").LIST) do
    Items.defs[c.id] = { name = c.name, desc = "Fresh from the farm", tag = "CROP", tab = "items",
                         icon = "Elements/Crops/" .. c.id .. "_05.png", sell = c.sellPrice }
    Items.defs[c.seed] = { name = c.name .. " Seeds", desc = "Plant in a dug hole", tag = "SEED", tab = "items",
                           icon = "Elements/Crops/" .. c.id .. "_00.png", crop = c.id }
end

function Items.get(id)
    return assert(Items.defs[id], "Unknown item: " .. tostring(id))
end

return Items
