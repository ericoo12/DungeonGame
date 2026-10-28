@tool
extends StaticBody2D
class_name ArenaObstacle

const MOVEMENT_LAYER: int = 1 << 7
const PROJECTILE_LAYER: int = 1 << 8
const SIGHT_LAYER: int = 1 << 9

@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		_request_refresh()
@export var blocks_projectiles: bool = true:
	set(value):
		blocks_projectiles = value
		_request_refresh()
@export var blocks_sight: bool = false:
	set(value):
		blocks_sight = value
		_request_refresh()
@export var obstacle_size := Vector2(32, 32):
	set(value):
		obstacle_size = value.max(Vector2.ONE)
		_request_refresh()
@export var placeholder_color := Color(0.15, 0.8, 0.25, 1):
	set(value):
		placeholder_color = value
		_request_refresh()
@export var show_placeholder: bool = true:
	set(value):
		show_placeholder = value
		_request_refresh()

@export_group("Art")
## Sprite sheet (frames side by side, e.g. treasure_containment_vaults.png). Empty =
## the placeholder square. The art's bottom sits on the bottom of the collision box and
## it can stick out above it (it's drawn y-sorted with the player in game).
@export var art_sheet: Texture2D:
	set(value):
		art_sheet = value
		_request_refresh()
@export var art_frames: int = 1:
	set(value):
		art_frames = maxi(value, 1)
		_request_refresh()
@export var art_frame: int = 0:
	set(value):
		art_frame = value
		_request_refresh()
## The object's part of a frame (frame pixels), trimming empty edges. Zero size = whole frame.
@export var art_content := Rect2():
	set(value):
		art_content = value
		_request_refresh()
## Width the art is drawn at (px).
@export var art_width: float = 52.0:
	set(value):
		art_width = value
		_request_refresh()
## Low object (shots fly over it): the art stays under everything - player, boss and
## every shot are drawn on top. Off = tall object, drawn y-sorted with the player.
@export var art_low: bool = false
## > 0: the frames play as a looping animation at this speed (in game), starting at
## art_frame. 0 = art_frame is a still picture.
@export var art_fps: float = 0.0
@export_group("")

var _refresh_pending: bool = false
var _art_holder: Node2D = null

func _ready() -> void:
	_refresh()

func _request_refresh() -> void:
	if not is_inside_tree() or _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_refresh")

func _refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree():
		return
	collision_layer = 0
	if blocks_movement:
		collision_layer |= MOVEMENT_LAYER
	if blocks_projectiles:
		collision_layer |= PROJECTILE_LAYER
	if blocks_sight:
		collision_layer |= SIGHT_LAYER
	collision_mask = 0
	if blocks_projectiles:
		add_to_group("projectile_blockers")
	else:
		remove_from_group("projectile_blockers")
	# Each instance owns its shape, so resizing one never resizes another.
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	$CollisionShape2D.shape = shape
	var half_size := obstacle_size * 0.5
	$Square.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		half_size, Vector2(-half_size.x, half_size.y)
	])
	$Square.color = placeholder_color
	$Square.visible = show_placeholder and art_sheet == null
	_refresh_art(half_size)


## Art holder sits a bit above the box's bottom edge: that's the y-sort line, so the
## player (whose origin is ~13 px above their feet) is drawn in front when standing south
## of it and behind it when north of it.
const ART_SORT_LIFT := 14.0

func _refresh_art(half_size: Vector2) -> void:
	if art_sheet == null:
		if _art_holder:
			_art_holder.queue_free()
			_art_holder = null
		return
	if _art_holder == null or not is_instance_valid(_art_holder):
		_art_holder = Node2D.new()
		_art_holder.name = "ArtHolder"
		var spr := Sprite2D.new()
		spr.name = "Art"
		spr.centered = false
		spr.region_enabled = true
		_art_holder.add_child(spr)
		add_child(_art_holder)
	var region := _frame_region(clampi(art_frame, 0, art_frames - 1))
	var s := art_width / region.size.x
	var spr := _art_holder.get_node("Art") as Sprite2D
	spr.texture = art_sheet
	spr.region_rect = region
	spr.scale = Vector2(s, s)
	if _art_holder.get_parent() == self:
		_art_holder.position = Vector2(0, half_size.y - ART_SORT_LIFT)
	spr.position = Vector2(-art_width / 2.0, ART_SORT_LIFT - region.size.y * s)


func _frame_region(frame: int) -> Rect2:
	var frame_w := art_sheet.get_width() / float(art_frames)
	var content := art_content if art_content.has_area() else Rect2(0, 0, frame_w, art_sheet.get_height())
	return Rect2(frame * frame_w + content.position.x, content.position.y, content.size.x, content.size.y)


var _anim_time: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or art_fps <= 0.0 or art_frames < 2 or art_sheet == null:
		return
	if _art_holder == null or not is_instance_valid(_art_holder):
		return
	_anim_time += delta
	var frame := (art_frame + int(_anim_time * art_fps)) % art_frames
	(_art_holder.get_node("Art") as Sprite2D).region_rect = _frame_region(frame)


## In game: moves the art into the (y-sorted) entities container so the player can walk
## behind and in front of it. Freed with the room (room_props group).
func move_art_to(container: Node) -> void:
	if _art_holder == null or not is_instance_valid(_art_holder) or container == null or art_low:
		return
	var at := _art_holder.global_position
	remove_child(_art_holder)
	container.add_child(_art_holder)
	_art_holder.global_position = at
	_art_holder.add_to_group("room_props")
	tree_exiting.connect(func():
		if is_instance_valid(_art_holder):
			_art_holder.queue_free())
