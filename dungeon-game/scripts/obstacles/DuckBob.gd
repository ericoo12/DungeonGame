## Gentle float for decoration (ducks in a pool). Attach to any Node2D/Sprite2D.
## Each one starts at a random point in the cycle so a group doesn't bob in sync.
extends Node2D

@export var bob_height: float = 1.5       # px up/down
@export var bob_speed: float = 1.2        # cycles per second
@export var tilt_degrees: float = 6.0     # side-to-side rock
@export var random_phase: bool = true

var _base_y: float
var _t: float


func _ready() -> void:
	_base_y = position.y
	_t = randf() * TAU if random_phase else 0.0


func _process(delta: float) -> void:
	_t += delta * bob_speed * TAU
	position.y = _base_y + sin(_t) * bob_height
	rotation = deg_to_rad(sin(_t * 0.5) * tilt_degrees)  # slower rock than the bob
