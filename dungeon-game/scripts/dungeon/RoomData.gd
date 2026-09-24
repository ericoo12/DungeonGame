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
