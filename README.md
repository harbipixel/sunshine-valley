# Sunshine Valley

A small, cozy pixel-art farming game made with [LÖVE](https://love2d.org).

Live in a little seaside town: dig the soil, plant seeds and harvest crops, catch fish off the dock and chop trees.
Sell everything at the market and spend the gold on new seeds and new fields.

## Features

- **Farming:** dig holes with the shovel, plant seeds and watch them grow through their stages, then harvest them
- **11 crops:** from cheap, fast carrots to expensive, slow pumpkins
- **Shop and market:** buy seeds from the shopkeeper; sell crops, fish and wood to the merchant
- **Fishing:** cast from the dock, wait for a bite and reel the fish in
- **Tree chopping:** fell trees with the axe and collect the wood; stumps regrow over time
- **Unlockable fields:** spend gold to open new farmland
- **Town life:** villagers wander around their houses and react when you come close
- **Inventory** with tabs, item details and stack counts
- **Sound effects** generated in code at startup (no audio files)

## Controls

| Key | Action |
|---|---|
| WASD / Arrow keys | Move |
| Shift | Run |
| Space / E | Use: dig, plant, harvest, chop, talk to the shopkeeper or merchant, unlock a field |
| F | Cast / reel in the fishing line |
| C | Switch the seed to plant |
| Tab / I | Inventory |
| M | Mute sound |
| F11 | Fullscreen |
| Esc | Close the open window / quit |

In the shop and inventory windows: arrows to select, Q / E to change the tab or amount, Space to confirm.

## Running the game

1. Install [LÖVE 11.5](https://love2d.org).
2. Clone this repository.
3. Run it from the project folder:

   ```
   love .
   ```

   On Windows you can also drag the project folder onto `love.exe`.

## Project structure

```
main.lua, conf.lua   entry point and window settings
src/core/            screen scaling, states, input, assets, animation, camera, fonts, sound effects
src/entities/        player, villagers, trees, items on the ground
src/world/           tilemap and sea, fences, dirt paths, farm fields
src/game/            items, crops, inventory data
src/ui/              HUD, inventory, shop, shared UI widgets, cursor
src/states/          title screen and the game
Sprites/             Sunnyside World asset pack
fonts/               pixel fonts
```

## Credits

- **Art:** [Sunnyside World](https://danieldiggle.itch.io/sunnyside) asset pack by **Daniel Diggle**.
  All characters, tiles, crops, buildings, UI and effects come from this pack. Thank you for the wonderful art!
- **Font:** [m5x7](https://managore.itch.io/m5x7) by **Daniel Linssen**.
- **Font:** Pixelify Sans by Stefie Justprince (SIL Open Font License); included but not currently used.
- **Engine:** [LÖVE](https://love2d.org).

The art and fonts belong to their creators and are covered by their own licenses.
Please check the original pages before using them in your own projects.
