## Overflow: adds two shots beside EVERY shot (±side_degrees). Custom pattern, so it
## multiplies whatever is already there: Quad Shot (4) becomes 12. The item itself also
## lowers damage and shot size (Item.damage_multiplier / projectile_size_multiplier).
class_name OverflowModifier
extends ShotPatternModifier

@export var side_degrees: float = 9.0


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var step := deg_to_rad(side_degrees)
	for d in dirs:
		result.append(d.rotated(-step))
		result.append(d)
		result.append(d.rotated(step))
	return result


func get_stat_text() -> String:
	return "Every shot becomes three"
