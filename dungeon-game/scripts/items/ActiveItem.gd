## A button-triggered (Space) pickup, separate from passive Items so the two
## can never be mixed up on accident — see ActiveItemEffect for the actual
## behavior. Only one ActiveItem can be equipped at a time; picking up a new
## one replaces the current one (see Player.add_active_item()).
class_name ActiveItem
extends ItemBase

@export var effect: ActiveItemEffect
@export var cooldown: float = 5.0
