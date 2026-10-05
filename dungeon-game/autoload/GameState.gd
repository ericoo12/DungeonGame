extends Node

signal stage_changed(new_stage: int)

var current_stage: int = 1
var picked_up_items: Array[ItemBase] = []

## Run seed. Seeds both `rng` (for luck rolls etc.) and Godot's global randi()/randf()
## (dungeon layout, obstacles, enemy spawns), so the same seed replays the same run as
## long as the player does the same things. Shown in the inventory.
## To replay a run: set FORCED_SEED to the seed you saw, 0 = random seed every run.
const FORCED_SEED := 0
var run_seed: int = 0
var rng := RandomNumberGenerator.new()

const HEALTH_SCALE_PER_STAGE := 0.25  # +25% enemy/boss max health per stage beyond 1
const DAMAGE_SCALE_PER_STAGE := 0.15  # +15% enemy/boss contact damage per stage beyond 1


func _ready() -> void:
	# Also seed when the game is started straight from a scene (F6), skipping the menu.
	_new_seed()


func get_health_multiplier() -> float:
	return 1.0 + float(current_stage - 1) * HEALTH_SCALE_PER_STAGE


func get_damage_multiplier() -> float:
	return 1.0 + float(current_stage - 1) * DAMAGE_SCALE_PER_STAGE


func advance_stage() -> void:
	current_stage += 1
	stage_changed.emit(current_stage)


func reset() -> void:
	current_stage = 1
	picked_up_items.clear()
	_new_seed()
	stage_changed.emit(current_stage)


func _new_seed() -> void:
	randomize()  # make sure the seed itself is random
	run_seed = FORCED_SEED if FORCED_SEED != 0 else randi()
	rng.seed = run_seed
	seed(run_seed)
	print("Run seed: ", run_seed)
