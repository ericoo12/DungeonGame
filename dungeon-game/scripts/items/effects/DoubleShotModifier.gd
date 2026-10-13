## ShotPatternModifier: +1 shot (additive with other extra-shot items, see
## ShotPatternModifier). Works with any ShotStyleModifier — see Player.fire_single_shot().
class_name DoubleShotModifier
extends ShotPatternModifier


func _init() -> void:
	extra_shots = 1
	spread_degrees = 8.0
