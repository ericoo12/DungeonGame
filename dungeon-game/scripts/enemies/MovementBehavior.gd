class_name MovementBehavior
extends Resource

## Returns the velocity this enemy should have this frame. Called every
## _physics_process() by EnemyBase, unless the enemy is mid-attack/knockback.
func get_velocity(enemy: EnemyBase, delta: float) -> Vector2:
	push_warning("MovementBehavior.get_velocity() not implemented")
	return Vector2.ZERO
