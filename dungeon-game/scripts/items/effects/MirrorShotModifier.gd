## ShotPatternModifier: every shot also fires straight backwards (custom pattern, so it
## runs after the extra-shot fan: Quad + Mirror = 4 forward + 4 back). The off-hand arm
## kicks/flashes with the backward shots (Player._play_arm_kick).
class_name MirrorShotModifier
extends ShotPatternModifier


func modify_directions(dirs: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = dirs.duplicate()
	for d in dirs:
		result.append(-d)
	return result
