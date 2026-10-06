class_name MuggStateMachine
extends Node

## Explicitly driven by EnemyBase hooks; this node never self-processes.
enum State { IDLE, PRESSURE, REPOSITION, WINDUP, FIRE, RECOVERY, STUNNED, DEAD, DODGE, DODGE_RECOVERY, TAKE_COVER, COVER_HOLD, AREA_WINDUP, AREA_RECOVERY, KITE }
signal state_changed(previous: State, current: State)
var state: State = State.IDLE
var elapsed: float = 0.0

func advance(delta: float) -> void:
	elapsed += delta

func is_committed() -> bool:
	return state in [State.WINDUP, State.FIRE, State.RECOVERY, State.DODGE, State.DODGE_RECOVERY, State.COVER_HOLD, State.AREA_WINDUP, State.AREA_RECOVERY]

func transition(next: State, interrupt: bool = false) -> bool:
	if state == State.DEAD or next == state:
		return false
	if is_committed() and not interrupt:
		return false
	var previous := state
	state = next
	elapsed = 0.0
	state_changed.emit(previous, state)
	return true

func state_name() -> String:
	return State.keys()[state]
