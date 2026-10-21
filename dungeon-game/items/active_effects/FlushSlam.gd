## Attached to an enemy by Emergency Flush: if the enemy hits a wall or obstacle within
## `window` seconds, it takes `damage` once. Removes itself afterwards.
class_name FlushSlam
extends Node

var damage: float = 8.0
var time_left: float = 0.6


static func attach(enemy: EnemyBase, slam_damage: float, window: float) -> void:
	var old := enemy.get_node_or_null("FlushSlam")
	if old:
		old.queue_free()
	var slam := FlushSlam.new()
	slam.name = "FlushSlam"
	slam.damage = slam_damage
	slam.time_left = window
	enemy.add_child(slam)


func _physics_process(delta: float) -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.is_dying:
		queue_free()
		return
	time_left -= delta
	for i in enemy.get_slide_collision_count():
		var col := enemy.get_slide_collision(i)
		if col.get_collider() is CharacterBody2D:
			continue  # bumping other enemies / the player doesn't count
		enemy.take_damage(damage, col.get_normal(), 0.0)
		queue_free()
		return
	if time_left <= 0.0:
		queue_free()
