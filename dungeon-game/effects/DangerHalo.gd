## Red glow under every enemy shot: the game's one colour for "this hurts you", so
## enemy shots stay readable whatever the player's own effects look like.
## Enemy shots also draw above everything else (DANGER_Z), see attach().
extends Node2D
class_name DangerHalo

const COLOR := Color(1.0, 0.18, 0.12)
## z_index for enemy shots: above characters, player shots and explosions.
const DANGER_Z := 6
## The red glow itself is switched off (enemy shots are only drawn on top). true = back on.
const SHOW_GLOW := false

var radius: float = 5.0
## Node whose position the glow copies (e.g. a shot's sprite that floats above its shadow).
var follow: Node2D = null


## Adds the glow to an enemy shot and lifts the shot above everything else.
## radius = the hit circle in the shot's local space (0 = read it from its CollisionShape2D).
static func attach(shot: Node2D, follow_node: Node2D = null, local_radius: float = 0.0) -> DangerHalo:
	shot.z_as_relative = false
	shot.z_index = DANGER_Z
	if not SHOW_GLOW:
		return null
	var halo := DangerHalo.new()
	halo.follow = follow_node
	halo.radius = local_radius if local_radius > 0.0 else _radius_of(shot)
	halo.show_behind_parent = true
	shot.add_child(halo)
	return halo


static func _radius_of(shot: Node) -> float:
	for child in shot.get_children():
		var cs := child as CollisionShape2D
		if cs and cs.shape is CircleShape2D:
			return (cs.shape as CircleShape2D).radius * absf(cs.scale.x)
	return 5.0


func _process(_delta: float) -> void:
	if follow and is_instance_valid(follow):
		position = follow.position
	queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	draw_circle(Vector2.ZERO, radius * 1.7 * pulse, Color(COLOR, 0.16))
	draw_circle(Vector2.ZERO, radius * 1.3 * pulse, Color(COLOR, 0.28))
	draw_arc(Vector2.ZERO, radius * 1.3 * pulse, 0.0, TAU, 24, Color(COLOR, 0.75), maxf(radius * 0.12, 0.6))
