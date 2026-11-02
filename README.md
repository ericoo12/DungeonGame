# Captain Filling: Return of the Shit

A top-down, twin-stick roguelike set in the sewers, made for TDDD23 (Design and
Programming of Computer Games) by Eric Åhlén & Albin Will.

Fight through procedurally generated floors, stack weird items into silly builds,
beat a boss on each floor and take on Doktor Mugg at the end. Runs are permadeath.

## Features

- Procedural floors with normal, big (2x1, 1x2, 2x2) and L-shaped rooms, plus
  item rooms, shops, challenge rooms and toilet portals/chests
- 67 items: stat ups, shot changes, companions and active items
- 20+ enemy types and 4 bosses: Toilet Brush, Great Clog and Gutterjaw on
  stages 1–3 (each once per run, random order), Doktor Mugg on stage 4
- Minimap that fills in as you explore, a logbook of discovered items and
  enemies, a game over screen and a highscore (furthest stage cleared)

## Requirements

- **Godot 4.7** (Help → About in the editor shows your version)
- Git

## Getting started

1. Clone the repo.
2. Open Godot, choose **Import** and select `dungeon-game/project.godot`.
3. Press **F5**. The game starts at the main menu.

## Controls

| Action | Key |
|---|---|
| Move | W A S D |
| Shoot | Arrow keys |
| Use active item | Space |
| Inventory (pauses) | I |
| Pause / freeze | P |
| Debug view (stats, enemy health bars) | Tab |
| Menus | Arrow keys + Enter/Space |

## Project structure

dungeon-game/
├── autoload/ EventBus (signals), GameState (run state, seed), Audio (music)
├── core/ Shared helpers (AnimSheetLoader, Luck, Discovery/logbook)
├── data/ Items (.tres), drop tables, floor variants
├── dungeon/ Dungeon, generator, doors, toilets
├── rooms/ Room scenes and room logic (RoomBase, ShapedRoom, RoomArt)
├── enemies/ EnemyBase, regular enemies, bosses, Doktor Mugg (+ his AI)
├── items/ Item base classes, effects, followers, orbitals
├── player/ Player and projectiles
├── pickups/ Hearts, ducks, decloggers
├── obstacles/ Rocks, pots, trash bags
├── shop/ Shop items
├── ui/ HUD, minimap, main menu, inventory, logbook, game over
├── debug/ Test rooms and recording tools (not part of a normal run)
├── tests/ Automated test scenes (Doktor Mugg AI etc.)
├── assets/ Sprites, tiles, audio
└── _unused/ Old assets kept for reference (ignored by Godot)


## Debug and test rooms

- `debug/TestRoom.tscn`: every item on a pedestal. Walk into the
  **START RUN** toilet to start a stage 1 run with the items you picked up.
- `debug/EnemyTestRoom.tscn`: spawn any enemy or boss (Q/E to pick, Enter to
  spawn, F4 shows all keys).
- In debug runs only: F1 clean screen, F2 god mode, F3 slow motion,
  F4 random item, F5 +20 ducks and full health, F6 boss room, F7 next stage.

## Collision layers

| # | Name | Used by |
|---|---|---|
| 1 | world | Walls |
| 2 | player | Player body |
| 3 | enemies | Enemy bodies |
| 4 | player_projectile | Player shots |
| 5 | player_hurtbox | Player hurtbox (contact damage) |
| 6 | enemy_hitbox | Enemy hitboxes |
| 7 | enemy_projectile | Enemy shots |
| 8 | movement_blocker | Blocks walking only |
| 9 | projectile_blocker | Blocks shots only |
| 10 | sight_blocker | Blocks Doktor Mugg's line of sight |

## Conventions

- **Items are resources (`.tres`)**, not scenes. A new item is usually just a
  new `.tres` in `data/items/` filled in in the Inspector. It is picked up
  automatically by the item pool.
- **New enemies and bosses are found automatically** from their folders
  (`enemies/regular/<tier>/`, `enemies/bosses/`, subfolders included).
  A boss needs `is_boss = true`.
- **Sprite sheets are sliced at runtime** (`core/AnimSheetLoader.gd`). Pass
  the real frame count; don't guess it from the image size.
- **`CharacterBody2D`s use Motion Mode: Floating** (top-down, no floor).
- **Contact damage uses Hitbox/Hurtbox `Area2D`s**, sized slightly larger
  than the body's collision shape.
- **Damage has diminishing returns** (`Player.get_effective_damage()`).
