## Looping aura around the player (Item cosmetic_slot = "Aura"), e.g. Static Cling,
## Sewer Gas. Auras stack: every aura item adds its own layer.
## Art: a horizontal strip of square frames (e.g. 6 x 256x256), same in every direction.
extends Node2D
class_name AuraCosmetic

@export var strip: Texture2D
@export var frame_count: int = 6
@export var fps: float = 10.0
## Size relative to one 256px frame on the player (the body is roughly one frame tall at 1.0).
@export var aura_scale: float = 1.0
@export var offset: Vector2 = Vector2.ZERO
## Behind the whole player (gas clouds) or in front (sparks).
@export var behind_player: bool = false
@export_range(0.0, 1.0) var opacity: float = 1.0

var _sprite: AnimatedSprite2D


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	var w := strip.get_width() / frame_count
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * w, 0, w, strip.get_height())
		frames.add_frame("default", atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2.ONE * aura_scale
	_sprite.position = offset
	_sprite.modulate.a = opacity
	add_child(_sprite)
	_sprite.play("default")
	_sprite.frame = randi() % frame_count  # stacked auras don't pulse in sync
	# The Aura anchor is the player's first child (Player._ready), so z 0 draws under the
	# legs and body; 2 is over the body rig (z 1).
	z_index = 0 if behind_player else 2
