class_name MuggBehaviorTree
extends Node

## READ FIRST: situations are prioritized; responses inside them are weighted.
## Death, stun and action commitment are guarded by the FSM before evaluation.
var actor: Node
var root_node: DecisionNode

func configure(boss: Node) -> void:
	actor = boss
	root_node = DecisionNode.selector([
		_when(actor.tactics.immediate_danger, MuggTactics.Situation.DANGER),
		_when(actor.tactics.player_blocked, MuggTactics.Situation.BLOCKED),
		_when(actor.tactics.player_too_close, MuggTactics.Situation.TOO_CLOSE),
		_when(actor.tactics.player_in_range, MuggTactics.Situation.COMBAT),
		_when(func(): return actor.blackboard.has_last_seen, MuggTactics.Situation.SEARCH),
		DecisionNode.action(_idle)
	])

func _when(condition: Callable, situation: MuggTactics.Situation) -> DecisionNode:
	return DecisionNode.sequence([
		DecisionNode.condition(condition),
		DecisionNode.action(func(): return _respond(situation))
	])

func tick() -> DecisionNode.Status:
	if not root_node:
		return DecisionNode.Status.FAILURE
	if not actor.state_machine.can_choose_tactic(actor):
		return DecisionNode.Status.RUNNING
	return root_node.tick()

func _idle() -> DecisionNode.Status:
	actor.blackboard.situation = "NO TARGET"
	actor.blackboard.chosen_response = "Idle"
	actor.blackboard.choice_weights.clear()
	return actor.ai_idle()

func _respond(situation: MuggTactics.Situation) -> DecisionNode.Status:
	var result: DecisionNode.Status = actor.tactics.choose(situation)
	if result == DecisionNode.Status.FAILURE and situation == MuggTactics.Situation.COMBAT:
		# Kiting is the movement between attacks, not another attack lottery.
		actor.blackboard.chosen_response = "Kite between attacks" if actor.kiting_enabled else "Move between attacks"
		return actor.ai_pressure()
	return result
