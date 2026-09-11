# Dungeon Game

A top-down, twin-stick roguelike dungeon crawler built for TDDD23 (Design and
Programming of Computer Games). Room-based procedural dungeons, permadeath
runs, and item-driven build variety.

## Requirements

- **Godot Engine 4.7.2** — use this version.
  Check your installed version with `godot --version`, or via
  Help → About in the editor. Download the matching version from
  [godotengine.org/download](https://godotengine.org/download) if needed.
- **Git** with **Git LFS** installed (`git lfs install` — see setup steps
  below).

This project relies on features introduced in **Godot 4.7.2** specifically
(`Floating` Motion Mode on `CharacterBody2D`, `TileMapLayer` nodes) — an
older 4.0–4.2 install will not open it correctly.

## First-time setup

1. Clone the repo:
   ```bash
   git clone <repo-url>
   cd <repo-folder>
   ```
2. Install Git LFS tracking for this machine (only needs to be run once per
   machine, not per clone):
   ```bash
   git lfs install
   ```
3. Open Godot, choose **Import**, and select the `project.godot` file inside
   this repo — do **not** create a new project.
4. Confirm the project opens with no missing-file/broken-dependency warnings
   before making any changes. If you see warnings, pull again and re-check
   before assuming it's a real bug — it may mean Git LFS wasn't installed
   before your first clone (see `Troubleshooting` below).
5. Press **F5** and select `scenes/test/TestRoom.tscn` as the main scene if
   prompted (it should already be set as the project's default main scene
   under Project Settings → Application → Run → Main Scene).

## Input Map

These actions must exist under **Project Settings → Input Map**. If you're
setting up a fresh clone and they're missing (Input Map bindings are stored
in `project.godot`, so they should already be there — this list is mainly
for reference/troubleshooting):

| Action | Default binding | Used for |
|---|---|---|
| `move_left` / `move_right` / `move_up` / `move_down` | WASD | Player movement |
| `shoot_left` / `shoot_right` / `shoot_up` / `shoot_down` | Arrow keys | Aiming/firing (independent of movement) |
| `toggle_items` | Shift | Opens/closes the item inventory overlay (pauses the game) |
| `toggle_debug_stats` | Tab | Shows/hides the debug stats readout |
| `ui_accept` | Space / Enter | Built-in Godot default — confirm in menus |
| `ui_cancel` | Escape | Built-in Godot default — closes the item overlay |

## Project structure

```
res://
├── autoload/            # Singletons (see below)
├── scenes/
│   ├── player/           # Player, Projectile
│   ├── enemies/           # EnemyBase and enemy variants
│   ├── items/              # ItemPickup scene + item_data/ (.tres Item resources)
│   ├── ui/                  # HUD, HeartsDisplay, DebugStatsDisplay
│   └── test/                 # TestRoom, TestDummy — scaffolding, not shipped content
├── scripts/
│   └── util/               # AnimSheetLoader (slices sprite sheets into SpriteFrames at runtime)
├── assets/
│   └── sprites/             # Imported art — see licensing note below
└── project.godot
```

## Autoloads

- **`EventBus`** (`autoload/EventBus.gd`) — global signal bus. UI and other
  systems listen to this instead of reaching into `Player` directly.
  Current signals: `player_health_changed(current, max)`,
  `item_added(item)`.

## Collision layers

Named under **Project Settings → Layer Names → 2D Physics**. If setting up
fresh and these aren't named yet, here's the current convention in use
(check actual layer numbers in Project Settings, since these were set up
interactively during development and may not be numbered exactly as
listed):

| Layer name | Used by |
|---|---|
| `world` | Wall tile collision (player/enemy-blocking geometry) |
| `player` | Player's physical `CharacterBody2D` |
| `enemies` | Enemy physical `CharacterBody2D`s |
| `player_projectiles` | Player's `Projectile` scenes |
| `player_hurtbox` | Player's `Hurtbox` Area2D (contact-damage detection) |

Wall tiles use **two separate Physics Layers** in the TileSet resource: one
with short, base-only collision geometry (what the player/enemies walk
into), and a second, taller one restricted to blocking projectiles — this
is deliberate, not a duplicate/mistake, and avoids visual overlap issues
where full-tile-height collision would make characters look like they're
standing "inside" tall wall art.

## Conventions worth knowing before editing

- **`CharacterBody2D`s use `Motion Mode: Floating`**, not the default
  `Grounded`. This is a top-down game with no real "floor" direction —
  `Grounded` mode causes directional sticking bugs (confirmed: getting
  stuck when colliding with an enemy from specific angles). Any new
  `CharacterBody2D` (new enemy types, etc.) should be set to `Floating` too.
- **Contact damage uses `Area2D` "Hitbox"/"Hurtbox" pairs**, separate from
  physical collision shapes. Hitbox/Hurtbox shapes should be sized slightly
  *larger* than the physical collision shape on the same body — if they
  match exactly, physical collision can stop bodies before the Area2D
  shapes ever get genuine overlap, causing contact damage to fail
  intermittently or directionally.
- **Sprite sheets are sliced at runtime**, not hand-built as `SpriteFrames`
  resources in the editor. See `scripts/util/AnimSheetLoader.gd`. When
  adding a new animation, you must know its real frame count (open the PNG
  and count poses — don't assume from divisibility of width/height, that
  has caused bugs before) and pass it explicitly.
- **Damage uses diminishing-returns scaling** (see `Player.get_effective_damage()`),
  loosely modeled on The Binding of Isaac's damage formula: each `+1` damage
  item is worth less than the last, via a square-root curve, with a hard
  floor so damage can never reach zero even with negative-damage items.
- **Items are `Resource` files (`.tres`)**, not scenes — see
  `scripts/items/Item.gd`. Creating a new item is "make a new `.tres` and
  fill in the Inspector," not new code, unless it needs an effect beyond
  the existing stat fields.
- **`TestDummy` and `TestRoom` are throwaway debug scaffolding**, not real
  game content — expect them to be deleted once real rooms/enemies exist.

## Licensing / asset credit

Character, environment, and weapon art from **Pixel Crawler – Free Pack**
(free for commercial/personal use, credit optional, cannot be resold as-is —
see `assets/sprites/.../Terms.txt` if still present, or the pack's itch.io
page). Enemy sprite pack under `assets/sprites/enemies/rouge_enemy/` —
confirm its license terms before submission if not already checked; if no
license file is present, note that in the project report per the course's
plagiarism/source-citation guidelines.

## Troubleshooting

- **Project opens with missing textures/broken paths:** almost always means
  Git LFS wasn't installed (`git lfs install`) before assets were first
  pulled. Run `git lfs install`, then `git lfs pull` to fetch the real
  binary content.
- **Scenes show as "changed" in git when you didn't touch them:** check
  both team members are on the exact same Godot version.
- **Walking through walls/enemies:** check `Motion Mode` is `Floating` and
  the relevant `CollisionShape2D` has both a `Shape` assigned and
  `Disabled` unchecked — both have been the cause of this before.
