## HUD counter: icon + number. Ducks (EventBus.ducks_changed) or decloggers
## (EventBus.decloggers_changed), picked with `counter`.
extends HBoxContainer
class_name DuckCounterDisplay

@export var icon_texture: Texture2D = preload("res://assets/sprites/pickups/ducks/duck_1.png")
@export_enum("ducks", "decloggers") var counter: String = "ducks"
@export var icon_size: float = 14.0
@export var font_size: int = 12

var _label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # big art, small icon
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	add_child(icon)

	_label = UIStyle.label("0", font_size, UIStyle.COL_TEXT)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	if counter == "decloggers":
		EventBus.decloggers_changed.connect(_on_ducks_changed)
	else:
		EventBus.ducks_changed.connect(_on_ducks_changed)


func _on_ducks_changed(total: int) -> void:
	_label.text = str(total)
