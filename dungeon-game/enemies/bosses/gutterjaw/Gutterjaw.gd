## GUTTERJAW - boss: a huge sewer crocodile that hunts you like an animal.
## Art: 4-direction sheets in assets/sprites/enemies/gutterjaw/clean/ (rows: down, left,
## right, up; 4 frames each, 320x288 cells, re-cut from the drawn sheets by
## clean_gutterjaw_sheets.py). Trash Spit (art ready), the rubbish and the phase combos
## come next.
##
## Stalking: circles you at `stalk_distance`, turning towards you at a limited speed (so
## you can get behind it). Between major attacks it uses Jaw Snap when you stand in front
## of its head. Snap and Tail Sweep are also picked as major attacks when you keep your
## distance: it rushes in (`rush_speed`, up to `rush_time`) first.
##   JAW SNAP   - you're close in front: head pulls back (0.3 s), fast cone bite, short
##                recovery, cooldown. As a major attack: rushes in, then lunges + bites.
##   AMBUSH     - dives (untargetable). Swims after your feet unseen (limited turning, so
##                keep moving), stops for `ambush_warn`, then erupts and bites. No warning
##                on the floor unless `show_ambush_warning` is on. A miss
##                leaves its head exposed (x`exposed_damage_mult`) while it pulls out.
##                Favoured when you camp near a wall. Phase 2/3: 2/3 ambushes in a row,
##                each warning a bit shorter.
##   TAIL SWEEP - you're behind it (or as a major attack: rushes in and whips its back
##                round to you): tail raised for `sweep_windup` (0.7 s): a soft tail shadow on the floor and sewage dripping off the tail, then
##                it spins and the tail sweeps a ~220 deg arc behind/beside it. Strong
##                knockback, moderate damage, knocks your shots away (deflects them).
##   HUNGRY CHARGE - you're far away: lowers its head, mouth open (the only tell; the
##                lane is hidden unless `show_charge_lane` is on), charges. Steers a little in the first third, then commits. Armoured
##                head while charging (x`armored_damage_mult`). Hitting a wall stuns it
##                (x`exposed_damage_mult`), then it backs off before the next attack.
## Never the same major attack twice in a row. Phases (boss phase shield between them):
##   1 Stalking 100-65%, 2 Feeding Frenzy 65-30% (faster), 3 Cornered Beast 30-0%.
extends EnemyBase
class_name Gutterjaw

enum Phase { STALKING, FRENZY, CORNERED }
enum Atk { NONE = -1, AMBUSH, SWEEP, CHARGE, SNAP }

const RIPPLE := preload("res://enemies/bosses/gutterjaw/GutterRipple.gd")
const SWEEP_ARC := preload("res://enemies/bosses/gutterjaw/GutterSweepArc.gd")
const LANE := preload("res://enemies/bosses/great_clog/ClogLaneWarning.gd")
const DRIPS := preload("res://enemies/bosses/gutterjaw/GutterDrips.gd")
## Tail tip during tail_raise per facing row (local, measured from the art) - drips fall from here.
const TAIL_TIPS := {"down": Vector2(0, -55), "left": Vector2(26, -39), "right": Vector2(-25, -32), "up": Vector2(-29, 17)}
const STARS := preload("res://enemies/bosses/gutterjaw/GutterStars.gd")
const ART := "res://assets/sprites/enemies/gutterjaw/clean/"
const CELL := Vector2i(320, 288)
const DIRS := ["down", "left", "right", "up"]   # sheet rows
## base animation -> [sheet, frames, fps, loop]
const ANIMS := {
	"idle": ["gutterjaw_stalk", [0], 1.0, true],
	"walk": ["gutterjaw_stalk", [0, 1, 2, 3], 7.0, true],
	"snap": ["gutterjaw_hungry_charge", [1], 1.0, true],
	"dive": ["gutterjaw_ambush", [0, 1], 7.0, false],
	"erupt": ["gutterjaw_ambush", [2], 1.0, true],
	"surface": ["gutterjaw_ambush", [3], 1.0, true],
	"stun": ["gutterjaw_ambush", [3], 1.0, true],
	"tail_raise": ["gutterjaw_tail_sweep", [0, 1], 4.0, false],
	"tail_swing": ["gutterjaw_tail_sweep", [2, 3], 8.0, false],
	"charge_wind": ["gutterjaw_hungry_charge", [0], 1.0, true],
	"charge": ["gutterjaw_hungry_charge", [0, 1, 2, 3], 10.0, true],
	"spit": ["gutterjaw_trash_spit", [0, 1, 2, 3], 6.0, false],
	"death": ["gutterjaw_ambush", [0, 1], 2.5, false],
}

