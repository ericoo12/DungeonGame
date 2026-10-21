## ActiveItemEffect: fires a full ring of shots in every direction at once.
## Weapon-agnostic on purpose — routes through Player.fire_single_shot() rather
## than spawning a Projectile directly, so it automatically fires lasers,
## double-shots, etc. if the player has those equipped. No code changes needed
## here when new shot styles/patterns are added elsewhere.
class_name RadialBurstEffect
extends ActiveItemEffect

@export var projectile_count: int = 12


func activate(player: Player) -> void:
	for i in projectile_count:
		var angle: float = TAU * float(i) / float(projectile_count)
		var dir := Vector2(cos(angle), sin(angle))
		player.fire_single_shot(dir, false)
