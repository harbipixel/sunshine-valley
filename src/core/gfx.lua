-- Küçük çizim yardımcıları
local Screen = require("src.core.screen")

local Gfx = {}

-- Görselin şeklini tek renge boyayan shader (dış çizgi için)
local silhouette = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        return vec4(color.rgb, color.a * Texel(tex, uv).a);
    }
]])

-- Görseli 1 piksellik beyaz dış çizgiyle çizer (yerdeki eşyalar için)
function Gfx.drawOutlined(img, x, y, r, g, b)
    x, y = Screen.snap(x), Screen.snap(y)
    love.graphics.setShader(silhouette)
    love.graphics.setColor(r or 1, g or 1, b or 1, 1)
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        love.graphics.draw(img, x + o[1], y + o[2])
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y)
end

-- Koyu dış çizgi rengi (referans görseldeki çit/kazık çizgisi)
Gfx.OUTLINE_COLOR = { 115 / 255, 62 / 255, 57 / 255, 1 }

local outlineShader = love.graphics.newShader([[
    extern vec2 texel;
    extern vec4 outline;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec4 p = Texel(tex, uv);
        if (p.a > 0.9) return p;
        float m = max(max(Texel(tex, uv + vec2(texel.x, 0.0)).a, Texel(tex, uv - vec2(texel.x, 0.0)).a),
                      max(Texel(tex, uv + vec2(0.0, texel.y)).a, Texel(tex, uv - vec2(0.0, texel.y)).a));
        if (m > 0.9) return outline;
        return p;   // yarı saydam gölge olduğu gibi kalır
    }
]])

-- drawFn'in çizdiklerini w x h boyutunda bir canvas'a alır ve birleşik şeklin etrafına
-- 1 piksellik dış çizgi ekler. Dönen canvas premultiplied alpha içerir:
-- çizerken love.graphics.setBlendMode("alpha", "premultiplied") kullan.
function Gfx.bakeOutlined(w, h, drawFn, color)
    local raw = love.graphics.newCanvas(w, h)
    local out = love.graphics.newCanvas(w, h)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(raw)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    drawFn()

    love.graphics.setCanvas(out)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setShader(outlineShader)
    outlineShader:send("texel", { 1 / w, 1 / h })
    outlineShader:send("outline", color or Gfx.OUTLINE_COLOR)
    love.graphics.draw(raw)
    love.graphics.pop()
    raw:release()
    return out
end

return Gfx
