## A wall of hair the Great Clog grows across part of its room (phase 1-2), cutting the
## room down for a while. Grows in (thin strands = warning, walk-through), then turns
## solid. Shoot it to tear it down early, otherwise it withers after `lifetime`.
## Player shots hit it like an obstacle (layer 1|8, take_damage); enemies bump into it.
extends StaticBody2D
class_name ClogHairWall

@export var health: float = 10.0
@export var grow_time: float = 0.9
@export var lifetime: float = 6.5
@export var hair_color: Color = Color(0.36, 0.25, 0.16)
@export var hair_light: Color = Color(0.58, 0.45, 0.3)

var size: Vector2 = Vector2(12, 160)   # local, centered
var _t: float = 0.0
var _solid: bool = false
var _dying: float = -1.0
var _flash: float = 0.0
var _shape: CollisionShape2D
var _seeds: Array = []


func _ready() -> void:
	add_to_group("room_effects")
	collision_layer = 0
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.disabled = true
	add_child(_shape)
	for i in int(size.length() / 3.0):
		_seeds.append(Vector2(randf_range(-size.x / 2.0, size.x / 2.0), randf_range(-size.y / 2.0, size.y / 2.0)))


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if not _solid and _dying < 0.0 and _t >= grow_time:
		_go_solid()
	if _solid and _t >= grow_time + lifetime:
		_wither()
	if _dying >= 0.0:
		_dying += delta
		if _dying >= 0.4:
			queue_free()
			return
	queue_redraw()


func _go_solid() -> void:
	_solid = true
	collision_layer = 1 | 8   # world (blocks walking) + hit by player shots
	_shape.set_deferred("disabled", false)
	# Don't trap the player inside it: shove them to the nearer side.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var local := to_local(player.global_position)
		var half := size / 2.0 + Vector2(7, 7)
		if absf(local.x) < half.x and absf(local.y) < half.y:
			if half.x - absf(local.x) < half.y - absf(local.y):
				local.x = half.x * (1.0 if local.x >= 0.0 else -1.0)
			else:
				local.y = half.y * (1.0 if local.y >= 0.0 else -1.0)
			player.global_position = to_global(local)


func _wither() -> void:
	if _dying >= 0.0:
		return
	_dying = 0.0
	_solid = false
	collision_layer = 0
	_shape.set_deferred("disabled", true)


func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO, _strength: float = 0.0) -> void:
	if not _solid:
		return
	health -= amount
	_flash = 0.08
	if health <= 0.0:
		_wither()


func _draw() -> void:
	var grow := clampf(_t / grow_time, 0.0, 1.0)
	var fade := 1.0 - clampf(_dying / 0.4, 0.0, 1.0) if _dying >= 0.0 else 1.0
	var alpha := (0.35 + 0.65 * float(_solid or _dying >= 0.0)) * fade
	if not _solid and _dying < 0.0:
		draw_rect(Rect2(-size / 2.0, size), Color(1.0, 0.3, 0.2, 0.12 + 0.08 * sin(_t * 16.0)))
	var long_axis_y := size.y >= size.x
	for i in _seeds.size():
		var s: Vector2 = _seeds[i]
		var stroke := (size.y if long_axis_y else size.x) * 0.18 * grow
		var a := s - (Vector2(0, stroke) if long_axis_y else Vector2(stroke, 0)) * 0.5
		var b := a + (Vector2(sin(i + _t * 3.0) * 2.0, stroke) if long_axis_y else Vector2(stroke, sin(i + _t * 3.0) * 2.0))
		var col := (hair_color if i % 2 == 0 else hair_light)
		if _flash > 0.0:
			col = Color(1.0, 0.6, 0.6)
		draw_line(a, b, Color(col, alpha), 1.5)
