-- Başlangıç ekranı: arka planda gerçek oyun dünyası (kamera kasabanın üstünde yavaşça gezinir),
-- önde oyunun adı ve Start / Exit düğmeleri.
--   W/S veya oklar: seç   Enter/Space/E: onayla   Esc: çık   Fare: üzerine gel / tıkla
local Assets    = require("src.core.assets")
local Fonts     = require("src.core.fonts")
local Screen    = require("src.core.screen")
local State     = require("src.core.state")
local NineSlice = require("src.ui.nineslice")
local W         = require("src.ui.widgets")
local Sfx       = require("src.core.sfx")

local C = W.C

local Title = {}

Title.NAME = "Sunshine Valley"
Title.SUBTITLE = "Farm, fish and grow"
local BUTTONS = { { id = "start", text = "Start" }, { id = "exit", text = "Exit" } }
local BTN_W, BTN_H, BTN_GAP = 76, 18, 6
local TITLE_MULT = 3          -- başlık yazı ölçeği (m5x7, 3 UI pikseli / font pikseli)
local PAN_SPEED = 0.12        -- kamera gezinme hızı (rad/sn)

function Title:enter()
    self.play = require("src.states.play")
    self.play:enter()                -- dünya arka plan için kurulur
    self.sel, self.time = 1, 0
    local cam = self.play.camera
    cam.x, cam.y = self.play.map.width / 2, 9 * 16
end

function Title:update(dt)
    self.time = self.time + dt
    local play = self.play
    play:updateWorld(dt)
    play.player.sprite:update(dt)
    -- kamera kasabanın üstünde sağa sola süzülür (harita sınırları içinde)
    local map, cam = play.map, play.camera
    local margin = Screen.w / 2 + 8
    local tx = map.width / 2 + math.sin(self.time * PAN_SPEED) * (map.width / 2 - margin)
    cam:follow(tx, 9 * 16, dt)
end

function Title:draw() self.play:draw() end

---------------------------------------------------------------------------
-- Düzen ve girdi
---------------------------------------------------------------------------

function Title:buttonRect(i)
    local x = math.floor((Screen.uiW - BTN_W) / 2)
    local y = math.floor(Screen.uiH * 0.56) + (i - 1) * (BTN_H + BTN_GAP)
    return { x = x, y = y, w = BTN_W, h = BTN_H }
end

local function inside(r, x, y) return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h end

function Title:choose()
    local id = BUTTONS[self.sel].id
    if id == "start" then
        Sfx.play("start", { vary = 0 })
        State.switch(self.play)   -- dünya hazır; kamera oyuncuya süzülür
    else
        love.event.quit()
    end
end

function Title:keypressed(key)
    if key == "up" or key == "w" then self.sel = (self.sel - 2) % #BUTTONS + 1; Sfx.play("move")
    elseif key == "down" or key == "s" then self.sel = self.sel % #BUTTONS + 1; Sfx.play("move")
    elseif key == "return" or key == "space" or key == "e" then self:choose()
    elseif key == "escape" then love.event.quit()
    end
    return true
end

-- main.lua oyun koordinatı verir; düğmeler UI ölçeğinde
local function toUI(x, y)
    local k = Screen.scale / Screen.uiScale
    return x * k, y * k
end

function Title:mousemoved(x, y)
    local ux, uy = toUI(x, y)
    for i = 1, #BUTTONS do
        if inside(self:buttonRect(i), ux, uy) and self.sel ~= i then self.sel = i; Sfx.play("move") end
    end
end

function Title:mousepressed(x, y, button)
    if button ~= 1 then return end
    local ux, uy = toUI(x, y)
    for i = 1, #BUTTONS do
        if inside(self:buttonRect(i), ux, uy) then self.sel = i; self:choose() end
    end
end

---------------------------------------------------------------------------
-- Çizim
---------------------------------------------------------------------------

-- Başlık yazısı: ince (1 UI pikseli) sıcak koyu kahve çerçeve + altında yarı saydam yumuşak gölge
local OUTLINE = { 115 / 255, 62 / 255, 57 / 255 }        -- çitlerin dış çizgi rengi
local SOFT_SHADOW = { 24 / 255, 20 / 255, 37 / 255, 0.35 }
local function outlined(text, x, y, color, mult)
    local d = Fonts.effMult(mult)
    Fonts.print(text, x, y + d + 1, SOFT_SHADOW, nil, mult)   -- gölge: 1 font pikseli + çerçeve kadar aşağı
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        Fonts.print(text, x + o[1], y + o[2], OUTLINE, nil, mult)
    end
    Fonts.print(text, x, y, color, nil, mult)
end

function Title:drawTitle()
    local mult = TITLE_MULT
    local tw = math.ceil(Fonts.width(Title.NAME, mult) - Fonts.effMult(mult))
    local x = math.floor((Screen.uiW - tw) / 2)
    -- hafif süzülme (1 UI pikseli)
    local bob = math.floor(math.sin(self.time * 2) + 0.5)
    local capY = math.floor(Screen.uiH * 0.24) + bob
    local y = capY - Fonts.capTop(mult)
    outlined(Title.NAME, x, y, C.yellow, mult)

    -- iki yanda ayçiçeği
    local flower = Assets.image("Elements/Crops/sunflower_05.png")
    local fy = capY + math.floor((Fonts.capHeight(mult) - flower:getHeight()) / 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(flower, x - flower:getWidth() - 8, fy)
    love.graphics.draw(flower, x + tw + 8, fy)

    local sub = Title.SUBTITLE
    local sw = Fonts.width(sub)
    Fonts.print(sub, math.floor((Screen.uiW - sw) / 2), capY + Fonts.capHeight(mult) + 10 - Fonts.capTop(),
        C.white, C.shadow)
end

function Title:drawButton(i)
    local b, r = BUTTONS[i], self:buttonRect(i)
    local selected = i == self.sel
    love.graphics.setColor(1, 1, 1)
    NineSlice.get(selected and "w" or "dt"):draw(r.x, r.y, r.w, r.h)
    local tw = math.ceil(Fonts.width(b.text) - Fonts.effMult())
    Fonts.print(b.text, r.x + math.floor((r.w - tw) / 2), Fonts.centerY(r.y, r.h),
        selected and C.dark or C.text, (not selected) and C.shadow or nil)
    if selected then W.selectCornersRect(r.x, r.y, r.w, r.h, self.time) end
end

function Title:drawUI()
    love.graphics.push()
    Screen.applyUI()
    -- dünyayı hafif karart, yazılar okunsun
    love.graphics.setColor(0.08, 0.06, 0.12, 0.35)
    love.graphics.rectangle("fill", 0, 0, Screen.uiW, Screen.uiH)

    self:drawTitle()
    for i = 1, #BUTTONS do self:drawButton(i) end

    local hint = "Arrows: select   Enter: confirm"
    Fonts.print(hint, math.floor((Screen.uiW - Fonts.width(hint, 0.5)) / 2), Screen.uiH - 10 - Fonts.capTop(0.5),
        C.white, C.shadow, 0.5)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

return Title
