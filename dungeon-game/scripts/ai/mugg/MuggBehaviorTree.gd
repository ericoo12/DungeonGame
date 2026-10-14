class_name MuggBehaviorTree
extends Node

## Active first iteration: lifecycle guards, commitment, anti-cover positioning,
## limited retreat, Basic Shot, reposition, pressure. New tactic leaves can be
## inserted here without moving physics or attack execution into the tree.
var root_node: DecisionNode

func configure(actor: Node) -> void:
	root_node = DecisionNode.selector([
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.is_dying),
			DecisionNode.action(func(): return actor.ai_dead())]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.action_state == "damage"),
			DecisionNode.action(func(): return actor.ai_stunned())]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.state_machine.is_committed()),
			DecisionNode.action(func(): return DecisionNode.Status.RUNNING)]),
		DecisionNode.action(func(): return actor.ai_dodge()),
		DecisionNode.action(func(): return actor.ai_take_cover()),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return not actor.blackboard.has_last_seen),
			DecisionNode.action(func(): return actor.ai_idle())]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.movement_is_committed()),
			DecisionNode.action(func(): return DecisionNode.Status.RUNNING)]),
		DecisionNode.action(func(): return actor.ai_area_attack()),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return not actor.blackboard.player_visible or not actor.blackboard.shot_clear),
			DecisionNode.action(func(): return actor.ai_reposition("Find firing angle"))]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.blackboard.distance < actor.close_distance),
			DecisionNode.action(func(): return actor.ai_reposition("Create distance"))]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.can_basic_shot()),
			DecisionNode.action(func(): return actor.ai_choose_offense())]),
		DecisionNode.sequence([
			DecisionNode.condition(func(): return actor.bad_position()),
			DecisionNode.action(func(): return actor.ai_reposition("Reposition"))]),
		DecisionNode.action(func(): return actor.ai_pressure()),
		DecisionNode.action(func(): return actor.ai_idle())
	])

func tick() -> DecisionNode.Status:
	return root_node.tick() if root_node else DecisionNode.Status.FAILURE
