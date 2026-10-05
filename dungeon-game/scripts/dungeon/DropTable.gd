class_name DropTable
extends Resource
@export var drop_chance: float = 0.3
@export var drop_chance_per_luck: float = 0.04
@export var luck_cap: float = Luck.ROOM_LUCK_CAP
@export var entries: Array[DropEntry] = []

## Returns a scene to spawn, or null (no drop).
func roll() -> PackedScene:
	if not Luck.roll(Luck.chance(drop_chance, drop_chance_per_luck, 1.0, luck_cap)):
		return null
	var l := Luck.effective(luck_cap)
	var total := 0.0
	var pool: Array = []
	for e in entries:
		if l >= e.min_luck:
			var w: float = e.weight + e.weight_per_luck * l
			pool.append([e, w]); total += w
	var r := GameState.rng.randf() * total
	for pair in pool:
		r -= pair[1]
		if r <= 0.0: return pair[0].scene
	return null
