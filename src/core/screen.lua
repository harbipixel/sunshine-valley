-- Sanal çözünürlük (ör. 320x180) koordinatlarında çizer, pencereye tam sayı katıyla ölçekler.
-- Düşük çözünürlüklü canvas KULLANMIYORUZ: dünya doğrudan ölçeklenmiş olarak pencereye çizilir.
-- Böylece konumlar oyun pikseline değil gerçek ekran pikseline (1/scale) yuvarlanır;
-- pikseller keskin kalır ama kamera ve hareket titremez.
local Screen = {}

function Screen.init(w, h)
    Screen.w, Screen.h = w, h
    Screen.resize(love.graphics.getDimensions())
end

-- Arayüz ölçeği dünyadan biraz küçük (4x -> 3x, 6x -> 5x): UI daha ince görünür, yine tam sayı = keskin
Screen.UI_RATIO = 0.75

function Screen.resize(ww, wh)
    Screen.scale = math.max(1, math.floor(math.min(ww / Screen.w, wh / Screen.h)))
    Screen.ox = math.floor((ww - Screen.w * Screen.scale) / 2)
    Screen.oy = math.floor((wh - Screen.h * Screen.scale) / 2)
    -- UI koordinat sistemi: oyun alanını kaplar, birimi uiScale gerçek piksel
    Screen.uiScale = math.max(1, math.floor(Screen.scale * Screen.UI_RATIO + 0.5))
    Screen.uiW = math.floor(Screen.w * Screen.scale / Screen.uiScale)
    Screen.uiH = math.floor(Screen.h * Screen.scale / Screen.uiScale)
end

-- Pencere koordinatını UI koordinatına çevirir
function Screen.toUI(x, y)
    return (x - Screen.ox) / Screen.uiScale, (y - Screen.oy) / Screen.uiScale
end

-- UI çizimi için dönüşüm (push/pop çağıran yapar)
function Screen.applyUI()
    love.graphics.translate(Screen.ox, Screen.oy)
    love.graphics.scale(Screen.uiScale)
end

-- Değeri en yakın gerçek ekran pikseline yuvarlar (sanal koordinatlarda)
function Screen.snap(v)
    local s = Screen.scale
    return math.floor(v * s + 0.5) / s
end

function Screen.beginDraw()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.setScissor(Screen.ox, Screen.oy, Screen.w * Screen.scale, Screen.h * Screen.scale)
    love.graphics.translate(Screen.ox, Screen.oy)
    love.graphics.scale(Screen.scale)
end

function Screen.endDraw()
    love.graphics.setScissor()
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Pencere koordinatını oyun (sanal) koordinatına çevirir
function Screen.toGame(x, y)
    return (x - Screen.ox) / Screen.scale, (y - Screen.oy) / Screen.scale
end

return Screen
