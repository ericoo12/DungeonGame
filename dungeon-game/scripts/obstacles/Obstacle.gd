class_name Obstacle
extends StaticBody2D

## Placed at runtime by RoomController._spawn_obstacles() on obstacle_spawn_points markers.
## Occupies exactly one 16x16 wall-grid cell (RoomGrid assumes this).
## collision_layer is set in the scene to 1 (world) + 8 (same bit the wall tiles use for
## projectiles), so player, enemies, and both projectile types all collide with it.
## take_damage() exists on every obstacle so Projectile._try_deal_damage() "just works":
## projectiles land on solid obstacles the same way they land on walls.

signal broken

@export var breakable: bool = true
## Breakables count HITS, not damage: every projectile / laser shot / beam tick is one hit,
## no matter how much damage the player does.
@export var hits_to_break: int = 3
## Optional: spawned where the obstacle broke. Empty = no drop.
@export var drop_scene: PackedScene
## Damage states: number of horizontal frames in the sprite sheet (Sprite2D.hframes).
## 1 = no damage states. Frames go from intact (0) to most damaged.
@export var damage_frames: int = 1
## If true, the LAST frame is a broken pile that stays on the floor (no collision)
## instead of the obstacle disappearing. Also shown on revisits.
@export var leave_remains: bool = false

var hits_left: int
var _is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("obstacles")  # stays in the group as remains too, so Dungeon cleans it up
	hits_left = hits_to_break
	sprite.hframes = maxi(damage_frames, 1)
	_update_damage_frame()


func take_damage(_amount: float, _knockback_dir: Vector2 = Vector2.ZERO, _knockback_strength: float = 0.0) -> void:
	if not breakable or _is_broken:
		return
	hits_left -= 1
	if hits_left <= 0:
		_break()
	else:
		_update_damage_frame()
		_hit_flash()


## Frames before the remains frame are spread evenly over the hits.
## (multiply before dividing so e.g. 3 hits / 3 frames lands exactly one frame per hit)
func _update_damage_frame() -> void:
	var alive_frames := damage_frames - (1 if leave_remains else 0)
	if alive_frames <= 1 or hits_to_break <= 0:
		return
	var frame := alive_frames - ceili(float(hits_left * alive_frames) / hits_to_break)
	sprite.frame = clampi(frame, 0, alive_frames - 1)


func _hit_flash() -> void:
	sprite.modulate = Color(1.8, 1.8, 1.8)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _break() -> void:
	_is_broken = true
	broken.emit()
	if drop_scene:
		var drop: Node2D = drop_scene.instantiate()
		drop.position = position
		# Deferred: _break() usually runs inside a physics callback (projectile hit).
		get_parent().add_child.call_deferred(drop)
	if leave_remains:
		show_as_broken()
	else:
		queue_free()


## Turns this into floor debris: last frame, no collision, can't be hit.
## Called on break, and by RoomController when revisiting a room with a broken one.
func show_as_broken() -> void:
	_is_broken = true
	hits_left = 0
	sprite.frame = maxi(damage_frames, 1) - 1
	collision_shape.set_deferred("disabled", true)
	# Move the y-sort anchor to the top of the pile so the player draws over it
	# when standing on it, and behind it only when standing above it.
	position.y -= 8.0
	sprite.position.y += 8.0
