extends Resource
class_name ChargeShotSettings

## Settings for charge-shot items: hold the attack button to charge, release to fire
## one stronger shot. Assigned to an Item's charge_shot field; the item gives it to
## the Player, which switches from auto-fire to charge-and-release.

## Full charge time = the player's fire_rate × this, so fire-rate items still matter.
## With the default fire_rate of 0.55 this is ~1.4 s.
@export var charge_time_multiplier: float = 2.5

@export var projectile_scene: PackedScene
## Releasing below this fraction of a full charge fires nothing (stops tap-spamming).
@export_range(0.0, 1.0, 0.05) var min_charge_ratio: float = 0.2

## Multipliers go from the "min" value at min_charge_ratio up to "max" at full charge.
@export var min_damage_multiplier: float = 1.0
@export var max_damage_multiplier: float = 4.0
@export var max_size_multiplier: float = 2.5
@export var max_knockback_multiplier: float = 3.0
@export var max_speed_multiplier: float = 1.3
