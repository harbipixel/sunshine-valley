# Sunshine Valley

LÖVE 11.5 (LuaJIT) ile, Sunnyside World asset paketini kullanan 2D pixel-art oyun.
LÖVE kurulumu: `C:/Program Files/LOVE/` (`lovec.exe` konsol çıktısı verir).

## Çalıştırma
- `"C:/Program Files/LOVE/lovec.exe" .` (VS Code: Ctrl+Shift+B ya da F5 "Run LOVE")
- `lovec.exe . --shot` → 1 sn sonra `%APPDATA%/LOVE/sunshinevalley/shot.png` kaydeder ve kapanır (görsel doğrulama için).

## Yapı
- `main.lua` / `conf.lua` — giriş, global tuşlar (Esc, F1 debug, F11 tam ekran)
- `src/core/` — screen (320x180 sanal çözünürlük, tam sayı ölçekleme), state (sahne yöneticisi), input (eylem bağlamaları), assets (önbellekli yükleme), animation (strip/grid), camera
- `src/entities/` — human (katmanlı karakter: base + saç + tools), player
- `src/world/` — tilemap (16px tileset, SpriteBatch)
- `src/states/` — sahneler: `title.lua` (başlangıç ekranı, açılışta), `play.lua` (oyun)
- `Sprites/Sunnyside_World_Assets/` — asset paketi; yollar `Assets.ROOT`'a görelidir