@export_group("Phases")
@export_range(0.0, 1.0) var frenzy_at: float = 0.65
@export_range(0.0, 1.0) var cornered_at: float = 0.30
## Seconds between major attacks, per phase (random in x..y).
@export var cooldowns: Array[Vector2] = [Vector2(1.6, 2.3), Vector2(1.2, 1.8), Vector2(0.9, 1.4)]
@export_group("")

@export_group("Stalking")
@export var stalk_distance: float = 95.0
@export var stalk_speed: float = 55.0
@export var turn_speed_deg: float = 150.0
@export_group("")

@export_group("Jaw Snap")
@export var snap_range: float = 46.0
@export var snap_reach: float = 58.0
@export var snap_cone_deg: float = 35.0
@export var snap_windup: float = 0.3
@export var snap_recovery: float = 0.45
@export var snap_cooldown: float = 1.6
@export var snap_damage: float = 0.5
## Major-attack snap/sweep: how fast and how long it rushes in before attacking.
@export var rush_speed: float = 190.0
@export var rush_time: float = 0.8
## Major-attack snap: how far the bite lunges forward.
@export var snap_lunge: float = 26.0
@export_group("")

@export_group("Ambush")
@export var ambush_counts: Array[int] = [1, 2, 3]
@export var ambush_track_time: float = 1.2
@export var ambush_warn: float = 0.3
## Show the ripple and the red bite circle while it's under the floor (off = no tell).
@export var show_ambush_warning: bool = false
## Each further ambush in a chain: warning and tracking times multiplied by this.
@export var ambush_chain_speedup: float = 0.85
@export var ripple_speed: float = 160.0
@export var ripple_turn_deg: float = 420.0
@export var ambush_radius: float = 24.0
@export var ambush_damage: float = 1.0
@export var ambush_miss_recovery: float = 0.7
@export var ambush_hit_recovery: float = 0.35
@export_group("")

@export_group("Tail Sweep")
## Tail raised (back turned to you) before the swing - the only tell.
@export var sweep_windup: float = 0.7
## Red warning arc instead of the soft tail shadow (+ drips) on the floor.
@export var show_sweep_arc: bool = false
@export var sweep_time: float = 0.28
@export var sweep_arcs_deg: Array[float] = [220.0, 235.0, 235.0]
@export var sweep_radii: Array[float] = [64.0, 72.0, 72.0]
@export var sweep_damage: float = 0.5
@export var sweep_knockback: float = 480.0
## Phase 1: you have to stay behind it this long before it sweeps.
@export var sweep_behind_time: float = 0.6
@export_group("")

@export_group("Hungry Charge")
## Show the shadow lane during the windup (off = only the open mouth tells you).
@export var show_charge_lane: bool = false
@export var charge_windups: Array[float] = [0.65, 0.55, 0.45]
@export var charge_speeds: Array[float] = [240.0, 280.0, 310.0]
@export var charge_steer_deg: float = 70.0
@export var charge_max_time: float = 1.8
@export var charge_damage: float = 1.0
@export var stun_time: float = 1.4
@export var retreat_time: float = 0.6
@export var exposed_damage_mult: float = 1.5
@export var armored_damage_mult: float = 0.5
@export var far_distance: float = 140.0
@export_group("")

