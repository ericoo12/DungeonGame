## Clogged toilet (RoomData.toilet_kind):
##   PORTAL - the way into an item/shop room (which has no door). Unclog it with a
##            declogger, then walk into it to travel to RoomData.toilet_target. The item/
##            shop room has one too (already unclogged) that takes you back.
##   CHEST  - unclog it for a few drops (Dungeon.toilet_chest_drops).
## Locked (lid down, can't be used) until the room is cleared - also toilets that start
## unclogged (stage 1 portals, Dungeon.free_special_rooms_until_stage). State lives on
## RoomData, so it stays unclogged/looted on revisits. Spawned by RoomController._spawn_toilet().
##
## Looks: lid down while enemies are alive -> clogged bowl (or clean water if already
## unclogged) once the room is cleared -> walk in: plunger plunges (plunge_duration) ->
## unclog frames -> clean water.
extends Node2D
class_name Toilet

## Lid-down toilet (frame lid_down_frame of a 4-frame sheet), shown while enemies live.
@export var lid_sheet_path: String = "res://assets/sprites/objects/toilet.png"
@export var lid_down_frame: int = 0
## Clogged sheet, 4 frames: clogged, unclogging 1, unclogging 2, clean.
## Both sheets must use the same frame size (543x724 now).
@export var clog_sheet_path: String = "res://assets/sprites/objects/toilet_clogged.png"
@export var sheet_columns: int = 4
@export var unclog_fps: float = 5.0
## Plunger sheet, 2 frames (up / squished), drawn in the bowl while unclogging.
@export var plunger_sheet_path: String = "res://assets/sprites/objects/plunger_sheet.png"
@export var plunger_columns: int = 2
@export var plunge_duration: float = 1.0
@export var plunge_fps: float = 6.0
## Plunger size relative to the toilet art, and where its cup sits: the bowl's centre in
## toilet-sheet pixels, measured from the bottom-centre of a frame.
@export var plunger_scale_ratio: float = 0.41
@export var bowl_point: Vector2 = Vector2(0, -304)
@export var display_height: float = 30.0   # px, art scaled to this
@export var trigger_radius: float = 11.0   # how close the player must get to use it

var room_data: RoomData
var room: RoomController
var dungeon: Dungeon

var _sprite: AnimatedSprite2D
var _plunger: AnimatedSprite2D
var _trigger: Area2D
var _armed: bool = true   # portal: must step off and back on after unclogging
var _busy: bool = false   # unclog animation playing
var _loot_spilled: bool = false


func setup(new_room: RoomController, new_data: RoomData, new_dungeon: Dungeon) -> void:
	room = new_room
	room_data = new_data
	dungeon = new_dungeon


func _ready() -> void:
	add_to_group("room_props")  # Dungeon._load_room() frees these on room change
	_build_sprite()
	_build_body()
	_build_trigger()
	_update_visual()
	if room and not room_data.cleared:
		room.room_cleared.connect(_on_room_cleared)  # lid opens once the enemies are dead


## Left mid-animation (room change): keep the loot for the next visit instead of losing it.
func _exit_tree() -> void:
	if _busy and room_data.toilet_kind == RoomData.ToiletKind.CHEST and not _loot_spilled:
		_loot_spilled = true
		for i in _loot_count():
			var scene: PackedScene = dungeon.toilet_chest_drops.roll() if dungeon.toilet_chest_drops else null
			if scene:
				room_data.pending_drops.append({"scene_path": scene.resource_path,
					"position": room.to_local(_loot_position(i, _loot_count()))})


## Where the player stands after arriving through this toilet: in front of it, or beside
## it if the room grid says that's a wall. Outside the trigger, so arriving doesn't send
## you straight back. (Grid, not a physics query: this runs in the same frame the rooms
## swap, when the old room's colliders still exist and the new ones aren't active yet.)
## Hand-made rooms: put the "ToiletSpot" marker where the space in front is free.
## Also has to be well inside the floor: the grid counts a doorway gap as walkable, so a
## toilet next to a closed door could drop you into the door blocker (stuck in the wall).
func get_arrival_point() -> Vector2:
	var d := trigger_radius + 12.0
	var grid: RoomGrid = room.grid if room else null
	var floor_rect: Rect2 = room.get_floor_rect().grow(-10.0) if room and room.has_method("get_floor_rect") else Rect2()
	for offset in [Vector2(0, d), Vector2(-d - 4, -4), Vector2(d + 4, -4), Vector2(0, -d - 14)]:
		var p: Vector2 = global_position + offset
		if floor_rect.has_area() and not floor_rect.has_point(p):
			continue
		if grid == null or _footprint_clear(grid, p):
			return p
	var fallback := global_position + Vector2(0, d)
	if floor_rect.has_area():
		fallback = fallback.clamp(floor_rect.position, floor_rect.end)
	return fallback


## The player's body is wider than a point: the cells under its edges must be free too,
## or an obstacle in the next cell overlaps it.
func _footprint_clear(grid: RoomGrid, p: Vector2) -> bool:
	for o in [Vector2.ZERO, Vector2(-7, 0), Vector2(7, 0), Vector2(0, -5), Vector2(0, 5)]:
		if not grid.is_walkable(grid.global_to_cell(p + o)):
			return false
	return true


