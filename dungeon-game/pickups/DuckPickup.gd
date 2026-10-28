## Counter pickups: rubber ducks (1 / 5 / 10 value - one scene per value) and
## decloggers (DeclogPickup.tscn, currency = "decloggers"). Picked up on touch.
## Movement, popping out and room memory: PhysicsPickup.
extends PhysicsPickup
class_name DuckPickup

@export var value: int = 1
@export_enum("ducks", "decloggers") var currency: String = "ducks"


func collect(player: Player) -> void:
	if currency == "decloggers":
		player.add_decloggers(value)
	else:
		player.add_ducks(value)
