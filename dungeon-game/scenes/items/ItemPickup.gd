extends Area2D
class_name ItemPickup

signal item_taken

@export var item: ItemBase
@export var display_size: float = 16.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("item_pickups")
	body_entered.connect(_on_body_entered)
	_update_visual()

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
