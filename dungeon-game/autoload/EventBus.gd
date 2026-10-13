extends Node

signal player_health_changed(current: int, max: int)
signal item_added(item: Item)
signal active_item_changed(item: ActiveItem)
signal active_item_charges_changed(charges: int, max_charges: int)
## A room's enemies were all killed (not item rooms). Recharges the active item.
signal combat_room_cleared()
signal ducks_changed(total: int)   # rubber duck currency
signal decloggers_changed(total: int)  # used on clogged toilets (Toilet.gd)

signal boss_spawned(max_health: float)
signal boss_health_changed(current: float)
signal boss_defeated()
