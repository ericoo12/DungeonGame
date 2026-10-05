class_name Luck
extends RefCounted

const ROOM_LUCK_CAP := 10.0

## Current player luck
static func raw() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group("player") as Player if tree else null
	return p.luck if p else 0.0

# Luck as used by a roll: negatives act like 0
static func effective(cap: float = INF) -> float:
	return clampf(raw(), 0.0, cap)

## Linear proc chance: base + per_luck * luck, clamped to max_chance
static func chance(base: float, per_luck: float, max_chance: float = 1.0, cap: float = INF) -> float:
	return clampf(base + per_luck * effective(cap), 0.0, max_chance)

static func chance_to_max(base: float, luck_for_max: float) -> float:
	return lerpf(base, 1.0, clampf(effective() / luck_for_max, 0.0, 1.0))

static func roll(p: float) -> bool:
	return GameState.rng.randf() < p
