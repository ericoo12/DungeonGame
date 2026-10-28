## Cross Flush: also fires one shot to each side (90° left and right of the aim).
## Single extra: added once off the aim, however many main shots you have
## (Quad + Cross = 4 forward + 1 left + 1 right).
class_name CrossShotModifier
extends ShotPatternModifier


func adds_single_extras() -> bool:
	return true


func extra_directions(aim: Vector2) -> Array[Vector2]:
	return [aim.rotated(PI / 2.0), aim.rotated(-PI / 2.0)]
