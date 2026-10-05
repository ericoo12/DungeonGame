class_name ShotProcEffect
extends Resource

@export var base_chance: float = 0.10
@export var luck_for_max: float = 10.0

func get_chance() -> float:
	
	return Luck.chance_to_max(base_chance, luck_for_max)

func decorate_projectile(projectile: Node) -> void: pass #e.g tint it
func on_hit(target: Node, player: Player) -> void: pass #the actuall effect


## Line shown in the inventory for items carrying this effect. Uses the CURRENT chance,
## so it updates as luck changes. Override for a nicer description.
func get_stat_text() -> String:
	return "%d%% chance for a special shot" % roundi(get_chance() * 100.0)
