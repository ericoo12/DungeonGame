# SpawnMinionsAttack.gd — periodically spawns minions (e.g. a trash bin spitting out
# flies). Plays the attack animation and releases the minions on its "open" frame.
# Minions are added through the room (RoomController.spawn_enemy), so the room stays
# locked until they're dead too. Per-enemy state: EnemyBase duplicates this resource.
class_name SpawnMinionsAttack
extends AttackBehavior

@export var minion_scene: PackedScene
@export var spawn_count: Vector2i = Vector2i(1, 2)    # per spawn (min, max)
@export var max_alive: int = 4                        # stop while this many of OUR minions live
@export var cooldown: float = 4.0
@export var first_spawn_delay: Vector2 = Vector2(1.0, 2.0)  # after the player comes in range
@export var activation_range: float = 200.0           # px; most of a room
## Seconds into the attack animation when the minions pop out (lid fully open).
@export var release_delay: float = 0.3
## Where minions appear relative to the spawner (above it = out of the lid), plus jitter.
@export var spawn_offset: Vector2 = Vector2(0, -10)
@export var spawn_jitter: float = 6.0

var timer: float = 0.0
var _armed: bool = false
var _minions: Array = []   # weakrefs


func try_attack(enemy: EnemyBase, delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		return
	if enemy.player == null or minion_scene == null:
		return
	if enemy.global_position.distance_to(enemy.get_player_aim_point()) > activation_range:
		return
	if not _armed:
		_armed = true
		timer = randf_range(first_spawn_delay.x, first_spawn_delay.y)
		return
	if _alive_count() >= max_alive:
		return
	timer = cooldown
	_spawn(enemy)


func _spawn(enemy: EnemyBase) -> void:
	var anim := "attack_" + enemy.facing_direction
	var animated := enemy.sprite.sprite_frames.has_animation(anim)
	if animated:
		enemy.action_state = "attack"
		enemy.sprite.play(anim)
		await enemy.get_tree().create_timer(release_delay, false).timeout
		if not is_instance_valid(enemy) or enemy.is_dying:
			return

	var room := _current_room(enemy)
	var count := mini(randi_range(spawn_count.x, spawn_count.y), max_alive - _alive_count())
	for i in count:
		var pos := enemy.global_position + spawn_offset \
			+ Vector2(randf_range(-spawn_jitter, spawn_jitter), randf_range(-spawn_jitter, spawn_jitter))
		var minion: Node = room.spawn_enemy(minion_scene, pos) if room else null
		if minion:
			_minions.append(weakref(minion))

	if animated:
		if enemy.sprite.animation == anim and enemy.sprite.is_playing():
			await enemy.sprite.animation_finished
		if is_instance_valid(enemy) and enemy.action_state == "attack":
			enemy.action_state = ""


func _alive_count() -> int:
	var alive := 0
	for ref in _minions:
		var m = ref.get_ref()
		if m and is_instance_valid(m) and not m.is_queued_for_deletion():
			alive += 1
	_minions = _minions.filter(func(r): return r.get_ref() != null)
	return alive


static func _current_room(enemy: EnemyBase) -> RoomController:
	var dungeon := enemy.get_tree().get_first_node_in_group("dungeon") as Dungeon
	if dungeon == null:
		return null
	return dungeon.current_room as RoomController
