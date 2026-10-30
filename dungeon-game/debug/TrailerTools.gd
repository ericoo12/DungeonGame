## Keys for recording the trailer (debug builds only - HUD adds this node when
## OS.is_debug_build(), so an exported game never has them):
##   F1  clean screen: hides the whole HUD (hearts, map, stats) + enemy health bars and
##       Dr Mugg's debug lines - just the game for the camera
##   F2  god mode (can't take damage)
##   F3  slow motion (35 % speed) on / off
##   F4  get a random item (rarity-weighted, like an item room)
##   F5  +20 ducks and full health
##   F6  go to this floor's boss room
##   F7  next stage (e.g. stage 3 = Dr Mugg)
## Each press prints what it did to the Output panel.
extends Node

const HEALTH_BAR := preload("res://ui/EnemyHealthBar.gd")
const SLOW_SCALE := 0.35

var hud: CanvasLayer
var clean: bool = false
var god_mode: bool = false
var _saved_visible: Dictionary = {}
var _saved_bars: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = get_parent() as CanvasLayer


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _dungeon() -> Dungeon:
	return get_tree().get_first_node_in_group("dungeon") as Dungeon


func _process(_delta: float) -> void:
	if god_mode:
		var p := _player()
		if p:
			p.invulnerable = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			set_clean(not clean)
			_say("clean screen " + ("on" if clean else "off"))
		KEY_F2:
			god_mode = not god_mode
			var p := _player()
			if p and not god_mode:
				p.invulnerable = false
			_say("god mode " + ("on" if god_mode else "off"))
		KEY_F3:
			Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else SLOW_SCALE
			_say("slow motion " + ("on" if Engine.time_scale < 1.0 else "off"))
		KEY_F4:
			give_random_item()
		KEY_F5:
			var p := _player()
			if p:
				p.add_ducks(20)
				p.heal(p.max_hearts)
				_say("+20 ducks, full health")
		KEY_F6:
			go_to_boss()
		KEY_F7:
			var d := _dungeon()
			if d:
				d.call_deferred("advance_to_next_stage")
				_say("next stage")
		_:
			return
	get_viewport().set_input_as_handled()


## Hides every HUD element (the HUD's own children) and the in-world debug drawing.
func set_clean(on: bool) -> void:
	if on == clean:
		return
	clean = on
	if on:
		_saved_bars = HEALTH_BAR.show_all
		HEALTH_BAR.show_all = false
	else:
		HEALTH_BAR.show_all = _saved_bars
	if hud == null:
		return
	for c in hud.get_children():
		var ci := c as CanvasItem
		if ci == null:
			continue
		if on:
			_saved_visible[ci] = ci.visible
			ci.visible = false
		elif _saved_visible.has(ci) and is_instance_valid(ci):
			ci.visible = _saved_visible[ci]
	if not on:
		_saved_visible.clear()


func give_random_item() -> void:
	var d := _dungeon()
	var p := _player()
	if d == null or p == null:
		return
	var picks := d.pick_items(1)
	if picks.is_empty():
		_say("no items left in the pool")
		return
	var item: ItemBase = picks[0]
	GameState.picked_up_items.append(item)
	if item is ActiveItem:
		p.add_active_item(item as ActiveItem)
	elif item is Item:
		p.add_item(item as Item)
	_say("got " + item.item_name)


func go_to_boss() -> void:
	var d := _dungeon()
	if d == null:
		return
	for cell in d.layout:
		var data: RoomData = d.layout[cell]
		if data.type == RoomData.Type.BOSS:
			d._load_room(data.home_cell(), Vector2i(0, -1))  # arrive at its south door
			_say("boss room")
			return


func _say(text: String) -> void:
	print("[Trailer] ", text)
