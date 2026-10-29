extends Node2D
class_name MuggAreaAttack

# Lobbed area denial - the cistern bomb: Mugg throws a cracked cistern at the locked
# spot, it lands and blinks faster and faster (the warning), then bursts
# into a swirling puddle that hurts while you stand in it and drains away at the end.
# Parent is the boss, so room removal/death also removes outstanding hazards.
# MuggCombat drives it: warning_progress (0..1) during the warning, then arm().
# Art: assets/sprites/enemies/doktor_mugg/bomb/ (128 px frame strips).
var radius: float = 60.0
var damage: float = 1.0
var duration: float = 1.4
var armed: bool = false
var elapsed: float = 0.0
var tick_remaining: float = 0.0
var warning_progress: float = 0.0

const ART := "res://assets/sprites/enemies/doktor_mugg/bomb/cistern_bomb_"
const CELL := 128
## Part of the warning spent in the air (the rest it sits there blinking).
const FLIGHT_PART := 0.22
const ARC_HEIGHT := 70.0
## On-screen sizes (world px) of the art.
const BOMB_SIZE := 34.0          # the cistern, flying / landed
const DRAIN_TIME := 0.35         # end of the puddle: drains away
## Width of the puddle in its 128 px frames (puddle_v2): scaled so it covers the area.
const PUDDLE_ART_WIDTH := 72.0

var _from: Vector2 = Vector2.ZERO   # thrower position (global), taken when spawned
var _bomb: AnimatedSprite2D         # flying + landed (above the floor)
var _shadow_t: float = 0.0
var _ground: AnimatedSprite2D       # explosion + puddle + drain
var _t: float = 0.0


func _ready() -> void:
	var parent := get_parent() as Node2D
	_from = (parent.global_position if parent else global_position) + Vector2(0, -18)  # from his hands
	z_index = -1                  # the ring/shadow drawn here lie on the floor
	z_as_relative = false
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "fly", "projectile", 4, 14.0, true)
	_add_anim(frames, "blink", "warning", 4, 6.0, true)
	_add_anim(frames, "explode", "explosion", 6, 16.0, false)
	_add_anim(frames, "puddle", "puddle_v2", 4, 7.0, true)
	_add_anim(frames, "drain", "drain_v3", 3, 3.0 / DRAIN_TIME, false)

	_ground = AnimatedSprite2D.new()
	_ground.sprite_frames = frames
	_ground.z_index = -1          # on the floor, under the player and enemies
	_ground.z_as_relative = false
	_ground.visible = false
	add_child(_ground)

	_bomb = AnimatedSprite2D.new()
	_bomb.sprite_frames = frames
	_bomb.z_index = 5             # in the air / standing on the floor, over things
	_bomb.z_as_relative = false
	_bomb.scale = Vector2.ONE * (BOMB_SIZE / 88.0)
	_bomb.play("fly")
	add_child(_bomb)
	_place_bomb()


static func _add_anim(frames: SpriteFrames, anim: String, file: String, count: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(ART + file + ".png")
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(anim, at)


func arm() -> void:
	armed = true
	elapsed = 0.0
	# Burst: the cistern breaks, the puddle spreads over the area.
	if _bomb:
		_bomb.visible = false
	if _ground:
		_ground.visible = true
		_ground.scale = Vector2.ONE * (radius * 2.0 / 90.0)
		_ground.z_index = 5           # the burst goes up over everything...
		_ground.play("explode")
		_ground.animation_finished.connect(_on_ground_anim_done)
	queue_redraw()


func _on_ground_anim_done() -> void:
	if _ground.animation == "explode":
		_ground.z_index = -1          # ...the puddle it leaves lies on the floor
		_ground.scale = Vector2.ONE * (radius * 2.0 / PUDDLE_ART_WIDTH)
		_ground.play("puddle")


func _process(delta: float) -> void:
	_t += delta
	if not armed:
		_place_bomb()
	queue_redraw()


## Flying along an arc to the target during the first part of the warning, then sitting
## on it blinking faster and faster.
func _place_bomb() -> void:
	if _bomb == null:
		return
	var k := clampf(warning_progress / FLIGHT_PART, 0.0, 1.0)
	if k < 1.0:
		var start := _from - global_position
		var pos := start.lerp(Vector2.ZERO, k)
		pos.y -= sin(k * PI) * ARC_HEIGHT
		_bomb.position = pos
		_bomb.rotation = k * TAU * 1.5
		_shadow_t = k
	else:
		if _bomb.animation != "blink":
			_bomb.play("blink")
			_bomb.rotation = 0.0
			# Squash on landing.
			_bomb.scale = Vector2.ONE * (BOMB_SIZE / 88.0) * Vector2(1.25, 0.8)
			create_tween().tween_property(_bomb, "scale", Vector2.ONE * (BOMB_SIZE / 88.0), 0.15)
		# Its base stands on the target spot.
		_bomb.position = Vector2(0, -(117 - 64) * _bomb.scale.y)
		var w := clampf((warning_progress - FLIGHT_PART) / (1.0 - FLIGHT_PART), 0.0, 1.0)
		_bomb.speed_scale = lerpf(1.0, 3.5, w)
		_shadow_t = 1.0


func _physics_process(delta: float) -> void:
	if get_parent() is FinalBossBase and get_parent().is_dying:
		queue_free()
		return
	if not armed:
		return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	if elapsed >= duration - DRAIN_TIME and _ground and _ground.animation != "drain":
		_ground.play("drain")
	tick_remaining -= delta
	if tick_remaining <= 0.0:
		tick_remaining = 0.35
		for player in get_tree().get_nodes_in_group("player"):
			if player is Node2D and player.has_method("take_damage") and global_position.distance_to(player.global_position) <= radius:
				player.take_damage(damage)


func _draw() -> void:
	if armed:
		return  # the puddle art shows the area
	# The bomb's shadow (grows as it comes down). No ring: the blinking cistern is the tell.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, BOMB_SIZE * 0.45 * (0.4 + 0.6 * _shadow_t), Color(0, 0, 0, 0.35 * _shadow_t + 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
