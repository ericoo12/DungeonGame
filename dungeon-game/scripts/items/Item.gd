## A passive pickup. Applying it permanently modifies the player's stats
## and/or equips a weapon-modifying piece (shot style / shot pattern).
## Multiple Items of different kinds stack freely; see apply() for how
## each field behaves (additive stat vs. equip/replace vs. stacking list).
class_name Item
extends ItemBase

# --- Flat stat bonuses (all additive, applied once on pickup) ---
@export var max_hearts_bonus: int = 0	# common +1, rare +2, bad -1
@export var speed_bonus: float = 0.0	# common +15, uncommon +25, rare +35, bad -25
@export var damage_bonus: int = 0	# common +1, rare +2, bad -1
@export var fire_rate_bonus: float = 0.0	# common +0.05, uncommon +0.10, rare +0.15, bad -0.15
@export var knockback_bonus: float = 0.0	# common +25, uncommon +50, rare +100, bad 50
@export var range_bonus: float = 0.0	# common +0.2, uncommon +0.4, rare +0.8, bad -0.3
@export var size_bonus: float = 0.0	# common +0.15, uncommon +0.3, rare +0.5, bad -0.2
@export var player_size_bonus: float = 0.0	# common -0.1, rare -0.2, bad 0.2
@export var shot_speed_bonus: float = 0.0
@export var luck_bonus: float = 0.0
# --- Multiplicative stat bonuses
@export var fire_rate_multiplier: float = 1.0       # >1 = fires faster, e.g. 5.5 = 5.5x faster
@export var damage_multiplier: float = 1.0          # <1 = weaker shots, e.g. 0.2 = keep 20% (-80%)
@export var projectile_size_multiplier: float = 1.0 # <1 = smaller shots, e.g. 0.5 = half size

# --- Orbital companion (spawns a persistent Orbital instance) ---
@export var orbital_scene: PackedScene


# --- follower companion ---
@export var follower_scene: PackedScene
@export var follower_trail_delay: float = 0.4


# --- Weapon composition ---
# shot_style REPLACES the player's current shot style (last one picked up wins,
# since a shot can't be two different things at once). shot_pattern_modifier
# STACKS (appended to a list) — multiple pattern items combine multiplicatively
# via Player.fire_single_shot().
@export var shot_style: ShotStyleModifier
@export var shot_pattern_modifier: ShotPatternModifier
@export var charge_shot: ChargeShotSettings
## Luck-scaled chance-per-shot effect (e.g. SlowShotProc). Stacks with everything.
@export var shot_proc: ShotProcEffect

#--- Cosmetics ---
@export var cosmetic_scene: PackedScene
@export_enum("Head", "Face", "Neck", "Body", "Back", "LeftHand", "RightHand", "Feet", "Aura", "Trail") var cosmetic_slot: String = ""

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

	if follower_scene:
		player.add_follower(follower_scene, follower_trail_delay)
		
	if knockback_bonus != 0.0:
		player.projectile_knockback = clamp(player.projectile_knockback + knockback_bonus, Player.KNOCKBACK_MIN, Player.KNOCKBACK_MAX)

	if range_bonus != 0.0:
		player.projectile_range = clamp(player.projectile_range + range_bonus, Player.RANGE_MIN, Player.RANGE_MAX)

	if size_bonus != 0.0:
		player.projectile_size = clamp(player.projectile_size + size_bonus, Player.PROJECTILE_SIZE_MIN, Player.PROJECTILE_SIZE_MAX)

	if player_size_bonus != 0.0:
		player.set_player_scale(player.player_scale + player_size_bonus)

	if shot_style:
		player.equip_shot_style(shot_style)
	if shot_pattern_modifier:
		player.shot_pattern_modifiers.append(shot_pattern_modifier)

	if knockback_bonus != 0.0 or range_bonus != 0.0 or size_bonus != 0.0:
		player.resync_shot_style()
		
	if fire_rate_multiplier != 1.0:
		player.fire_rate = clamp(player.fire_rate / fire_rate_multiplier, 0.05, 2.0)

	if damage_multiplier != 1.0:
		player.damage_multiplier = clamp(player.damage_multiplier * damage_multiplier, 0.05, 5.0)

	if projectile_size_multiplier != 1.0:
		player.projectile_size = clamp(player.projectile_size * projectile_size_multiplier, Player.PROJECTILE_SIZE_MIN, Player.PROJECTILE_SIZE_MAX)
	
	if shot_speed_bonus != 0.0:
		player.shot_speed = clamp(player.shot_speed + shot_speed_bonus, Player.SHOT_SPEED_MIN, Player.SHOT_SPEED_MAX)
	
	if cosmetic_scene:
		player.add_cosmetic(cosmetic_scene, cosmetic_slot)
	
	if charge_shot:
		player.charge_shot = charge_shot
	
	if luck_bonus != 0.0:
		player.luck += luck_bonus

	if shot_proc:
		player.shot_procs.append(shot_proc)


