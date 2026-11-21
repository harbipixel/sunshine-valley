function love.conf(t)
    t.identity = "sunshinevalley"       -- save klasörü: %APPDATA%/LOVE/sunshinevalley
    t.version = "11.5"
    t.console = false                   -- konsol için lovec.exe kullan

    t.window.title = "Sunshine Valley"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 180
    t.window.vsync = 1

    t.modules.physics = false           -- gerekirse aç
    t.modules.video = false
end
