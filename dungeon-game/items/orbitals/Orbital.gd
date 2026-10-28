extends Area2D
class_name Orbital

const BUBBLE_SHOT := preload("res://items/orbitals/BubbleShot.gd")
const PAPER_STREAMER := preload("res://items/orbitals/PaperStreamer.gd")

@export var radius: float = 40.0
@export var damage: float = 0.0  # 0 = pure blocker, deals no contact damage
@export var damage_interval: float = 0.3
## Orbit speed compared to the shared orbital speed (0.5 = half as fast). Orbitals with
## different speeds drift relative to each other.
@export var speed_scale: float = 1.0
## Urinal Cake: poisons enemies it touches (damage per second, seconds). 0 = off.
@export var poison_dps: float = 0.0
@export var poison_duration: float = 3.0

@export_group("Projectile blocking")
## Destroys enemy projectiles it touches (needs collision_mask to include 64,
## the enemy_projectile layer).
@export var blocks_projectiles: bool = false
## Soap Bubble: pops after blocking one projectile and comes back after respawn_time.
@export var pops_on_block: bool = false
@export var respawn_time: float = 4.0
## When it pops, it flings this many little bubbles out in a ring (BubbleShot) that
## hurt the enemies they hit. 0 = just pops.
@export var pop_ring_count: int = 0
@export var pop_ring_damage: float = 1.5
@export var pop_ring_speed: float = 95.0
@export var pop_ring_range: float = 75.0
@export_group("")
## Toilet Roll: unrolls a paper streamer behind it that slows enemies (PaperStreamer).
@export var paper_trail: bool = false

var _popped: bool = false

# Set by Player.add_orbital()/_recalculate_orbital_spacing() — this orbital's
# fixed angular position relative to its siblings, so multiple orbitals stay
# evenly spaced. Actual rotation speed lives on Player (shared clock), so all
# orbitals rotate in lockstep regardless of when each was picked up.
var angle_offset: float = 0.0
var player_ref: Player

var overlapping_bodies: Array[Node] = []
var tick_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if blocks_projectiles:
		area_entered.connect(_on_area_entered)
	player_ref = get_parent()
	if paper_trail:
		_make_streamer.call_deferred()


var _streamer: Node2D


func _make_streamer() -> void:
	var ground := get_tree().get_first_node_in_group("ground_effects")
	_streamer = PAPER_STREAMER.new()
	_streamer.source = self
	(ground if ground else player_ref.get_parent()).add_child(_streamer)


func _physics_process(delta: float) -> void:
	var angle := player_ref.orbital_rotation * speed_scale + angle_offset
	position = Vector2(cos(angle), sin(angle)) * radius

	if overlapping_bodies.size() > 0 and (damage > 0.0 or poison_dps > 0.0):
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = damage_interval
			_deal_damage_to_all()


func _on_area_entered(area: Area2D) -> void:
	if _popped or not _is_enemy_shot(area):
		return
	if area.has_method("_land"):
		area.call("_land")
	else:
		area.queue_free()
	if pops_on_block:
		_pop()


## Enemy projectiles only (the player's own shots are Projectile). Checked by type too,
## because a shot only joins the "projectiles" group one frame after it spawns.
static func _is_enemy_shot(area: Area2D) -> bool:
	if area is Projectile:
		return false
	return area is EnemyProjectile or area is FinalBossProjectile or area.is_in_group("projectiles")


func _pop() -> void:
	_popped = true
	if pop_ring_count > 0:
		_fire_pop_ring.call_deferred(global_position)
	visible = false
	set_deferred("monitoring", false)
	overlapping_bodies.clear()
	await get_tree().create_timer(respawn_time, false).timeout
	if not is_instance_valid(self):
		return
	_popped = false
	visible = true
	monitoring = true


## Ring of little bubbles from where it popped (deferred: popping happens inside a
## physics callback, where new areas can't be added).
func _fire_pop_ring(at: Vector2) -> void:
	var world := player_ref.get_parent() if is_instance_valid(player_ref) else null
	if world == null:
		return
	var twist := randf() * TAU
	for i in pop_ring_count:
		var b: Area2D = BUBBLE_SHOT.new()
		var dir := Vector2.RIGHT.rotated(twist + TAU * i / pop_ring_count)
		b.velocity = dir * pop_ring_speed
		b.damage = pop_ring_damage
		b.max_range = pop_ring_range
		world.add_child(b)
		b.global_position = at + dir * 4.0


func _on_body_entered(body: Node) -> void:
	if _popped:
		return
	overlapping_bodies.append(body)
	if (damage > 0.0 or poison_dps > 0.0) and body.has_method("take_damage"):
		tick_timer = damage_interval
		_hit(body)


func _on_body_exited(body: Node) -> void:
	overlapping_bodies.erase(body)


func _deal_damage_to_all() -> void:
	for body in overlapping_bodies:
		if is_instance_valid(body) and body.has_method("take_damage"):
			_hit(body)


func _hit(body: Node) -> void:
	if damage > 0.0:
		body.take_damage(damage)
	if poison_dps > 0.0 and is_instance_valid(body):
		PoisonStatus.apply(body, poison_dps, poison_duration)
