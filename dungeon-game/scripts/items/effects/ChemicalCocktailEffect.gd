## Chemical Cocktail: for `duration` seconds every shot poisons and slows, and shots
## are bigger.
class_name ChemicalCocktailEffect
extends ActiveItemEffect

@export var duration: float = 8.0
@export var size_multiplier: float = 1.3
@export var tint: Color = Color(0.8, 1.0, 0.7)


func activate(player: Player) -> void:
	var poison := PoisonShotProc.new()
	poison.base_chance = 1.0
	poison.max_chance = 1.0
	var slow := SlowShotProc.new()
	slow.base_chance = 1.0
	slow.max_chance = 1.0
	slow.slow_factor = 0.6
	slow.duration = 2.0
	var buff := TempStatBuff.new()
	buff.key = "chemical_cocktail"
	buff.duration = duration
	buff.size_multiplier = size_multiplier
	buff.extra_procs = [poison, slow]
	buff.tint = tint
	TempStatBuff.start(player, buff)
