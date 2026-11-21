-- Eylem tabanlı girdi: kod tuşları değil eylemleri sorar ("left", "action" ...).
local Input = {}

Input.bindings = {
    left   = { "a", "left" },
    right  = { "d", "right" },
    up     = { "w", "up" },
    down   = { "s", "down" },
    run    = { "lshift", "rshift" },
    action = { "space", "e" },
    fish   = { "f" },
}

local pressedThisFrame = {}

function Input.down(action)
    return love.keyboard.isDown(unpack(Input.bindings[action]))
end

function Input.pressed(action)
    for _, key in ipairs(Input.bindings[action]) do
        if pressedThisFrame[key] then return true end
    end
    return false
end

-- Normalize edilmiş hareket vektörü
function Input.axis()
    local x, y = 0, 0
    if Input.down("left")  then x = x - 1 end
    if Input.down("right") then x = x + 1 end
    if Input.down("up")    then y = y - 1 end
    if Input.down("down")  then y = y + 1 end
    if x ~= 0 and y ~= 0 then
        local inv = 1 / math.sqrt(2)
        x, y = x * inv, y * inv
    end
    return x, y
end

function Input.keypressed(key, isrepeat)
    if not isrepeat then pressedThisFrame[key] = true end
end

function Input.endFrame()
    pressedThisFrame = {}
end

return Input
