extends Node

signal stage_changed(new_stage: int)

var current_stage: int = 1
var picked_up_items: Array[ItemBase] = []

const HEALTH_SCALE_PER_STAGE := 0.25  # +25% enemy/boss max health per stage beyond 1
const DAMAGE_SCALE_PER_STAGE := 0.15  # +15% enemy/boss contact damage per stage beyond 1


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
	stage_changed.emit(current_stage)
