## Draws the generated room grid on screen — toggle with the same Tab key as
## DebugStatsDisplay, purely a dev tool, not part of the shipped game.
extends Control
class_name DungeonMapDebug

@export var cell_size: float = 24.0
@export var margin: Vector2 = Vector2(20, 20)

var dungeon: Dungeon


func _ready() -> void:
	call_deferred("_find_dungeon")


func _find_dungeon() -> void:
	dungeon = get_tree().get_first_node_in_group("dungeon")


func _process(_delta: float) -> void:
	if is_instance_valid(dungeon):
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(dungeon) or dungeon.layout.is_empty():
		return

	for grid_pos in dungeon.layout.keys():
		var data: RoomData = dungeon.layout[grid_pos]
		var screen_pos: Vector2 = margin + Vector2(grid_pos) * cell_size

		var color: Color
		match data.type:
			RoomData.Type.START: color = Color(0.3, 0.7, 1.0)
			RoomData.Type.BOSS: color = Color(0.9, 0.2, 0.2)
			_: color = Color(0.6, 0.6, 0.6) if data.cleared else Color(0.9, 0.8, 0.3)

		if grid_pos == dungeon.current_grid_pos:
			draw_rect(Rect2(screen_pos - Vector2(2, 2), Vector2.ONE * (cell_size - 4)), Color(1, 1, 1), false, 2.0)

		draw_rect(Rect2(screen_pos, Vector2.ONE * (cell_size - 6)), color)

		# Door connections, drawn as short lines toward each connected neighbor
		for dir in [DungeonGenerator.NORTH, DungeonGenerator.SOUTH, DungeonGenerator.EAST, DungeonGenerator.WEST]:
			if data.doors.get(dir, false):
				var center: Vector2 = screen_pos + Vector2.ONE * (cell_size - 6) / 2.0
				var line_end: Vector2 = center + Vector2(dir) * cell_size * 0.6
				draw_line(center, line_end, Color(0.3, 0.3, 0.3), 2.0)
