## Split Seam: when a shot hits an enemy it splits into two smaller diagonal shots. A shot
## that hits nothing splits at the very end of its flight instead (just before it lands).
## Always on (base_chance 1.0). The split shots keep the other procs (poison etc.) but
## can't split again, and ignore the enemy they split from. Works with any projectile
## (normal, charged, boomerang); lasers have no projectile so they don't split.
class_name SplitShotProc
extends ShotProcEffect

@export var split_angle_deg: float = 40.0
@export var damage_ratio: float = 0.5
@export var size_ratio: float = 0.6
@export var range_ratio: float = 0.55

const SPLIT_SCENE := preload("res://player/Projectile.tscn")


func _init() -> void:
	base_chance = 1.0


func get_chance() -> float:
	return 1.0  # always (not luck based)


func on_projectile_hit(projectile: Node, target: Node) -> void:
	_split(projectile, target)


func on_projectile_expire(projectile: Node) -> void:
	_split(projectile, null)


func _split(projectile: Node, target: Node) -> void:
	var p := projectile as Projectile
	if p == null or p.has_meta("split_done"):
		return
	p.set_meta("split_done", true)
	var dir := p.velocity.normalized()
	if dir == Vector2.ZERO:
		return
	var parent := p.get_parent()
	if parent == null:
		return
	var child_procs: Array[ShotProcEffect] = []
	for proc in p.procs:
		if not proc is SplitShotProc:
			child_procs.append(proc)
	for side in [-1.0, 1.0]:
		var child: Projectile = SPLIT_SCENE.instantiate()
		child.damage = p.damage * damage_ratio
		child.knockback_strength = p.knockback_strength * 0.5
		child.lifetime = maxf(p.lifetime * range_ratio, 0.15)
		child.speed_multiplier = p.speed_multiplier
		child.scale = p.scale * size_ratio
		child.shooter = p.shooter
		child.procs = child_procs
		child.ignored_target = target
		child.modulate = p.modulate
		# Same parent, so local == local. Start back at gun height (the parent may have
		# dropped towards the floor already) so the halves get a full flight.
		child.position = p.position - Vector2(0, p.get_fallen())
		child.fall_depth = p.fall_depth
		# Deferred: we're inside a physics callback. Calls run in order: add, then launch.
		parent.add_child.call_deferred(child)
		child.launch.call_deferred(dir.rotated(deg_to_rad(split_angle_deg) * side), Vector2.ZERO)


func get_stat_text() -> String:
	return "Shots split in two when they hit or land"
