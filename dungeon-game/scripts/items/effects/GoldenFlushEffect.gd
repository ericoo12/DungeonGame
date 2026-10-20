## Golden Flush: hits every enemy in the room for `damage_ratio` x the player's shot
## damage. Each enemy it kills gives +luck_per_kill luck until the player leaves the room.
class_name GoldenFlushEffect
extends ActiveItemEffect

@export var damage_ratio: float = 3.0
@export var luck_per_kill: float = 0.5
@export var tint: Color = Color(1.0, 0.92, 0.5)


func activate(player: Player) -> void:
	var damage := player.get_effective_damage() * damage_ratio
	var kills := 0
	for node in player.get_parent().get_children():
		var e := node as EnemyBase
		if e == null or e.is_dying:
			continue
		e.take_damage(damage, (e.global_position - player.global_position).normalized(), 60.0)
		if e.is_dying:
			kills += 1
	if kills > 0:
		var buff := TempStatBuff.new()
		buff.key = "golden_flush"
		buff.luck_bonus = kills * luck_per_kill
		buff.tint = tint
		TempStatBuff.start(player, buff)
