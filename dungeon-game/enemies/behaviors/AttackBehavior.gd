class_name AttackBehavior
extends Resource

## Called every frame. Handles its own cooldown internally and triggers
## whatever attack this enemy does when conditions are met.
func try_attack(enemy: EnemyBase, delta: float) -> void:
	push_warning("AttackBehavior.try_attack() not implemented")
