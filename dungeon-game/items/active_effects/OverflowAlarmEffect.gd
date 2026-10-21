## Overflow Alarm: floods the room for `duration` seconds: every enemy is slowed and
## the player runs faster. A blue tint shows while the water is up.
class_name OverflowAlarmEffect
extends ActiveItemEffect

@export var duration: float = 5.0
@export var enemy_slow_factor: float = 0.5
@export var player_speed_bonus: float = 40.0
@export var tint: Color = Color(0.7, 0.85, 1.0)


func activate(player: Player) -> void:
	for node in player.get_parent().get_children():
		var e := node as EnemyBase
		if e and not e.is_dying:
			e.apply_slow(enemy_slow_factor, duration)
	var buff := TempStatBuff.new()
	buff.key = "overflow_alarm"
	buff.duration = duration
	buff.speed_bonus = player_speed_bonus
	buff.tint = tint
	TempStatBuff.start(player, buff)
