class_name AnimSheetLoader
extends RefCounted


# ============================================================
# PLAYER - CAPTAIN FILLING
# Lower body: animated legs (idle + run per direction, 2-row grid, one file per direction).
# Upper body: static torso/head/arm textures, assembled in Player.gd.
# ============================================================

static func build_lower_body_frames() -> SpriteFrames:
	var lower := SpriteFrames.new()
	lower.remove_animation("default")

	const LOWER_PATH := "res://assets/sprites/player/Filling2/Lower/"

	_add_2row_anim(lower, "idle_down", LOWER_PATH + "front_lower.png", 0, [0], 6.0, true)
	_add_2row_anim(lower, "run_down",  LOWER_PATH + "front_lower.png", 1, [0, 1, 2, 3], 8.0, true)

	_add_2row_anim(lower, "idle_left", LOWER_PATH + "left_lower.png", 0, [0], 6.0, true)
	_add_2row_anim(lower, "run_left",  LOWER_PATH + "left_lower.png", 1, [0, 1, 3, 2], 12.0, true)

	_add_2row_anim(lower, "idle_up", LOWER_PATH + "up_lower.png", 0, [0], 6.0, true)
	_add_2row_anim(lower, "run_up",  LOWER_PATH + "up_lower.png", 1, [0, 1, 2, 3], 4.0, true)

	return lower


## Returns {"torso": {dir: Texture2D}, "head": {...}, "arm": {...}, "offarm": {...}} for
## down/left/up. Right is left with flip_h, handled in Player.gd.
## Plain textures, not SpriteFrames — these pieces don't animate.
static func build_body_part_textures() -> Dictionary:
	const BODY_PATH := "res://assets/sprites/player/Filling3/"

	var result := {"torso": {}, "head": {}, "arm": {}, "offarm": {}}
	for dir in ["down", "left", "up"]:
		result.torso[dir] = _load_texture(BODY_PATH + "torso_%s.png" % dir)
		result.head[dir] = _load_texture(BODY_PATH + "head_%s.png" % dir)
		result.arm[dir] = _load_texture(BODY_PATH + "arm_%s.png" % dir)
		result.offarm[dir] = _load_texture(BODY_PATH + "offarm_%s.png" % dir)
	return result


static func _load_texture(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
	return tex


static func _add_player_anim(frames: SpriteFrames, anim_name: String, path: String, frame_indices: Array, fps: float, loop: bool, source_columns: int = 4) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)

	var frame_width := int(tex.get_width() / source_columns)
	var frame_height := tex.get_height()

	for i in frame_indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)


static func _add_2row_anim(frames: SpriteFrames, anim_name: String, path: String, row: int, frame_indices: Array, fps: float, loop: bool, source_columns: int = 4) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)

	var frame_width := int(tex.get_width() / source_columns)
	var frame_height := int(tex.get_height() / 2)

	for i in frame_indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, row * frame_height, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)


# ============================================================
# ENEMY - 9 COLUMNS × 4 ROWS (combined grid sheet, e.g. DoktorMugg)
#
# Columns: 0-3 = run, 4-6 = attack, 7-8 = damage
# Rows: 0 = down, 1 = left, 2 = right, 3 = up
# ============================================================

static func build_enemy_frames(path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load enemy texture: " + path)
		return frames

	var directions: Array[String] = ["down", "left", "right", "up"]

	for row in range(4):
		var direction := directions[row]
		_add_grid_animation(frames, tex, "run_" + direction,    row, 0, 4, 8.0,  true)
		_add_grid_animation(frames, tex, "attack_" + direction, row, 4, 3, 10.0, false)
		_add_grid_animation(frames, tex, "damage_" + direction, row, 7, 2, 8.0,  false)

	return frames


static func _add_grid_animation(frames: SpriteFrames, texture: Texture2D, anim_name: String, row: int, start_column: int, frame_count: int, fps: float, loop: bool) -> void:
	const COLUMNS := 9
	const ROWS := 4

	var frame_width := int(texture.get_width() / COLUMNS)
	var frame_height := int(texture.get_height() / ROWS)

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)

	for i in range(frame_count):
		var column := start_column + i
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(column * frame_width, row * frame_height, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)


# ============================================================
# ENEMY - PER-FILE, PER-DIRECTION (e.g. Toilet Brush)
# ============================================================

