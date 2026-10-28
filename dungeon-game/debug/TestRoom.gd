## Item test room: puts a small name label under every item pedestal (taken from the
## item itself, so it stays right when you swap items around in the editor).
## The group headings are plain Label nodes in the scene (Labels/...).
extends Node2D

@export var name_font_size: int = 6
@export var name_width: float = 46.0
@export var name_offset_y: float = 9.0


func _ready() -> void:
	Discovery.reveal_all = true  # test room: every item shows its info, nothing is saved
	tree_exiting.connect(func(): Discovery.reveal_all = false)
	for node in $Entities.get_children():
		var pickup := node as ItemPickup
		if pickup == null or pickup.item == null:
			continue
		var label := Label.new()
		label.text = pickup.item.item_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size = Vector2(name_width, 0)
		label.position = Vector2(-name_width / 2.0, name_offset_y)
		label.add_theme_font_size_override("font_size", name_font_size)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pickup.add_child(label)
		# The label follows a swapped item (active items swap on the same pedestal).
		pickup.item_taken.connect(func():
			if is_instance_valid(label) and is_instance_valid(pickup) and pickup.item:
				label.text = pickup.item.item_name)
