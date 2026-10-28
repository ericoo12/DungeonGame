## THE GREAT CLOG - boss. A giant living blockage of hair, toilet paper, grease and
## rubbish, stuck in a drain in the wall OPPOSITE the door you came in through.
##
## Phase 1 - Blockage (100% -> 65%): stays in the drain. Picks an attack each cooldown
##   (weighted, never the same twice in a row):
##     DOORS     - every doorway (not the drain wall) aims a red lane at you, then a
##                 hair tentacle shoots out of each door along its lane. Phase 2: twice.
##     SPIT      - slow fan of sewage balls.
##     MINIONS   - spits out Hair Clogs (small chasers).
##     PULL      - inhales: all loose rubbish on the floor flies back to its mouth and
##                 hurts you on the way. Coughs it back out afterwards.
##     HAIR_WALL - grows a hair wall cutting off the side of the room you're NOT on.
## Phase 2 - Backflow (65% -> 30%): sewer water floods in (BackflowWater): a sideways
##   current that flips now and then pushes the player, enemies, ALL shots and rubbish.
##   Adds:  ROW      - a row of rubbish (one gap) floats out, bent by the current.
##          GRATES   - tentacles burst from the marked floor grates nearest to you.
##          ADDS     - Soap Bubbles / Drip Drops pour out of the drain.
##          SUCTION  - rings warn, then everything is pulled to its mouth for a while.
## Phase 3 - Unclogged (30% -> 0): tears free and becomes a giant rolling hairball. No
##   ranged attacks. Shakes briefly (no lane shown), rolls straight at you, crashes into the wall and
##   is stunned with its core exposed (takes x`exposed_damage_mult` damage; while rolling
##   only x`armored_damage_mult`). Leaves slowing hair piles. Every roll is faster.
##
## Each phase change has the usual boss phase shield (EnemyBase), so you always see it.
## Boss art: assets/sprites/enemies/great_clog/ - every sheet is 4x2 frames of 256 px
## (see _build_frames for which frame is what). Floor/attack effects are drawn in code.
extends EnemyBase
class_name GreatClog

enum Phase { BLOCKAGE, BACKFLOW, UNCLOGGED }
enum Atk { DOORS, SPIT, MINIONS, PULL, HAIR_WALL, ROW, GRATES, ADDS, SUCTION }

const TENTACLE := preload("res://enemies/bosses/great_clog/ClogTentacle.gd")
const RUBBISH := preload("res://enemies/bosses/great_clog/ClogRubbish.gd")
const HAIR_WALL := preload("res://enemies/bosses/great_clog/ClogHairWall.gd")
const HAIR_PILE := preload("res://enemies/bosses/great_clog/ClogHairPile.gd")
const WATER := preload("res://enemies/bosses/great_clog/BackflowWater.gd")
const DRAIN_ART := preload("res://enemies/bosses/great_clog/ClogDrainArt.gd")
const HAIR_CLOG := preload("res://enemies/bosses/great_clog/HairClog.tscn")
const ART := "res://assets/sprites/enemies/great_clog/"
const REMAINS_TEX := preload("res://assets/sprites/enemies/great_clog/great_clog_remains.png")
const WATER_ADDS: Array[PackedScene] = [
	preload("res://enemies/regular/easy/SoapBubble.tscn"),
	preload("res://enemies/regular/easy/DripDrop.tscn"),
]

@export_group("Phases")
@export_range(0.0, 1.0) var backflow_at: float = 0.65
@export_range(0.0, 1.0) var unclogged_at: float = 0.30
@export_group("")


@export_group("Attacks")
@export var cooldown_p1: Vector2 = Vector2(1.2, 1.8)
@export var cooldown_p2: Vector2 = Vector2(0.9, 1.5)
## Door tentacles: warning time, and how far off straight-in a door may aim (degrees).
@export var door_warn: float = 1.2
@export var door_max_aim_deg: float = 55.0
@export var spit_scene: PackedScene
@export var spit_speed: float = 90.0
@export var spit_range: float = 230.0
@export var spit_damage: float = 0.5
@export var max_adds: int = 5
@export var start_rubbish: int = 5
@export var pull_speed: float = 190.0
@export var hair_wall_every: float = 10.0
@export var suction_every: float = 6.5
@export var suction_time: float = 2.4
@export var row_count: int = 8
@export var row_speed: float = 68.0
@export_group("")

