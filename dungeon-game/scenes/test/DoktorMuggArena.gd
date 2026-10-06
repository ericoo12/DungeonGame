extends Node2D

@onready var room: RoomController = $Room
@onready var boss: DoktorMugg = $Entities/DoktorMugg
@onready var player: Player = $Entities/Player
@onready var info: Label = $Instructions/Info

func _enter_tree() -> void:
	GameState.reset()
	get_tree().paused = false

func _ready() -> void:
	for door in room.doors.values():
		door.set_unlocked(false)
	boss.set_arena(room)
	var bounds := room.get_arena_bounds()
	player.set_camera_bounds(bounds.get_center(), bounds.size)
	# Keep the Player scene's normal zoom and following behavior.
	player.camera.make_current()
	player.camera.reset_smoothing()

func _process(_delta: float) -> void:
	var status := "Boss defeated!"
	if is_instance_valid(boss):
		status = "%s | %s | HP %.0f | Sight: %s | Clear shot: %s" % [boss.state_machine.state_name(), boss.blackboard.last_decision, boss.health, boss.blackboard.player_visible, boss.blackboard.shot_clear]
	info.text = "DOKTOR MUGG TEST | WASD: move | Arrows: shoot | R: restart\nGreen: walk blocker | Blue: walk/shot/sight blocker | Leave warning circles\n" + status

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		GameState.reset()
		get_tree().reload_current_scene()
