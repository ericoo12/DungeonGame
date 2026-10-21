extends Node2D
class_name MuggPaperTrail

## Each deposited strip expires independently, even after the projectile is gone.
var damage: float = 0.5
var segment_lifetime: float = 1.0
var width: float = 8.0
var segments: Array[Dictionary] = []
var idle_time: float = 0.0

func _ready() -> void:
	z_index = -1
	add_to_group("mugg_paper_trails")

func add_segment(from: Vector2, to: Vector2) -> void:
	if from.distance_squared_to(to) < 0.001:
		return
	segments.append({"from": from, "to": to, "age": 0.0})
	idle_time = 0.0

func _physics_process(delta: float) -> void:
	idle_time += delta
	for i in range(segments.size() - 1, -1, -1):
		segments[i].age += delta
		if segments[i].age >= segment_lifetime:
			segments.remove_at(i)
	if segments.is_empty() and idle_time >= segment_lifetime:
		queue_free()
		return
	for player in get_tree().get_nodes_in_group("player"):
		if not player is Player or player.is_dying or player.invulnerable:
			continue
		for segment in segments:
			var nearest := Geometry2D.get_closest_point_to_segment(player.global_position, segment.from, segment.to)
			if nearest.distance_to(player.global_position) <= width * 0.5 + 5.0:
				player.take_damage(damage)
				break
	queue_redraw()

func _draw() -> void:
	for segment in segments:
		var a := to_local(segment.from)
		var b := to_local(segment.to)
		draw_line(a, b, Color(0.55, 0.45, 0.36), width + 2.0)
		draw_line(a, b, Color(0.95, 0.92, 0.83), width)
