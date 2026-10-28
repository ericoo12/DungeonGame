extends MuggSettings
class_name DoktorMugg

## COORDINATE: FinalBossBase calls these hooks. Observe, decide when allowed, execute.
## Settings live in MuggSettings. Tactical choices live in MuggTactics.
## The short forwarding methods below keep the public boss API in one place.

@onready var state_machine: MuggStateMachine = $StateMachine
@onready var behavior_tree: MuggBehaviorTree = $BehaviorTree
@onready var navigator: ArenaNavigator = $Navigation
var blackboard := MuggBlackboard.new()
var arena: FinalBossArena
var _rng := RandomNumberGenerator.new()
var _decision_timer: float = 0.0
var _shot_cooldown: float = 0.0
var _reposition_timer: float = 0.0
var _shot_pending: bool = false
var _locked_aim: Vector2 = Vector2.DOWN
var _locked_target: Vector2
var _last_position: Vector2
var _stuck_time: float = 0.0
var _movement_retry: float = 0.0
var _dodge_timer: float = 0.0
var _offense_timer: float = 0.0
var _dodge_direction := Vector2.ZERO
var _dodge_moved_time: float = 0.0
# IDs are retained only while their projectile exists: one probability roll per threat.
var _considered_projectiles: Dictionary = {}
var _cover_timer: float = 0.0
var _recent_damage: float = 0.0
var _area_timer: float = 0.0
var _area_choice_timer: float = 0.0
var _blocked_duration: float = 0.0
var _pending_area: MuggAreaAttack
var _active_windup: float = 0.55
var _active_recovery: float = 0.65
var _homing_timer: float = 0.0
var _kite_side: float = 1.0
var _kite_side_timer: float = 0.0
var _kite_steer_timer: float = 0.0
var _kite_direction := Vector2.ZERO
var _observed_player_velocity := Vector2.ZERO
var _observed_player_health_ratio: float = 1.0

# Small helpers share this boss instance; none runs an independent physics loop.
var perception = MuggPerception.new(self)
var health_rules = MuggHealth.new(self)
var movement = MuggMovement.new(self)
var combat = MuggCombat.new(self)
var tactics = MuggTactics.new(self)

## New animation pack (assets/sprites/enemies/doktor_mugg/clean/: 4 rows = down, left,
## right, up; 88 px cells with the 64 px frame centred). The "clean" sheets are the
## artist's sheets re-cut so no frame shows pieces of its neighbours.
const ART_DIR := "res://assets/sprites/enemies/doktor_mugg/clean/"
const PACK := {
	# name: [file, frames, fps, loop]
	"idle": ["doktor_mugg_idle.png", 4, 6.0, true],
	"run": ["doktor_mugg_run.png", 4, 10.0, true],
	"throw": ["doktor_mugg_throw.png", 4, 10.0, false],
	"running_throw": ["doktor_mugg_running_throw.png", 4, 10.0, false],
	"cluster_throw": ["doktor_mugg_cluster_throw.png", 4, 10.0, false],
	"lob": ["doktor_mugg_lob.png", 4, 10.0, false],
	"dodge": ["doktor_mugg_dodge.png", 4, 12.0, false],
	"cover": ["doktor_mugg_cover.png", 4, 10.0, false],
	"damage": ["doktor_mugg_hurt.png", 4, 12.0, false],
	"death": ["doktor_mugg_death.png", 6, 8.0, false],
}
const ART_CELL := 88
const ATTACK_ANIM := {"basic_shot": "throw", "running_shot": "running_throw",
	"cluster_shot": "cluster_throw", "homing_shot": "lob"}


func _setup_animations() -> void:
	if ResourceLoader.exists(ART_DIR + "doktor_mugg_idle.png"):
		sprite.sprite_frames = _build_pack_frames()
	else:
		super._setup_animations()
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	behavior_tree.configure(self)
	state_machine.state_changed.connect(func(_previous, _current): queue_redraw())
	label.visible = debug_ai

