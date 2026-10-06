class_name AttackBehavior
extends Resource

## Each enemy duplicates its configured behavior before using it.
## Cooldowns tick separately, even while attacks/hurt/knockback prevent decisions.
func update_cooldown(_delta: float) -> void:
	pass

## Called only when the enemy is free to decide. Use enemy.begin_action() for
## committed attacks; never move the body or schedule uncancellable effects here.
func try_attack(_enemy: EnemyBase, _delta: float) -> void:
	push_warning("AttackBehavior.try_attack() not implemented")
