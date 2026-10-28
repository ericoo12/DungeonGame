## Heart drop (room-clear rewards, broken obstacles). Heals on touch, but only if the
## player is missing health - otherwise it gets kicked around the floor (like Isaac).
## Movement, popping out and room memory: PhysicsPickup.
extends PhysicsPickup
class_name HeartPickup

@export var heal_amount: float = 1.0  # 0.5 = half heart (HalfHeartPickup.tscn)


func can_collect(player: Player) -> bool:
	return player.current_hearts < player.max_hearts


func collect(player: Player) -> void:
	player.heal(heal_amount)
