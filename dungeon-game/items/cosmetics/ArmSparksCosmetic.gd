## Cosmetic: electricity crackling along the gun arm, from the shoulder to the muzzle
## (Static Cling). Attaches itself to the player's arm sprite, so it follows the arm in
## every direction, the shot kick and the draw order (behind the body when facing up).
## Art: a horizontal strip of square frames, the arcs running left -> right with the
## bright spark on the RIGHT (that end goes on the muzzle).
extends Node2D
class_name ArmSparksCosmetic

@export var strip: Texture2D
@export var frame_count: int = 6
@export var fps: float = 14.0
## Share of the shoulder -> muzzle length the art covers.
@export_range(0.2, 1.5) var length_share: float = 1.1
## Height compared to width (the art is square; arms are thin).
@export var squash: float = 0.75
## Where the bright spark is in the art, 0 = left edge, 1 = right edge.
@export_range(0.0, 1.0) var spark_at: float = 0.82
@export_range(0.0, 1.0) var opacity: float = 0.95

var _player: Player
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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.modulate.a = opacity
	var n: Node = get_parent()
	while n and not (n is Player):
		n = n.get_parent()
	_player = n as Player
	if _player and _player.arm_sprite:
		_player.arm_sprite.add_child(_sprite)   # rides on the arm
	else:
		add_child(_sprite)
	_sprite.play("default")
	_sprite.frame = randi() % frame_count


func _exit_tree() -> void:
	if is_instance_valid(_sprite) and _sprite.get_parent() != self:
		_sprite.queue_free()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_sprite):
		return
	# Arm sprite space: shoulder at the origin, muzzle from the player's arm data.
	var muzzle: Vector2 = _player.get_arm_muzzle_local()
	var arm_len := muzzle.length()
	if arm_len < 1.0:
		return
	var dir := muzzle / arm_len
	var frame_w := float(strip.get_width() / frame_count)
	var sx := arm_len * length_share / frame_w
	_sprite.scale = Vector2(sx, sx * squash)
	_sprite.rotation = dir.angle()
	# Put the art's spark on the muzzle.
	_sprite.position = muzzle - dir * (spark_at - 0.5) * frame_w * sx
	_sprite.modulate.a = opacity * randf_range(0.8, 1.0)  # crackle