var phase: Phase = Phase.STALKING
var floor_rect: Rect2
var _facing: Vector2 = Vector2.LEFT
var _gen: int = 0                 # bumped on phase change/death: stale coroutines stop
var _busy: bool = false
var _attack_timer: float = 2.0
var _last_major: int = Atk.NONE
var _snap_cd: float = 1.0
var _behind_time: float = 0.0
var _circle_sign: float = 1.0
var _circle_timer: float = 2.0
var _submerged: bool = false
var hide_health_bar: bool = false  # EnemyHealthBar: hidden while it's under the sewage
var _exposed: bool = false
var _armored: bool = false
var _charging: bool = false
var _charge_dir: Vector2
var _charge_speed: float = 0.0
var _crashed: bool = false
var _charge_hit: bool = false
var _move: Vector2 = Vector2.ZERO  # movement during actions (retreat)
var _base_scale: Vector2
var _anim_base: String = "idle"
var _stars: Node2D = null
var _saved_layer: int = 0
var _saved_mask: int = 0
var _default_mask: int = 0
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	knockback_immune = true
	_default_mask = collision_mask
	phase_shield_at = frenzy_at
	phase_shield_started.connect(_on_phase_shield)
	sprite.sprite_frames = _build_frames()
	_play("idle")
	_base_scale = sprite.scale
	_stars = _make_stars()
	_find_floor.call_deferred()
	if player:
		_facing = (player.global_position - global_position).normalized()


## Little dizzy stars over its head while stunned after a wall crash.
func _make_stars() -> Node2D:
	var stars := Node2D.new()
	stars.set_script(STARS)
	stars.position = Vector2(0, -34)
	stars.visible = false
	add_child(stars)
	return stars


func _find_floor() -> void:
	var room: Node = null
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon and "current_room" in dungeon and dungeon.current_room:
		room = dungeon.current_room
	else:
		var scene := get_tree().current_scene
		if scene and scene.has_method("get_floor_rect") and scene.get_floor_rect().has_area():
			room = scene  # e.g. the enemy test arena
		elif scene:
			for c in scene.get_children():
				if c.has_method("get_floor_rect") and c.get_floor_rect().has_area():
					room = c
	if room and room.has_method("get_floor_rect"):
		floor_rect = room.get_floor_rect()
	if not floor_rect.has_area():
		floor_rect = Rect2(global_position - Vector2(179, 83), Vector2(358, 162))


func _build_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	var sheets := {}
	for base in ANIMS:
		var spec: Array = ANIMS[base]
		if not sheets.has(spec[0]):
			sheets[spec[0]] = load(ART + spec[0] + ".png")
		var tex: Texture2D = sheets[spec[0]]
		for row in DIRS.size():
			var anim: String = base + "_" + DIRS[row]
			f.add_animation(anim)
			f.set_animation_speed(anim, spec[2])
			f.set_animation_loop(anim, spec[3])
			for col in spec[1]:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2(col * CELL.x, row * CELL.y), CELL)
				f.add_frame(anim, at)
	return f


## Which sheet row fits where it faces (side views win near the diagonals).
func _dir_name() -> String:
	if absf(_facing.x) > absf(_facing.y) * 0.85:
		return "left" if _facing.x < 0.0 else "right"
	return "up" if _facing.y < 0.0 else "down"


## Plays base animation `base` in the current facing direction (keeps the frame when
## only the direction changed).
func _play(base: String) -> void:
	var anim := base + "_" + _dir_name()
	if not sprite.sprite_frames.has_animation(anim):
		return
	var same_base := _anim_base == base
	_anim_base = base
	if sprite.animation == anim:
		return
	var frame := sprite.frame if same_base else 0
	sprite.play(anim)
	if same_base:
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1)


