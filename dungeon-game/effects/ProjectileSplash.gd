## Standalone splash effect, spawned by Projectile either on impact (wall/enemy)
## or natural landing (falling to max range). Self-destructs after playing once.
extends Node2D
class_name ProjectileSplash

## Single-row splash sheet. Defaults = the player's splash; enemy splashes override
## these in their own scene (e.g. EnemyBloodSplash.tscn).
@export_file("*.png") var sheet_path: String = "res://assets/sprites/player/projectiles/projectile_splash.png"
@export var frame_count: int = 3
@export var fps: float = 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = AnimSheetLoader.build_single_animation(sheet_path, frame_count, fps, false)
	sprite.play("splash")
	sprite.animation_finished.connect(queue_free)
