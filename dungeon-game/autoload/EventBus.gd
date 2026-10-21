extends Node

signal player_health_changed(current: float, max: int)
signal player_damaged()   # an enemy/hazard hit landed (not item heart costs)
signal item_added(item: Item)
signal active_item_changed(item: ActiveItem)
signal active_item_charges_changed(charges: int, max_charges: int)
## A room's enemies were all killed (not item rooms). Recharges the active item.
signal combat_room_cleared()
## A new room was loaded (Plumber's Toolbox buff ends here).
signal room_entered()
signal ducks_changed(total: int)   # rubber duck currency
signal decloggers_changed(total: int)  # used on clogged toilets (Toilet.gd)

signal boss_spawned(max_health: float)
signal boss_health_changed(current: float)
signal boss_defeated()
