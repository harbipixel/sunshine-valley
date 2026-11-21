-- Ses efektleri: hazır dosya yok, açılışta kodla sentezlenir (8-bit tarzı).
-- Sfx.play(name, { pitch = 1, volume = 1, vary = 0.05 })  — vary: rastgele perde oynaması (tekrarlar aynı duyulmasın)
-- Sfx.toggleMute() (M tuşu)
local Sfx = {}

Sfx.RATE = 22050
Sfx.VOLUME = 0.45
Sfx.muted = false

local sounds = {}
local TAU = math.pi * 2

---------------------------------------------------------------------------
-- Sentez yardımcıları
---------------------------------------------------------------------------

-- fn(t, i) -> örnek (-1..1). dur: saniye
local function render(dur, fn)
    local n = math.floor(dur * Sfx.RATE)
    local sd = love.sound.newSoundData(n, Sfx.RATE, 16, 1)
    for i = 0, n - 1 do
        local v = fn(i / Sfx.RATE, i)
        sd:setSample(i, math.max(-1, math.min(1, v)))
    end
    return sd
end

local function square(phase, duty) return (phase % 1) < (duty or 0.5) and 1 or -1 end
local function tri(phase) local p = phase % 1; return p < 0.5 and (4 * p - 1) or (3 - 4 * p) end
local function noise() return love.math.random() * 2 - 1 end
-- hızlı vuruş, üstel sönüm
local function env(t, dur, attack)
    attack = attack or 0.004
    if t < attack then return t / attack end
    return math.max(0, 1 - (t - attack) / (dur - attack)) ^ 2
end

-- Frekansı zamanla değişen osilatör (faz biriktirir)
local function osc(wave, freqFn, duty)
    local phase = 0
    return function(t)
        phase = phase + freqFn(t) / Sfx.RATE
        return wave(phase, duty)
    end
end

-- Tek kutuplu alçak geçiren süzgeç (gürültüyü yumuşatır). k: 0..1 (küçük = daha boğuk)
local function lowpass(k)
    local y = 0
    return function(x) y = y + k * (x - y); return y end
end

-- Notalar sırayla (arpej): notes = { {freq, len}, ... }
local function arpeggio(notes, wave, duty, gain)
    local total = 0
    for _, n in ipairs(notes) do total = total + n[2] end
    return total, function(t)
        local acc = 0
        for _, n in ipairs(notes) do
            if t < acc + n[2] then
                if n[1] == 0 then return 0 end   -- sus
                local lt = t - acc
                return wave(lt * n[1], duty) * env(lt, n[2], 0.003) * (gain or 1)
            end
            acc = acc + n[2]
        end
        return 0
    end
end

---------------------------------------------------------------------------
-- Ses tanımları
---------------------------------------------------------------------------

local DEFS = {}

-- Arayüz: imleç hareketi (kısa yüksek bip)
DEFS.move = function()
    return render(0.04, function(t) return square(t * 1050, 0.25) * env(t, 0.04) * 0.35 end)
end

-- Arayüz: onay (iki ton yukarı)
DEFS.confirm = function()
    local d, f = arpeggio({ { 660, 0.05 }, { 990, 0.09 } }, square, 0.25, 0.4)
    return render(d, f)
end

-- Arayüz: aç / kapat (yumuşak kayış)
DEFS.open = function()
    local o = osc(tri, function(t) return 300 + t * 6000 end)
    return render(0.07, function(t) return o(t) * env(t, 0.07) * 0.5 end)
end
DEFS.close = function()
    local o = osc(tri, function(t) return 700 - t * 5000 end)
    return render(0.07, function(t) return o(t) * env(t, 0.07) * 0.5 end)
end

-- Olmaz / para yetmiyor (alçak iki vuruş)
DEFS.deny = function()
    local d, f = arpeggio({ { 196, 0.07 }, { 147, 0.12 } }, square, 0.5, 0.3)
    return render(d, f)
end

-- Para (klasik iki nota)
DEFS.coin = function()
    local d, f = arpeggio({ { 988, 0.06 }, { 1319, 0.2 } }, square, 0.5, 0.3)
    return render(d, f)
end

