class_name RoomData
extends RefCounted

enum Type { START, NORMAL, BOSS, ITEM, SHOP, CHALLENGE }

## Top-left map square of the room's size box (the only square for a 1x1 room). NOT
## always part of the room (an L can miss that corner): look rooms up with home_cell().
var grid_pos: Vector2i
var type: Type = Type.NORMAL
## How many map squares the room covers: 1x1, or a big NORMAL room (2x1 wide, 1x2 tall,
## 2x2 big). The Dungeon's layout maps EVERY covered square to this same RoomData.
var size: Vector2i = Vector2i.ONE
## L-shaped rooms: the square of the size box that is NOT part of the room, relative to
## grid_pos (e.g. (1, 0) = top-right missing). NO_MISSING_CELL for full rectangles.
## That square is free for other rooms (a room can sit in the L's notch).
var missing_cell: Vector2i = NO_MISSING_CELL
const NO_MISSING_CELL := Vector2i(-1, -1)
## 1x1 rooms: direction -> bool (has a door on that side). Kept in sync by set_door_at.
var doors: Dictionary = {}
## Every door, per edge: Vector4i(cell.x, cell.y, dir.x, dir.y) -> true, where cell is
## the (absolute) map square the door is on and dir the side. Works for any room size.
var edge_doors: Dictionary = {}
var cleared: bool = false
## The player has been in this room (minimap: yellow; unvisited neighbours are grey).
var visited: bool = false
var scene_path: String = ""
var stage_door_activated: bool = false
var assigned_item: ItemBase = null
## ITEM rooms: the item was taken (it's optional; the room counts as cleared anyway).
var item_taken: bool = false
## CHALLENGE rooms: 0 = altars waiting, 1 = fighting, 2 = done (ChallengeRoom.State).
var challenge_state: int = 0

## Obstacle layout, rolled once on first visit and reused on every revisit
## (rooms are destroyed/recreated each visit, same idea as assigned_item).
## Keyed by obstacle marker index -> { "scene_path": String, "broken": bool }.
var obstacle_state: Dictionary = {}
var obstacles_rolled: bool = false

## Drops (room-clear rewards, obstacle drops) lying in this room that haven't been
## picked up yet: [{ "scene_path": String, "position": Vector2 (room-local) }].
## Respawned on revisit; an entry is removed when its pickup emits `collected`.
var pending_drops: Array = []

## Active items the player put down here (swapped for another one), so they're still
## on their pedestal on revisits: [{ "item": ItemBase, "charges": int, "position": Vector2 (room-local) }].
var floor_items: Array = []

## Shop rooms: what's for sale, rolled on first visit and kept for revisits.
## [{ "item": ItemBase, "price": int, "sold": bool }], one entry per item spot (in order).
var shop_stock: Array = []
var shop_rolled: bool = false

## Clogged toilet in this room (Toilet.gd). PORTAL = leads to toilet_target (item/shop
## rooms have no door; the room before them has a portal toilet, and they have one back).
## CHEST = unclog for a few drops.
enum ToiletKind { NONE, PORTAL, CHEST }
var toilet_kind: ToiletKind = ToiletKind.NONE
var toilet_target: Vector2i = Vector2i.ZERO   # PORTAL: room it leads to
var toilet_unclogged: bool = false            # used a declogger on it (exit toilets start unclogged)
var toilet_cell: Vector2i = Vector2i.ZERO     # where it stands, picked on first visit
var toilet_placed: bool = false


# --- Shape / doors -----------------------------------------------------------------------

func is_multi_cell() -> bool:
	return size != Vector2i.ONE


func is_l_shape() -> bool:
	return missing_cell != NO_MISSING_CELL


## Every map square this room covers (absolute), row by row.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if Vector2i(x, y) != missing_cell:
				result.append(grid_pos + Vector2i(x, y))
	return result


## The room's first own square (= grid_pos unless an L is missing its top-left square).
## Use this, not grid_pos, to look the room up in the layout.
func home_cell() -> Vector2i:
	return cells()[0]


## Is map square `cell` (absolute) part of this room?
func has_cell(cell: Vector2i) -> bool:
	var rel := cell - grid_pos
	return rel.x >= 0 and rel.y >= 0 and rel.x < size.x and rel.y < size.y and rel != missing_cell


static func edge_key(cell: Vector2i, dir: Vector2i) -> Vector4i:
	return Vector4i(cell.x, cell.y, dir.x, dir.y)


func has_door_at(cell: Vector2i, dir: Vector2i) -> bool:
	return edge_doors.has(edge_key(cell, dir))


func set_door_at(cell: Vector2i, dir: Vector2i, value: bool) -> void:
	if value:
		edge_doors[edge_key(cell, dir)] = true
	else:
		edge_doors.erase(edge_key(cell, dir))
	if not is_multi_cell():
		doors[dir] = value


## [[cell, dir], ...] for every door of this room.
func door_edges() -> Array:
	var result: Array = []
	for k: Vector4i in edge_doors:
		result.append([Vector2i(k.x, k.y), Vector2i(k.z, k.w)])
	return result
