## Toilet Tornado: on top of your normal (aimed) shots, fires ONE extra shot rotated by
## an angle that grows by step_degrees every trigger pull, so a second stream spins
## around you. Single extra: always one spinning shot, however many main shots you have.
class_name TornadoModifier
extends ShotPatternModifier

@export var step_degrees: float = 25.0

var _angle: float = 0.0
var _last_frame: int = -1


func adds_single_extras() -> bool:
	return true


func extra_directions(aim: Vector2) -> Array[Vector2]:
	# Advance once per trigger pull (fire_single_shot can run several times per frame
	# for Panty Panic's ring; those all share one angle).
	var frame := Engine.get_physics_frames()
	if frame != _last_frame:
		_last_frame = frame
		_angle = fmod(_angle + deg_to_rad(step_degrees), TAU)
	return [aim.rotated(_angle)]


func get_stat_text() -> String:
	return "Adds a spinning stream of shots"
