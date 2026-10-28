## Chest / torso cosmetic (Item cosmetic_slot = "Body"), e.g. Porcelain Skin.
## Art is drawn on the torso canvas (1254x1254, same spot as
## assets/sprites/player/body/torso_down/left/up.png), so it just copies the torso
## sprite's texture direction, position, scale and flip every frame. Right = left mirrored.
extends Node2D
class_name TorsoOverlayCosmetic

@export var texture_down: Texture2D
@export var texture_left: Texture2D
@export var texture_up: Texture2D

@export_group("Tuning")
## Per-direction nudge in torso-art pixels (1254 canvas; ~5 px = 1 head pixel). Right = left mirrored.
@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_left: Vector2 = Vector2.ZERO
@export var offset_up: Vector2 = Vector2.ZERO
## Size multiplier per direction (1 = same size as the torso).
@export var scale_down: float = 1.0
@export var scale_left: float = 1.0
@export var scale_up: float = 1.0
@export_group("")

var player_ref: Player = null
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	player_ref = get_parent().get_parent() as Player  # lives in Player/Body


func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.torso_sprite == null:
		return
	var torso: Sprite2D = player_ref.torso_sprite
	var dir: String = player_ref._facing_suffix()
	var tex_dir := "left" if dir == "right" else dir
	var nudge: Vector2 = get("offset_" + tex_dir)
	if dir == "right":
		nudge.x = -nudge.x
	_sprite.texture = get("texture_" + tex_dir)
	_sprite.flip_h = torso.flip_h
	_sprite.position = nudge
	_sprite.scale = Vector2.ONE * float(get("scale_" + tex_dir))
	position = torso.position
	scale = torso.scale
