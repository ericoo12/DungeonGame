extends EnemyProjectile
class_name MuggBall

var ball_radius: float = 4.0
var ball_color := Color(1.0, 0.55, 0.15)
var homing: bool = false
var target: Node2D
var arena: RoomController
var turn_rate_degrees: float = 85.0
var tracking_duration: float = 1.6
var tracking_delay: float = 0.2
var age: float = 0.0
var tracking_lost: bool = false
var _spent: bool = false

func _ready() -> void:
	collision_layer = 64
	collision_mask = 273 # world, player hurtbox and projectile blockers; green is excluded
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ball_radius
	collision.shape = circle
	add_child(collision)
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().physics_frame
	monitoring = true
	add_to_group("projectiles")

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime or _spent:
		queue_free()
		return
	if homing and not tracking_lost and age < tracking_delay + tracking_duration:
		if not is_instance_valid(target) or (target is Player and target.is_dying):
			tracking_lost = true
		elif is_instance_valid(arena) and not arena.has_clear_sight(global_position, target.global_position):
			tracking_lost = true
		elif age >= tracking_delay:
			var desired := global_position.direction_to(target.global_position)
			# A successful sidestep makes it overshoot instead of circling back.
			if absf(velocity.angle_to(desired)) > deg_to_rad(100.0):
				tracking_lost = true
			else:
				var heading := rotate_toward(velocity.angle(), desired.angle(), deg_to_rad(turn_rate_degrees) * delta)
				velocity = Vector2.from_angle(heading) * speed
	super._physics_process(delta)

func _try_deal_damage(body: Node) -> void:
	if _spent:
		return
	if body.has_method("take_damage") or body.is_in_group("walls") or body.is_in_group("projectile_blockers"):
		_spent = true
		super._try_deal_damage(body)

func _draw() -> void:
	draw_circle(Vector2.ZERO, ball_radius + 1.5, ball_color.darkened(0.4))
	draw_circle(Vector2.ZERO, ball_radius, ball_color)
	draw_circle(Vector2(-ball_radius * 0.25, -ball_radius * 0.25), ball_radius * 0.3, Color.WHITE)
