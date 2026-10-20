## Side Leakage: every shot also leaks one extra shot to each side, at a random angle
## between min_angle and max_angle from the aim (so it sprays, unlike Cross Flush's
## exact 90°). Custom pattern: applied to every direction after the fan.
class_name SideLeakModifier
extends ShotPatternModifier

@export var min_angle_deg: float = 55.0
@export var max_angle_deg: float = 125.0


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = dirs.duplicate()
	for d in dirs:
		result.append(d.rotated(deg_to_rad(randf_range(min_angle_deg, max_angle_deg))))
		result.append(d.rotated(-deg_to_rad(randf_range(min_angle_deg, max_angle_deg))))
	return result


func get_stat_text() -> String:
	return "Leaks shots out to the sides"
