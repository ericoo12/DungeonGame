extends Label
class_name DebugStatsDisplay

var player: Player = null

func _ready() -> void:
	call_deferred("_find_player")


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		return
	
	text = "hearts: %d/%d\ndamage_ups: %d\neffective_dmg: %.2f\nmove_speed: %.1f\nfire_rate: %.2f\nknockback: %.1f\nrange: %.2f\nproj_size: %.2f\nplayer_size: %.2f\nitems: %d" % [
		player.current_hearts,
		player.max_hearts,
		player.damage_ups,
		player.get_effective_damage(),
		player.move_speed,
		player.fire_rate,
		player.projectile_knockback,
		player.projectile_range,
		player.projectile_size,
		player.player_scale,
		player.items.size(),
	]
