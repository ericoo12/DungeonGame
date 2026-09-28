extends Node2D
class_name PlungerBootsCosmetic

const DOWN_PATH := "res://assets/sprites/player/cosmetics/plunger_boots/plunger_boots_front_overlay.png"
const LEFT_PATH := "res://assets/sprites/player/cosmetics/plunger_boots/plunger_boots_left_overlay.png"
const UP_PATH   := "res://assets/sprites/player/cosmetics/plunger_boots/plunger_boots_up_overlay.png"

@export var cosmetic_scale: float = 0.7  # tune per-item to compensate for how much of its own canvas the art fills

var player_ref: Player = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = AnimSheetLoader.build_cosmetic_2row_frames(DOWN_PATH, LEFT_PATH, UP_PATH)
	sprite.scale = Vector2.ONE * cosmetic_scale
	player_ref = get_parent().get_parent() as Player


func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		return
	var target_anim: String = player_ref.lower_sprite.animation
	if sprite.sprite_frames.has_animation(target_anim):
		sprite.animation = target_anim
		sprite.frame = player_ref.lower_sprite.frame
	sprite.flip_h = player_ref.lower_sprite.flip_h
