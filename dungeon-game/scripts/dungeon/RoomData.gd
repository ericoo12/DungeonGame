class_name RoomData
extends RefCounted

enum Type { START, NORMAL, BOSS }

var grid_pos: Vector2i
var type: Type = Type.NORMAL
var doors: Dictionary = {}
var cleared: bool = false
var scene_path: String = ""
