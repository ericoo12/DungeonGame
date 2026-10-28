## Base for every floor pickup (hearts, ducks, plungers). A small physics body that
## slides and bounces off walls, gets pushed by the player and knocked by enemy shots and
## explosions, with fake height: it pops out when spawned, bounces when it lands, and
## its shadow stays on the ground.
##
## Scene layout (see HeartPickup.tscn):
##   PhysicsPickup (CharacterBody2D)  <- collides with walls/obstacles (small circle)
##     CollisionShape2D
##     PickupArea (Area2D)            <- touches the player / shots (bigger circle)
##       CollisionShape2D
##     Visual (Node2D)                <- lifted by the height, squashed on landing
##       Sprite2D
## Subclasses implement can_collect(player) and collect(player).
extends CharacterBody2D
class_name PhysicsPickup

signal collected
## Came to rest after moving. RoomBase saves the new spot so it's there on revisits.
signal settled

const SHADOW_TEXTURE := preload("res://assets/sprites/player/shadow.png")
const WORLD_MASK := 1 | 8 | 128   # walls + obstacles, the room's outer box, door blockers
const TOUCH_MASK := 2 | 64        # player, enemy shots (player shots pass through pickups)

@export_group("Movement")
## Slowdown while sliding on the floor (px/s per second).
@export var friction: float = 260.0
## Slowdown while in the air.
@export var air_drag: float = 30.0
## Share of the speed kept when it hits a wall.
@export_range(0.0, 1.0) var wall_bounce: float = 0.55
## Speed it's kicked away at when the player walks into it (and can't pick it up).
@export var push_speed: float = 95.0
## Push from an enemy shot passing through it (player shots pass through without moving it).
@export var shot_knock: float = 70.0
## Heavier = pushed and knocked less.
@export var mass: float = 1.0

@export_group("Height")
@export var gravity: float = 520.0
## Share of the falling speed kept on each landing bounce.
@export_range(0.0, 1.0) var bounce: float = 0.45
## Can only be grabbed while lower than this (px).
@export var pickup_height: float = 6.0
## Can't be grabbed right after popping out, so you see it fly.
@export var pickup_delay: float = 0.35

@export_group("Look")
## On-screen size in px (largest side of the texture). 0 = keep the sprite's scale.
@export var display_size: float = 12.0
@export var bob_height: float = 1.0
@export var bob_period: float = 1.2
## Shadow width in px on the ground.
@export var shadow_width: float = 10.0
@export_group("")

## Global floor area it has to stay in (RoomBase.get_floor_rect(), set on spawn), so it
## can't be pushed into a doorway. Empty = no limit (e.g. the test rooms).
var floor_bounds: Rect2 = Rect2()
var height: float = 0.0          # px above the ground
var vertical_speed: float = 0.0  # px/s, up is positive

var _delay: float = 0.0
var _moving: bool = false
var _taken: bool = false
var _bob_time: float = 0.0
var _shadow: Sprite2D
var _shadow_base_scale: float = 1.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var area: Area2D = $PickupArea


func _ready() -> void:
	add_to_group("item_pickups")    # Dungeon._load_room() clears this group on room change
	add_to_group("physics_pickups") # Explosion.gd knocks these around
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0             # nothing bumps into pickups, they only bump into walls
	collision_mask = WORLD_MASK
	area.collision_layer = 0
	area.collision_mask = TOUCH_MASK
	area.monitorable = false
	area.area_entered.connect(_on_area_entered)

	if display_size > 0.0 and sprite.texture:
		var tex_size := sprite.texture.get_size()
		sprite.scale = Vector2.ONE * (display_size / maxf(tex_size.x, tex_size.y))
	# Big art shrunk this much shimmers with nearest filtering; mipmaps keep it clean.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.texture = SHADOW_TEXTURE
	_shadow.modulate = Color(1, 1, 1, 0.45)
	_shadow_base_scale = shadow_width / SHADOW_TEXTURE.get_width()
	_shadow.scale = Vector2.ONE * _shadow_base_scale
	_shadow.position = Vector2(0, _ground_offset())
	add_child(_shadow)
	move_child(_shadow, 0)  # drawn first = under the sprite
	_bob_time = randf() * bob_period
	_update_visual(0.0)


# --- Things that move it -------------------------------------------------------------

## Fly out in an arc (new drops). Random direction unless one is given.
func pop(direction: Vector2 = Vector2.ZERO, speed: float = -1.0, lift: float = -1.0) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = direction.normalized() * (speed if speed >= 0.0 else randf_range(35.0, 75.0))
	vertical_speed = lift if lift >= 0.0 else randf_range(110.0, 150.0)
	height = maxf(height, 0.01)
	_delay = pickup_delay
	_moving = true