func _alive(g: int) -> bool:
	return is_instance_valid(self) and not is_dying and g == _gen and is_inside_tree()


func _wait(seconds: float) -> bool:
	var g := _gen
	await get_tree().create_timer(seconds, false).timeout
	return _alive(g)


static func _free(n) -> void:   # untyped: a typed arg rejects an already-freed node
	if is_instance_valid(n):
		n.queue_free()


func _ground() -> Node:
	var g := get_tree().get_first_node_in_group("ground_effects")
	return g if g else get_parent()


func _player_feet() -> Vector2:
	var feet = player.get("body_collision") if player else null
	return (feet as Node2D).global_position if feet is Node2D else (player.global_position if player else global_position)


func _hurt_player(amount: float, from: Vector2, knockback: float) -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(amount, (player.global_position - from).normalized(), knockback)


## Angle (radians, 0..PI) between where it faces and the player.
func _angle_to_player() -> float:
	if player == null:
		return 0.0
	return absf(_facing.angle_to(_player_feet() - global_position))


# --- Frame -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if spawn_timer > 0.0:
		spawn_timer -= delta
		return
	if player == null or is_dying:
		return
	if not _submerged and overlapping_hurtboxes.size() > 0:
		contact_tick_timer -= delta
		if contact_tick_timer <= 0.0:
			contact_tick_timer = contact_damage_interval
			_deal_contact_damage()
	_update_look()

	if _charging:
		_charge_step(delta)
		return
	if _busy or is_phase_shielded() or is_stunned():
		velocity = _move
		move_and_slide()
		return

	_stalk(delta)
	var dist := global_position.distance_to(_player_feet())
	var ang := _angle_to_player()
	_behind_time = _behind_time + delta if ang > deg_to_rad(110.0) and dist < _sweep_radius() + 8.0 else 0.0
	_snap_cd -= delta
	if _snap_cd <= 0.0 and dist < snap_range + 14.0 and ang < deg_to_rad(snap_cone_deg):
		_jaw_snap()
		return
	# Defensive tail: phase 1 waits a moment, later phases react straight away.
	if _last_major != Atk.SWEEP and _behind_time > (sweep_behind_time if phase == Phase.STALKING else 0.25):
		_start_major(Atk.SWEEP)
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_start_major(_choose_major(dist, ang))


func _update_look() -> void:
	if sprite.animation != _anim_base + "_" + _dir_name():
		_play(_anim_base)  # turned: same animation, other direction
	if _stars:
		_stars.visible = _exposed and _anim_base == "stun"
	var col := Color.WHITE
	if _exposed:
		col = col.lerp(Color(1.6, 0.55, 0.55), 0.5 + 0.5 * sin(_t * 16.0))
	elif _armored:
		col = Color(0.85, 0.85, 0.95)
	sprite.self_modulate = col


func _turn_towards(dir: Vector2, delta: float, deg_per_s: float) -> void:
	if dir == Vector2.ZERO:
		return
	var diff := wrapf(dir.angle() - _facing.angle(), -PI, PI)
	var step := deg_to_rad(deg_per_s) * delta
	_facing = Vector2.from_angle(_facing.angle() + clampf(diff, -step, step))


## Circles the player at stalk_distance, facing them (limited turning).
func _stalk(delta: float) -> void:
	var to := _player_feet() - global_position
	_turn_towards(to, delta, turn_speed_deg)
	_circle_timer -= delta
	if _circle_timer <= 0.0:
		_circle_timer = randf_range(1.8, 3.5)
		_circle_sign = -_circle_sign
	var dist := to.length()
	var radial := to.normalized() * clampf((dist - stalk_distance) * 2.0, -stalk_speed, stalk_speed)
	var tangent := to.normalized().orthogonal() * _circle_sign * stalk_speed * 0.8
	velocity = (radial + tangent).limit_length(stalk_speed) + external_velocity
	external_velocity = Vector2.ZERO
	move_and_slide()
	if get_slide_collision_count() > 0 and randf() < 0.05:
		_circle_sign = -_circle_sign  # stuck on a wall: go round the other way
	_play("walk" if velocity.length() > 5.0 else "idle")


