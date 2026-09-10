class_name Item
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export var max_hearts_bonus: int = 0
@export var speed_bonus: float = 0.0
@export var damage_bonus: int = 0
@export var fire_rate_bonus: float = 0.0


func apply(player: Player) -> void:
	if max_hearts_bonus != 0:
		player.max_hearts += max_hearts_bonus
		player.current_hearts += max_hearts_bonus
		EventBus.player_health_changed.emit(player.current_hearts, player.max_hearts)
	
	if damage_bonus != 0:
		player.damage_ups += damage_bonus
	
	player.move_speed += speed_bonus
	player.fire_rate = max(0.5, player.fire_rate - fire_rate_bonus)

func get_stat_summary() -> String:
	var lines: PackedStringArray = []
	if max_hearts_bonus != 0:
		lines.append("%+d Max Hearts" % max_hearts_bonus)
	if damage_bonus != 0:
		lines.append("%+d Damage" % damage_bonus)
	if speed_bonus != 0.0:
		lines.append("%+.1f Speed" % speed_bonus)
	if fire_rate_bonus != 0.0:
		lines.append("%+.2f Fire Rate" % fire_rate_bonus)
	return "\n".join(lines)
