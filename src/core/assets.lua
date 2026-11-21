-- Asset yükleme + önbellek. Tüm yollar Sunnyside asset köküne görelidir.
local Assets = {}

Assets.ROOT = "Sprites/Sunnyside_World_Assets/"

local images = {}

function Assets.path(rel) return Assets.ROOT .. rel end

function Assets.image(rel)
    local img = images[rel]
    if not img then
        img = love.graphics.newImage(Assets.path(rel))
        img:setFilter("nearest", "nearest")
        images[rel] = img
    end
    return img
end

-- Bir klasörde Lua pattern'ine uyan ilk dosyayı bulur; yakalanan grupları da döndürür.
function Assets.find(dir, pattern)
    for _, name in ipairs(love.filesystem.getDirectoryItems(Assets.path(dir))) do
        local caps = { name:match(pattern) }
        if #caps > 0 then return dir .. "/" .. name, unpack(caps) end
    end
end

-- "xxx_strip8.png" -> 8
function Assets.stripCount(rel)
    return tonumber(rel:match("_strip(%d+)%.png$"))
end

return Assets
