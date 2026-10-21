## Portable Toilet: the player can't be hurt and can't shoot for `duration` seconds
## (sitting on the toilet), then heals `heal` hearts.
class_name PortableToiletEffect
extends ActiveItemEffect

@export var duration: float = 2.5
@export var heal: int = 1
@export var tint: Color = Color(1, 1, 1, 0.55)


func activate(player: Player) -> void:
	var buff := TempStatBuff.new()
	buff.key = "portable_toilet"
	buff.duration = duration
	buff.invulnerable = true
	buff.block_shooting = true
	buff.heal_on_end = heal
	buff.tint = tint
	TempStatBuff.start(player, buff)