func _sweep_radius() -> float:
	return sweep_radii[mini(phase, sweep_radii.size() - 1)]


# --- Attack picking --------------------------------------------------------------------

func _choose_major(dist: float, ang: float) -> int:
	var w := {}
	w[Atk.CHARGE] = 1.0 + (2.0 if dist > far_distance else 0.0)
	w[Atk.AMBUSH] = 1.5 + (1.5 if _player_near_wall() else 0.0)
	# Close-range attacks: it rushes in for them, so they also come when you keep away.
	var reachable := dist < far_distance + 60.0
	w[Atk.SNAP] = 2.0 if reachable else 1.0
	w[Atk.SWEEP] = 2.5 if reachable else 1.0
	if ang > deg_to_rad(110.0) and dist < _sweep_radius() + 8.0:
		w[Atk.SWEEP] = 4.0
	w.erase(_last_major)  # never the same major attack twice in a row
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return w.keys()[0]


func _player_near_wall() -> bool:
	var p := _player_feet()
	var r := floor_rect.grow(-40.0)
	return not r.has_point(p)


func _start_major(atk: int) -> void:
	_last_major = atk
	_behind_time = 0.0
	match atk:
		Atk.AMBUSH: _ambush()
		Atk.SWEEP: _tail_sweep(true)
		Atk.CHARGE: _hungry_charge()
		Atk.SNAP: _rush_snap()


## Ends an action: back to stalking, next major attack after the phase's cooldown.
func _end_action() -> void:
	_busy = false
	_move = Vector2.ZERO
	var cd: Vector2 = cooldowns[mini(phase, cooldowns.size() - 1)]
	_attack_timer = randf_range(cd.x, cd.y)
	_play("idle")


# --- Jaw Snap --------------------------------------------------------------------------

func _jaw_snap() -> void:
	_busy = true
	_snap_cd = snap_cooldown
	velocity = Vector2.ZERO
	# Head pulls back.
	var tween := create_tween()
	tween.tween_property(sprite, "position", -_facing * 4.0, snap_windup)
	if not await _wait(snap_windup):
		return
	_play("snap")
	sprite.position = _facing * 6.0
	var to := _player_feet() - global_position
	if to.length() <= snap_reach and absf(_facing.angle_to(to)) <= deg_to_rad(snap_cone_deg + 10.0):
		_hurt_player(snap_damage, global_position, 160.0)
	if not await _wait(0.12):
		return
	sprite.position = Vector2.ZERO
	_play("idle")
	if not await _wait(snap_recovery):
		return
	_busy = false  # a snap doesn't reset the major attack timer
	_snap_cd = snap_cooldown


## Snap as a major attack: rushes up to you, then lunges and bites.
func _rush_snap() -> void:
	_busy = true
	if not await _rush_in(snap_range):
		return
	_snap_cd = snap_cooldown
	var tween := create_tween()
	tween.tween_property(sprite, "position", -_facing * 4.0, snap_windup * 0.8)
	if not await _wait(snap_windup * 0.8):
		return
	_play("snap")
	sprite.position = _facing * 6.0
	# Lunge: the last bit of distance (stops at you / walls).
	var to := _player_feet() - global_position
	move_and_collide(_facing * clampf(to.length() - 26.0, 0.0, snap_lunge))
	to = _player_feet() - global_position
	if to.length() <= snap_reach and absf(_facing.angle_to(to)) <= deg_to_rad(snap_cone_deg + 10.0):
		_hurt_player(snap_damage, global_position, 160.0)
	if not await _wait(0.12):
		return
	sprite.position = Vector2.ZERO
	_play("idle")
	if not await _wait(snap_recovery):
		return
	_end_action()


