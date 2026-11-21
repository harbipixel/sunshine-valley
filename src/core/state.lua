-- Basit sahne (gamestate) yöneticisi.
-- Bir state şu fonksiyonlardan istediklerini tanımlar:
--   enter(prev, ...), leave(), update(dt), draw(), drawUI(), keypressed(...), mousepressed(...)
local State = { current = nil }

function State.switch(to, ...)
    local prev = State.current
    if prev and prev.leave then prev:leave() end
    State.current = to
    if to.enter then to:enter(prev, ...) end
end

function State.call(name, ...)
    local s = State.current
    if s and s[name] then return s[name](s, ...) end
end

function State.update(dt) State.call("update", dt) end
function State.draw()     State.call("draw") end
function State.drawUI()   State.call("drawUI") end

return State
