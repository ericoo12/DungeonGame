## Persistent, player-tracking damage beam (TickBeamEffect). Unlike
## LaserBeamVisual, this manages its own live raycast + damage-tick loop every
## frame — length updates continuously so the beam correctly shortens if the
## player moves toward a wall mid-cast, and DamageArea ticks everything
## currently overlapping rather than stopping at the first enemy hit.
extends Node2D
class_name TickBeamVisual

@onready var line: Line2D = $Line2D
@onready var splash_pivot: Node2D = $SplashPivot
@onready var splash_sprite: AnimatedSprite2D = $SplashPivot/SplashSprite
@onready var damage_area: Area2D = $DamageArea
@onready var damage_shape: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var wall_ray: RayCast2D = $WallRay

# Actual per-frame pixel width of the splash sheet (96x64, 2 frames = 48px each).
# Used to pin the splash's wall-facing edge in place while it shrinks — see
# SplashPivot's role in _ready()/_update_beam_geometry().
const SPLASH_FRAME_WIDTH := 6.0

var duration: float = 1.5
var shrink_duration: float = 0.3
var timer: float = 0.0

var damage: float = 0.0
var damage_interval: float = 0.3
var tick_timer: float = 0.0
var overlapping_bodies: Array[Node] = []

var base_width: float = 6.0
var max_range: float = 3000.0


func _ready() -> void:
	damage_area.body_entered.connect(_on_body_entered)
	damage_area.body_exited.connect(_on_body_exited)
	splash_sprite.sprite_frames = AnimSheetLoader.build_single_animation(
		"res://assets/sprites/items/active_items/lazerturdsplash2.png", 2, 12.0
	)
	# Sprite sits fully to the left of SplashPivot's own origin, so the pivot's
	# (0,0) point lines up with the sprite's right (wall-facing) edge — see
	# _update_beam_geometry(), where splash_pivot itself is positioned at the
	# true wall-collision point.
	splash_sprite.position = Vector2(-SPLASH_FRAME_WIDTH / 2.0, 0)


func setup(start: Vector2, direction: Vector2, range_limit: float, width: float, vis_duration: float, dmg: float, tick_interval: float, shrink_time: float = 0.3) -> void:
	global_position = start
	rotation = direction.angle()
	max_range = range_limit

	base_width = width
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	wall_ray.target_position = Vector2(max_range, 0)

	duration = vis_duration
	shrink_duration = min(shrink_time, vis_duration)
	damage = dmg
	damage_interval = tick_interval

	_update_beam_geometry()


func _physics_process(delta: float) -> void:
	timer += delta
	var time_remaining: float = duration - timer

	_update_beam_geometry()

	# Beam holds at full size until the final shrink_duration seconds, then
	# tapers to nothing — reads as "the jet runs dry" rather than fading.
	if time_remaining <= shrink_duration:
		var shrink_progress: float = 1.0 - (time_remaining / shrink_duration)
		line.width = base_width * (1.0 - shrink_progress)
		splash_pivot.scale = Vector2.ONE * (1.0 - shrink_progress)
	else:
		line.width = base_width
		splash_pivot.scale = Vector2.ONE

	if overlapping_bodies.size() > 0 and damage > 0.0:
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = damage_interval
			for body in overlapping_bodies:
				if is_instance_valid(body) and body.has_method("take_damage"):
					body.take_damage(damage)

	if timer >= duration:
		queue_free()


func _update_beam_geometry() -> void:
	wall_ray.force_raycast_update()

	var length: float = max_range
	var did_hit := false
	if wall_ray.is_colliding():
		length = wall_ray.global_position.distance_to(wall_ray.get_collision_point())
		did_hit = true

	line.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0)])

	var shape := damage_shape.shape as RectangleShape2D
	shape.size = Vector2(length, base_width)
	damage_area.position = Vector2(length / 2.0, 0)

	splash_pivot.position = Vector2(length, 0)
	splash_pivot.visible = did_hit
	if did_hit and not splash_sprite.is_playing():
		splash_sprite.play("splash")


func _on_body_entered(body: Node) -> void:
	overlapping_bodies.append(body)
	if damage > 0.0 and body.has_method("take_damage"):
		tick_timer = damage_interval
		body.take_damage(damage)


func _on_body_exited(body: Node) -> void:
	overlapping_bodies.erase(body)