## Runs at you (facing you) until within `want` px or `rush_time` runs out.
## Returns false if the action was cut short (phase change / death).
func _rush_in(want: float) -> bool:
	var g := _gen
	var t := 0.0
	_play("walk")
	sprite.speed_scale = 2.0
	while t < rush_time:
		var to := _player_feet() - global_position
		if to.length() <= want:
			break
		_turn_towards(to, get_physics_process_delta_time(), 540.0)
		_move = to.normalized() * rush_speed
		await get_tree().physics_frame
		if not _alive(g):
			return false
		t += get_physics_process_delta_time()
	sprite.speed_scale = 1.0
	_move = Vector2.ZERO
	velocity = Vector2.ZERO
	return true


# --- Ambush ----------------------------------------------------------------------------

func _set_submerged(on: bool) -> void:
	_submerged = on
	hide_health_bar = on
	if on:
		_saved_layer = collision_layer
		_saved_mask = collision_mask
		collision_layer = 0
		collision_mask = 0
		hitbox.set_deferred("monitoring", false)
		overlapping_hurtboxes.clear()
	else:
		collision_layer = _saved_layer
		collision_mask = _saved_mask
		hitbox.set_deferred("monitoring", true)
	if shadow:
		shadow.visible = not on


func _ambush() -> void:
	_busy = true
	var g := _gen
	var count: int = ambush_counts[mini(phase, ambush_counts.size() - 1)]
	var track := ambush_track_time
	var warn := ambush_warn
	for i in count:
		# Dive.
		_play("dive")
		var dive := create_tween()
		dive.tween_interval(0.15)
		dive.tween_property(sprite, "modulate:a", 0.0, 0.15)
		if not await _wait(0.3):
			return
		_set_submerged(true)
		var ripple: Node2D = RIPPLE.new()
		ripple.target = player
		ripple.speed = ripple_speed
		ripple.turn_rate = deg_to_rad(ripple_turn_deg)
		ripple.bounds = floor_rect.grow(-14.0)
		ripple.warn_radius = ambush_radius
		# Sets off straight at you; the limited turning only matters once you move.
		var to_feet := _player_feet() - global_position
		ripple.dir = to_feet.normalized() if to_feet.length() > 1.0 else _facing
		ripple.visible = show_ambush_warning
		_ground().add_child(ripple)
		ripple.global_position = global_position
		if not await _wait(track):
			_free(ripple)
			return
		ripple.start_warning(warn)
		if not await _wait(warn):
			_free(ripple)
			return
		# Erupt + bite.
		global_position = ripple.global_position
		_facing = (_player_feet() - global_position).normalized() if _player_feet() != global_position else _facing
		_free(ripple)
		_set_submerged(false)
		sprite.modulate.a = 1.0
		_play("erupt")
		sprite.scale = _base_scale * 1.15
		create_tween().tween_property(sprite, "scale", _base_scale, 0.2)
		var hit := _player_feet().distance_to(global_position) <= ambush_radius + 4.0
		if hit:
			_hurt_player(ambush_damage, global_position, 220.0)
		track *= ambush_chain_speedup
		warn *= ambush_chain_speedup
		if i < count - 1:
			if not await _wait(0.35):
				return
			continue
		# Last one: pulls itself out. A miss leaves the head exposed.
		if not await _wait(0.25):
			return
		_play("surface")
		_exposed = not hit
		if not await _wait(ambush_hit_recovery if hit else ambush_miss_recovery):
			return
		_exposed = false
	if _alive(g):
		_end_action()


# --- Tail Sweep ------------------------------------------------------------------------

