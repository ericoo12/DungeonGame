class_name RoomData
extends RefCounted

enum Type { START, NORMAL, BOSS, ITEM, SHOP }

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