## Builds the "+2 Damage" / "+0.5 Speed" style summary shown in the item overlay's
## detail panel. Only non-zero fields are listed, so a pure weapon-modifier item
## (no stat bonuses) correctly shows nothing here — its effect is described via
## item_name/description instead.
func get_stat_summary() -> String:
	var lines: PackedStringArray = []
	for line in get_stat_lines():
		lines.append(line.text)
	return "\n".join(lines)


## Same info as get_stat_summary(), but structured for the inventory UI:
## [{ "text": String, "good": bool, "neutral": bool }]. "good" accounts for stats where
## lower is better (e.g. player size).
func get_stat_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	_add_line(lines, max_hearts_bonus, "%+d Max Hearts" % max_hearts_bonus)
	_add_line(lines, damage_bonus, "%+d Damage" % damage_bonus)
	_add_line(lines, speed_bonus, "%+.0f Speed" % speed_bonus)
	_add_line(lines, fire_rate_bonus, "%+.2f Fire Rate" % fire_rate_bonus)
	_add_line(lines, knockback_bonus, "%+.0f Knockback" % knockback_bonus)
	_add_line(lines, range_bonus, "%+.1f Range" % range_bonus)
	_add_line(lines, size_bonus, "%+.2f Shot Size" % size_bonus)
	_add_line(lines, shot_speed_bonus, "%+.0f Shot Speed" % shot_speed_bonus)
	_add_line(lines, -player_size_bonus, "%+.2f Player Size" % player_size_bonus)  # smaller = good
	_add_line(lines, fire_rate_multiplier - 1.0, "x%.2f Fire Rate" % fire_rate_multiplier)
	_add_line(lines, damage_multiplier - 1.0, "x%.2f Damage" % damage_multiplier)
	_add_line(lines, projectile_size_multiplier - 1.0, "x%.2f Shot Size" % projectile_size_multiplier)
	_add_line(lines, luck_bonus, "%+d Luck" % int(luck_bonus))
	if shot_style:
		lines.append({"text": "Changes your shot", "good": true, "neutral": true})
	if shot_pattern_modifier:
		lines.append({"text": "Changes your shot pattern", "good": true, "neutral": true})
	if charge_shot:
		lines.append({"text": "Charge shot", "good": true, "neutral": true})
	if shot_proc:
		lines.append({"text": shot_proc.get_stat_text(), "good": true, "neutral": true})
	if orbital_scene:
		lines.append({"text": "Adds an orbital", "good": true, "neutral": true})
	if follower_scene:
		lines.append({"text": "Adds a follower", "good": true, "neutral": true})
	return lines


## `goodness` > 0 means the change helps the player, < 0 hurts, 0 = not listed.
func _add_line(lines: Array[Dictionary], goodness: float, text: String) -> void:
	if is_zero_approx(goodness):
		return
	lines.append({"text": text, "good": goodness > 0.0, "neutral": false})