func _tail_sweep(rush: bool = false) -> void:
	_busy = true
	velocity = Vector2.ZERO
	if rush and _angle_to_player() < deg_to_rad(110.0):
		# You're not behind it: rush in, then whip its back round to you.
		if not await _rush_in(_sweep_radius() - 16.0):
			return
		var to := _player_feet() - global_position
		if to.length() > 1.0:
			_facing = -to.normalized()
	var half := deg_to_rad(sweep_arcs_deg[mini(phase, sweep_arcs_deg.size() - 1)]) / 2.0
	var radius := _sweep_radius()
	var tail_angle := (-_facing).angle()
	_play("tail_raise")
	var arc: Node2D = SWEEP_ARC.new()
	arc.radius = radius
	arc.center_angle = tail_angle
	arc.half_arc = half
	arc.duration = sweep_windup
	arc.shadow = not show_sweep_arc
	_ground().add_child(arc)
	arc.global_position = global_position
	var drips: Node2D = DRIPS.new()
	drips.tip = TAIL_TIPS.get(_dir_name(), Vector2(0, -40))
	drips.ground_y = maxf(drips.tip.y + 10.0, 4.0)
	drips.duration = sweep_windup
	add_child(drips)
	if not await _wait(sweep_windup):
		_free(arc)
		_free(drips)
		return
	_free(arc)
	# (the drips free themselves once the last drops have landed)
	# The tail travels from one end of the arc to the other (random side first).
	_play("tail_swing")
	var sweep_sign := 1.0 if randf() < 0.5 else -1.0
	var a0 := tail_angle - half * sweep_sign
	var total := 2.0 * half * sweep_sign
	var g := _gen
	var hit_player := false
	var t := 0.0
	while t < sweep_time:
		await get_tree().physics_frame
		if not _alive(g):
			return
		t += get_physics_process_delta_time()
		var cur := a0 + total * minf(t / sweep_time, 1.0)
		# Player.
		var to := _player_feet() - global_position
		if not hit_player and to.length() <= radius and _angle_between(to.angle(), a0, cur):
			hit_player = true
			_hurt_player(sweep_damage, global_position, sweep_knockback)
		# The player's shots get swatted away.
		for p in get_tree().get_nodes_in_group("projectiles"):
			if p is EnemyProjectile or not (p is Node2D) or not ("velocity" in p):
				continue
			var rel: Vector2 = (p as Node2D).global_position - global_position
			if rel.length() <= radius and _angle_between(rel.angle(), a0, cur):
				var speed: float = maxf((p.velocity as Vector2).length(), 120.0)
				p.velocity = rel.normalized() * speed
				if "ignored_target" in p:
					p.ignored_target = self
				var rot = p.get("sprite_rotator")
				if rot is Node2D:
					(rot as Node2D).rotation = rel.angle()
	_play("idle")
	if not await _wait(0.35):
		return
	_end_action()


## Is angle `a` inside the arc swept from `from` to `to` (either direction)?
static func _angle_between(a: float, from: float, to: float) -> bool:
	var span := to - from
	if span >= 0.0:
		return wrapf(a - from, 0.0, TAU) <= span
	return wrapf(from - a, 0.0, TAU) <= -span


# --- Hungry Charge ---------------------------------------------------------------------

