## Temporary effect on the player, used by active items (Plumber's Toolbox, Overflow
## Alarm, Golden Flush, Portable Toilet, Chemical Cocktail). Remembers exactly how much
## it changed each stat (after the player's min/max limits), so ending it undoes only
## its own change, even if items were picked up meanwhile.
## Ends when the player enters a new room (EventBus.room_entered), or after `duration`
## seconds if that's > 0. One buff per `key`: using the item again replaces it.
class_name TempStatBuff
extends Node

var key: String = "buff"
var duration: float = 0.0              # 0 = until the next room
var damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0  # >1 = faster
var shot_speed_bonus: float = 0.0
var knockback_bonus: float = 0.0
var speed_bonus: float = 0.0
var luck_bonus: float = 0.0
var size_multiplier: float = 1.0
var extra_procs: Array[ShotProcEffect] = []
var invulnerable: bool = false
var block_shooting: bool = false
var heal_on_end: int = 0
var tint: Color = Color.WHITE

var _player: Player
var _dmg_factor := 1.0
var _fire_factor := 1.0
var _size_factor := 1.0
var _shot_speed_delta := 0.0
var _knockback_delta := 0.0
var _speed_delta := 0.0
var _time_left := 0.0
var _ended := false


## Replaces any running buff with the same key, then starts this one on `player`.
static func start(player: Player, buff: TempStatBuff) -> void:
	var meta := "temp_buff_" + buff.key
	if player.has_meta(meta):
		var old = player.get_meta(meta)
		if is_instance_valid(old):
			old.end(false)
	player.add_child(buff)
	player.set_meta(meta, buff)


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		queue_free()
		return
	var p := _player
	var before: float

	before = p.damage_multiplier
	p.damage_multiplier = clampf(before * damage_multiplier, 0.05, 5.0)
	_dmg_factor = p.damage_multiplier / before

	before = p.fire_rate
	p.fire_rate = clampf(before / fire_rate_multiplier, 0.05, 2.0)
	_fire_factor = p.fire_rate / before

	before = p.projectile_size
	p.projectile_size = clampf(before * size_multiplier, Player.PROJECTILE_SIZE_MIN, Player.PROJECTILE_SIZE_MAX)
	_size_factor = p.projectile_size / before

	before = p.shot_speed
	p.shot_speed = clampf(before + shot_speed_bonus, Player.SHOT_SPEED_MIN, Player.SHOT_SPEED_MAX)
	_shot_speed_delta = p.shot_speed - before

	before = p.projectile_knockback
	p.projectile_knockback = clampf(before + knockback_bonus, Player.KNOCKBACK_MIN, Player.KNOCKBACK_MAX)
	_knockback_delta = p.projectile_knockback - before

	before = p.move_speed
	p.move_speed = clampf(before + speed_bonus, 20.0, 300.0)
	_speed_delta = p.move_speed - before

	p.luck += luck_bonus
	for proc in extra_procs:
		p.shot_procs.append(proc)

	p.resync_shot_style()
	if tint != Color.WHITE:
		p.modulate = tint
	_time_left = duration
	EventBus.room_entered.connect(end)


func _physics_process(delta: float) -> void:
	if _ended or not is_instance_valid(_player):
		return
	if invulnerable:
		_player.invulnerable = true
	if block_shooting:
		_player.shoot_cooldown = maxf(_player.shoot_cooldown, 0.1)
	if duration > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			end()


func end(apply_end_effects: bool = true) -> void:
	if _ended:
		return
	_ended = true
	if is_instance_valid(_player):
		var p := _player
		p.damage_multiplier /= _dmg_factor
		p.fire_rate /= _fire_factor
		p.projectile_size /= _size_factor
		p.shot_speed -= _shot_speed_delta
		p.projectile_knockback -= _knockback_delta
		p.move_speed -= _speed_delta
		p.luck -= luck_bonus
		for proc in extra_procs:
			p.shot_procs.erase(proc)
		p.resync_shot_style()
		if tint != Color.WHITE:
			p.modulate = Color.WHITE
		if invulnerable:
			p.invulnerable = false
		if apply_end_effects and heal_on_end > 0:
			p.heal(heal_on_end)
		var meta := "temp_buff_" + key
		if p.has_meta(meta) and p.get_meta(meta) == self:
			p.remove_meta(meta)
	queue_free()
