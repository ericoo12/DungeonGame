## Heart drop (room-clear rewards, broken obstacles). Heals on touch, but only if
## the player is missing health, otherwise it stays on the floor (like Isaac).
## Emits `collected` so RoomController stops remembering it for revisits.
extends Area2D
class_name HeartPickup

signal collected

@export var heal_amount: int = 1


func _ready() -> void:
	add_to_group("item_pickups")  # Dungeon._load_room() clears this group on room change
	collision_layer = 0
	collision_mask = 2            # player body


## Polled instead of body_entered: if you stand on it at full health and then take
## damage, it should still pick up.
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and player.current_hearts < player.max_hearts:
			player.heal(heal_amount)
			collected.emit()
			queue_free()
			return
