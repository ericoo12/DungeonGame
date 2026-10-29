## A small health bar floating just above an enemy's (or boss's) visible art.
## An enemy can hide its bar for a while with `hide_health_bar = true` (Gutterjaw under
## the sewage). Shown while the debug view is on: Tab toggles it together with the stats and the map
## (HUD sets EnemyHealthBar.show_all). EnemyBase / FinalBossBase add one each.
extends Node2D

static var show_all: bool = true

## Width of the bar (px) for normal enemies / bosses.
const WIDTH := 16.0
const BOSS_WIDTH := 44.0
const HEIGHT := 2.0
const GAP := 3.0   # above the art's top edge
const COL_BACK := Color(0.05, 0.03, 0.03, 0.75)
const COL_FILL := Color(0.9, 0.18, 0.15)
const COL_FILL_BOSS := Color(0.85, 0.35, 0.95)

var target: Node2D
var _frac: float = 1.0
var _width: float = WIDTH
var _boss: bool = false

## Visible top of each frame texture (empty padding trimmed), cached per texture.
static var _top_cache: Dictionary = {}


func _ready() -> void:
	top_level = true   # placed in world coordinates, unaffected by the enemy's scale/flip
	z_index = 60


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var health = target.get("health")
	var max_health = target.get("max_health")
	visible = show_all and target.is_visible_in_tree() and health != null and max_health != null \
		and max_health > 0.0 and not target.get("is_dying") and target.get("hide_health_bar") != true
	if not visible:
		return
	_boss = target.get("is_boss") == true
	_width = BOSS_WIDTH if _boss else WIDTH
	_frac = clampf(health / max_health, 0.0, 1.0)
	global_position = _top_point().round()
	queue_redraw()


## Centre-top of the target's visible sprite art (falls back to just above its origin).
func _top_point() -> Vector2:
	var spr := target.get("sprite") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null or not spr.sprite_frames.has_animation(spr.animation):
		return target.global_position + Vector2(0, -18)
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return target.global_position + Vector2(0, -18)
	var size := tex.get_size()
	var used_top := _used_top(tex)
	var scale_y := absf(spr.global_scale.y)
	var top_local := (-size.y / 2.0 if spr.centered else 0.0) + spr.offset.y + used_top
	return Vector2(spr.global_position.x, spr.global_position.y + top_local * scale_y - GAP - HEIGHT)


static func _used_top(tex: Texture2D) -> float:
	var id := tex.get_instance_id()
	if _top_cache.has(id):
		return _top_cache[id]
	var top := 0.0
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.has_area():
			top = used.position.y
	_top_cache[id] = top
	return top


func _draw() -> void:
	var w := _width
	draw_rect(Rect2(-w / 2.0 - 1.0, -1.0, w + 2.0, HEIGHT + 2.0), COL_BACK)
	if _frac > 0.0:
		draw_rect(Rect2(-w / 2.0, 0.0, w * _frac, HEIGHT), COL_FILL_BOSS if _boss else COL_FILL)
