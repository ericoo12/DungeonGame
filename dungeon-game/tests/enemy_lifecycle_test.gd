extends Node

# Run after importing the project: godot --headless --path . res://tests/EnemyLifecycleTest.tscn
const FLY := "res://scenes/enemies/regular_enemies/easy/Fly.tscn"
const SMILEY := "res://scenes/enemies/regular_enemies/easy/smiley.tscn"
const BRUSH := "res://scenes/enemies/bosses/ToiletBrush.tscn"
var failures: int = 0
var checks: int = 0
var sequence: int = 0
var target: Node2D
@onready var root: Window = get_tree().root

class DamageTarget extends Node2D:
	var hits: int = 0
	func take_damage(_amount: float, _dir: Vector2 = Vector2.ZERO, _strength: float = 0.0) -> void:
		hits += 1

func _ready() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func spawn_enemy(path: String, chase: bool = false) -> EnemyBase:
	var enemy: EnemyBase = load(path).instantiate()
	if chase:
		enemy.movement_behavior = ChaseMovement.new()
	enemy.spawn_grace_period = 0.0
	enemy.max_health = 1000.0
	sequence += 1
	enemy.position = Vector2(sequence * 1000, 0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player = target
	return enemy

func shots() -> int:
	var count := 0
	for child in root.get_children():
		if child is EnemyProjectile:
			count += 1
	return count

func run_checks() -> void:
	target = Node2D.new()
	root.add_child(target)
	target.position = Vector2(0, 10000)
	var fly := spawn_enemy(FLY)
	fly.knockback_velocity = Vector2(120, 0)
	fly._physics_process(0.05)
	check(fly.velocity == Vector2(120, 0), "AI must not overwrite knockback")
	check(fly.knockback_velocity.x < 120, "Knockback decays")
	fly.knockback_velocity = Vector2.ZERO
	fly.take_damage(1)
	check(fly.action_state == "damage", "Damage starts bounded hurt action")
	fly._physics_process(0.05)
	check(fly.velocity == Vector2.ZERO, "Hurt suppresses chase")
	fly._physics_process(0.2)
	check(fly.action_state == "" and fly.velocity.length() > 0, "Static enemy recovers and chases")
	check(not fly.sprite.sprite_frames.get_animation_loop("damage_down"), "Static hurt animation does not loop")
	fly.sprite.stop()
	fly._play_run_animation()
	check(fly.sprite.is_playing(), "Same-direction run animation resumes")

	var shooter := spawn_enemy(SMILEY, true)
	var other := spawn_enemy(SMILEY)
	check(shooter.attack_behavior != other.attack_behavior, "Attack resource is per enemy")
	var third := spawn_enemy(SMILEY)
	check(other.movement_behavior != third.movement_behavior, "Movement resource is per enemy")
	shooter.attack_behavior.timer = 0.8
	check(other.attack_behavior.timer == 0.0, "Enemy cooldowns are independent")
	shooter._physics_process(0.1)
	check(shooter.velocity.length() > 0, "Movement runs when attack is on cooldown/out of range")
	shooter.take_damage(1)
	var cooldown_before: float = shooter.attack_behavior.timer
	shooter._physics_process(0.05)
	check(shooter.attack_behavior.timer < cooldown_before, "Cooldown ticks during hurt")
	shooter._physics_process(0.2)
	target.global_position = shooter.global_position + Vector2(50, 0)
	shooter.attack_behavior.timer = 0
	var before := shots()
	shooter._physics_process(0.01)
	check(shots() == before + 1 and shooter.action_state == "attack", "Ranged enemy starts an attack and fires once")
	check(shooter.velocity == Vector2.ZERO, "Attack owns movement; chase does not run afterward")
	shooter._physics_process(0.05)
	check(shots() == before + 1, "Attack does not fire repeatedly")
	var old_handle := shooter.begin_action("attack", "attack_down", 0.5)
	shooter.take_damage(1)
	shooter.finish_action(old_handle)
	check(shooter.action_state == "damage", "Stale completion cannot end hurt")
	var new_handle := shooter.begin_action("attack", "attack_down", 0.5)
	shooter.finish_action(old_handle)
	check(shooter.is_action_current(new_handle), "Stale completion cannot end a replacement attack")
	shooter.cancel_action()
	check(shooter.action_state == "" and not shooter.is_action_current(new_handle), "Explicit cancellation invalidates handle")

	var brush: ToiletBrushEnemy = spawn_enemy(BRUSH)
	target.global_position = brush.global_position + Vector2(50, 0)
	brush.projectile_launch_delay = 0.4
	before = shots()
	brush._do_shoot_attack(Vector2.RIGHT)
	brush._physics_process(0.1)
	brush.take_damage(1)
	check(not brush._shot_pending, "Hurt clears pending shot immediately")
	brush._physics_process(0.21)
	check(shots() == before, "Cancelled spit never fires")
	brush._do_shoot_attack(Vector2.LEFT)
	brush._physics_process(0.2)
	check(shots() == before and brush.action_state == "attack", "New spit uses its own launch delay")
	brush._physics_process(0.21)
	check(shots() == before + 1, "Replacement spit fires exactly once")
	brush._physics_process(0.1)
	check(shots() == before + 1, "Completed spit does not fire again")
	brush.cancel_action()
	brush._do_lunge_attack()
	check(brush.is_lunging and brush.velocity.length() > 0, "Lunge starts movement")
	brush.take_damage(1, Vector2.LEFT, 100)
	check(not brush.is_lunging and brush.lunge_direction == Vector2.ZERO, "Hurt cancels lunge immediately")
	brush._physics_process(0.05)
	check(brush.velocity.x < 0, "Knockback wins over interrupted lunge")
	brush._physics_process(0.3)
	check(not brush.is_lunging, "Lunge does not resume after hurt")
	brush.cancel_action()
	brush._do_lunge_attack()
	brush.cancel_action()
	check(not brush.is_lunging and brush.velocity == Vector2.ZERO, "Explicit cancellation stops lunge")
	brush.projectile_launch_delay = 0.8
	before = shots()
	brush._do_shoot_attack(Vector2.RIGHT)
	brush._physics_process(0.4)
	check(brush.action_state == "attack" and shots() == before, "Late launch outlives short animation")
	brush._physics_process(0.41)
	check(shots() == before + 1 and brush.action_state == "", "Late event resolves without waiting forever")

	var victim := DamageTarget.new()
	var hurtbox := Area2D.new()
	victim.add_child(hurtbox)
	root.add_child(victim)
	brush.spawn_timer = 0.1
	brush._on_hitbox_area_entered(hurtbox)
	check(victim.hits == 0 and brush.overlapping_hurtboxes.has(hurtbox), "Grace tracks overlap without damage")
	brush._physics_process(0.11)
	brush._physics_process(0.01)
	check(victim.hits == 1, "Contact begins after grace without re-entry")
	brush._physics_process(0.61)
	check(victim.hits == 2, "Brush inherits repeated contact damage")
	brush._on_hitbox_area_exited(hurtbox)
	brush._physics_process(0.7)
	check(victim.hits == 2, "Contact stops on exit")

	var dying: ToiletBrushEnemy = spawn_enemy(BRUSH)
	before = shots()
	dying._do_shoot_attack(Vector2.RIGHT)
	var deaths := {"count": 0}
	var on_death := func(): deaths.count += 1
	root.get_node("EventBus").boss_defeated.connect(on_death)
	dying.take_damage(2000)
	check(dying.is_dying and not dying._shot_pending, "Death cancels pending shot")
	dying.die()
	dying.cancel_action()
	check(dying.action_state == "death", "Death cannot be cancelled or restarted")
	dying._physics_process(0.5)
	check(deaths.count == 1 and dying.is_queued_for_deletion(), "Repeated death calls emit once")
	check(shots() == before and dying.velocity == Vector2.ZERO, "Death does not attack or move")
	check(dying.begin_action("attack", "attack_down") == -1, "Dead enemy rejects new actions")
	root.get_node("EventBus").boss_defeated.disconnect(on_death)

	var removed: ToiletBrushEnemy = spawn_enemy(BRUSH)
	removed._do_shoot_attack(Vector2.RIGHT)
	root.remove_child(removed)
	check(not removed._shot_pending and removed.action_state == "", "Removing enemy cancels action")
	removed.free()

	# Real engine frames: tree pause must suspend windup instead of spawning a shot.
	var paused_brush: ToiletBrushEnemy = spawn_enemy(BRUSH)
	paused_brush.projectile_launch_delay = 0.15
	paused_brush._do_shoot_attack(Vector2.RIGHT)
	paused_brush.set_physics_process(true)
	before = shots()
	get_tree().paused = true
	await get_tree().create_timer(0.25, true).timeout
	check(paused_brush.action_elapsed == 0.0 and shots() == before, "Pause freezes attack windup")
	get_tree().paused = false
	for i in range(14):
		await get_tree().physics_frame
	check(not paused_brush._shot_pending and shots() == before + 1, "Windup resumes and fires once after unpause")
	paused_brush.set_physics_process(false)
	print("ENEMY LIFECYCLE: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
