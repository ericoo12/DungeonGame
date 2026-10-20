## Pink Eye mark on an enemy: it takes `mult` x damage while marked and infects other
## enemies that come within SPREAD_RANGE (touching). Spread copies get the remaining time.
class_name PinkEyeStatus
extends Node

const NODE_NAME := "PinkEyeStatus"
const SPREAD_RANGE := 16.0
const CHECK_INTERVAL := 0.2
const TINT := Color(1.0, 0.6, 0.8)

var time_left: float = 5.0
var mult: float = 1.25
var _check: float = 0.0


static func apply(enemy: EnemyBase, duration: float, damage_mult: float) -> void:
	if enemy.is_dying:
		return
	var s := enemy.get_node_or_null(NODE_NAME) as PinkEyeStatus
	if s:
		s.time_left = maxf(s.time_left, duration)
		return
	s = PinkEyeStatus.new()
	s.name = NODE_NAME
	s.time_left = duration
	s.mult = damage_mult
	enemy.add_child.call_deferred(s)


func _ready() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null:
		queue_free()
		return
	enemy.damage_taken_mult = mult
	enemy.modulate = TINT


func _physics_process(delta: float) -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.is_dying:
		queue_free()
		return
	time_left -= delta
	if time_left <= 0.0:
		enemy.damage_taken_mult = 1.0
		enemy.modulate = Color.WHITE
		queue_free()
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_INTERVAL
	for node in enemy.get_parent().get_children():
		var other := node as EnemyBase
		if other and other != enemy and not other.is_dying \
				and other.get_node_or_null(NODE_NAME) == null \
				and other.global_position.distance_to(enemy.global_position) <= SPREAD_RANGE:
			PinkEyeStatus.apply(other, time_left, mult)
