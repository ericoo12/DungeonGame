## Toilet Tornado: on top of your normal (aimed) shots, fires a copy of the whole pattern
## rotated by an angle that grows by step_degrees every trigger pull, so a second stream
## spins around you. Double Shot = a spinning pair, Quad = a spinning fan, Mirror = two
## opposing spinning streams. Your aimed shots stay where you aim.
class_name TornadoModifier
extends ShotPatternModifier

@export var step_degrees: float = 25.0

var _angle: float = 0.0
var _last_frame: int = -1


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	# Advance once per trigger pull (fire_single_shot can run several times per frame
	# for Panty Panic's ring; those all share one angle).
	var frame := Engine.get_physics_frames()
	if frame != _last_frame:
		_last_frame = frame
		_angle = fmod(_angle + deg_to_rad(step_degrees), TAU)
	var result: Array[Vector2] = dirs.duplicate()
	for d in dirs:
		result.append(d.rotated(_angle))
	return result


func get_stat_text() -> String:
	return "Adds a spinning stream of shots"
