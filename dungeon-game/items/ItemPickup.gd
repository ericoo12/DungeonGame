extends Area2D
class_name ItemPickup

signal item_taken

@export var item: ItemBase
@export var display_size: float = 16.0
## The item icon gently floats above the pedestal (px up/down, seconds per cycle).
@export var bob_height: float = 1.5
@export var bob_period: float = 1.6

## Active items put down by the player (swapped out) keep their charges. -1 = full.
var stored_charges: int = -1
## Set when this pedestal is remembered by its room (RoomData.floor_items), so it comes
## back on revisits. See RoomController.register_floor_item().
var room_data: RoomData = null
var room_entry: Dictionary = {}

## Item icon. The pedestal is its own node ("Pedestal"), so setting the icon doesn't
## overwrite it.
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("item_pickups")
	body_entered.connect(_on_body_entered)
	_update_visual()
	_start_bob()


func _start_bob() -> void:
	var base_y := sprite.position.y
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", base_y - bob_height, bob_period / 2.0)
	tween.tween_property(sprite, "position:y", base_y + bob_height, bob_period / 2.0)

func setup(new_item: ItemBase) -> void:
	item = new_item
	if is_inside_tree():
		_update_visual()

func _update_visual() -> void:
	if item and item.icon:
		sprite.texture = item.icon
		var tex_size := item.icon.get_size()
		var largest_side: float = max(tex_size.x, tex_size.y)
		sprite.scale = Vector2.ONE * (display_size / largest_side)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("add_item") or item == null:
		return
	if item is ActiveItem:
		var player := body as Player
		var previous: ActiveItem = player.add_active_item(item, stored_charges)
		if previous:
			# Swap: the item you were holding goes onto this pedestal instead of vanishing.
			var previous_charges := player.last_dropped_active_charges
			item_taken.emit()
			setup(previous)
			stored_charges = previous_charges
			_remember_in_room()
			return
	else:
		body.add_item(item)
	item_taken.emit()
	_forget_in_room()
	queue_free()


## Puts an active item the player let go of on a new pedestal at `global_pos`
## (shop purchases: the old item lands next to the counter). Remembered by the room.
static func drop_active(parent: Node, item_to_drop: ActiveItem, charges: int, global_pos: Vector2) -> ItemPickup:
	var pickup: ItemPickup = load("res://items/ItemPickup.tscn").instantiate()
	pickup.item = item_to_drop
	pickup.stored_charges = charges
	parent.add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", global_pos)
	pickup.call_deferred("_remember_in_room")
	return pickup


func _remember_in_room() -> void:
	if room_data:  # already remembered: just update what's on it
		room_entry["item"] = item
		room_entry["charges"] = stored_charges
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon") as Dungeon
	if dungeon and dungeon.current_room:
		dungeon.current_room.register_floor_item(self)


func _forget_in_room() -> void:
	if room_data and not room_entry.is_empty():
		room_data.floor_items.erase(room_entry)
	room_data = null
