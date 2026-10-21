extends Node2D
class_name PaperArmourCosmetic

const DOWN_PATH := "res://assets/sprites/player/cosmetics/paper_armour/toilet_paper_torso_down.png"
const LEFT_PATH := "res://assets/sprites/player/cosmetics/paper_armour/toilet_paper_torso_left.png"
const UP_PATH   := "res://assets/sprites/player/cosmetics/paper_armour/toilet_paper_torso_up.png"

# Small per-direction nudges in head-pixels, if the art doesn't line up exactly with the torso.
@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_left: Vector2 = Vector2.ZERO
@export var offset_right: Vector2 = Vector2.ZERO
@export var offset_up: Vector2 = Vector2.ZERO


@export var scale_down: float = 5.0
@export var scale_left: float = 9
@export var scale_right: float = 9
@export var scale_up: float = 5.0

var player_ref: Player = null
var textures: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	textures = {
		"down": load(DOWN_PATH),
		"left": load(LEFT_PATH),
		"up":   load(UP_PATH),
	}

	# Lives inside Player/Body (see Player.add_cosmetic), so grandparent is the Player —
	# same as the boots, whose parent is a cosmetic anchor.
	player_ref = get_parent().get_parent() as Player


# Mirrors the torso the same way the boots mirror the lower body: the torso is static,
# so instead of animation/frame we copy its texture direction, position, scale and flip.
func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref) or player_ref.torso_sprite == null:
		return

	var torso: Sprite2D = player_ref.torso_sprite
	var dir: String = player_ref._facing_suffix()
	var tex_dir: String = "left" if dir == "right" else dir

	sprite.texture = textures.get(tex_dir)
	sprite.flip_h = torso.flip_h
	sprite.scale = Vector2.ONE * get("scale_" + dir)
	position = torso.position + get("offset_" + dir)
	scale = torso.scale
