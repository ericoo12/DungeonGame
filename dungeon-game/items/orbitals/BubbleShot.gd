## Little soap bubble flung out when the Soap Bubble orbital pops: flies straight out,
## hurts the first enemy it touches a bit, pops on walls / at the end of its range.
extends Area2D
class_name BubbleShot

const TEX := preload("res://assets/sprites/items/icons/soap_bubble.png")

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.5
var max_range: float = 70.0
var size_px: float = 6.0
var _travelled: float = 0.0
var _done: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("room_effects")
	collision_layer = 0
	collision_mask = 1 | 4        # walls/obstacles + enemy bodies
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size_px * 0.5
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.scale = Vector2.ONE * (size_px / float(TEX.get_width()))
	_sprite.modulate = Color(1, 1, 1, 0.9)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := velocity * delta
	global_position += step
	_travelled += step.length()
	_sprite.position.y = sin(_travelled * 0.25) * 0.8  # light wobble
	if _travelled >= max_range:
		_burst()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body is EnemyBase or body is FinalBossBase:
		if body.has_method("take_damage"):
			body.take_damage(damage, velocity.normalized(), 30.0)
		_burst()
	elif body is StaticBody2D:
		_burst()


func _burst() -> void:
	_done = true
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * 1.8, 0.12)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
