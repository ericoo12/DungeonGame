## ShotPatternModifier: +3 shots (additive with other extra-shot items, see
## ShotPatternModifier). Alone: 4 shots. With Double Shot: 5. Works with any
## ShotStyleModifier — see Player.fire_single_shot().
class_name QuadShotModifier
extends ShotPatternModifier


func _init() -> void:
	extra_shots = 3
	spread_degrees = 10.0