@export_group("Rolling (phase 3)")
@export var roll_speed_start: float = 215.0
@export var roll_speed_step: float = 20.0
@export var roll_speed_max: float = 340.0
@export var roll_windup_start: float = 0.5
@export var roll_windup_min: float = 0.3
@export var stun_time: float = 1.15
@export var roll_contact_damage: float = 1.0
@export var exposed_damage_mult: float = 1.5
@export var armored_damage_mult: float = 0.5
@export var pile_every_px: float = 30.0
@export var max_piles: int = 10
@export_group("")

var phase: Phase = Phase.BLOCKAGE
var drain_dir: Vector2 = Vector2.UP   # from the room's middle towards the drain wall
var floor_rect: Rect2
var mouth: Vector2                    # global, middle of the drain opening
var _room: Node = null
var _ready_done: bool = false
var _gen: int = 0                     # bumped on phase change/death: stale coroutines stop
var _busy: bool = false
var _attack_timer: float = 2.0
var _last_attack: int = -1
var _last_wall_ms: int = -100000
var _last_suction_ms: int = -100000
var _adds: Array = []
var _hair_wall: Node = null
var _water: BackflowWater = null
var _art: ClogDrainArt = null
var _grates: Array[Vector2] = []
var _piles: Array = []
var _base_scale: Vector2
var _t: float = 0.0
var _rolling: bool = false
var _roll_dir: Vector2
var _roll_speed: float = 0.0
var _crashed: bool = false
var _exposed: bool = false
var _rolls_done: int = 0


func _ready() -> void:
	super._ready()
	knockback_immune = true
	phase_shield_at = backflow_at
	phase_shield_started.connect(_on_phase_shield)
	sprite.sprite_frames = _build_frames()
	sprite.play("idle_p1")
	_base_scale = sprite.scale
	set_physics_process(false)
	_setup_arena.call_deferred()  # the room sets our position right after add_child


# --- Arena -----------------------------------------------------------------------------

func _setup_arena() -> void:
	if not is_inside_tree():
		return
	_room = _find_room()
	if _room and _room.has_method("get_floor_rect"):
		floor_rect = _room.get_floor_rect()
	if not floor_rect.has_area():
		floor_rect = Rect2(global_position - Vector2(179, 83), Vector2(358, 162))
	drain_dir = _drain_direction()
	var half := floor_rect.size / 2.0
	mouth = floor_rect.get_center() + drain_dir * Vector2(absf(drain_dir.x) * half.x, absf(drain_dir.y) * half.y).length()
	var body_r := 100.0 * visual_scale
	global_position = mouth - drain_dir * (body_r + 4.0)

	_art = DRAIN_ART.new()
	_ground().add_child(_art)
	_art.setup(mouth, drain_dir)
	# Floor drains: in the room from the start, tentacles come out of them in phase 2.
	for uv in [Vector2(-0.6, 0.35), Vector2(0.6, 0.35), Vector2(0.0, 0.6), Vector2(-0.65, 0.85), Vector2(0.65, 0.85)]:
		var g := _arena_point(uv.x, uv.y)
		_grates.append(g)
		_art.add_grate(g)
	for i in start_rubbish:
		_add_rubbish(_arena_point(randf_range(-0.85, 0.85), randf_range(0.35, 0.9)), false)
	_ready_done = true
	set_physics_process(true)


func _find_room() -> Node:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon and "current_room" in dungeon and dungeon.current_room:
		return dungeon.current_room
	var scene := get_tree().current_scene
	if scene:
		for c in scene.get_children():
			if c.has_method("get_floor_rect"):
				return c   # e.g. the enemy test room
	return null


## The wall opposite the room's only door (boss rooms are dead ends). Default north.
func _drain_direction() -> Vector2:
	var data = _room.get("_current_room_data") if _room else null
	if data and "doors" in data:
		for d in data.doors:
			if data.doors[d]:
				return -Vector2(d)
	return Vector2.UP


## u: -1..1 across the room (along the drain wall), v: 0 (drain wall) .. 1 (far wall).
func _arena_point(u: float, v: float) -> Vector2:
	var side := drain_dir.orthogonal()
	var half_w := absf(side.x) * floor_rect.size.x / 2.0 + absf(side.y) * floor_rect.size.y / 2.0
	var depth := absf(drain_dir.x) * floor_rect.size.x + absf(drain_dir.y) * floor_rect.size.y
	return mouth + side * u * half_w - drain_dir * v * depth


