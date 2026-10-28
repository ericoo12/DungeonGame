## Back cosmetic (Item cosmetic_slot = "Back"), e.g. Golden Plunger, Overflow's tank.
## Lives in the player's body rig: drawn behind the body, and in front of it when facing
## up (Player._update_body). Several back items can be worn together, so each one has its
## own spot per direction - keep them apart (plunger left shoulder, tank right side).
## Art: 256x256 per direction (down/left/up); right = left mirrored.
## Positions/scale are in head-art pixels (the head is a 256x256 canvas at 0,0).
extends Node2D
class_name BackCosmetic

@export var texture_down: Texture2D
@export var texture_left: Texture2D
@export var texture_up: Texture2D

@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_left: Vector2 = Vector2.ZERO   ## right uses this with x mirrored
@export var offset_up: Vector2 = Vector2.ZERO
@export var scale_down: float = 0.6
@export var scale_left: float = 0.6
@export var scale_up: float = 0.6

var player_ref: Player = null
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	player_ref = get_parent().get_parent() as Player  # lives in Player/Body


func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		return
	var dir: String = player_ref._facing_suffix()
	var flip := dir == "right"
	var tex_dir := "left" if flip else dir
	var offset: Vector2 = get("offset_" + tex_dir)
	if flip:
		offset.x = -offset.x
	_sprite.texture = get("texture_" + tex_dir)
	_sprite.flip_h = flip
	position = offset
	scale = Vector2.ONE * float(get("scale_" + tex_dir))
