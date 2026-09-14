## A passive pickup. Applying it permanently modifies the player's stats
## and/or equips a weapon-modifying piece (shot style / shot pattern).
## Multiple Items of different kinds stack freely; see apply() for how
## each field behaves (additive stat vs. equip/replace vs. stacking list).
class_name Item
extends ItemBase

# --- Flat stat bonuses (all additive, applied once on pickup) ---
@export var max_hearts_bonus: int = 0
@export var speed_bonus: float = 0.0
@export var damage_bonus: int = 0
@export var fire_rate_bonus: float = 0.0

# --- Orbital companion (spawns a persistent Orbital instance) ---
@export var orbital_scene: PackedScene

# --- Weapon composition ---
# shot_style REPLACES the player's current shot style (last one picked up wins,
# since a shot can't be two different things at once). shot_pattern_modifier
# STACKS (appended to a list) — multiple pattern items combine multiplicatively
# via Player.fire_single_shot().
@export var shot_style: ShotStyleModifier
@export var shot_pattern_modifier: ShotPatternModifier


func apply(player: Player) -> void:
	if max_hearts_bonus != 0:
		player.max_hearts += max_hearts_bonus
		player.current_hearts += max_hearts_bonus
		EventBus.player_health_changed.emit(player.current_hearts, player.max_hearts)

	player.move_speed = clamp(player.move_speed + speed_bonus, 20.0, 300.0)
	if damage_bonus != 0:
		player.damage_ups += damage_bonus
	player.fire_rate = max(0.05, player.fire_rate - fire_rate_bonus)

	if orbital_scene:
		player.add_orbital(orbital_scene)

	if shot_style:
		player.shot_style = shot_style
	if shot_pattern_modifier:
		player.shot_pattern_modifiers.append(shot_pattern_modifier)


## Builds the "+2 Damage" / "+0.5 Speed" style summary shown in the item overlay's
## detail panel. Only non-zero fields are listed, so a pure weapon-modifier item
## (no stat bonuses) correctly shows nothing here — its effect is described via
## item_name/description instead.
func get_stat_summary() -> String:
	var lines: PackedStringArray = []
	if max_hearts_bonus != 0:
		lines.append("%+d Max Hearts" % max_hearts_bonus)
	if damage_bonus != 0:
		lines.append("%+d Damage" % damage_bonus)
	if speed_bonus != 0.0:
		lines.append("%+.1f Speed" % speed_bonus)
	if fire_rate_bonus != 0.0:
		lines.append("%+.2f Fire Rate" % fire_rate_bonus)
	return "\n".join(lines)