func _arena_u(pos: Vector2) -> float:
	var side := drain_dir.orthogonal()
	var half_w := absf(side.x) * floor_rect.size.x / 2.0 + absf(side.y) * floor_rect.size.y / 2.0
	return (pos - mouth).dot(side) / maxf(half_w, 1.0)


func _ground() -> Node:
	var g := get_tree().get_first_node_in_group("ground_effects")
	return g if g else get_parent()


# --- Frame -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if spawn_timer > 0.0:
		spawn_timer -= delta
		return
	if overlapping_hurtboxes.size() > 0:
		contact_tick_timer -= delta
		if contact_tick_timer <= 0.0:
			contact_tick_timer = contact_damage_interval
			_deal_contact_damage()
	_update_look()

	if phase == Phase.UNCLOGGED:
		velocity = _roll_dir * _roll_speed if _rolling else Vector2.ZERO
		move_and_slide()
		if _rolling:
			for i in get_slide_collision_count():
				var hit := get_slide_collision(i)
				if hit.get_collider() is StaticBody2D and hit.get_normal().dot(_roll_dir) < -0.3:
					_crashed = true
		return

	velocity = Vector2.ZERO
	if _busy or is_phase_shielded() or is_stunned():
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_start_attack(_choose_attack())


## Exposed core (stunned in phase 3): pulses red so you know to unload on it.
func _update_look() -> void:
	var col := Color.WHITE
	if _exposed:
		col = col.lerp(Color(1.5, 0.6, 0.6), 0.5 + 0.5 * sin(_t * 16.0))
	sprite.self_modulate = col


# --- Animations ------------------------------------------------------------------------
# Frame numbers: 0-3 = top row, 4-7 = bottom row of each 1024x512 sheet.
#   phase1:          idle 0-3 | 4 closed, 5 swirling (inhale), 6 spitting balls, 7 back
#   phase1_special:  roar 0-3 | 4 squint, 5 hairball in mouth, 6 hairball dropped, 7 back
#   phase2:          wet idle 0-3 | 4 closed, 5-6 vortex (suction), 7 back
#   phase3:          roll 0-3 | 4 crashed flat, 5 getting up, 6 dizzy (stars), 7 ready
#   transition:      0-3 dry -> flooded (phase 1->2) | 4-7 flooded -> torn free (2->3)
#   death:           0-7, then great_clog_remains.png stays on the floor

func _build_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	var p1 := load(ART + "great_clog_phase1.png") as Texture2D
	var sp := load(ART + "great_clog_phase1_special.png") as Texture2D
	var p2 := load(ART + "great_clog_phase2.png") as Texture2D
	var p3 := load(ART + "great_clog_phase3.png") as Texture2D
	var tr := load(ART + "great_clog_transition.png") as Texture2D
	var dt := load(ART + "great_clog_death.png") as Texture2D
	_add_anim(f, "idle_p1", p1, [0, 1, 2, 3], 6.0, true)
	_add_anim(f, "spit", p1, [4, 5, 6, 6, 7], 4.5, false)      # balls leave on frame 6 (~0.45 s)
	_add_anim(f, "inhale", p1, [4, 5], 5.0, false)               # then holds 5 while pulling
	_add_anim(f, "roar", sp, [0, 1, 2, 3], 6.0, false)
	_add_anim(f, "summon", sp, [4, 5, 6, 7], 4.0, false)         # hairball drops on frame 6
	_add_anim(f, "idle_p2", p2, [0, 1, 2, 3], 7.0, true)
	_add_anim(f, "agitated_p2", p2, [0, 1, 2, 3], 14.0, true)
	_add_anim(f, "suck_start", p2, [4, 5, 6], 3.0, false)        # ~1 s warning
	_add_anim(f, "suck_hold", p2, [5, 6], 6.0, true)
	_add_anim(f, "suck_end", p2, [7], 5.0, false)
	_add_anim(f, "to_p2", tr, [0, 1, 2, 3], 3.5, false)
	_add_anim(f, "to_p3", tr, [4, 5, 6, 7], 4.5, false)
	_add_anim(f, "roll", p3, [0, 1, 2, 3], 1.0, false)           # frames set by distance rolled
	_add_anim(f, "crash", p3, [4, 4, 5], 8.0, false)
	_add_anim(f, "dizzy", p3, [6], 1.0, true)
	_add_anim(f, "idle_p3", p3, [7], 1.0, true)
	_add_anim(f, "death_down", dt, [0, 1, 2, 3, 4, 5, 6, 7], 8.0, false)  # EnemyBase.die() plays it
	return f


