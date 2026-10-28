# SewerBeamAttack.gd — the wizard: every few seconds he stops, raises his staff and
# calls columns of sewer water down on random spots of the floor (SewerBeam.gd), plus
# one aimed at where the player stands. Each spot shows a warning puddle first.
# Cast sheet frames: 0 = grip staff, 1 = raise, 2 = cast (beams spawn), 3 = lower.
# Per-enemy state lives here; EnemyBase duplicates the resource for every enemy.
class_name SewerBeamAttack
extends AttackBehavior

const BEAM_SCENE := preload("res://enemies/projectiles/SewerBeam.tscn")

@export var cooldown_min: float = 3.5
@export var cooldown_max: float = 5.0
## First cast waits at least this long after the wizard appears.
@export var first_delay: float = 2.0
## Random spots per cast, anywhere on the floor.
@export var random_beams: int = 4
## Extra beams aimed at the player's position when he casts (0 = only random ones).
@export var aimed_beams: int = 1
## Random spots keep at least this far apart (px), so they spread over the room.
@export var min_spacing: float = 40.0
## Beams appear one after another, this many seconds apart.
@export var stagger: float = 0.12

@export_group("Cast animation")
@export var windup: float = 0.5        # frames 0-1: the visual tell
@export var cast_hold: float = 0.4     # frame 2, beams spawn at the start
@export var recover: float = 0.35      # frame 3

var timer: float = 0.0
var _started: bool = false


func try_attack(enemy: EnemyBase, delta: float) -> void:
	if not _started:
		_started = true
		timer = first_delay
	if timer > 0.0:
		timer -= delta
		return
	if enemy.player == null:
		return
	timer = INF  # paused until the cast finishes
	_cast(enemy)


func _cast(enemy: EnemyBase) -> void:
	enemy.action_state = "attack"
	enemy.super_armor = true  # hits don't cancel the cast
	enemy.forced_velocity_active = true
	enemy.forced_velocity = Vector2.ZERO
	enemy._update_facing_direction(enemy.get_player_aim_point() - enemy.global_position)
	var anim := "attack_" + enemy.facing_direction

	LungeAttack._show_frame(enemy, anim, 0)
	if await _wait(enemy, windup * 0.5):
		LungeAttack._show_frame(enemy, anim, 1)
		if await _wait(enemy, windup * 0.5):
			LungeAttack._show_frame(enemy, anim, 2)
			_spawn_beams(enemy)
			if await _wait(enemy, cast_hold):
				LungeAttack._show_frame(enemy, anim, 3)
				await _wait(enemy, recover)
	_finish(enemy)


func _spawn_beams(enemy: EnemyBase) -> void:
	var spots: Array[Vector2] = []
	var feet := enemy.get_player_aim_point()
	var p := enemy.player as Player
	if p and p.body_collision:
		feet = p.body_collision.global_position  # beams hit the floor where you stand
	for i in aimed_beams:
		spots.append(feet if i == 0 else feet + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(16.0, 32.0))
	var area := _floor_area(enemy)
	for i in random_beams:
		var best := Vector2.ZERO
		for attempt in 12:  # spread them out
			best = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			var ok := true
			for s in spots:
				if s.distance_to(best) < min_spacing:
					ok = false
					break
			if ok:
				break
		spots.append(best)
	spots.shuffle()

	var parent := _beam_parent(enemy)
	for i in spots.size():
		var beam: SewerBeam = BEAM_SCENE.instantiate()
		parent.add_child(beam)
		beam.global_position = spots[i]
		beam.warn_time += i * stagger  # they land one after another


## The room's floor (RoomBase.get_floor_rect), shrunk a little; outside a dungeon room
## (test rooms) a square around the player.
func _floor_area(enemy: EnemyBase) -> Rect2:
	var dungeon := enemy.get_tree().get_first_node_in_group("dungeon") as Dungeon
	if dungeon and dungeon.current_room and dungeon.current_room.has_method("get_floor_rect"):
		var r: Rect2 = dungeon.current_room.get_floor_rect()
		if r.has_area():
			return r.grow(-12.0)
	var c := enemy.get_player_aim_point()
	return Rect2(c - Vector2(140, 80), Vector2(280, 160))


## Floor-decal layer (under characters) if the room has one, else the enemy's parent.
static func _beam_parent(enemy: EnemyBase) -> Node:
	var ground := enemy.get_tree().get_first_node_in_group("ground_effects")
	return ground if ground else enemy.get_parent()


func _wait(enemy: EnemyBase, seconds: float) -> bool:
	await enemy.get_tree().create_timer(seconds, false).timeout
	if not is_instance_valid(enemy) or enemy.is_dying:
		return false
	return enemy.action_state == "attack"


func _finish(enemy: EnemyBase) -> void:
	timer = randf_range(cooldown_min, cooldown_max)
	if not is_instance_valid(enemy):
		return
	enemy.forced_velocity_active = false
	enemy.forced_velocity = Vector2.ZERO
	enemy.super_armor = false
	if enemy.action_state == "attack":
		enemy.action_state = ""
