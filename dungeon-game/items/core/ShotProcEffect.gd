## Base for "chance per shot" effects (Sticky Briefs, Septic Infection, ...).
## Chance = base_chance + per_luck * luck, capped at max_chance (default: +1.5% per
## luck point, never above 50%, so no proc becomes guaranteed). Negative luck counts as 0.
class_name ShotProcEffect
extends Resource

@export var base_chance: float = 0.10
@export var per_luck: float = 0.015
@export var max_chance: float = 0.5
## Old setting (chance hit 100% at this much luck). No longer used; kept so older
## .tres files that set it still load.
@export var luck_for_max: float = 10.0


func get_chance() -> float:
	return Luck.chance(base_chance, per_luck, max_chance)


func decorate_projectile(projectile: Node) -> void: pass #e.g tint it
func on_hit(target: Node, player: Player) -> void: pass #the actuall effect
## Called by Projectile right after on_hit, with the projectile itself (position,
## velocity, size). For effects that spawn things where the shot hit (SplitShotProc).
## Not called for lasers / beams (they have no projectile).
func on_projectile_hit(projectile: Node, target: Node) -> void: pass


## Line shown in the inventory for items carrying this effect. Uses the CURRENT chance,
## so it updates as luck changes. Override for a nicer description.
func get_stat_text() -> String:
	return "%d%% chance for a special shot" % roundi(get_chance() * 100.0)


## " (+1.5%/luck, max 50%)" — shared suffix for proc descriptions.
func luck_text() -> String:
	return " (+%s%% per luck, max %d%%)" % [str(snappedf(per_luck * 100.0, 0.1)), roundi(max_chance * 100.0)]
