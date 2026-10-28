## Floor drains in the Great Clog's room (great_clog_floor_drain.png). They're there from
## the moment you walk in; in phase 2 tentacles burst out of them. The boss places them
## (add_grate). Lives in the GroundEffects layer, under everything.
extends Node2D
class_name ClogDrainArt

const DRAIN_TEX := preload("res://assets/sprites/enemies/great_clog/great_clog_floor_drain.png")
## The grate's middle in the png (it isn't centred in its 256 px canvas).
const DRAIN_CENTER := Vector2(140, 129)

## On-screen width of a drain (px).
@export var drain_size: float = 20.0

var mouth: Vector2           # global, where the boss sits
var drain_dir: Vector2       # towards the boss's wall
var grates: Array[Vector2] = []
var flowing: bool = false    # kept for the boss script (phase 2-3); nothing drawn for it


func _ready() -> void:
	add_to_group("room_effects")
	z_index = 0


func setup(mouth_pos: Vector2, dir_to_wall: Vector2) -> void:
	mouth = mouth_pos
	drain_dir = dir_to_wall
	global_position = Vector2.ZERO


func add_grate(pos: Vector2) -> void:
	grates.append(pos)
	var s := Sprite2D.new()
	s.texture = DRAIN_TEX
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.offset = Vector2(128, 128) - DRAIN_CENTER
	s.scale = Vector2.ONE * (drain_size / 216.0)   # the grate is ~216 px wide in the png
	add_child(s)
	s.global_position = pos
