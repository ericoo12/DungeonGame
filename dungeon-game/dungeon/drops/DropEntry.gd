class_name DropEntry
extends Resource
@export var scene: PackedScene
@export var weight: float = 1.0
@export var weight_per_luck: float = 0.0   # >0 = gets more likely with luck (chests, rare stuff)
@export var min_luck: float = 0.0          # can't appear below this luck