## Asset notları
- İnsan kareleri 96x64; ayak pivotu yaklaşık (48, 42). Katmanlar aynı karelerle üst üste çizilir.
- Kare süreleri: `_Source/Human/*.aseprite` içinde TÜM animasyonlarda 75 ms (~13.3 fps) → `Human.FPS`.
  Aseprite dosyası Python ile parse edilebilir (frame header'da WORD duration, 0x2018 tags chunk).
- Dosya adları tutarsız (ör. `base_hamering_strip23.png`), bu yüzden `Assets.find` ile klasör taranır.
- Goblin sheet'lerinin bir kısmı çok satırlı grid; `_stripN` sayısı genişliğe bölünmez → `Animation.new` ile frameW/frameH açıkça verilmeli.
- Tileset 16px; düz çim (2,1), detaylı çimler (1..6, 2). (1,1) bir ton koyu, karıştırma.
- Damalı zemin: çim hücrelerinin (x+y) tek olanları multiply ile `CHECKER_TINT` (=(1,1)/(2,1) oranı) kadar koyulaştırılır.
- Küçük süsler tileset'te (piksel bölgeleri `play.lua` FLOWERS/GRASS/PROPS): çiçekler ~(500..575, 18..62),
  ot öbekleri (434..496, 38..76), kütük (512,81,16,15), bitkiler (977,163)/(977,272). Mantarlar Elements/Plants (animasyonlu).
- Deniz karo değil, `Tilemap` içindeki shader ile çiziliyor: taban (0,153,219) + kayan koyu lekeler (30,109,213), ~%11 kaplama
  (kullanıcının referans görselinden ölçüldü; paketteki su karosunun paleti farklı ve hareketsiz).
- Çitler `src/world/fences.lua`: hücre tabanlı otomatik bağlantı. Yatay (38/39/42,2) + dikey (40,1/3/4) parçalar üst üste
  çizilerek köşe/T oluşur, tek direk (41,3). Canvas'a çizilip birleşik şekle (115,62,57) dış çizgi eklenir, y-sort için satır dilimlenir.
  `autoShore()` yar/suya komşu tüm çim hücrelerine çit koyar, iskele girişini açık bırakır.
  Çarpışma hücre değil `Fences:addCollision` ile ince engeller (direk x5..11, ray bandı y7..12, bağlı yönlere raylar);
  çit hücresinin üst kısmında yürünür (oyuncu çitin arkasında kalır).
- Dış çizgi ortak: `Gfx.bakeOutlined(w, h, drawFn)` (premultiplied canvas döner). Çitler ve iskele kazıkları kullanır;
  iskele parçası sol kazık | tahta | sağ kazık olarak bölünür, sadece kazıklar çizgilenir.
- Kıyı (referans görünüm): çim kenarı (25,7) → KISA yar → deniz. Kısa yar (~yarım karo) tileset'te hazır yok;
  `makeShortCliff()` yüklenirken üretir: kırmızı (171,53,32) 2px + (11,3) dalga satırları + (23,2) köpük satırları,
  hücrenin alt kısmı saydam (deniz görünür, `CLIFF_WATER_Y` altı olta için su sayılır).
  Deniz üstü bindirmeler: köpük (23,2), yan gölgeler (19,3) batı / (24,3) doğu / (25,2) iki yan. Parıltı animasyonu (11..14,22).
  İskele: piksel bölgesi (632,80,32,32) = direkli 2 satırlık parça; tek tahta (640,96,16,16). Çit (38/39/42, 2).
  `Tilemap:setCoast` kolon başına deniz başlangıç satırı alır; denizin üstünde en az 2 kara satırı olmalı.
  Kuzeyinde kara olmayan su (kara denizin güneyinde) şimdilik desteklenmiyor.
- Açık gölet karoları da var (kullanılmıyor): su (22,7), köşeler (23,7)(24,7)(26,7)(22,8), kıyılar (25,7)(26,8)(27,7)(24,8).
- UI: greenbar_00..06 ilerleme çubuğu, expression_* başüstü ifadeleri.
- Balık tutma animasyonları: CASTING → WAITING (döngü) → REELING (döngü) → CAUGHT. İp ayak pivotunun ~(30, 20) px ötesine düşer.
- Varsayılan LÖVE fontunda ş/ı/ğ yok; Türkçe metin için TTF font yüklenmeli.
- UI fontu: m5x7 (`fonts/m5x7/m5x7.ttf`), `src/core/fonts.lua`. 16 piksellik ızgara (1024/64): boyut 16'nın katı olmalı.
  Büyük harf/rakam 7 font pikseli. Harf üstü ofseti `Fonts.capTop` fontun gerçek yükseliğinden hesaplanır (LÖVE ölçeğe göre
  farklı yuvarlıyor: 16px→4, 32px→8, 48px→11). Kutuda dikey ortalama: `Fonts.centerY(boxY, boxH, mult)`.
  Pixelify de `fonts/Pixelify` içinde duruyor (kullanılmıyor).
- Damalı zemin açık (`Tilemap.CHECKER = true`).
- UI kendi ölçeğinde çizilir: `Screen.uiScale` = round(scale * 0.75) (4x dünyada 3x), koordinatlar `Screen.uiW/uiH`,
  dönüşüm `Screen.applyUI()`. Fonts ve imleç de uiScale kullanır. Metin: `Fonts.print(text, x, y, color, shadow, mult)`;
  başlıklar mult=1, küçük yazılar mult=0.5. Font boyutu her zaman GRID * tam sayı gerçek piksel (`Fonts.effMult`), yoksa bozulur.
- Envanter: veri `src/game/inventory.lua` + tanımlar `src/game/items.lua` (sekme, ikon, ad, açıklama, etiket);
  ekran `src/ui/inventory_ui.lua` (Tab/I). 9-dilimli kutular `src/ui/nineslice.lua`: dt=koyu panel, lt=açık, w=beyaz.
- Başlangıç ekranı `src/states/title.lua`: `Play:enter()` ile dünyayı önceden kurar ve arka planda çizer (kamera
  kasabanın üstünde gezinir, `Play:updateWorld`), önde başlık + Start/Exit. Start `State.switch(play)`; `Play:enter`
  `self.built` ile ikinci kez kurmaz, kamera oyuncuya süzülür. `--shot` artık başlangıç ekranını çeker.
- Sahne `keypressed` true dönerse tuş kullanılmış sayılır (main.lua Esc ile çıkmaz, Input'a gitmez).
- Para: `Inventory.money` (`addMoney`, `spend`), HUD `src/ui/hud.lua` (sol üst, altın ikon tileset (883,451,10,10)).
- Yerdeki balık: yaklaşınca oyuncuya çekilir (`FishItem.ATTRACT_RADIUS`), değince toplanır + Glint efekti
  (Elements/VFX/Glint/spr_deco_glint_02_strip4.png) `Play:spawnGlint`.
- Para biçimi `Hud.formatMoney`: 9,999'a kadar binlik ayraç; 10K-999K; 1M+ (aşağı yuvarlar, "1000K" çıkmaz).
- Kasaba `Play:buildTown` (TOWN tablosu): hazır evler tileset (520, y, 32, 56) — mavi 168, yeşil 296, turuncu 424,
  kırmızı 552, mor 680. Çatı sırtı (11px, evin 8px üstünde) ayrı parça, kullanılmıyor. Dükkân = turuncu ev + Elements/Crops
  kasaları (crate_base + ürün + crate_top). Binalar dekordan ÖNCE yerleşir; `Tilemap:reserveRect` dekoru uzak tutar,
  duvarın alt 2 satırı `block`.
- NPC `src/entities/npc.lua`: Human (tools=false), evinin çevresinde dolaşır (wander px), oyuncu yaklaşınca durur/döner/
  konuşma balonu. Saç stilleri renkleriyle ayırt edici; base kıyafet herkeste aynı. Oyuncu NPC'lerin içinden geçebilir.
- Toprak katmanı `src/world/dirt.lua`: tarla ve kasaba yolları tek görüntüye pişirilir (`Dirt:add(x,y,w,h,r)` sonra
  `bake()`), birleşim yerlerinde iç kenar çizgisi olmaz. Yollar `Play:buildPaths` (1 karo genişlik, köşe r=3):
  ana yol 14. satır (dükkân/pazar/mavi ev/iskele kolları), batı yolu 12. satır (tarla → mor ev), kırmızı/yeşil ev kolları.
  Yollar `reserveRect` ile dekora kapalı.
- Tarla `src/world/farm.lua` (`Play:enter` içinde, yeşil evin altı: hücre (2,11), 7x3). Zemini toprak katmanında:
  toprak (1,7) + benekli (9..11,7)/(9..10,8) bloklar, yuvarlak köşe, kenar: toprak tarafı (188,121,92), çim tarafı (84,178,99)
  (tileset'teki toprak kenarları çapraz/izometrik, dikdörtgen tarlaya uymuyor). Ekim hücresi = 1 karo.
  Çukurlar Elements/Crops/soil_*: 00 sürülmüş boş, 01 sulanmış, 03 küçük çukur, 04 derin çukur.
- Ek tarlalar `Play.FIELDS` (cx, cy, cols, rows, price): kilitli başlar (kesikli çerçeve + ortada tabela: çit direği
  656,48 + pano 718,162). Tabelanın 20px yakınında Space/E parayla açar (`Farm:unlock` toprağı katmana ekleyip yeniden
  pişirir). Fiyat etiketi `Play:drawFieldPrices` (UI ölçeğinde, dünyayı takip eder). Tarlalar `Farm.group(list)` ile
  oyuncuya tek tarla gibi görünür (noktalı çağrılar o noktadaki açık tarlaya gider).
- Space/E = `Player:use()`, öncelik: `player.interact()` (dükkâncı yanındaysa dükkân) → olgun ürünü topla → açık çukura
  tohum ek → kürekle kaz. Hedef nokta `digPoint` (ayağın (14,-1) ötesi). Kazma: dig animasyonu 3. karede soil_03,
  8. karede soil_04, çukur açık kalır. Ekme/hasat: doing animasyonu 4. karede. Yapacak bir şey yoksa "confused".
- Ürünler `src/game/crops.lua` `Crops.LIST` (11 ürün, ucuzdan pahalıya: seedPrice, sellPrice, stageTime).
  Aşamalar Elements/Crops/<id>_00..04 (00 = tohum, 04 = olgun), _05 = hasat ikonu. Items bu listeden "<id>" (CROP, sell)
  ve "<id>_seed" (SEED, ikon _00, crop alanı) üretir. Hasattan sonra hücre soil_00 kalır, tekrar kazılır.
- Ekilecek tohum `Player.activeSeed`, C ile sıradaki tohuma geçer; bitince eldeki ilk tohum. HUD paranın altında gösterir.
- Dekor: önce rastgele öbekler, sonra doldurma geçişi (her çim hücresinde %80 olasılıkla, 11px içinde başka süs/ağaç
  yoksa ot öbeği veya çiçek). Props `x` alanı taşır.
- Satış fiyatı `Items.defs[id].sell` (balık 1, odun 2, ürünler sellPrice).
- Ağaçlar `src/entities/tree.lua` (`Play.trees`, iki tür strip). Baltayla (axe animasyonu 7. kare) `Tree.HITS`=3 vuruşta
  devrilir: sallanma, kütük (tileset 512,81), `Tree.REGROW` sn sonra yeniden büyür (oyuncu üstündeyse bekler).
  Devrilince 2-3 odun (Elements/Crops/wood.png) saçılır. Gövde `Tilemap:addSolid` ile yürünemez (hücreden bağımsız engel).
- Yerden toplanan eşyalar `src/entities/fishitem.lua` genel: `FishItem.new(from, to, id, arc)`, toplanınca `inventory:add(id)`.
- Dükkân penceresi `src/ui/shop_ui.lua`, iki mod: "buy" (dükkâncı, tüm tohumlar) ve "sell" (pazarcı, envanterdeki
  `sell` alanlı eşyalar; miktar en çok eldeki adet). Pazar tezgâhı `play.lua` MARKET (haritanın sağı, kasaların
  arkasında pazarcı). `Play:openShop()` açık pencereyi döner. Düzen: sol üst "Shop" başlığı, solda bilgi kutusu
  (aşama noktaları, ad, büyüme süresi, tohum>filiz>olgun, ✓ satın al / ✗ kapat), sol altta BUY + miktar + toplam fiyat;
  sağda "Seeds" sekmeli ızgara, rozet = sahip olunan tohum. Q/E miktar, Space satın al, Esc kapat. Para yetmezse fiyat kırmızı + sallanma.
- Envanter ve dükkânın ortak çizim parçaları `src/ui/widgets.lua` (renkler, kutucuk, rozet, seçim köşeleri, sekme, üçgen ok, pill).
  Başlangıç parası `Play.START_MONEY` = 10.
- Fare imleci: `src/ui/cursor.lua`, UI/cursor_02.png (= tileset (611,736)), ekran ölçeğinde büyütülmüş donanım imleci.

- Ses efektleri `src/core/sfx.lua`: dosya yok, `Sfx.load()` açılışta kodla sentezler (kare/üçgen dalga, süzülmüş gürültü,
  arpej). `Sfx.play(name, {pitch, volume, vary})`, M tuşu sessiz. Sesler: move, confirm, open, close, deny, coin, pickup,
  dig, chop, fell, cast, splash, bite, plant, harvest, unlock, start. "confused" ifadesi otomatik deny çalar.

## Kurallar
- Oyun içindeki TÜM metinler İngilizce (UI, eşya adları, yardım satırı, hata mesajları). Kod yorumları Türkçe olabilir.
- Envanter paneli genişliği sekmelere göre büyür (`InventoryUI:panelWidth`); sabit genişlik varsayma.
- Pixel art: `nearest` filtre. Düşük çözünürlüklü canvas yok; dünya ölçeklenerek doğrudan pencereye çizilir ve konumlar `Screen.snap` ile gerçek ekran pikseline yuvarlanır (oyun pikseline yuvarlamak kamera titremesine yol açıyordu).
- Oyun mantığı sanal koordinatlarda; fare girdisi `Screen.toGame` ile çevrilir.
- Harici kütüphane eklenecekse `lib/` klasörüne konur.
