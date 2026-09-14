extends Control
class_name ActiveItemSlotDisplay

@onready var icon: TextureRect = $Icon
@onready var cooldown_overlay: ColorRect = $CooldownOverlay

var player: Player = null


func _ready() -> void:
	EventBus.active_item_changed.connect(_on_active_item_changed)
	icon.visible = false
	cooldown_overlay.visible = false
	call_deferred("_find_player")


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")


func _on_active_item_changed(item: ActiveItem) -> void:
	icon.texture = item.icon
	icon.visible = true
	cooldown_overlay.visible = true


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.active_item:
		return

	var cooldown_fraction: float = 0.0
	if player.active_item.cooldown > 0.0:
		cooldown_fraction = player.active_item_cooldown_timer / player.active_item.cooldown

	# Overlay shrinks from the top down as cooldown counts down —
	# classic "swipe" reveal, fully covered right after use, fully clear when ready.
	cooldown_overlay.anchor_top = 1.0 - cooldown_fraction
