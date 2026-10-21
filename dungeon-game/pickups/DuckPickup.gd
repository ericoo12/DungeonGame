## Counter pickups: rubber ducks (1 / 5 / 10 value — one scene per value) and
## decloggers (DeclogPickup.tscn, currency = "decloggers"). Always picked up on touch. Emits `collected` so RoomController stops remembering it
## for revisits (same contract as HeartPickup, see RoomController._spawn_drop()).
extends Area2D
class_name DuckPickup

signal collected

@export var value: int = 1
@export_enum("ducks", "decloggers") var currency: String = "ducks"
## On-screen size in px (largest side). The sprite is scaled to this from whatever
## resolution the art has, so new art never needs the scene scale touched.
@export var display_size: float = 12.0
## Gentle bob so it reads as a pickup (px up/down, seconds per cycle).
@export var bob_height: float = 1.0
@export var bob_period: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D

var _taken: bool = false


func _ready() -> void:
	add_to_group("item_pickups")  # Dungeon._load_room() clears this group on room change
	collision_layer = 0
	collision_mask = 2            # player body
	body_entered.connect(_on_body_entered)

	if sprite.texture:
		var tex_size := sprite.texture.get_size()
		sprite.scale = Vector2.ONE * (display_size / maxf(tex_size.x, tex_size.y))
	# Big art shrunk this much shimmers with nearest filtering; mipmaps keep it clean.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var base_y := sprite.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", base_y - bob_height, bob_period / 2.0)
	tween.tween_property(sprite, "position:y", base_y + bob_height, bob_period / 2.0)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or _taken:
		return
	_taken = true
	if currency == "decloggers":
		player.add_decloggers(value)
	else:
		player.add_ducks(value)
	collected.emit()
	queue_free()
