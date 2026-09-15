## Standalone splash effect, spawned by Projectile either on impact (wall/enemy)
## or natural landing (falling to max range). Self-destructs after playing once.
extends Node2D
class_name ProjectileSplash

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = AnimSheetLoader.build_single_animation(
		"res://assets/sprites/player/poop_splash.png", 4, 24.0, false
	)
	sprite.play("splash")
	sprite.animation_finished.connect(queue_free)
