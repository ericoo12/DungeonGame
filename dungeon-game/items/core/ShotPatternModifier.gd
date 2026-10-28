## Base class for "how many shots fire, and in what pattern" — e.g. DoubleShotModifier.
## Unlike ShotStyleModifier, these STACK: Player.shot_pattern_modifiers is a list.
##
## Two kinds, both handled in Player.fire_single_shot():
##   - Extra shots (extra_shots > 0): ADDITIVE. All equipped extras are summed and
##     1 + total shots are fanned evenly around the aim, spread_degrees apart
##     (the widest spread_degrees among them is used). Double (+1) + Quad (+3) = 5 shots.
##   - Custom patterns (extra_shots == 0): override modify_directions(); applied after
##     the fan, in pickup order (e.g. a future "also shoot backwards").
##   - Single extras: override extra_directions(aim) (and adds_single_extras() -> true).
##     They add shots off the aim direction ONCE, not per multishot shot, and other
##     custom patterns don't copy them (Quad + Cross Flush = 4 forward + 2 sides).
class_name ShotPatternModifier
extends Resource

@export var extra_shots: int = 0
@export var spread_degrees: float = 10.0   # angle between neighbouring shots in the fan


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	return dirs


## True for modifiers that add their shots once, off the aim (see extra_directions).
func adds_single_extras() -> bool:
	return false


## Extra directions added once per trigger pull, based on the aim only.
func extra_directions(_aim: Vector2) -> Array[Vector2]:
	return []


## Inventory line for custom patterns ("" = the generic "Changes your shot pattern").
func get_stat_text() -> String:
	return ""


## `count` directions fanned evenly around `aim`, `spread_deg` apart.
static func fan(aim: Vector2, count: int, spread_deg: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var step := deg_to_rad(spread_deg)
	var half := (count - 1) / 2.0
	for i in count:
		result.append(aim.rotated((i - half) * step))
	return result
