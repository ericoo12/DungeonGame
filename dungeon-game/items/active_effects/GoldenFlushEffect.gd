## Golden Flush: turns the room golden until you leave it - every enemy you kill in
## this room has `duck_chance` to drop a duck (sometimes a 5-duck). Luck adds a bit.
## The player glows gold while it lasts (TempStatBuff tint; ends on the next room).
class_name GoldenFlushEffect
extends ActiveItemEffect

@export_range(0.0, 1.0) var duck_chance: float = 0.5
@export var duck_chance_per_luck: float = 0.05
@export_range(0.0, 1.0) var five_duck_share: float = 0.15
@export var tint: Color = Color(1.0, 0.92, 0.5)

const DUCK_1 := preload("res://pickups/DuckPickup1.tscn")
const DUCK_5 := preload("res://pickups/DuckPickup5.tscn")


func activate(player: Player) -> void:
	var buff := GoldenFlushBuff.new()
	buff.key = "golden_flush"
	buff.tint = tint
	buff.chance = duck_chance
	buff.chance_per_luck = duck_chance_per_luck
	buff.five_share = five_duck_share
	buff.duck_1 = DUCK_1
	buff.duck_5 = DUCK_5
	TempStatBuff.start(player, buff)


## The room-long part: listens for kills while it exists.
class GoldenFlushBuff extends TempStatBuff:
	var chance: float = 0.5
	var chance_per_luck: float = 0.05
	var five_share: float = 0.15
	var duck_1: PackedScene
	var duck_5: PackedScene

	func _ready() -> void:
		super._ready()
		EventBus.enemy_killed.connect(_on_enemy_killed)

	func _on_enemy_killed(enemy: Node2D) -> void:
		if not is_instance_valid(_player) or not is_instance_valid(enemy):
			return
		var luck: float = _player.luck if "luck" in _player else 0.0
		if randf() >= clampf(chance + luck * chance_per_luck, 0.0, 1.0):
			return
		var scene := duck_5 if randf() < five_share else duck_1
		var dungeon := get_tree().get_first_node_in_group("dungeon")
		var room = dungeon.current_room if dungeon and "current_room" in dungeon else null
		if room and room.has_method("_spawn_drop"):
			room._spawn_drop.call_deferred(scene, enemy.global_position)
		else:
			var drop := scene.instantiate()
			_player.get_parent().add_child.call_deferred(drop)
			drop.set_deferred("global_position", enemy.global_position)
