## ActiveItemEffect: fires a persistent, player-tracking damage-over-time beam.
## Unlike LaserShotStyle (instant hitscan), this spawns a TickBeamVisual that
## manages its own live raycast/damage-tick loop independently every frame —
## see TickBeamVisual.gd for that logic.
class_name TickBeamEffect
extends ActiveItemEffect

@export var max_range: float = 3000.0
@export var damage: float = 5.0
@export var damage_interval: float = 0.3
@export var beam_width: float = 6.0
@export var visual_duration: float = 1.0
@export var start_offset: float = 2.0
@export var shrink_time: float = 0.4

const TICK_BEAM_VISUAL_SCENE := preload("res://scenes/items/tick_beam/TickBeamVisual.tscn")


func activate(player: Player) -> void:
	var dir: Vector2 = player.last_true_aim_dir
	var start_point: Vector2 = player.weapon_marker.global_position + dir * start_offset

	var beam: TickBeamVisual = TICK_BEAM_VISUAL_SCENE.instantiate()
	player.add_child(beam)
	beam.setup(start_point, dir, max_range, beam_width, visual_duration, damage, damage_interval, shrink_time)
