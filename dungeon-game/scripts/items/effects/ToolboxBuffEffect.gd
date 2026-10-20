## Plumber's Toolbox: damage, fire rate, shot speed and knockback up until the player
## leaves the room. Using it again while active refreshes it (doesn't stack).
class_name ToolboxBuffEffect
extends ActiveItemEffect

@export var damage_multiplier: float = 1.5
@export var fire_rate_multiplier: float = 1.4   # >1 = faster
@export var shot_speed_bonus: float = 0.3
@export var knockback_bonus: float = 80.0
@export var tint: Color = Color(1.0, 0.86, 0.62)


func activate(player: Player) -> void:
	var buff := TempStatBuff.new()
	buff.key = "toolbox"
	buff.damage_multiplier = damage_multiplier
	buff.fire_rate_multiplier = fire_rate_multiplier
	buff.shot_speed_bonus = shot_speed_bonus
	buff.knockback_bonus = knockback_bonus
	buff.tint = tint
	TempStatBuff.start(player, buff)
