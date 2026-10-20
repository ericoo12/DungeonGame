## Damage over time on whatever it's attached to (added by PoisonShotProc). Ticks every
## TICK seconds; re-poisoning refreshes the duration and keeps the stronger damage.
## Uses the target's take_dot_damage() when it has one (enemies: no hit animation /
## knockback, so poison can't stun-lock), otherwise plain take_damage().
class_name PoisonStatus
extends Node

const NODE_NAME := "PoisonStatus"
const TICK := 0.5

var dps: float = 2.0
var time_left: float = 3.0
var _tick: float = TICK


static func apply(target: Node, damage_per_second: float, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var status := target.get_node_or_null(NODE_NAME) as PoisonStatus
	if status:
		status.dps = maxf(status.dps, damage_per_second)
		status.time_left = maxf(status.time_left, duration)
		return
	status = PoisonStatus.new()
	status.name = NODE_NAME
	status.dps = damage_per_second
	status.time_left = duration
	target.add_child.call_deferred(status)  # usually called from a physics callback


func _physics_process(delta: float) -> void:
	var target := get_parent()
	if target == null or ("is_dying" in target and target.is_dying):
		queue_free()
		return
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick += TICK
		var amount := dps * TICK
		if target.has_method("take_dot_damage"):
			target.take_dot_damage(amount)
		elif target.has_method("take_damage"):
			target.take_damage(amount)
	if time_left <= 0.0:
		queue_free()