## The sheets are hand-drawn 4x2 grids that don't sit exactly on 256 px lines (the death
## sheet's top row reaches 27 px into the bottom row, so a plain 256 grid showed a slice
## of another frame). These are the real gaps between frames, measured from the art:
## [row split y, [column splits, top row], [column splits, bottom row]].
## Each frame is cut on those gaps and placed on a FRAME x FRAME canvas with its row's
## bottom edge on the canvas bottom (= the ground), so every frame lines up.
const FRAME := 288
const CUTS := {
	"great_clog_phase1.png": [250, [257, 513, 769], [256, 515, 771]],
	"great_clog_phase1_special.png": [257, [256, 519, 764], [259, 512, 769]],
	"great_clog_phase2.png": [256, [261, 512, 772], [253, 512, 772]],
	"great_clog_phase3.png": [256, [258, 515, 769], [256, 522, 771]],
	"great_clog_transition.png": [264, [256, 512, 768], [259, 512, 775]],
	"great_clog_death.png": [283, [261, 510, 761], [267, 512, 764]],
}


static func _add_anim(f: SpriteFrames, anim: String, tex: Texture2D, frames: Array, fps: float, loop: bool) -> void:
	f.add_animation(anim)
	f.set_animation_speed(anim, fps)
	f.set_animation_loop(anim, loop)
	var cut: Array = CUTS.get(tex.resource_path.get_file(), [256, [256, 512, 768], [256, 512, 768]])
	var split: int = cut[0]
	for i in frames:
		var col: int = i % 4
		var row: int = i / 4
		var xs: Array = [0] + cut[1 + row] + [tex.get_width()]
		var x0: int = xs[col]
		var x1: int = xs[col + 1]
		var y0: int = 0 if row == 0 else split
		var y1: int = split if row == 0 else tex.get_height()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(x0, y0, x1 - x0, y1 - y0)
		var left := clampi(16 + (x0 - col * 256), 0, FRAME - (x1 - x0))
		var top := FRAME - (y1 - y0)
		at.margin = Rect2(left, top, FRAME - (x1 - x0), FRAME - (y1 - y0))
		f.add_frame(anim, at)


func _idle_anim() -> String:
	match phase:
		Phase.BACKFLOW: return "idle_p2"
		Phase.UNCLOGGED: return "idle_p3"
	return "idle_p1"


func _play(anim: String) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


## Plays a one-shot animation, then goes back to the phase's idle loop.
func _play_then_idle(anim: String) -> void:
	_play(anim)
	var g := _gen
	await sprite.animation_finished
	if is_instance_valid(self) and not is_dying and g == _gen and sprite.animation == anim:
		_play(_idle_anim())


# --- Damage ----------------------------------------------------------------------------

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	super.take_damage(amount * _damage_mult(), knockback_dir, knockback_strength)


func _damage_mult() -> float:
	if phase == Phase.UNCLOGGED:
		return exposed_damage_mult if _exposed else armored_damage_mult
	if _water and _water.is_sucking():
		return 1.25  # mouth wide open
	return 1.0


func _on_phase_shield() -> void:
	if phase == Phase.BLOCKAGE:
		_enter_backflow()
		_phase_shield_done = false
		phase_shield_at = unclogged_at
	elif phase == Phase.BACKFLOW:
		_enter_unclogged()


func die() -> void:
	_gen += 1
	_cleanup(true)
	facing_direction = "down"   # EnemyBase plays "death_down"
	sprite.self_modulate = Color.WHITE
	sprite.position = Vector2.ZERO
	_leave_remains.call_deferred(global_position)
	super.die()


## The flattened heap that stays on the floor once it's dead (fades in as the death
## animation ends). A room effect, so it goes away when you leave the room.
func _leave_remains(at: Vector2) -> void:
	var remains := Sprite2D.new()
	# The png has a stray strip of another drawing along its top 30 px: skip it.
	var tex := AtlasTexture.new()
	tex.atlas = REMAINS_TEX
	tex.region = Rect2(0, 40, 256, 216)
	remains.texture = tex
	remains.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	remains.scale = Vector2.ONE * visual_scale
	remains.offset = Vector2(0, -40)
	remains.modulate.a = 0.0
	remains.add_to_group("room_effects")
	_ground().add_child(remains)
	remains.global_position = at
	var tween := remains.create_tween()
	tween.tween_interval(0.85)
	tween.tween_property(remains, "modulate:a", 1.0, 0.2)


