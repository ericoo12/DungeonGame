## One altar in the Challenge Room: stand on it for `hold_time` seconds to sacrifice
## what it asks for (a ring fills up while you stand there, step off to cancel).
##   HEART  - one max heart for good (needs 2+ max hearts).
##   DUCKS  - all your ducks (needs at least min_ducks).
##   ACTIVE - your active item.
## The ChallengeRoom listens to `sacrificed` and starts the waves.
extends Node2D
class_name SacrificeAltar

signal sacrificed(kind: int)

enum Kind { HEART, DUCKS, ACTIVE }

const PEDESTAL := preload("res://assets/sprites/objects/bathroom_pedestal.png")
const HEART_ICON := preload("res://assets/sprites/pickups/hearts/heart.png")
const DUCK_ICON := preload("res://assets/sprites/pickups/ducks/duck_10.png")
const LABEL_FONT_SIZE := 24
const LABEL_SCALE := 0.25
const COL_OK := Color(0.95, 0.88, 0.45)
const COL_NO := Color(0.88, 0.48, 0.42)

@export var kind: Kind = Kind.HEART
@export var hold_time: float = 1.0
@export var reach: float = 13.0
@export var min_ducks: int = 10
@export var icon_size: float = 14.0
## Text under the altar (cost, or why you can't pay). Off by default: the icon says what
## it takes, and it's dimmed when you can't pay it.
@export var show_label: bool = false

var _icon: Sprite2D
var _label: Label
var _hold: float = 0.0
var _done: bool = false
var _bob: float = 0.0


func _ready() -> void:
	var pedestal := Sprite2D.new()
	pedestal.texture = PEDESTAL
	pedestal.position = Vector2(0, 4)
	pedestal.scale = Vector2(0.1, 0.1)
	pedestal.modulate = Color(1.0, 0.6, 0.6)  # blood-red stone
	add_child(pedestal)

	_icon = Sprite2D.new()
	_icon.z_index = 1
	_icon.position = Vector2(0, -8)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_icon)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.scale = Vector2.ONE * LABEL_SCALE
	_label.size = Vector2(240, 30)
	_label.position = Vector2(-120 * LABEL_SCALE, 14)
	_label.z_index = 2
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = show_label
	add_child(_label)
	_refresh()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Can the player pay this right now? Returns "" if yes, else why not.
func why_not(player: Player) -> String:
	if player == null:
		return "?"
	match kind:
		Kind.HEART:
			if player.max_hearts < 2:
				return "Need 2+ hearts"
		Kind.DUCKS:
			if player.ducks < min_ducks:
				return "Need %d ducks" % min_ducks
		Kind.ACTIVE:
			if player.active_item == null:
				return "No active item"
	return ""


func _refresh() -> void:
	var player := _player()
	var tex: Texture2D = HEART_ICON
	var text := "-1 max heart"
	match kind:
		Kind.DUCKS:
			tex = DUCK_ICON
			text = "All ducks" + (" (%d)" % player.ducks if player else "")
		Kind.ACTIVE:
			tex = player.active_item.icon if player and player.active_item else null
			text = "Your active item"
	var reason := why_not(player)
	if reason != "":
		text = reason
	_icon.texture = tex
	if tex:
		var s := tex.get_size()
		_icon.scale = Vector2.ONE * (icon_size / maxf(s.x, s.y))
	_icon.modulate = Color(1, 1, 1, 0.35) if reason != "" else Color.WHITE
	_label.text = text
	_label.add_theme_color_override("font_color", COL_NO if reason != "" else COL_OK)


func _process(delta: float) -> void:
	if _done:
		return
	_bob += delta
	_icon.position.y = -8 + sin(_bob * 3.0) * 1.0
	_refresh()
	var player := _player()
	var standing := player != null and player.global_position.distance_to(global_position + Vector2(0, 4)) < reach
	if standing and why_not(player) == "":
		_hold += delta
		if _hold >= hold_time:
			_done = true
			_pay(player)
			sacrificed.emit(kind)
	else:
		_hold = maxf(_hold - delta * 3.0, 0.0)
	queue_redraw()


func _pay(player: Player) -> void:
	match kind:
		Kind.HEART:
			player.max_hearts -= 1
			player.current_hearts = minf(player.current_hearts, float(player.max_hearts))
			EventBus.player_health_changed.emit(player.current_hearts, player.max_hearts)
		Kind.DUCKS:
			player.ducks = 0
			EventBus.ducks_changed.emit(0)
		Kind.ACTIVE:
			player.remove_active_item()


## Progress ring while standing on it.
func _draw() -> void:
	if _hold <= 0.0 or _done:
		return
	var t := clampf(_hold / hold_time, 0.0, 1.0)
	draw_arc(Vector2(0, -8), 10.0, -PI / 2.0, -PI / 2.0 + TAU * t, 32, Color(0.95, 0.25, 0.2), 2.0)