# --- Building ------------------------------------------------------------------

func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var lid_tex := load(lid_sheet_path) as Texture2D
	var clog_tex := load(clog_sheet_path) as Texture2D
	var frame_size := Vector2(clog_tex.get_width() / float(sheet_columns), clog_tex.get_height())
	_add_anim(frames, "lid_down", lid_tex, sheet_columns, [lid_down_frame], 1.0, false)
	_add_anim(frames, "clogged", clog_tex, sheet_columns, [0], 1.0, false)
	_add_anim(frames, "unclog", clog_tex, sheet_columns, [1, 2, 3], unclog_fps, false)
	_add_anim(frames, "clean", clog_tex, sheet_columns, [3], 1.0, false)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var toilet_scale := display_height / frame_size.y
	_sprite.scale = Vector2.ONE * toilet_scale
	_sprite.offset = Vector2(0, -frame_size.y / 2.0)  # bottom of the art on our origin (y-sort)
	add_child(_sprite)

	# Plunger: bottom-centre of its frame on the bowl point, hidden until used.
	var p_tex := load(plunger_sheet_path) as Texture2D
	var p_frames := SpriteFrames.new()
	p_frames.remove_animation("default")
	_add_anim(p_frames, "plunge", p_tex, plunger_columns, range(plunger_columns), plunge_fps, true)
	_plunger = AnimatedSprite2D.new()
	_plunger.sprite_frames = p_frames
	_plunger.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_plunger.scale = Vector2.ONE * toilet_scale * plunger_scale_ratio
	_plunger.offset = Vector2(0, -p_tex.get_height() / 2.0)
	_plunger.position = bowl_point * toilet_scale
	_plunger.visible = false
	add_child(_plunger)


static func _add_anim(frames: SpriteFrames, anim: String, tex: Texture2D, columns: int,
		indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var w := tex.get_width() / float(columns)
	for i in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * w, 0, w, tex.get_height())
		frames.add_frame(anim, atlas)


## Solid base so you bump into it instead of walking through.
func _build_body() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	body.add_child(shape)
	add_child(body)


func _build_trigger() -> void:
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2  # player body
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = trigger_radius
	shape.shape = circle
	shape.position = Vector2(0, -4)
	_trigger.add_child(shape)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)
	_trigger.body_exited.connect(_on_body_exited)


## Runs before Dungeon flips room_data.cleared (it connects later), so don't rely on it.
func _on_room_cleared() -> void:
	if not _busy:
		_sprite.play("clean" if room_data.toilet_unclogged else "clogged")


func _update_visual() -> void:
	if _busy:
		return
	if not room_data.cleared:
		_sprite.play("lid_down")
	elif room_data.toilet_unclogged:
		_sprite.play("clean")
	else:
		_sprite.play("clogged")


# --- Using it --------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return

	if _busy:
		return
	if not room_data.cleared:
		_deny()  # lid down until the enemies are dead
		return
	if not room_data.toilet_unclogged:
		if not player.use_declogger():
			_deny()  # no declogger
			return
		_unclog()
		return

	if room_data.toilet_kind == RoomData.ToiletKind.PORTAL and _armed:
		dungeon.travel_through_toilet(room_data.toilet_target)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		_armed = true


## Plunger plunges for plunge_duration, then the unclog frames play, then clean water.
## Saved as unclogged right away (the declogger is spent), so leaving mid-animation is safe.
func _unclog() -> void:
	room_data.toilet_unclogged = true
	_busy = true
	_armed = false  # step off and back on to go through

	_plunger.visible = true
	_plunger.play("plunge")
	var timer := Timer.new()  # child timer: if the room unloads, this coroutine just stops
	timer.one_shot = true
	add_child(timer)
	timer.start(plunge_duration)
	await timer.timeout
	timer.queue_free()
	_plunger.stop()
	_plunger.visible = false

	_sprite.play("unclog")
	await _sprite.animation_finished
	_busy = false
	_sprite.play("clean")
	var pop := create_tween()
	pop.tween_property(_sprite, "scale", _sprite.scale * 1.1, 0.08)
	pop.tween_property(_sprite, "scale", _sprite.scale, 0.12)
	if room_data.toilet_kind == RoomData.ToiletKind.CHEST:
		_spill_loot()


var _loot_n: int = -1

func _loot_count() -> int:
	if _loot_n < 0:
		_loot_n = randi_range(dungeon.chest_toilet_drops.x, dungeon.chest_toilet_drops.y)
	return _loot_n


func _loot_position(i: int, count: int) -> Vector2:
	return global_position + Vector2((i - (count - 1) / 2.0) * 12.0, 16)


## 2-3 drops in front of the toilet, remembered by the room like other drops.
func _spill_loot() -> void:
	if _loot_spilled or dungeon.toilet_chest_drops == null:
		return
	_loot_spilled = true
	var count := _loot_count()
	for i in count:
		room._spawn_drop(dungeon.toilet_chest_drops.roll(), _loot_position(i, count))


## Can't use it (yet): little shake.
func _deny() -> void:
	var tween := create_tween()
	for x in [2.0, -2.0, 1.0, -1.0, 0.0]:
		tween.tween_property(_sprite, "position:x", x, 0.04)