func _cleanup(everything: bool) -> void:
	_rolling = false
	if is_instance_valid(_hair_wall):
		_hair_wall.queue_free()
	for n in get_tree().get_nodes_in_group("room_effects"):
		if n is ClogTentacle or n is ClogLaneWarning or (everything and n is ClogRubbish):
			n.queue_free()
	if is_instance_valid(_water):
		_water.drain_away()
	if everything:
		for a in _adds:
			if is_instance_valid(a):
				a.queue_free()
		_adds.clear()


# --- Attack picking --------------------------------------------------------------------

func _choose_attack() -> int:
	var now := Time.get_ticks_msec()
	var dist := global_position.distance_to(player.global_position) if player else 999.0
	var adds_alive := _alive_adds()
	var w := {}
	w[Atk.DOORS] = 3.0
	w[Atk.SPIT] = 3.0
	w[Atk.PULL] = 2.0 if _rubbish_count() >= 2 else 1.0  # with too few it coughs more up
	if not is_instance_valid(_hair_wall) and now - _last_wall_ms > hair_wall_every * 1000.0:
		w[Atk.HAIR_WALL] = 1.3
	if phase == Phase.BLOCKAGE:
		if adds_alive < max_adds - 1:
			w[Atk.MINIONS] = 2.0
	else:
		w[Atk.SPIT] = 1.5
		w[Atk.ROW] = 3.0
		w[Atk.GRATES] = 3.0
		if adds_alive < max_adds - 1:
			w[Atk.ADDS] = 1.5
			w[Atk.MINIONS] = 0.8
		if now - _last_suction_ms > suction_every * 1000.0:
			w[Atk.SUCTION] = 2.0
	w.erase(_last_attack)
	var total := 0.0
	for v in w.values():
		total += v
	var roll := randf() * total
	for k in w:
		roll -= w[k]
		if roll <= 0.0:
			return k
	return Atk.SPIT


func _start_attack(kind: int) -> void:
	_busy = true
	_last_attack = kind
	match kind:
		Atk.DOORS: _do_doors()
		Atk.SPIT: _do_spit()
		Atk.MINIONS: _do_spawn([HAIR_CLOG, HAIR_CLOG] if phase == Phase.BLOCKAGE else [HAIR_CLOG])
		Atk.PULL: _do_pull()
		Atk.HAIR_WALL: _do_hair_wall()
		Atk.ROW: _do_row()
		Atk.GRATES: _do_grates()
		Atk.ADDS: _do_spawn([WATER_ADDS.pick_random(), WATER_ADDS.pick_random()])
		Atk.SUCTION: _do_suction()


func _end_attack() -> void:
	_busy = false
	if sprite.animation != _idle_anim():
		_play(_idle_anim())
	var cd := cooldown_p1 if phase == Phase.BLOCKAGE else cooldown_p2
	_attack_timer = randf_range(cd.x, cd.y)


## Waits (pauses with the game). False if the boss died or changed phase meanwhile.
func _wait(seconds: float) -> bool:
	var g := _gen
	await get_tree().create_timer(seconds, false).timeout
	return is_instance_valid(self) and not is_dying and g == _gen


## Shakes and flashes in the drain: "something is coming". `anim` = the attack's
## animation (empty = keep the current one).
func _windup(seconds: float, anim: String = "") -> void:
	if anim != "":
		_play(anim)
	var tween := create_tween()
	var steps := maxi(1, int(seconds / 0.08))
	for i in steps:
		tween.tween_property(sprite, "position:x", 1.6 if i % 2 == 0 else -1.6, 0.04)
		tween.tween_property(sprite, "position:x", 0.0, 0.04)
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), seconds * 0.5)
	flash.tween_property(sprite, "modulate", Color.WHITE, seconds * 0.5)


func _mouth_out(dist: float = 20.0) -> Vector2:
	return global_position - drain_dir * dist


# --- Phase 1 attacks -------------------------------------------------------------------

