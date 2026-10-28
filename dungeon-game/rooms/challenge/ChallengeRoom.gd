## Challenge Room (RoomData.Type.CHALLENGE): high risk, high reward.
## A dead end behind a red door, on some floors (Dungeon.challenge_room_chance). It's
## safe to walk in and look. Three altars (SacrificeAltar) each ask for something:
## a max heart, all your ducks, or your active item. Stand on one to pay - then the
## doors lock and waves of enemies (one tier harder than the floor) come at you.
## Survive every wave for a guaranteed RARE item plus a burst of drops (more drops for
## a bigger sacrifice).
##
## The room is bigger than a normal one (room_size): walls, doors, floor art, grid and
## camera all follow that size, set up in code from RoomBase.tscn.
extends RoomController
class_name ChallengeRoom

const ALTAR_SCRIPT := preload("res://rooms/challenge/SacrificeAltar.gd")
const WARNING_SCRIPT := preload("res://rooms/challenge/SpawnWarning.gd")
const PILLAR_SCENE := preload("res://obstacles/Rock.tscn")

enum State { IDLE, FIGHTING, DONE }

## Inside size of the room (a normal room is 432 x 224).
@export var room_size := Vector2(512, 272)

## Play and find out: no sign over the altars, no altar labels, no "WAVE 1 / 3" or
## "CHALLENGE COMPLETE" banners. Tick to bring the text back (e.g. for testing).
@export var show_text: bool = false

@export_group("Waves")
## Enemies in each wave (also sets how many waves there are), on stage 1.
@export var wave_sizes: Array[int] = [5, 7, 9]
## Extra enemies per wave for every stage after the first.
@export var extra_per_stage: int = 2
## Chance per enemy of being easy / medium / hard, per stage (one tier harder than
## the floor's normal rooms). Index 0 = stage 1.
@export var tier_weights_by_stage: Array[Vector3] = [Vector3(0.55, 0.45, 0.0), Vector3(0.3, 0.45, 0.25), Vector3(0.2, 0.4, 0.4)]
@export var wave_pause: float = 1.0
## The next wave comes in once this few enemies are left (waves overlap, no breather).
## 0 = wait until the wave is fully dead.
@export var next_wave_at_remaining: int = 2
## Enemies keep at least this many cells (16 px) away from you when they appear.
@export var min_spawn_cells: float = 4.0
@export_group("")

@export_group("Rewards")
## Drops on top of the rare item, per sacrifice: heart / ducks / active item.
@export var drops_heart: int = 6
@export var drops_ducks: int = 3
@export var drops_active: int = 4
@export_group("")

var _state: State = State.IDLE
var _wave: int = -1
var _pending_spawns: int = 0
var _next_wave_queued: bool = false
var _paid: int = -1
var _altars: Array[Node2D] = []
var _sign: Label
var _announce_label: Label


func _ready() -> void:
	_fit_to_size()
	super._ready()


# --- Room shape ------------------------------------------------------------------------

## Stretches RoomBase's walls/doors/grid to room_size. Shapes get NEW resources (the
## ones in RoomBase.tscn are shared with every normal room).
func _fit_to_size() -> void:
	var w := room_size.x / 2.0
	var h := room_size.y / 2.0
	var gap := 16.0  # half door opening
	var walls := {
		"NorthLeft": Rect2(-w, -h - 19, w - gap, 48), "NorthRight": Rect2(gap, -h - 19, w - gap, 48),
		# South edge = h - 33, same as RoomBase and the south door's blocker (else a 4 px step).
		"SouthLeft": Rect2(-w, h - 33, w - gap, 48), "SouthRight": Rect2(gap, h - 33, w - gap, 48),
		"WestTop": Rect2(-w - 8, -h, 45, h - gap), "WestBottom": Rect2(-w - 8, gap, 45, h - gap),
		"EastTop": Rect2(w - 37, -h, 45, h - gap), "EastBottom": Rect2(w - 37, gap, 45, h - gap),
	}
	for n in walls:
		_set_box($WallBlockers.get_node(n), walls[n])
	_set_box($ProjectileWalls/North, Rect2(-w - 30, -h - 38, room_size.x + 60, 40))
	_set_box($ProjectileWalls/South, Rect2(-w - 30, h - 16, room_size.x + 60, 40))
	_set_box($ProjectileWalls/West, Rect2(-w - 20, -h - 30, 40, room_size.y + 60))
	_set_box($ProjectileWalls/East, Rect2(w - 20, -h - 30, 40, room_size.y + 60))
	$Doors/North.position = Vector2(0, -h + 20)
	$Doors/South.position = Vector2(0, h - 20)
	$Doors/East.position = Vector2(w - 23, 0)
	$Doors/West.position = Vector2(-w + 21, 0)
	$Background.visible = false
	grid_rect = Rect2i(-int(w / 16.0) - 1, -int(h / 16.0) - 1, int(w / 8.0) + 2, int(h / 8.0) + 2)