## Push (explosions, shots). lift > 0 also hops it into the air.
func knock(impulse: Vector2, lift: float = 0.0) -> void:
	velocity += impulse / mass
	if lift > 0.0:
		vertical_speed = maxf(vertical_speed, lift / mass)
		height = maxf(height, 0.01)
	_moving = true


# --- Subclass hooks --------------------------------------------------------------------

func can_collect(_player: Player) -> bool:
	return true


func collect(_player: Player) -> void:
	pass


# --- Simulation ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_delay -= delta
	_update_height(delta)

	var decel := friction if height <= 0.0 else air_drag
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)
	if velocity != Vector2.ZERO:
		var hit := move_and_collide(velocity * delta)
		if hit:
			velocity = velocity.bounce(hit.get_normal()) * wall_bounce
	_keep_on_floor()

	_touch_player()
	if _taken:
		return

	var resting := velocity.length() < 1.0 and height <= 0.0
	if resting:
		velocity = Vector2.ZERO
		if _moving:
			_moving = false
			settled.emit()
	else:
		_moving = true
	_update_visual(delta)


func _update_height(delta: float) -> void:
	if height <= 0.0 and vertical_speed <= 0.0:
		return
	vertical_speed -= gravity * delta
	height += vertical_speed * delta
	if height > 0.0:
		return
	height = 0.0
	if vertical_speed < -60.0:
		vertical_speed = -vertical_speed * bounce
		height = 0.01
		_squash(clampf(-vertical_speed / 200.0, 0.1, 0.35))
	else:
		vertical_speed = 0.0


## Bounces back off the edges of floor_bounds (doorways are outside it).
func _keep_on_floor() -> void:
	if not floor_bounds.has_area():
		return
	var margin := 4.0
	var area_rect := floor_bounds.grow(-margin)
	var pos := global_position
	if pos.x < area_rect.position.x:
		pos.x = area_rect.position.x; velocity.x = absf(velocity.x) * wall_bounce
	elif pos.x > area_rect.end.x:
		pos.x = area_rect.end.x; velocity.x = -absf(velocity.x) * wall_bounce
	if pos.y < area_rect.position.y:
		pos.y = area_rect.position.y; velocity.y = absf(velocity.y) * wall_bounce
	elif pos.y > area_rect.end.y:
		pos.y = area_rect.end.y; velocity.y = -absf(velocity.y) * wall_bounce
	if pos != global_position:
		global_position = pos


func _touch_player() -> void:
	for body in area.get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		if not _taken and _delay <= 0.0 and height < pickup_height and can_collect(player):
			_taken = true
			collect(player)
			collected.emit()
			queue_free()
			return
		_push_from(player)


## Kicked away from the player, at least as fast as they walk into it. Measured from the
## player's FEET (body collision), not the player's origin, which sits higher up the body
## - otherwise walking north into a pickup counted as touching it from above and kicked it
## south. Mostly goes the way the player walks, with a bit of "away" so it slides off.
func _push_from(player: Player) -> void:
	var feet: Vector2 = player.body_collision.global_position if player.body_collision else player.global_position
	var away := global_position - feet
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var dir := away.normalized()
	if player.velocity.length() > 10.0:
		var walk := player.velocity.normalized()
		dir = (walk * 0.75 + dir * 0.25).normalized()
	var speed := maxf(push_speed, player.velocity.length() * 1.15) / mass
	var along := velocity.dot(dir)
	if along < speed:
		velocity += dir * (speed - along)
	_moving = true


func _on_area_entered(other: Area2D) -> void:
	var dir := Vector2.ZERO
	if "velocity" in other and other.get("velocity") is Vector2:  # enemy shots
		dir = other.get("velocity")
	if dir != Vector2.ZERO:
		knock(dir.normalized() * shot_knock, 40.0)


# --- Look ------------------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	var bob := 0.0
	if height <= 0.0 and not _moving:
		_bob_time += delta
		bob = sin(_bob_time / bob_period * TAU) * bob_height
	visual.position = Vector2(0.0, -height + bob)
	# Shadow shrinks and fades as it rises.
	var t := clampf(height / 40.0, 0.0, 1.0)
	_shadow.scale = Vector2.ONE * _shadow_base_scale * lerpf(1.0, 0.55, t)
	_shadow.modulate.a = lerpf(0.45, 0.2, t)


func _squash(amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(1.0 + amount, 1.0 - amount), 0.05)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Where the bottom of the sprite touches the floor, relative to the body.
func _ground_offset() -> float:
	if sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().y * sprite.scale.y * 0.45
