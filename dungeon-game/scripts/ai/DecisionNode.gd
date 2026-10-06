class_name DecisionNode
extends RefCounted

## Small reactive behavior-tree primitives. Actions request a tactic; the FSM
## owns its execution. A committed-action branch prevents repeated restarts.
enum Status { FAILURE, SUCCESS, RUNNING }
enum Kind { SELECTOR, SEQUENCE, CONDITION, ACTION }
var kind: Kind
var children: Array[DecisionNode] = []
var callback: Callable

static func selector(nodes: Array[DecisionNode]) -> DecisionNode:
	var node := DecisionNode.new()
	node.kind = Kind.SELECTOR
	node.children = nodes
	return node

static func sequence(nodes: Array[DecisionNode]) -> DecisionNode:
	var node := DecisionNode.new()
	node.kind = Kind.SEQUENCE
	node.children = nodes
	return node

static func condition(test: Callable) -> DecisionNode:
	var node := DecisionNode.new()
	node.kind = Kind.CONDITION
	node.callback = test
	return node

static func action(execute: Callable) -> DecisionNode:
	var node := DecisionNode.new()
	node.kind = Kind.ACTION
	node.callback = execute
	return node

func tick() -> Status:
	match kind:
		Kind.CONDITION:
			return Status.SUCCESS if callback.call() else Status.FAILURE
		Kind.ACTION:
			return callback.call()
		Kind.SELECTOR:
			for child in children:
				var result := child.tick()
				if result != Status.FAILURE:
					return result
			return Status.FAILURE
		Kind.SEQUENCE:
			for child in children:
				var result := child.tick()
				if result != Status.SUCCESS:
					return result
			return Status.SUCCESS
	return Status.FAILURE