## Maps a set of separate per-animation, per-direction files onto the
## animation KEY names EnemyBase/subclasses expect, independent of the
## source filenames. No "right" — mirrored from "left" in code.
static func build_toilet_brush_frames(base_path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var sets := [
		{"key": "run",          "file": "brush_walk",        "count": 4, "fps": 8.0,  "loop": true},
		{"key": "attack_lunge", "file": "brush_attack_lunge", "count": 3, "fps": 10.0, "loop": false},
		{"key": "attack_spit",  "file": "brush_attack_spit",  "count": 3, "fps": 10.0, "loop": false},
		{"key": "damage",       "file": "brush_hit",          "count": 2, "fps": 10.0, "loop": false},
		{"key": "death",        "file": "brush_death",        "count": 3, "fps": 8.0,  "loop": false},
	]
	var directions := ["down", "left", "up"]

	for entry in sets:
		for dir in directions:
			var anim_name: String = "%s_%s" % [entry.key, dir]
			var path: String = "%s%s_%s.png" % [base_path, entry.file, dir]
			_add_player_anim(frames, anim_name, path, range(entry.count), entry.fps, entry.loop, entry.count)

	return frames


# ============================================================
# ENEMY - SIDE VIEW (one horizontal run cycle facing LEFT, e.g. Rat)
# ============================================================

## A single row of `frame_count` equal frames, drawn facing left. Every direction uses
## that cycle; there's deliberately no "_right" animation, so EnemyBase mirrors "left"
## (flip_h) when moving right. attack_/damage_ reuse the run cycle so EnemyBase's
## shared sprite.play(...) calls always find an animation.
static func build_side_view_enemy_frames(path: String, frame_count: int, fps: float = 12.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load side-view enemy texture: " + path)
		return frames

	var frame_width := tex.get_width() / frame_count
	for prefix in ["run", "attack", "damage"]:
		for dir in ["down", "left", "up"]:
			var anim_name: String = "%s_%s" % [prefix, dir]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			frames.set_animation_loop(anim_name, prefix == "run")
			for i in frame_count:
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(i * frame_width, 0, frame_width, tex.get_height())
				frames.add_frame(anim_name, atlas)
	return frames


# ============================================================
# ENEMY - IDLE + ATTACK SHEETS (front-facing, e.g. sewer turret)
# ============================================================

## Two single-row sheets of square frames (frame count = width / height):
##   idle_path   -> "run_<dir>" (looping) and "damage_<dir>" (one play, the hit flash
##                  is EnemyBase's red modulate)
##   attack_path -> "attack_<dir>" (one play)
## Same frames for every direction, including "_right" so nothing gets mirrored.
static func build_idle_attack_frames(idle_path: String, attack_path: String,
		idle_fps: float = 6.0, attack_fps: float = 10.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var idle := load(idle_path) as Texture2D
	var attack := load(attack_path) as Texture2D
	if idle == null or attack == null:
		push_error("AnimSheetLoader: could not load idle/attack sheets: %s, %s" % [idle_path, attack_path])
		return frames
	for dir in ["down", "left", "right", "up"]:
		_add_row_animation(frames, "run_" + dir, idle, idle_fps, true)
		_add_row_animation(frames, "damage_" + dir, idle, idle_fps * 2.0, false)
		_add_row_animation(frames, "attack_" + dir, attack, attack_fps, false)
	return frames


static func _add_row_animation(frames: SpriteFrames, anim_name: String, tex: Texture2D, fps: float, loop: bool) -> void:
	var size := tex.get_height()  # square frames
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in tex.get_width() / size:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * size, 0, size, size)
		frames.add_frame(anim_name, atlas)


# ============================================================
# ENEMY - STATIC (no real animation, e.g. Smiley)
# ============================================================

## Every expected animation key (run/damage/attack, per direction) points at
## the same single static image. Keeps full compatibility with EnemyBase's
## shared sprite.play(...) calls without needing a custom script.
static func build_static_enemy_frames(path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load static enemy texture: " + path)
		return frames

	var directions := ["down", "left", "right", "up"]
	var prefixes := ["run", "damage", "attack"]  # death_ deliberately omitted — die() already
												  # checks has_animation() before playing it

	for prefix in prefixes:
		for dir in directions:
			var anim_name: String = "%s_%s" % [prefix, dir]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, 1.0)
			frames.set_animation_loop(anim_name, true)
			frames.add_frame(anim_name, tex)

	return frames


# ============================================================
# SINGLE HORIZONTAL ANIMATION
# Used by things like the projectile splash / tumble effects
# ============================================================

static func build_single_animation(path: String, frame_count: int, fps: float, loop: bool = true, animation_name: String = "splash") -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return frames

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	var frame_width := int(tex.get_width() / frame_count)
	var frame_height := tex.get_height()

	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame(animation_name, atlas)

	return frames
	
	
## Same as build_single_animation, but takes explicit frame_indices instead of
## a plain count — lets you skip/reorder/loop a specific subset of frames.
static func build_single_animation_indexed(path: String, frame_indices: Array, source_columns: int, fps: float, loop: bool = true, animation_name: String = "splash") -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return frames

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)

	var frame_width := int(tex.get_width() / source_columns)
	var frame_height := tex.get_height()

	for i in frame_indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame(animation_name, atlas)

	return frames


static func build_cosmetic_2row_frames(down_path: String, left_path: String, up_path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_2row_anim(frames, "idle_down", down_path, 0, [0, 1, 2, 3], 6.0, true)
	_add_2row_anim(frames, "run_down",  down_path, 1, [0, 1, 2, 3], 8.0, true)
	_add_2row_anim(frames, "idle_left", left_path, 0, [0, 1, 2, 3], 6.0, true)
	_add_2row_anim(frames, "run_left",  left_path, 1, [0, 1, 2, 3], 8.0, true)
	_add_2row_anim(frames, "idle_up",   up_path,   0, [0, 1, 2, 3], 6.0, true)
	_add_2row_anim(frames, "run_up",    up_path,   1, [0, 1, 2, 3], 8.0, true)

	return frames
