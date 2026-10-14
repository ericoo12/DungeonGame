extends EnemyProjectile
class_name MuggBall

const CLEAN_ROLL = preload("res://assets/sprites/projectiles/white-paper-roll.png")
const STAINED_ROLL = preload("res://assets/sprites/projectiles/stained-roll.png")
## Cosmetic tumbling only: degrees per second, with a different phase per roll.
@export var spin_speed_degrees: float = 420.0
@export_range(0.0, 1.0) var spin_variation: float = 0.25
var _visual_angle: float = 0.0
var _spin_rate: float = 0.0
var stained: bool = false
var trail_damage: float = 0.5
var trail_lifetime: float = 1.0
var trail_width: float = 8.0
var paper_trail: MuggPaperTrail
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
	_visual_angle = randf_range(-PI, PI)
	_spin_rate = deg_to_rad(spin_speed_degrees) * randf_range(1.0 - spin_variation, 1.0 + spin_variation)
	if randf() < 0.5:
		_spin_rate = -_spin_rate
	collision_layer = 64
	collision_mask = 401 if homing else 273 # Homing rolls also hit movement blockers (128).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if homing:
		paper_trail = MuggPaperTrail.new()
		paper_trail.damage = trail_damage
		paper_trail.segment_lifetime = trail_lifetime
		paper_trail.width = trail_width
		get_parent().add_child.call_deferred(paper_trail)
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
	# Rotate only the drawing; collision shape, aim and trail stay in world space.
	_visual_angle = wrapf(_visual_angle + _spin_rate * delta, -PI, PI)
	queue_redraw()
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
	var start := global_position
	var motion := velocity * delta
	# Sweep the footprint so fast rolls cannot tunnel through blocks or players.
	var shape := CircleShape2D.new()
	shape.radius = ball_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, start)
	query.motion = motion
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var fraction := space.cast_motion(query)
	global_position = start + motion * fraction[0]
	if homing and is_instance_valid(paper_trail) and paper_trail.is_inside_tree():
		paper_trail.add_segment(start, global_position)
	if fraction[0] < 1.0:
		query.transform.origin = start + motion * minf(1.0, fraction[1] + 0.001)
		query.motion = Vector2.ZERO
		for hit in space.intersect_shape(query):
			var body: Node = hit.collider
			_try_deal_damage(body.get_parent() if body is Area2D else body)
		_spent = true
		queue_free()

func _try_deal_damage(body: Node) -> void:
	if _spent:
		return
	if homing and body is PhysicsBody2D and (body.collision_layer & 128) != 0:
		_spent = true
		queue_free()
		return
	if body.has_method("take_damage") or body.is_in_group("walls") or body.is_in_group("projectile_blockers"):
		_spent = true
		super._try_deal_damage(body)

func _draw() -> void:
	# Crop the generated canvas padding without modifying the source images.
	var texture := STAINED_ROLL if stained else CLEAN_ROLL
	var source := Rect2(360, 330, 535, 630) if stained else Rect2(385, 275, 545, 710)
	var height := ball_radius * 3.2
	var size := Vector2(height * source.size.x / source.size.y, height)
	draw_set_transform(Vector2.ZERO, _visual_angle)
	draw_texture_rect_region(texture, Rect2(-size * 0.5, size), source)
	draw_set_transform(Vector2.ZERO)
