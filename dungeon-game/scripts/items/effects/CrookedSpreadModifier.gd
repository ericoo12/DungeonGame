## Crooked Barrel: every shot is knocked off course by a random angle up to
## ±spread_degrees. With multishot it becomes a shotgun.
class_name CrookedSpreadModifier
extends ShotPatternModifier

@export var max_spread_degrees: float = 9.0


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for d in dirs:
		result.append(d.rotated(deg_to_rad(randf_range(-max_spread_degrees, max_spread_degrees))))
	return result


func get_stat_text() -> String:
	return "Shots go a bit off course"
