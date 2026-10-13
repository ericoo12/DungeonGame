## A button-triggered (Space) pickup, separate from passive Items so the two
## can never be mixed up on accident — see ActiveItemEffect for the actual
## behavior. Only one ActiveItem can be equipped at a time; picking up a new
## one replaces the current one (see Player.add_active_item()).
class_name ActiveItem
extends ItemBase

@export var effect: ActiveItemEffect
## Charges needed to use it. Full when picked up; only usable when full, and a use
## spends ALL of them; clearing a combat room gives one back
## (Player.add_active_item_charge), up to this max.
@export_range(1, 12) var max_charges: int = 1
## Short lockout after a use. Charges are the real limiter now; this only matters
## if an item ever recharges instantly.
@export var cooldown: float = 0.5
