extends CanvasLayer
class_name HUD

@onready var item_overlay: InventoryOverlay = $ItemOverlay
@onready var debug_stats: Label = $DebugStats
@onready var active_item_icon: TextureRect = $ActiveItemSlot/Icon
@onready var dungeon_map: Control = $DungeonMap

const HEALTH_BAR := preload("res://ui/EnemyHealthBar.gd")
const TRAILER_TOOLS := preload("res://debug/TrailerTools.gd")

## P: freezes the whole game with nothing drawn on top (for screenshots).
var _frozen: bool = false

func _ready() -> void:
	visible = true
	# Item info card (next to items) and pickup banner, under the rest of the HUD.
	var popup := ItemInfoPopup.new()
	add_child(popup)
	move_child(popup, 0)
	var banner := ItemBanner.new()
	add_child(banner)
	move_child(banner, 1)
	item_overlay.visible = false
	HEALTH_BAR.show_all = debug_stats.visible
	dungeon_map.visible = true
	move_child(dungeon_map, item_overlay.get_index())  # under the inventory screen
	if OS.is_debug_build():
		add_child(TRAILER_TOOLS.new())  # F1-F7 recording helpers (debug/TrailerTools.gd)
	EventBus.item_added.connect(_on_item_added)
	EventBus.active_item_changed.connect(_on_active_item_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause") and not item_overlay.visible:
		_frozen = not _frozen
		get_tree().paused = _frozen
		get_viewport().set_input_as_handled()
		return
	if _frozen:
		return  # frozen: nothing else (inventory, debug view) until P again

	if event.is_action_pressed("toggle_items"):
		_toggle_item_overlay()
	elif event.is_action_pressed("ui_cancel") and item_overlay.visible:
		_toggle_item_overlay()

	if event.is_action_pressed("toggle_debug_stats"):
		debug_stats.visible = not debug_stats.visible
		HEALTH_BAR.show_all = debug_stats.visible  # enemy health bars


func _toggle_item_overlay() -> void:
	if item_overlay.visible:
		item_overlay.close()
	else:
		item_overlay.open()
	get_tree().paused = item_overlay.visible


func _on_item_added(item: Item) -> void:
	item_overlay.add_passive(item)


func _on_active_item_changed(item: ActiveItem) -> void:
	active_item_icon.texture = item.icon if item else null
	item_overlay.set_active(item)
