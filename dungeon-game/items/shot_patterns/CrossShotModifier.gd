## Cross Flush: every shot also fires to both sides (90° left and right). Custom
## pattern, so it runs after the extra-shot fan: Double + Cross = 2 forward + 2 + 2.
class_name CrossShotModifier
extends ShotPatternModifier


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = dirs.duplicate()
	for d in dirs:
		result.append(d.rotated(PI / 2.0))
		result.append(d.rotated(-PI / 2.0))
	return result