## Tentacles shoot out of every doorway (the drain wall's excepted), each aimed at
## where you are when the warning lanes appear.
func _do_doors() -> void:
	var volleys := 2 if phase == Phase.BACKFLOW else 1
	for i in volleys:
		if player == null:
			break
		var warn := door_warn * (0.9 if phase == Phase.BACKFLOW else 1.0) * (0.85 if i > 0 else 1.0)
		for origin_in in _door_origins():
			var origin: Vector2 = origin_in[0]
			var inward: Vector2 = origin_in[1]
			var to_player: Vector2 = get_player_aim_point() - origin
			var ang := clampf(inward.angle_to(to_player), -deg_to_rad(door_max_aim_deg), deg_to_rad(door_max_aim_deg))
			var dir := inward.rotated(ang)
			var t: ClogTentacle = TENTACLE.new()
			get_parent().add_child(t)
			t.setup_thrust(origin, dir, _reach(origin, dir), warn, 0.5)
		_windup(warn, "roar" if phase == Phase.BLOCKAGE else "agitated_p2")
		if not await _wait(warn + 0.6):
			return
	_end_attack()


## [doorway position, direction into the room] for each wall except the drain's.
func _door_origins() -> Array:
	var result := []
	var doors = _room.get("doors") if _room else null
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var inward := -Vector2(d)
		if Vector2(d).dot(drain_dir) > 0.5:
			continue  # the boss is in that wall
		var pos: Vector2
		if doors is Dictionary and doors.has(d) and is_instance_valid(doors[d]):
			pos = doors[d].global_position
		else:
			var half := floor_rect.size / 2.0
			pos = floor_rect.get_center() + Vector2(d) * Vector2(half.x * absf(d.x), half.y * absf(d.y)).length()
		result.append([pos, inward])
	return result


## How far an arm from `origin` along `dir` can reach before the far wall.
func _reach(origin: Vector2, dir: Vector2) -> float:
	var from := origin + dir * 14.0
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * 800.0, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 300.0
	return maxf(60.0, origin.distance_to(hit.position) - 4.0)


func _do_spit() -> void:
	_windup(0.45, "spit" if phase == Phase.BLOCKAGE else "agitated_p2")
	if not await _wait(0.45):
		return
	var count := 7 if phase == Phase.BACKFLOW else 5
	var aim := (get_player_aim_point() - _mouth_out()).normalized()
	for d in ShotPatternModifier.fan(aim, count, 20.0):
		_shoot(d, spit_speed, spit_range, null)
	if await _wait(0.4):
		_end_attack()


## A slow enemy shot. tex = null: a sewage ball, else a piece of rubbish.
func _shoot(dir: Vector2, speed: float, max_range: float, tex: Texture2D, from: Vector2 = Vector2.INF) -> void:
	if spit_scene == null:
		return
	var proj := spit_scene.instantiate()
	proj.speed = speed
	proj.max_range = max_range
	proj.damage = spit_damage
	var spr := proj.get_node_or_null("Sprite2D") as Sprite2D
	if tex and spr:
		spr.texture = tex
		spr.scale = Vector2.ONE * (11.0 / (maxf(tex.get_width(), tex.get_height()) * 0.2))
		spr.modulate = Color(0.8, 0.75, 0.6)
		proj.rotate_to_velocity = false
	else:
		proj.scale = Vector2.ONE * 0.3
		proj.modulate = Color(0.6, 0.45, 0.22)
	get_parent().add_child(proj)
	proj.global_position = _mouth_out() if from == Vector2.INF else from
	proj.launch(dir, Vector2.ZERO)


