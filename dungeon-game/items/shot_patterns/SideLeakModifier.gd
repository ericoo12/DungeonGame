## Side Leakage: also leaks one extra shot to each side, at a random angle between
## min_angle and max_angle from the aim (so it sprays, unlike Cross Flush's exact 90°).
## Single extra: added once off the aim, however many main shots you have.
class_name SideLeakModifier
extends ShotPatternModifier

@export var min_angle_deg: float = 55.0
@export var max_angle_deg: float = 125.0


func adds_single_extras() -> bool:
	return true


func extra_directions(aim: Vector2) -> Array[Vector2]:
	return [
		aim.rotated(deg_to_rad(randf_range(min_angle_deg, max_angle_deg))),
		aim.rotated(-deg_to_rad(randf_range(min_angle_deg, max_angle_deg))),
	]


func get_stat_text() -> String:
	return "Leaks shots out to the sides"