-- Yerden toplama (yukarı kayan pop)
DEFS.pickup = function()
    local o = osc(function(p) return math.sin(p * TAU) end, function(t) return 450 + t * 9000 end)
    return render(0.08, function(t) return o(t) * env(t, 0.08) * 0.6 end)
end

-- Kürek toprağa (boğuk gürültü + alçak gümleme)
DEFS.dig = function()
    local lp = lowpass(0.18)
    local thump = osc(function(p) return math.sin(p * TAU) end, function(t) return 110 - t * 300 end)
    return render(0.16, function(t)
        return (lp(noise()) * 1.6 + thump(t) * 0.6) * env(t, 0.16, 0.002) * 0.7
    end)
end

-- Balta ağaca (tok vuruş + kısa çıtırtı)
DEFS.chop = function()
    local lp = lowpass(0.45)
    local knock = osc(tri, function(t) return 240 - t * 900 end)
    return render(0.12, function(t)
        return (knock(t) * 0.8 + lp(noise()) * 0.7 * env(t, 0.04, 0.001)) * env(t, 0.12, 0.001) * 0.7
    end)
end

-- Ağaç devrildi (alçak gümbürtü + gıcırtı)
DEFS.fell = function()
    local lp = lowpass(0.06)
    local creak = osc(square, function(t) return 180 - t * 160 end, 0.2)
    return render(0.55, function(t)
        local rumble = lp(noise()) * 3 * env(t, 0.55, 0.02)
        local c = t < 0.2 and creak(t) * 0.18 * env(t, 0.2) or 0
        return (rumble + c) * 0.8
    end)
end

-- Olta atma (havada kayan vınlama)
DEFS.cast = function()
    local lp = lowpass(0.25)
    return render(0.22, function(t)
        local k = t / 0.22
        return lp(noise()) * math.sin(k * math.pi) * 0.9
    end)
end

-- Suya düşme / sıçrama
DEFS.splash = function()
    local lp = lowpass(0.3)
    local lp2 = lowpass(0.08)
    return render(0.35, function(t)
        local n = noise()
        return (lp(n) * 0.8 + lp2(n) * 1.5) * env(t, 0.35, 0.005) * 0.8
    end)
end

-- Balık vurdu (iki hızlı tiz bip)
DEFS.bite = function()
    local d, f = arpeggio({ { 1400, 0.05 }, { 0, 0.03 }, { 1400, 0.07 } }, square, 0.25, 0.3)
    return render(d, f)
end

-- Tohum ekme (yumuşak tok pop)
DEFS.plant = function()
    local o = osc(function(p) return math.sin(p * TAU) end, function(t) return 320 - t * 1500 end)
    local lp = lowpass(0.2)
    return render(0.1, function(t) return (o(t) * 0.7 + lp(noise()) * 0.5) * env(t, 0.1) * 0.7 end)
end

-- Hasat (pop + parlak nota)
DEFS.harvest = function()
    local d, f = arpeggio({ { 784, 0.05 }, { 1175, 0.12 } }, tri, nil, 0.55)
    return render(d, f)
end

-- Tarla açıldı / büyük başarı (arpej)
DEFS.unlock = function()
    local d, f = arpeggio({ { 523, 0.08 }, { 659, 0.08 }, { 784, 0.08 }, { 1047, 0.28 } }, square, 0.25, 0.3)
    return render(d, f)
end

-- Oyuna başla
DEFS.start = function()
    local d, f = arpeggio({ { 392, 0.07 }, { 523, 0.07 }, { 784, 0.2 } }, square, 0.25, 0.3)
    return render(d, f)
end

---------------------------------------------------------------------------

function Sfx.load()
    for name, make in pairs(DEFS) do
        sounds[name] = love.audio.newSource(make(), "static")
    end
end

function Sfx.play(name, opts)
    if Sfx.muted then return end
    local base = sounds[name]
    if not base then return end
    opts = opts or {}
    local src = base:clone()
    local vary = opts.vary or 0.05
    src:setPitch((opts.pitch or 1) * (1 + (love.math.random() * 2 - 1) * vary))
    src:setVolume((opts.volume or 1) * Sfx.VOLUME)
    src:play()
end

function Sfx.toggleMute() Sfx.muted = not Sfx.muted end

return Sfx
