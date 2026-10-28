## Cosmetic that puffs a little animated cloud out of the gun every time the player
## fires (Sewer Gas). The puff stays where it was fired and drifts the way the shot went.
## Art: a horizontal strip of square frames, the cloud blowing to the RIGHT (rotated to
## the shot; mirrored instead of turned upside down when shooting left).
## Equip in any slot (the item uses "Aura"): it only listens to Player.shot_fired.
extends Node2D
class_name GunPuffCosmetic

@export var strip: Texture2D
@export var frame_count: int = 6
@export var fps: float = 16.0
## On-screen width of one frame in px.
@export var size_px: float = 16.0
## How far past the muzzle the puff's middle sits (px), so it starts at the barrel.
@export var push_out: float = 5.0
## Drift speed along the shot (px/s).
@export var drift: float = 22.0
@export_range(0.0, 1.0) var opacity: float = 0.9

var _player: Player
var _frames: SpriteFrames


func _ready() -> void:
	_frames = SpriteFrames.new()
	_frames.set_animation_speed("default", fps)
	_frames.set_animation_loop("default", false)
	var w := strip.get_width() / frame_count
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * w, 0, w, strip.get_height())
		_frames.add_frame("default", atlas)
	var n: Node = get_parent()
	while n and not (n is Player):
		n = n.get_parent()
	_player = n as Player
	if _player:
		_player.shot_fired.connect(_on_shot_fired)


func _on_shot_fired(dir: Vector2) -> void:
	if not is_instance_valid(_player) or dir == Vector2.ZERO:
		return
	var world := _player.get_parent()
	if world == null:
		return
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = _frames
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	puff.scale = Vector2.ONE * (size_px / float(strip.get_width() / frame_count))
	puff.modulate.a = opacity
	if dir.x < -0.5:
		puff.flip_h = true                 # blowing left: mirror, don't flip it upside down
		puff.rotation = (-dir).angle()     # mirrored art points left; tilt it to the shot
	else:
		puff.rotation = dir.angle()
	puff.add_to_group("room_effects")
	world.add_child(puff)
	puff.global_position = _player.get_muzzle_position(dir) + dir * push_out
	puff.play("default")
	var tween := puff.create_tween()
	tween.tween_property(puff, "global_position", puff.global_position + dir * drift * 0.4, 0.4)
	puff.animation_finished.connect(puff.queue_free)
