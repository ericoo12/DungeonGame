extends Area2D
class_name ItemPickup

@export var item: ItemBase
@export var display_size: float = 16.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if item and item.icon:
		sprite.texture = item.icon
		var tex_size := item.icon.get_size()
		var largest_side: float = max(tex_size.x, tex_size.y)
		sprite.scale = Vector2.ONE * (display_size / largest_side)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("add_item"):
		return
	# ActiveItems route to a separate slot/cooldown system; everything else
	# is a passive Item applied immediately.
	if item is ActiveItem:
		body.add_active_item(item)
	else:
		body.add_item(item)
	queue_free()
