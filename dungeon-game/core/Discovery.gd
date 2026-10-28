## What the player has discovered across ALL runs (saved to user://discovery.cfg).
##   Items:   unknown until picked up once. Unknown items show "??" plus their
##            flavour_text when you walk up to them; known ones show the full
##            description and stats (ItemInfoPopup). Counts how often each was taken.
##   Enemies: "seen" when one spawns near you, counts kills. Shown in the Logbook.
## Static class (no autoload needed): call Discovery.is_item_known(item) etc. anywhere.
class_name Discovery
extends RefCounted

const SAVE_PATH := "user://discovery.cfg"

## Test rooms set this: everything shows as known (not saved).
static var reveal_all: bool = false

static var _loaded: bool = false
static var _items: Dictionary = {}    # resource_path -> times picked up
static var _enemies: Dictionary = {}  # scene_path -> {"seen": bool, "kills": int}

## Enemy scenes that moved folder (tier changes): old path -> new path. Saved progress
## under an old path is carried over when the logbook loads.
const MOVED_ENEMIES := {
	"res://enemies/regular/easy/Rat.tscn": "res://enemies/regular/medium/Rat.tscn",
	"res://enemies/regular/medium/Hairball.tscn": "res://enemies/regular/hard/Hairball.tscn",
}


# --- Items --------------------------------------------------------------------------

static func is_item_known(item: Resource) -> bool:
	if item == null:
		return false
	if reveal_all:
		return true
	_load()
	return _items.has(_key(item))


static func item_pickups(item: Resource) -> int:
	_load()
	return int(_items.get(_key(item), 0))


## Returns true if this was the first time ever (a new discovery).
static func mark_item(item: Resource) -> bool:
	if item == null or reveal_all:
		return false  # test rooms don't count
	_load()
	var key := _key(item)
	var first := not _items.has(key)
	_items[key] = int(_items.get(key, 0)) + 1
	_save()
	return first


# --- Enemies ------------------------------------------------------------------------

static func is_enemy_seen(scene_path: String) -> bool:
	if reveal_all:
		return true
	_load()
	return _enemies.has(scene_path)


static func enemy_kills(scene_path: String) -> int:
	_load()
	return int(_enemies.get(scene_path, {}).get("kills", 0))


static func mark_enemy_seen(scene_path: String) -> void:
	if scene_path == "" or reveal_all:
		return
	_load()
	if _enemies.has(scene_path):
		return
	_enemies[scene_path] = {"kills": 0}
	_save()


static func mark_enemy_killed(scene_path: String) -> void:
	if scene_path == "" or reveal_all:
		return
	_load()
	var entry: Dictionary = _enemies.get(scene_path, {"kills": 0})
	entry["kills"] = int(entry.get("kills", 0)) + 1
	_enemies[scene_path] = entry
	_save()


# --- Saving -------------------------------------------------------------------------

## Wipes all progress (Logbook "Forget everything" button).
static func reset() -> void:
	_items.clear()
	_enemies.clear()
	_loaded = true
	_save()


static func _key(item: Resource) -> String:
	return item.resource_path if item.resource_path != "" else str(item.get("item_name"))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_items = cfg.get_value("items", "picked", {})
	_enemies = cfg.get_value("enemies", "log", {})
	var moved := false
	for old in MOVED_ENEMIES:
		if _enemies.has(old):
			var entry: Dictionary = _enemies[old]
			var new_entry: Dictionary = _enemies.get(MOVED_ENEMIES[old], {"kills": 0})
			new_entry["kills"] = int(new_entry.get("kills", 0)) + int(entry.get("kills", 0))
			_enemies[MOVED_ENEMIES[old]] = new_entry
			_enemies.erase(old)
			moved = true
	if moved:
		_save()


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("items", "picked", _items)
	cfg.set_value("enemies", "log", _enemies)
	cfg.save(SAVE_PATH)