func _build_pack_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var dirs := ["down", "left", "right", "up"]
	for anim in PACK:
		var info: Array = PACK[anim]
		var tex := load(ART_DIR + info[0]) as Texture2D
		if tex == null:
			continue
		for row in dirs.size():
			var anim_name: String = anim + "_" + dirs[row]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, info[2])
			frames.set_animation_loop(anim_name, info[3])
			for i in int(info[1]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * ART_CELL, row * ART_CELL, ART_CELL, ART_CELL)
				frames.add_frame(anim_name, at)
			if anim == "throw":  # contact "attack" pose = the throw
				frames.add_animation("attack_" + dirs[row])
				frames.set_animation_speed("attack_" + dirs[row], info[2])
				frames.set_animation_loop("attack_" + dirs[row], false)
				for i in int(info[1]):
					frames.add_frame("attack_" + dirs[row], frames.get_frame_texture(anim_name, i))
	return frames


## Holds `anim` (facing the current direction) on `frame`.
func _show_frame(anim: String, frame: int) -> void:
	var anim_name := anim + "_" + facing_direction
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	sprite.pause()
	sprite.frame = clampi(frame, 0, sprite.sprite_frames.get_frame_count(anim_name) - 1)


## Picks the frame for the committed action from how far into it we are, so the art
## follows the gameplay timing: throws wind up on 0-1, release on 2 (the shot leaves
## exactly when the attack fires), follow through on 3.
func _update_action_visual() -> void:
	var e := action_elapsed
	match action_state:
		"basic_shot", "cluster_shot", "homing_shot", "running_shot":
			var w := _active_windup
			var f := 0 if e < w * 0.5 else (1 if e < w else (2 if e < w + fire_duration + _active_recovery * 0.5 else 3))
			_show_frame(ATTACK_ANIM[action_state], f)
		"dodge":
			_show_frame("dodge", 3 if e >= dodge_duration else mini(2, int(e / maxf(dodge_duration, 0.01) * 3.0)))
		"area_attack":
			if blackboard.has_last_seen and e < 0.05:
				_update_facing_direction(global_position.direction_to(blackboard.last_seen_position))
			var k := e / maxf(area_warning, 0.01)
			_show_frame("lob", 0 if k < 0.25 else (1 if k < 0.55 else (2 if k < 0.85 else 3)))
		"cover_hold":
			if blackboard.has_last_seen and e < 0.05:
				_update_facing_direction(global_position.direction_to(blackboard.last_seen_position))
			_show_frame("cover", mini(2, int(e * 10.0)))


func set_arena(room: FinalBossArena) -> void:
	arena = room
	blackboard.forget()
	_observed_player_health_ratio = 1.0
	navigator.configure(self, room, navigation_radius)
	_last_position = global_position
	_decision_timer = 0.0

