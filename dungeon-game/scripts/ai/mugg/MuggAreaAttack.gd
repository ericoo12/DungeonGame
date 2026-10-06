extends Node2D
class_name MuggAreaAttack

# Lobbed area denial: a fixed, visible warning followed by a damaging puddle.
# Parent is the boss, so room removal/death also removes outstanding hazards.
var radius: float = 60.0
var damage: float = 1.0
var duration: float = 1.4
var armed: bool = false
var elapsed: float = 0.0
var tick_remaining: float = 0.0
var warning_progress: float = 0.0

func arm() -> void:
	armed = true
	elapsed = 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if get_parent() is EnemyBase and get_parent().is_dying:
		queue_free()
		return
	if not armed:
		return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	tick_remaining -= delta
	if tick_remaining <= 0.0:
		tick_remaining = 0.35
		for player in get_tree().get_nodes_in_group("player"):
			if player is Node2D and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= radius:
				player.take_damage(damage)
	queue_redraw()

func _draw() -> void:
	var color := Color(0.95, 0.25, 0.1, 0.3) if armed else Color(1.0, 0.75, 0.1, 0.12)
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1.0, 0.55, 0.1), 2.0)
	if not armed:
		draw_arc(Vector2.ZERO, radius - 4, -PI / 2, -PI / 2 + TAU * warning_progress, 64, Color(1, 0.9, 0.3), 3.0)
