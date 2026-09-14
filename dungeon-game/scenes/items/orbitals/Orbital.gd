extends Area2D
class_name Orbital

@export var radius: float = 40.0
@export var damage: float = 0.0  # 0 = pure blocker, deals no contact damage
@export var damage_interval: float = 0.3

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
	player_ref = get_parent()


func _physics_process(delta: float) -> void:
	var angle := player_ref.orbital_rotation + angle_offset
	position = Vector2(cos(angle), sin(angle)) * radius

	if overlapping_bodies.size() > 0 and damage > 0.0:
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = damage_interval
			_deal_damage_to_all()


func _on_body_entered(body: Node) -> void:
	overlapping_bodies.append(body)
	if damage > 0.0 and body.has_method("take_damage"):
		tick_timer = damage_interval
		body.take_damage(damage)


func _on_body_exited(body: Node) -> void:
	overlapping_bodies.erase(body)


func _deal_damage_to_all() -> void:
	for body in overlapping_bodies:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage)
