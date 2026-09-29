class_name RoomData
extends RefCounted

enum Type { START, NORMAL, BOSS, ITEM }

var grid_pos: Vector2i
var type: Type = Type.NORMAL
var doors: Dictionary = {}
var cleared: bool = false
var scene_path: String = ""
var stage_door_activated: bool = false
var assigned_item: ItemBase = null

## Obstacle layout, rolled once on first visit and reused on every revisit
## (rooms are destroyed/recreated each visit, same idea as assigned_item).
## Keyed by obstacle marker index -> { "scene_path": String, "broken": bool }.
var obstacle_state: Dictionary = {}
var obstacles_rolled: bool = false
