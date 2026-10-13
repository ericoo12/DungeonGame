extends Area2D
class_name ItemPickup

signal item_taken

@export var item: ItemBase
@export var display_size: float = 16.0
## The item icon gently floats above the pedestal (px up/down, seconds per cycle).
@export var bob_height: float = 1.5
@export var bob_period: float = 1.6

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
	if not body.has_method("add_item"):
		return
	if item is ActiveItem:
		body.add_active_item(item)
	else:
		body.add_item(item)
	item_taken.emit()
	queue_free()