static func _set_box(node: CollisionShape2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	node.shape = shape
	node.position = rect.get_center()
	node.scale = Vector2.ONE


## Floor art: the floor variant's room picture as 4 mirrored, stretched quarters (like
## the final boss arena), plus a plain fill behind.
func _apply_floor_variant(variant: RoomFloorVariant) -> void:
	var tex: Texture2D = variant.texture if variant and variant.texture else load("res://assets/sprites/tiles/sewer.png")
	var art := Node2D.new()
	art.name = "QuarterArt"
	art.z_index = -2
	add_child(art)
	move_child(art, 0)
	var w := room_size.x / 2.0
	var h := room_size.y / 2.0
	var fill := TextureRect.new()
	var patch := AtlasTexture.new()
	patch.atlas = tex
	patch.region = Rect2(80, 48, 64, 48)
	fill.texture = patch
	fill.stretch_mode = TextureRect.STRETCH_TILE
	fill.position = Vector2(-w, -h)
	fill.size = room_size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(fill)
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var holder := Node2D.new()
		holder.position = Vector2(q[0] * w, q[1] * h)
		holder.scale = Vector2(-q[0], -q[1])  # mirror so each quarter's wall faces out
		art.add_child(holder)
		var quarter := AtlasTexture.new()
		quarter.atlas = tex
		quarter.region = Rect2(10, 0, 202, 112)
		var nine := NinePatchRect.new()
		nine.texture = quarter
		nine.size = Vector2(w, h)
		nine.draw_center = false
		nine.patch_margin_left = 32
		nine.patch_margin_top = 32
		nine.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		nine.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
		nine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(nine)


## Camera limits and door arrival points use these (Dungeon checks for them).
func get_arena_bounds() -> Rect2:
	return Rect2(global_position - room_size / 2.0, room_size)


func get_entry_position(travel_direction: Vector2i, margin: float = 40.0) -> Vector2:
	var half := room_size / 2.0 - Vector2.ONE * margin
	return global_position - Vector2(travel_direction) * half


# --- Setup -----------------------------------------------------------------------------

func setup(room_data: RoomData, distance: int, dungeon: Dungeon, entities_container: Node2D) -> void:
	super.setup(room_data, distance, dungeon, entities_container)
	_spawn_pillars()
	_build_announcer()
	if room_data.challenge_state == State.IDLE:
		_spawn_altars()
	_state = room_data.challenge_state as State


## Four 2x2 rock pillars for cover, mirrored around the middle.
func _spawn_pillars() -> void:
	var w := room_size.x / 2.0
	var h := room_size.y / 2.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var base := Vector2(corner.x * w * 0.5, corner.y * h * 0.45)
		for dx in 2:
			for dy in 2:
				var cell := grid.global_to_cell(global_position + base + Vector2(dx * 16 - 8, dy * 16 - 8))
				var rock := PILLAR_SCENE.instantiate()
				_entities_container.add_child(rock)
				rock.global_position = grid.cell_to_global(cell)
				grid.set_obstacle(cell, true)


func _spawn_altars() -> void:
	var kinds := [SacrificeAltar.Kind.HEART, SacrificeAltar.Kind.DUCKS, SacrificeAltar.Kind.ACTIVE]
	for i in kinds.size():
		var altar: SacrificeAltar = ALTAR_SCRIPT.new()
		altar.kind = kinds[i]
		altar.show_label = show_text
		_entities_container.add_child(altar)
		altar.add_to_group("room_props")  # freed on room change
		altar.global_position = global_position + Vector2((i - 1) * 56, 4)
		altar.sacrificed.connect(_on_sacrificed)
		_altars.append(altar)
	if show_text:
		_sign = _world_label("SACRIFICE ONE  -  SURVIVE %d WAVES  -  WIN A RARE ITEM" % wave_sizes.size(),
			global_position + Vector2(0, -34), Color(0.95, 0.4, 0.35))


func _world_label(text: String, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.scale = Vector2.ONE * 0.25
	l.size = Vector2(1400, 40)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 3
	add_child(l)
	l.global_position = pos - Vector2(700 * 0.25, 5)
	return l


## Big text in the middle of the screen ("WAVE 1 / 3").
func _build_announcer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_announce_label = Label.new()
	_announce_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_announce_label.offset_top = 90
	_announce_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.add_theme_font_size_override("font_size", 48)
	_announce_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	_announce_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_announce_label.add_theme_constant_override("outline_size", 12)
	_announce_label.modulate.a = 0.0
	layer.add_child(_announce_label)


func _announce(text: String) -> void:
	if not show_text:
		return
	_announce_label.text = text
	var tween := create_tween()
	_announce_label.modulate.a = 0.0
	tween.tween_property(_announce_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.1)
	tween.tween_property(_announce_label, "modulate:a", 0.0, 0.4)


# --- The fight -------------------------------------------------------------------------

func _on_sacrificed(kind: int) -> void:
	_paid = kind
	for altar in _altars:
		if is_instance_valid(altar):
			altar.queue_free()
	_altars.clear()
	if is_instance_valid(_sign):
		_sign.queue_free()
	_state = State.FIGHTING
	_current_room_data.challenge_state = State.FIGHTING
	for door: Door in doors.values():
		if door.visible:
			door.set_unlocked(false)
	Audio.play_boss_music()
	get_tree().create_timer(1.0, false).timeout.connect(_start_wave.bind(0))


func _start_wave(index: int) -> void:
	if not is_inside_tree():
		return
	_wave = index
	_announce("WAVE %d / %d" % [index + 1, wave_sizes.size()])
	var stage := GameState.current_stage
	var count := wave_sizes[index] + maxi(stage - 1, 0) * extra_per_stage
	var scenes := _pick_wave_scenes(count)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var away: Array[Vector2i] = [grid.global_to_cell(player.global_position)]
	var cells := EnemySpawnPlanner.pick_cells(grid, away, scenes.size(), min_spawn_cells, 8)
	_next_wave_queued = false
	_pending_spawns += cells.size()
	for i in cells.size():
		var warning: SpawnWarning = WARNING_SCRIPT.new()
		warning.duration = 0.8 + randf() * 0.4
		add_child(warning)
		warning.global_position = grid.cell_to_global(cells[i])
		warning.finished.connect(_spawn_one.bind(scenes[i], warning.global_position))


func _spawn_one(scene: PackedScene, pos: Vector2) -> void:
	_pending_spawns -= 1
	if _state == State.FIGHTING:
		spawn_enemy(scene, pos)
	_check_progress()


func _pick_wave_scenes(count: int) -> Array[PackedScene]:
	var tiers: Array = [_dungeon.easy_enemy_scenes, _dungeon.medium_enemy_scenes, _dungeon.hard_enemy_scenes]
	var stage_index := clampi(GameState.current_stage - 1, 0, tier_weights_by_stage.size() - 1)
	var w: Vector3 = tier_weights_by_stage[stage_index]
	var result: Array[PackedScene] = []
	for i in count:
		var tier := _roll_tier([w.x, w.y, w.z], tiers)
		if tier == -1:
			break
		var scene := _weighted_pick(tiers[tier], _dungeon)
		if scene:
			result.append(scene)
	return result


## Counts down the wave; when everything (including enemies still being announced and
## anything they spawned) is gone, the next wave starts or the challenge is won.
func _on_enemy_removed() -> void:
	_enemy_count -= 1
	_check_progress()


## Next wave when only next_wave_at_remaining are left; the win when the LAST wave is
## completely dead (counting enemies still being announced and anything they spawned).
func _check_progress() -> void:
	if _state != State.FIGHTING or not is_inside_tree() or _pending_spawns > 0:
		return
	if _wave + 1 < wave_sizes.size():
		if not _next_wave_queued and _enemy_count <= next_wave_at_remaining:
			_next_wave_queued = true
			get_tree().create_timer(wave_pause, false).timeout.connect(_start_wave.bind(_wave + 1))
	elif _enemy_count <= 0:
		_win.call_deferred()  # can run while the last enemy leaves the tree: can't add nodes yet


func _win() -> void:
	if _state != State.FIGHTING or not is_inside_tree():
		return
	_state = State.DONE
	_current_room_data.challenge_state = State.DONE
	Audio.play_normal_music()
	_unlock_all_doors()
	if not _combat_cleared:
		_combat_cleared = true
		EventBus.combat_room_cleared.emit()  # active item charge
	_announce("CHALLENGE COMPLETE")
	_spawn_reward()


func _spawn_reward() -> void:
	var item := _pick_rare_item()
	if item:
		GameState.picked_up_items.append(item)
		var pickup: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
		_entities_container.add_child(pickup)
		pickup.global_position = global_position
		pickup.setup(item)
		register_floor_item(pickup)  # still here on a revisit if you leave it
	var drops := drops_heart
	match _paid:
		SacrificeAltar.Kind.DUCKS: drops = drops_ducks
		SacrificeAltar.Kind.ACTIVE: drops = drops_active
	if _dungeon.room_clear_drops:
		for i in drops:
			_spawn_drop(_dungeon.room_clear_drops.roll(1.0), global_position + Vector2(0, 14))


func _pick_rare_item() -> ItemBase:
	var rares := _dungeon.item_pool.filter(func(i: ItemBase):
		return i.rarity == ItemBase.Rarity.RARE and not GameState.picked_up_items.has(i))
	if not rares.is_empty():
		return rares.pick_random()
	var any := _dungeon.pick_items(1)  # all rares taken: best we can do
	return any[0] if not any.is_empty() else null


func _exit_tree() -> void:
	if _state == State.FIGHTING:
		Audio.play_normal_music()
