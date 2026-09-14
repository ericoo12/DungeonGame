## ShotPatternModifier: turns each incoming direction into two, spread apart by
## spread_degrees. Stacks with other pattern modifiers and works with any
## ShotStyleModifier (laser, projectile, future styles) — see Player.fire_single_shot().
class_name DoubleShotModifier
extends ShotPatternModifier

@export var spread_degrees: float = 5.0


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var half_spread: float = deg_to_rad(spread_degrees / 2.0)
	for d in dirs:
		result.append(d.rotated(half_spread))
		result.append(d.rotated(-half_spread))
	return result
