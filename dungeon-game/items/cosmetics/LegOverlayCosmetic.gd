## Leg cosmetic that follows every lower-body frame (Item cosmetic_slot = "Feet" or
## "Underwear"), e.g. Public Bathroom Shoes, Lead Underwear.
## Art: one 1024x512 sheet per direction, drawn over the matching legs sheet
## (assets/sprites/player/legs/front_lower / left_lower / up_lower.png), frame for frame.
## The frames are cut with the same regions the player's own leg animation uses, so the
## overlay always shows the same frame as the legs (including left's 0,1,3,2 run order).
##
## Optional torso pieces (torso canvas 1254x1254, like torso_*.png) are drawn right over
## the torso, under chest cosmetics - e.g. Lead Underwear's waistband covering the pink band.
extends Node2D
class_name LegOverlayCosmetic

@export var sheet_front: Texture2D
@export var sheet_left: Texture2D
@export var sheet_up: Texture2D
@export var torso_down: Texture2D
@export var torso_left: Texture2D
@export var torso_up: Texture2D

@export_group("Tuning")
## Per-direction nudge of the leg overlay, in sheet pixels (one frame = 256x256).
## Right = left mirrored. The torso piece uses torso_offset_* (torso-art pixels).
@export var offset_down: Vector2 = Vector2.ZERO
@export var offset_left: Vector2 = Vector2.ZERO
@export var offset_up: Vector2 = Vector2.ZERO
## Leg overlay size multiplier per direction (1 = same size as the legs).
@export var scale_down: float = 1.0
@export var scale_left: float = 1.0
@export var scale_up: float = 1.0
@export var torso_offset_down: Vector2 = Vector2.ZERO
@export var torso_offset_left: Vector2 = Vector2.ZERO
@export var torso_offset_up: Vector2 = Vector2.ZERO
@export_group("")

var player_ref: Player = null
var _legs: AnimatedSprite2D
var _torso: Sprite2D


func _ready() -> void:
	player_ref = get_parent().get_parent() as Player  # lives on a cosmetic anchor
	# Child of the legs sprite: drawn right after the legs and before the body rig, and
	# it inherits the legs' position, size and hit flash.
	_legs = AnimatedSprite2D.new()
	_legs.name = name + "Legs"
	player_ref.lower_sprite.add_child(_legs)
	_legs.sprite_frames = _build_frames(player_ref.lower_sprite.sprite_frames)
	if torso_down or torso_left or torso_up:
		_torso = Sprite2D.new()
		_torso.name = name + "Torso"
		player_ref.add_underwear_layer(_torso)


## Same animations, frame regions and speeds as the player's legs, on this item's sheets.
func _build_frames(source: SpriteFrames) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in source.get_animation_names():
		var sheet: Texture2D = sheet_up if anim.ends_with("_up") else (sheet_left if anim.ends_with("_left") else sheet_front)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, source.get_animation_speed(anim))
		frames.set_animation_loop(anim, source.get_animation_loop(anim))
		for i in source.get_frame_count(anim):
			var src := source.get_frame_texture(anim, i) as AtlasTexture
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = src.region if src else Rect2(Vector2.ZERO, sheet.get_size())
			frames.add_frame(anim, atlas)
	return frames


func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		return
	var lower: AnimatedSprite2D = player_ref.lower_sprite
	var dir: String = player_ref._facing_suffix()
	var tex_dir := "left" if dir == "right" else dir
	var nudge: Vector2 = get("offset_" + tex_dir)
	if dir == "right":
		nudge.x = -nudge.x
	_legs.visible = is_visible_in_tree()
	_legs.scale = Vector2.ONE * float(get("scale_" + tex_dir))
	_legs.offset = lower.offset + nudge
	_legs.flip_h = lower.flip_h
	if _legs.animation != lower.animation:
		_legs.animation = lower.animation
	_legs.frame = lower.frame

	if _torso:
		var torso: Sprite2D = player_ref.torso_sprite
		var tnudge: Vector2 = get("torso_offset_" + tex_dir)
		if dir == "right":
			tnudge.x = -tnudge.x
		_torso.texture = get("torso_" + tex_dir)
		_torso.visible = is_visible_in_tree() and _torso.texture != null
		_torso.flip_h = torso.flip_h
		_torso.offset = tnudge
		_torso.position = torso.position
		_torso.scale = torso.scale


func _exit_tree() -> void:
	if is_instance_valid(_torso):
		_torso.queue_free()
	if is_instance_valid(_legs):
		_legs.queue_free()