func _do_spawn(scenes: Array) -> void:
	_windup(0.5, "summon" if phase == Phase.BLOCKAGE else "agitated_p2")
	if not await _wait(0.5):
		return
	for i in scenes.size():
		if _alive_adds() >= max_adds:
			break
		var target := _arena_point(randf_range(-0.5, 0.5), randf_range(0.3, 0.5))
		var add := _spawn_enemy(scenes[i], _mouth_out(14.0))
		if add:
			_adds.append(add)
			var hop := add.create_tween()
			hop.tween_property(add, "global_position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if await _wait(0.4):
		_end_attack()


func _spawn_enemy(scene: PackedScene, pos: Vector2) -> Node2D:
	if _room and _room.has_method("spawn_enemy") and _room.get("_entities_container"):
		return _room.spawn_enemy(scene, pos)
	var e := scene.instantiate()
	get_parent().add_child(e)
	e.global_position = pos
	return e


func _alive_adds() -> int:
	_adds = _adds.filter(func(a): return is_instance_valid(a) and not a.is_dying)
	return _adds.size()


func _rubbish_count() -> int:
	return get_tree().get_nodes_in_group("clog_rubbish").filter(func(r): return not r.is_queued_for_deletion()).size()


func _add_rubbish(pos: Vector2, tossed: bool) -> void:
	var r: ClogRubbish = RUBBISH.new()
	r.floor_rect = floor_rect
	get_parent().add_child(r)
	if tossed:
		r.global_position = _mouth_out(10.0)
		r.toss_to(pos, 0.6)
	else:
		r.global_position = pos


## Inhale: rubbish flies back to the mouth (hurting you on the way), then it coughs it
## (plus a bit more) back out onto the floor.
func _do_pull() -> void:
	var pieces := get_tree().get_nodes_in_group("clog_rubbish").filter(func(r): return not r.is_pulled())
	if pieces.size() < 2:
		# Not enough to pull: cough some up instead.
		_windup(0.4, "spit" if phase == Phase.BLOCKAGE else "agitated_p2")
		if not await _wait(0.4):
			return
		for i in 3:
			_add_rubbish(_arena_point(randf_range(-0.85, 0.85), randf_range(0.35, 0.9)), true)
		if await _wait(0.6):
			_end_attack()
		return
	for p in pieces:
		p.warn()
	_windup(0.7, "inhale" if phase == Phase.BLOCKAGE else "suck_start")
	if not await _wait(0.7):
		return
	for p in pieces:
		if is_instance_valid(p):
			p.pull_to(_mouth_out(6.0), pull_speed)
	if not await _wait(2.0):
		return
	for i in pieces.size():
		_add_rubbish(_arena_point(randf_range(-0.85, 0.85), randf_range(0.35, 0.9)), true)
	if await _wait(0.5):
		_end_attack()


func _do_hair_wall() -> void:
	_last_wall_ms = Time.get_ticks_msec()
	_windup(0.5, "roar" if phase == Phase.BLOCKAGE else "agitated_p2")
	if not await _wait(0.5):
		return
	var u := 0.45 if (player == null or _arena_u(player.global_position) < 0.0) else -0.45
	var depth := absf(drain_dir.x) * floor_rect.size.x + absf(drain_dir.y) * floor_rect.size.y
	var wall: ClogHairWall = HAIR_WALL.new()
	wall.size = Vector2(10, depth + 8.0)
	get_parent().add_child(wall)
	wall.global_position = _arena_point(u, 0.5)
	wall.rotation = drain_dir.angle() + PI / 2.0
	_hair_wall = wall
	if await _wait(0.5):
		_end_attack()


# --- Phase 2 ---------------------------------------------------------------------------

func _enter_backflow() -> void:
	phase = Phase.BACKFLOW
	_gen += 1
	_busy = false
	_attack_timer = 1.6
	_play_then_idle("to_p2")   # floods during the phase shield
	_water = WATER.new()
	_ground().add_child(_water)
	_water.setup(floor_rect, _mouth_out(4.0), drain_dir, self)
	if _art:
		_art.flowing = true


func _do_row() -> void:
	_windup(0.6, "agitated_p2")
	if not await _wait(0.6):
		return
	var depth := absf(drain_dir.x) * floor_rect.size.x + absf(drain_dir.y) * floor_rect.size.y
	var gap := randi_range(1, row_count - 2)
	_fire_row(gap, depth)
	# Below half health: a second row follows, with its gap somewhere else.
	if health < max_health * 0.5:
		if not await _wait(0.75):
			return
		var gap2 := randi_range(1, row_count - 2)
		while absi(gap2 - gap) < 2:
			gap2 = randi_range(1, row_count - 2)
		_fire_row(gap2, depth)
	if await _wait(0.5):
		_end_attack()


func _fire_row(gap: int, depth: float) -> void:
	for i in row_count:
		if i == gap:
			continue
		var u := lerpf(-0.9, 0.9, float(i) / (row_count - 1))
		var from := _arena_point(u, 0.1)
		_shoot(-drain_dir, row_speed, depth, ClogRubbish.random_texture(), from)


func _do_grates() -> void:
	if _grates.is_empty() or player == null:
		_end_attack()
		return
	var by_dist := _grates.duplicate()
	by_dist.sort_custom(func(a, b): return a.distance_to(player.global_position) < b.distance_to(player.global_position))
	var n := 4 if health < max_health * 0.45 else 3
	_windup(0.3, "agitated_p2")
	for i in mini(n, by_dist.size()):
		var t: ClogTentacle = TENTACLE.new()
		get_parent().add_child(t)
		t.setup_burst(by_dist[i], 0.8, 0.5)
	if await _wait(1.6):
		_end_attack()


func _do_suction() -> void:
	_last_suction_ms = Time.get_ticks_msec()
	if _water:
		_water.warn_suction(1.0)
	_windup(1.0, "suck_start")
	if not await _wait(1.0):
		return
	if _water:
		_water.start_suction(suction_time)
	_play("suck_hold")
	if not await _wait(suction_time):
		return
	_play_then_idle("suck_end")
	if await _wait(0.6):
		_end_attack()


# --- Phase 3 ---------------------------------------------------------------------------

func _enter_unclogged() -> void:
	phase = Phase.UNCLOGGED
	_gen += 1
	_busy = false
	_cleanup(false)
	contact_damage = snappedf(roll_contact_damage * GameState.get_damage_multiplier(), 0.5)
	collision_mask = 1 | 8   # rolls through the player (contact damage), stops at walls
	_roll_loop()


func _roll_loop() -> void:
	var g := _gen
	# Tear free: shake hard, then pop out of the drain.
	_windup(0.9, "to_p3")
	await get_tree().create_timer(0.9, false).timeout
	if not _alive(g):
		return
	var pop := create_tween()
	pop.tween_property(self, "global_position", global_position - drain_dir * 22.0, 0.3).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(0.5, false).timeout
	while _alive(g):
		await _one_roll(g)


func _alive(g: int) -> bool:
	return is_instance_valid(self) and not is_dying and g == _gen


func _one_roll(g: int) -> void:
	if player == null:
		await get_tree().create_timer(0.5, false).timeout
		return
	var dir := (player.global_position - global_position).normalized()
	var windup := maxf(roll_windup_min, roll_windup_start - _rolls_done * 0.04)
	# No lane warning: it always rolls straight at you, the shake is the tell.
	_windup(windup, "idle_p3")
	await get_tree().create_timer(windup, false).timeout
	if not _alive(g):
		return

	_roll_dir = dir
	_roll_speed = minf(roll_speed_max, roll_speed_start + roll_speed_step * _rolls_done)
	_rolls_done += 1
	_crashed = false
	_rolling = true
	var rolled := 0.0
	var since_pile := 0.0
	var time := 0.0
	var start := global_position
	while _alive(g) and not _crashed and time < 4.0:
		await get_tree().physics_frame
		if not _alive(g):
			return
		var step := global_position.distance_to(start)
		since_pile += step - rolled
		rolled = step
		time += get_physics_process_delta_time()
		# Roll cycle advances with the distance rolled (backwards when rolling left).
		if sprite.animation != "roll":
			sprite.play("roll")
		sprite.pause()
		var k := int(rolled / 9.0) % 4
		sprite.frame = 3 - k if _roll_dir.x < 0.0 else k
		if since_pile >= pile_every_px:
			since_pile = 0.0
			_drop_pile()
	_rolling = false
	_roll_speed = 0.0
	if not _alive(g):
		return
	# Crash: stunned, core exposed.
	_shake_camera(4.0)
	_exposed = true
	_play("crash")   # flattened, then getting up
	await get_tree().create_timer(0.4, false).timeout
	if not _alive(g):
		return
	_play("dizzy")   # stars: the punish window
	await get_tree().create_timer(stun_time - 0.4, false).timeout
	_exposed = false
	if not _alive(g):
		return
	_play("idle_p3")
	await get_tree().create_timer(0.1, false).timeout


func _drop_pile() -> void:
	_piles = _piles.filter(func(p): return is_instance_valid(p))
	if _piles.size() >= max_piles:
		_piles[0].queue_free()
		_piles.remove_at(0)
	var pile: ClogHairPile = HAIR_PILE.new()
	_ground().add_child(pile)
	pile.global_position = global_position
	_piles.append(pile)


func _shake_camera(strength: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tween := cam.create_tween()
	for i in 6:
		tween.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 6.0), 0.04)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.04)