func _update_cooldowns(delta: float) -> void:
	super._update_cooldowns(delta)
	state_machine.advance(delta)
	_kite_side_timer -= delta
	_kite_steer_timer -= delta
	_homing_timer = maxf(0.0, _homing_timer - delta)
	_cover_timer = maxf(0, _cover_timer - delta)
	_recent_damage = maxf(0, _recent_damage - delta)
	_area_timer = maxf(0, _area_timer - delta)
	_area_choice_timer = maxf(0, _area_choice_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_offense_timer = maxf(0.0, _offense_timer - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_reposition_timer = maxf(0.0, _reposition_timer - delta)
	_movement_retry = maxf(0.0, _movement_retry - delta)
	_decision_timer -= delta
	if not is_instance_valid(arena):
		blackboard.forget()
		return
	navigator.update(delta)
	_update_perception(delta)
	_blocked_duration = _blocked_duration + delta if blackboard.has_last_seen and not blackboard.shot_clear else 0.0
	queue_redraw()
	if debug_ai:
		label.text = "%s | %.0f HP" % [state_machine.state_name(), health]

func _update_perception(delta: float) -> void:
	perception._update_perception(delta)

func has_clear_shot(from: Vector2, to: Vector2) -> bool:
	return perception.has_clear_shot(from, to)

func _update_behavior(delta: float) -> void:
	if not is_instance_valid(arena) or not navigator.ready_for_paths:
		return
	if _try_hold_cover():
		return
	if _decision_timer <= 0.0:
		_decision_timer = decision_interval
		behavior_tree.tick()
	movement.update_free_movement(delta)

func movement_is_committed() -> bool:
	return movement.movement_is_committed()

func can_basic_shot() -> bool:
	return combat.can_basic_shot()

func ai_idle() -> DecisionNode.Status:
	return movement.ai_idle()

func ai_reposition(reason: String) -> DecisionNode.Status:
	return movement.ai_reposition(reason)

func ai_pressure() -> DecisionNode.Status:
	return movement.ai_pressure()

func _choose_position(retreat: bool) -> PackedVector2Array:
	return movement._choose_position(retreat)

func ai_basic_shot(kind: String = "basic_shot") -> DecisionNode.Status:
	return combat.start_projectile_attack(kind)

func _update_action(_delta: float) -> void:
	combat.advance_action(_delta)
	_update_action_visual()

func _on_action_ended(_action: String, _cancelled: bool) -> void:
	combat.cleanup_action(_action, _cancelled)

func stun(duration: float = 0.3) -> void:
	combat.stun(duration)

func _play_damage_animation() -> void:
	combat._play_damage_animation()

func _play_attack_animation() -> void:
	# Contact damage is passive; only the tree starts committed boss attacks.
	pass

func _draw() -> void:
	if not is_instance_valid(state_machine):
		return
	if state_machine.state == MuggStateMachine.State.DODGE:
		draw_line(Vector2.ZERO, -_dodge_direction * 35.0, Color(0.3, 0.9, 1.0), 4.0)
	elif state_machine.state == MuggStateMachine.State.WINDUP:
		var progress := clampf(action_elapsed / maxf(_active_windup, 0.1), 0.0, 1.0)
		var warning_color := homing_color if action_state == "homing_shot" else (Color(0.15, 0.9, 1.0) if action_state == "running_shot" else Color(1, 0.7, 0.1))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU * progress, 32, warning_color, 3.0)
		draw_line(_locked_aim * 22.0, _locked_aim * 65.0, warning_color, 3.0)
	elif state_machine.state == MuggStateMachine.State.RECOVERY:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 32, Color(0.5, 0.8, 1, 0.6), 1.0)
	if debug_ai and is_instance_valid(navigator):
		var previous := Vector2.ZERO
		for point in navigator.path:
			var local := to_local(point)
			draw_line(previous, local, Color(0.9, 0.9, 0.3, 0.6), 1.0)
			previous = local

func _varied_cooldown(base: float) -> float:
	return maxf(0.0, base * _rng.randf_range(1.0 - cooldown_variation, 1.0 + cooldown_variation))

func ai_choose_offense() -> DecisionNode.Status:
	return tactics.choose(MuggTactics.Situation.COMBAT)

func homing_selection_weight() -> float:
	return tactics.homing_selection_weight()

func _fire_selected_shot() -> void:
	combat.release_projectiles()

func _incoming_threat(include_considered: bool = false) -> Projectile:
	return perception._incoming_threat(include_considered)

func ai_dodge(allow_retreat: bool = false) -> DecisionNode.Status:
	return combat.start_dodge(allow_retreat)

func _update_dodge(delta: float) -> void:
	combat._update_dodge(delta)

func ai_take_cover() -> DecisionNode.Status:
	return movement.ai_take_cover()

func ai_area_attack() -> DecisionNode.Status:
	return combat.start_area_attack()

func _try_hold_cover() -> bool:
	return movement._try_hold_cover()

func _start_kiting() -> DecisionNode.Status:
	return movement._start_kiting()

func _kite_velocity(delta: float) -> Vector2:
	return movement._kite_velocity(delta)

func health_defense() -> float:
	return health_rules.health_defense()

func health_aggression() -> float:
	return health_rules.health_aggression()

func effective_preferred_distance() -> float:
	return health_rules.effective_preferred_distance()

func effective_attack_cooldown_scale() -> float:
	return health_rules.effective_attack_cooldown_scale()

func effective_defense_cooldown_scale() -> float:
	return health_rules.effective_defense_cooldown_scale()

func effective_dodge_chance() -> float:
	return health_rules.effective_dodge_chance()
