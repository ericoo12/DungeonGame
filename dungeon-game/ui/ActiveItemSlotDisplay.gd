extends Control
class_name ActiveItemSlotDisplay

## Active item icon (top left) + its charge bar to the right of it.
## The bar always has the same size (as tall as the icon): it's split into one
## square segment per max charge, so 1 charge = one tall block, 3 = three smaller ones.

@export var bar_gap: float = 2.0          # space between icon and bar
@export var bar_width: float = 8.0
@export var segment_gap: float = 2.0      # space between segments
@export var filled_color: Color = Color(0.45, 0.78, 0.62)  # UIStyle.COL_ACTIVE
@export var empty_color: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.9)

@onready var icon: TextureRect = $Icon
@onready var cooldown_overlay: ColorRect = $CooldownOverlay

var player: Player = null
var charges: int = 0
var max_charges: int = 0


func _ready() -> void:
	EventBus.active_item_changed.connect(_on_active_item_changed)
	EventBus.active_item_charges_changed.connect(_on_charges_changed)
	icon.visible = false
	cooldown_overlay.visible = false
	call_deferred("_find_player")


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")


func _on_active_item_changed(item: ActiveItem) -> void:
	icon.texture = item.icon if item else null
	icon.visible = item != null
	cooldown_overlay.visible = item != null


func _on_charges_changed(new_charges: int, new_max: int) -> void:
	charges = new_charges
	max_charges = new_max
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.active_item:
		return

	var cooldown_fraction: float = 0.0
	if player.active_item.cooldown > 0.0:
		cooldown_fraction = player.active_item_cooldown_timer / player.active_item.cooldown

	# Overlay = how far from usable: covers the part of the icon that still needs
	# charging (shrinks from the top as charges come in), fully clear when full.
	var missing: float = 1.0 - float(charges) / float(maxi(max_charges, 1))
	cooldown_overlay.anchor_top = 1.0 - maxf(missing, cooldown_fraction)


## Charge bar, drawn to the right of the icon. Fills from the bottom up.
func _draw() -> void:
	if max_charges <= 0:
		return
	var height: float = icon.size.y
	var x: float = icon.position.x + icon.size.x + bar_gap
	var top: float = icon.position.y
	var seg_h: float = (height - segment_gap * (max_charges - 1)) / max_charges
	for i in max_charges:
		# i = 0 is the bottom segment
		var y: float = top + height - (i + 1) * seg_h - i * segment_gap
		var rect := Rect2(x, y, bar_width, seg_h)
		draw_rect(rect, filled_color if i < charges else empty_color)
		draw_rect(rect, border_color, false, 1.0)
