## Generic hat / head cosmetic (Item cosmetic_slot = "Head"). Lives in the player's body
## rig next to the head sprite and copies its texture direction, position, scale and flip
## every frame, so it sits on the head facing any way.
##
## Easiest art: draw the hat on a copy of the head canvas (256x256, same spot as
## assets/sprites/player/Filling3/head_down/left/up.png) - then offsets 0 / scale 1 line
## up exactly. Right uses the left texture mirrored, like the head.
extends Node2D
class_name HeadCosmetic

@export var texture_down: Texture2D
@export var texture_left: Texture2D
@export var texture_up: Texture2D

## Per-direction nudges (head-art pixels) and size multipliers, for art that isn't drawn
## on the head canvas.
@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_left: Vector2 = Vector2.ZERO
@export var offset_right: Vector2 = Vector2.ZERO
@export var offset_up: Vector2 = Vector2.ZERO
@export var scale_multiplier: float = 1.0

var player_ref: Player = null
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	# Lives inside Player/Body (Player.add_cosmetic), so the grandparent is the Player.
	player_ref = get_parent().get_parent() as Player


func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.head_sprite == null:
		return
	var head: Sprite2D = player_ref.head_sprite
	var dir: String = player_ref._facing_suffix()
	var tex_dir: String = "left" if dir == "right" else dir

	_sprite.texture = get("texture_" + tex_dir)
	_sprite.flip_h = head.flip_h
	_sprite.texture_filter = head.texture_filter
	position = head.position
	scale = head.scale * scale_multiplier
	_sprite.position = get("offset_" + dir)
	z_index = head.z_index
