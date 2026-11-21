-- Sunshine Valley - giriş noktası
-- Not: love.filesystem yolları her zaman proje köküne göredir ve "/" kullanır.

-- Lua debugger (VS Code "Local Lua Debugger" eklentisi) bağlıysa etkinleştir
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local Screen = require("src.core.screen")
local State  = require("src.core.state")
local Input  = require("src.core.input")
local Cursor = require("src.ui.cursor")
local Sfx    = require("src.core.sfx")

DEBUG = false

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")   -- pixel art: bulanıklık yok
    love.graphics.setLineStyle("rough")
    Screen.init(320, 180)                                  -- sanal çözünürlük (1280x720'de 4x)
    Cursor.apply()
    Sfx.load()                                             -- ses efektleri kodla üretilir
    State.switch(require("src.states.title"))   -- başlangıç ekranı; Start oyunu başlatır

    -- "love . --shot": 1 sn sonra ekran görüntüsü alıp kapanır (otomatik test için).
    -- Çıktı: %APPDATA%/LOVE/sunshinevalley/shot.png
    for _, a in ipairs(arg) do if a == "--shot" then SHOT_TIMER = 1 end end
end

function love.update(dt)
    if SHOT_TIMER then
        SHOT_TIMER = SHOT_TIMER - dt
        if SHOT_TIMER <= 0 then
            SHOT_TIMER = nil
            love.graphics.captureScreenshot(function(img)
                img:encode("png", "shot.png")
                love.event.quit()
            end)
        end
    end
    dt = math.min(dt, 1 / 20)    -- pencere sürüklenirken dev dt sıçramalarını engelle
    State.update(dt)
    Input.endFrame()
end

function love.draw()
    Screen.beginDraw()
    State.draw()
    Screen.endDraw()

    State.drawUI()               -- tam çözünürlükte UI / debug metni
    if DEBUG then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(("FPS %d"):format(love.timer.getFPS()), 8, 8)
    end
end

function love.resize(w, h)
    Screen.resize(w, h)
    Cursor.apply()   -- ölçek değiştiyse imleci yeniden büyüt
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f1" then DEBUG = not DEBUG end
    if key == "m" then Sfx.toggleMute() end
    if key == "f11" then love.window.setFullscreen(not love.window.getFullscreen(), "desktop") end
    -- Önce sahne: tuşu kullanırsa (ör. envanter açıkken Esc onu kapatır) oyun girdisine gitmez
    if State.call("keypressed", key, scancode, isrepeat) then return end
    if key == "escape" then love.event.quit() end
    Input.keypressed(key, isrepeat)
end

function love.mousepressed(x, y, button)
    local gx, gy = Screen.toGame(x, y)
    State.call("mousepressed", gx, gy, button)
end

function love.mousemoved(x, y)
    local gx, gy = Screen.toGame(x, y)
    State.call("mousemoved", gx, gy)
end

function love.wheelmoved(x, y)
    State.call("wheelmoved", x, y)
end
