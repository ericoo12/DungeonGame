## Base class for "what does a single shot actually look like" — laser, regular
## projectile, and any future style all subclass this. Only one can be equipped
## at a time (Player.shot_style), since a shot can't be two things at once.
## See ShotPatternModifier for the separate, STACKABLE piece that controls how
## many shots fire per input — the two compose together in
## Player.fire_single_shot() without either one knowing the other exists.
class_name ShotStyleModifier
extends Resource

func fire(player: Player, dir: Vector2, apply_momentum: bool) -> void:
	push_warning("ShotStyleModifier.fire() not implemented")


## Called once when this style is equipped, and again any time a relevant
## player stat changes afterward. Override in subclasses that want to react
## to the player's current range/size/knockback bonuses.
func apply_player_stats(player: Player) -> void:
	pass
