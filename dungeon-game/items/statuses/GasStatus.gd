## Attached to an enemy by Sewer Gas. When the enemy dies (not when a room is simply
## unloaded) it spawns an explosion that hurts enemies only.
class_name GasStatus
extends Node

const NODE_NAME := "GasStatus"
const EXPLOSION := preload("res://effects/Explosion.tscn")
const TINT := Color(0.8, 1.0, 0.6)

var enemy_damage: float = 7.0
var radius: float = 30.0


static func apply(enemy: EnemyBase, damage: float, blast_radius: float) -> void:
	var s := enemy.get_node_or_null(NODE_NAME) as GasStatus
	if s == null:
		s = GasStatus.new()
		s.name = NODE_NAME
		enemy.add_child.call_deferred(s)
	s.enemy_damage = maxf(s.enemy_damage, damage)
	s.radius = blast_radius


func _ready() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy:
		enemy.modulate = TINT


func _exit_tree() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null or not enemy.is_dying or enemy.get_parent() == null:
		return
	var boom: Explosion = EXPLOSION.instantiate()
	boom.damages_player = false
	boom.damages_enemies = true
	boom.enemy_damage = enemy_damage
	boom.radius = radius
	boom.position = enemy.position
	enemy.get_parent().add_child.call_deferred(boom)
