## An item for sale in the shop: icon floating on a table marker, price below it.
## Walk into it with enough ducks to buy it. Not enough -> price flashes red and
## the item shakes; walk out and back in to try again.
extends Area2D
class_name ShopItem

signal purchased

@export var display_size: float = 16.0     # icon size in px (largest side)
## How far from the marker the player can be and still buy (px). Bigger than the
## icon on purpose: the items sit on the table, which the player can't walk onto.
## When the player touches two at once, only the CLOSEST one sells (_physics_process).
@export var reach_radius: float = 14.0
@export var bob_height: float = 1.5
@export var bob_period: float = 1.6
@export var price_color: Color = Color(0.95, 0.88, 0.45)
@export var cant_afford_color: Color = Color(0.88, 0.48, 0.42)

const DUCK_ICON := preload("res://assets/sprites/pickups/ducks/duck_1.png")
	## Loaded at runtime (not preload) so a missing/unimported icon can't stop the script compiling.
const DECLOGGER_ICON_PATH := "res://assets/sprites/pickups/declogger/declogger.png"
## World-space text: big font scaled down stays crisp under the 3x camera zoom.
const LABEL_FONT_SIZE := 24
const LABEL_SCALE := 0.25

var item: ItemBase
var price: int = 0
var decloggers: int = 0  # > 0: sells decloggers instead of an item

var _icon: Sprite2D
var _price_root: Node2D
var _label: Label
var _sold: bool = false
var _player_inside: Player = null
var _tried: bool = false   # one buy attempt per visit (walk out and back in to retry)
## Set after a purchase; cleared once the player has touched no shop item for a moment.
static var _purchase_lock: bool = false
static var _clear_since_ms: int = 0


func setup(new_item: ItemBase, new_price: int, new_decloggers: int = 0) -> void:
	item = new_item
	price = new_price
	decloggers = new_decloggers


func _ready() -> void:
	add_to_group("item_pickups")  # Dungeon._load_room() clears this group on room change
	add_to_group("item_info_sources")  # ItemInfoPopup shows what it is when you're close
	collision_layer = 0
	collision_mask = 2            # player body

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = reach_radius
	shape.shape = circle
	add_child(shape)

	_build_icon()
	_build_price()
	_update_affordable()

	add_to_group("shop_items")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.ducks_changed.connect(_on_ducks_changed)  # method, so it auto-disconnects on free


func _build_icon() -> void:
	_icon = Sprite2D.new()
	_icon.z_index = 1
	var tex: Texture2D = null
	if decloggers > 0:
		tex = load(DECLOGGER_ICON_PATH) as Texture2D
	elif item:
		tex = item.icon
	if tex:
		_icon.texture = tex
		var s := tex.get_size()
		_icon.scale = Vector2.ONE * (display_size / maxf(s.x, s.y))
	add_child(_icon)
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_icon, "position:y", -bob_height, bob_period / 2.0)
	tween.tween_property(_icon, "position:y", bob_height, bob_period / 2.0)


## "[duck] 7" centred under the item.
func _build_price() -> void:
	_price_root = Node2D.new()
	_price_root.position = Vector2(0, display_size * 0.5 + 6)
	_price_root.z_index = 2
	add_child(_price_root)

	var duck := Sprite2D.new()
	duck.texture = DUCK_ICON
	duck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ds := DUCK_ICON.get_size()
	duck.scale = Vector2.ONE * (6.0 / maxf(ds.x, ds.y))
	duck.position = Vector2(-5, 0)
	_price_root.add_child(duck)

	_label = Label.new()
	_label.text = str(price)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.scale = Vector2.ONE * LABEL_SCALE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Left edge just right of the duck, vertically centred on it.
	_label.position = Vector2(-1, -LABEL_FONT_SIZE * LABEL_SCALE * 0.7)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_root.add_child(_label)


func _on_ducks_changed(_total: int) -> void:
	_update_affordable()


func _update_affordable() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var can := player != null and player.ducks >= price
	_label.add_theme_color_override("font_color", price_color if can else cant_afford_color)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player:
		_player_inside = player
		_tried = false


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
		_tried = false


func _physics_process(_delta: float) -> void:
	if _purchase_lock:
		var now := Time.get_ticks_msec()
		if _player_touches_any():
			_clear_since_ms = now
		elif now - _clear_since_ms > 350:
			_purchase_lock = false
	if _player_inside == null or _tried or _sold or _purchase_lock or not is_instance_valid(_player_inside):
		return
	if not _is_closest_to(_player_inside):
		return
	_tried = true
	_try_buy(_player_inside)


func _player_touches_any() -> bool:
	for other in get_tree().get_nodes_in_group("shop_items"):
		if is_instance_valid(other) and not other._sold and other._player_inside != null:
			return true
	return false


## Only the item nearest to the player sells, so standing between two never buys both
## (or the one you weren't going for).
func _is_closest_to(player: Player) -> bool:
	var my_d := global_position.distance_to(player.global_position)
	for other in get_tree().get_nodes_in_group("shop_items"):
		if other != self and is_instance_valid(other) and not other._sold \
				and other.global_position.distance_to(player.global_position) < my_d:
			return false
	return true


func _try_buy(player: Player) -> void:
	if _sold or (item == null and decloggers <= 0):
		return
	if not player.spend_ducks(price):
		_deny()
		return

	_sold = true
	if decloggers > 0:
		player.add_decloggers(decloggers)
	elif item is ActiveItem:
		var previous: ActiveItem = player.add_active_item(item as ActiveItem)
		if previous:  # the old one is put down just above the counter, not lost
			ItemPickup.drop_active(get_parent(), previous, player.last_dropped_active_charges,
				global_position + Vector2(0, -24))
	elif item is Item:
		player.add_item(item as Item)
	purchased.emit()
	# Nothing else sells until you've stepped away from every item on the table, so one
	# walk into the table never buys two things.
	_purchase_lock = true
	_clear_since_ms = Time.get_ticks_msec()
	queue_free()


## Can't afford: quick shake + red flash on the price.
func _deny() -> void:
	var tween := create_tween()
	for x in [3.0, -3.0, 2.0, -2.0, 0.0]:
		tween.tween_property(_icon, "position:x", x, 0.04)
	_label.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(_label, "modulate", Color.WHITE, 0.3)
