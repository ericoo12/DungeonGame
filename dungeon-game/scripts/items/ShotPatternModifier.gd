## Base class for "how many shots fire, and in what pattern" — e.g. DoubleShotModifier.
## Unlike ShotStyleModifier, these STACK: Player.shot_pattern_modifiers is a list,
## and every equipped modifier runs in sequence inside Player.fire_single_shot(),
## each one taking the previous step's output directions and expanding them further.
class_name ShotPatternModifier
extends Resource

func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	push_warning("ShotPatternModifier.modify_directions() not implemented")
	return dirs
