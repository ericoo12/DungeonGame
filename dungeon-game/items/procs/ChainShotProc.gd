## Static Cling: chance per shot to chain a zap to the nearest other enemy within
## `chain_range` (`damage_ratio` x the player's shot damage). Draws a short-lived bolt.
class_name ChainShotProc
extends ShotProcEffect

@export var chain_range: float = 80.0
@export var damage_ratio: float = 2.6
@export var tint: Color = Color(0.75, 0.95, 1.0)


func decorate_projectile(projectile: Node) -> void:
	if projectile is CanvasItem:
		projectile.modulate = tint


func on_hit(target: Node, player: Player) -> void:
	if not (target is Node2D) or not is_instance_valid(player):
		return
	var from := (target as Node2D).global_position
	var best: EnemyBase = null
	var best_d := chain_range
	for node in target.get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e == target or e.is_dying:
			continue
		var d := from.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	best.take_damage(player.get_effective_damage() * damage_ratio, (best.global_position - from).normalized(), 30.0)
	_draw_bolt(target.get_parent(), from, best.global_position)


static func _draw_bolt(parent: Node, a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.top_level = true  # points are global positions
	line.width = 1.5
	line.default_color = Color(0.7, 0.95, 1.0)
	var steps := 6
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		if i > 0 and i < steps:
			p += (b - a).orthogonal().normalized() * randf_range(-4.0, 4.0)
		line.add_point(p)
	parent.add_child.call_deferred(line)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.12
	timer.autostart = true
	timer.timeout.connect(line.queue_free)
	line.add_child(timer)


func get_stat_text() -> String:
	return "%d%% chance to zap a nearby enemy" % roundi(get_chance() * 100.0) + luck_text()
