class_name MuggBlackboard
extends RefCounted

## Last decision details for the test arena/debugger. Not gameplay conditions.
var situation: String = "NO TARGET"
var chosen_response: String = "Idle"
var choice_weights: Dictionary = {}

var player_visible: bool = false
var shot_clear: bool = false
var has_last_seen: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var time_since_seen: float = INF
var distance: float = INF
var last_decision: String = "Idle"
var last_attack: String = ""
var shots_fired: int = 0

func forget() -> void:
	player_visible = false
	shot_clear = false
	has_last_seen = false
	time_since_seen = INF
	distance = INF
