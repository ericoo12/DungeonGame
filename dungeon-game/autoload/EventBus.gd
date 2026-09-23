extends Node

signal player_health_changed(current: int, max: int)
signal item_added(item: Item)
signal active_item_changed(item: ActiveItem)

signal boss_spawned(max_health: float)
signal boss_health_changed(current: float)
signal boss_defeated()