func _hungry_charge() -> void:
	_busy = true
	velocity = Vector2.ZERO
	var windup: float = charge_windups[mini(phase, charge_windups.size() - 1)]
	_charge_dir = (_player_feet() - global_position).normalized()
	if _charge_dir == Vector2.ZERO:
		_charge_dir = _facing
	_facing = _charge_dir
	_play("charge_wind")
	# Lowers its body.
	sprite.scale = _base_scale * Vector2(0.92, 1.08)
	var lane: Node2D = LANE.new()
	lane.from = global_position
	lane.to = _lane_end(_charge_dir)
	lane.width = 30.0
	lane.duration = windup
	lane.visible = show_charge_lane
	_ground().add_child(lane)
	if not await _wait(windup):
		_free(lane)
		return
	_free(lane)
	sprite.scale = _base_scale
	_play("charge")
	_charge_speed = charge_speeds[mini(phase, charge_speeds.size() - 1)]
	_crashed = false
	_charge_hit = false
	_armored = true
	_charging = true
	# Ploughs through you (knocking you aside) instead of getting stuck on you; only
	# walls stop it.
	var mask_before := collision_mask
	collision_mask = 1 | 8
	var g := _gen
	var steer_time := global_position.distance_to(_lane_end(_charge_dir)) / _charge_speed / 3.0
	var t := 0.0
	while _charging:
		await get_tree().physics_frame
		if not _alive(g):
			return
		t += get_physics_process_delta_time()
		if t < steer_time:
			var to := (_player_feet() - global_position).normalized()
			var diff := wrapf(to.angle() - _charge_dir.angle(), -PI, PI)
			var step := deg_to_rad(charge_steer_deg) * get_physics_process_delta_time()
			_charge_dir = _charge_dir.rotated(clampf(diff, -step, step))
			_facing = _charge_dir
		if _crashed or t > charge_max_time:
			_charging = false
	collision_mask = mask_before
	_armored = false
	velocity = Vector2.ZERO
	if _crashed:
		# Head first into the wall: stunned, mouth open, takes extra damage.
		_shake_camera(4.0)
		_play("stun")
		_exposed = true
		if not await _wait(stun_time):
			return
		_exposed = false
		# Backs off a little before choosing again.
		_play("walk")
		_move = (global_position - _player_feet()).normalized() * stalk_speed
		if not await _wait(retreat_time):
			return
		_move = Vector2.ZERO
	else:
		_play("idle")
		if not await _wait(0.4):
			return
	_end_action()


func _charge_step(_delta: float) -> void:
	velocity = _charge_dir * _charge_speed
	move_and_slide()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_collider() is StaticBody2D and hit.get_normal().dot(_charge_dir) < -0.25:
			_crashed = true
	if not _charge_hit and _player_feet().distance_to(global_position + _charge_dir * 14.0) < 22.0:
		_charge_hit = true
		_hurt_player(charge_damage, global_position, 260.0)


## Where a charge along `dir` would hit a wall (for the warning lane).
func _lane_end(dir: Vector2) -> Vector2:
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * 900.0, 1 | 8, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else from + dir * 300.0


func _shake_camera(strength: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tween := cam.create_tween()
	for i in 6:
		tween.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 6.0), 0.04)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.04)


# --- Damage / phases -------------------------------------------------------------------

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0) -> void:
	if _submerged:
		return
	var mult := 1.0
	if _exposed:
		mult = exposed_damage_mult
	elif _armored:
		mult = armored_damage_mult
	super.take_damage(amount * mult, knockback_dir, knockback_strength)


## Stops whatever it was doing (phase change / death): resurfaces, clears warnings.
func _reset_actions() -> void:
	_gen += 1
	_charging = false
	_armored = false
	_exposed = false
	_move = Vector2.ZERO
	if _submerged:
		_set_submerged(false)
	collision_mask = _default_mask  # a charge cut short leaves it walls-only
	sprite.modulate.a = 1.0
	sprite.scale = _base_scale
	sprite.position = Vector2.ZERO
	sprite.speed_scale = 1.0
	for n in get_tree().get_nodes_in_group("room_effects"):
		if n.get_script() in [RIPPLE, SWEEP_ARC, LANE, DRIPS]:
			n.queue_free()


func _on_phase_shield() -> void:
	_reset_actions()
	_busy = false
	_last_major = Atk.NONE
	if phase == Phase.STALKING:
		phase = Phase.FRENZY
		_phase_shield_done = false
		phase_shield_at = cornered_at
	elif phase == Phase.FRENZY:
		phase = Phase.CORNERED
	_attack_timer = 1.0


func die() -> void:
	_reset_actions()
	# Sinks into the sewage: EnemyBase plays "death_<facing_direction>".
	facing_direction = _dir_name()
	sprite.self_modulate = Color.WHITE
	_play("death")
	var fade := create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.3)
	super.die()
