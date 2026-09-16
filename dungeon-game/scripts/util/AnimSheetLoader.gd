class_name AnimSheetLoader
extends RefCounted


# ============================================================
# PLAYER - CAPTAIN FILLING
# ============================================================

const PLAYER_PATH := "res://assets/sprites/player/Filling/"


static func build_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Idle: 4 columns × 4 rows
	_add_directional_sheet(
		frames,
		PLAYER_PATH + "StandingFilling.png",
		"idle",
		4,
		6.0,
		true
	)

	# Run: 4 columns × 4 rows
	_add_directional_sheet(
		frames,
		PLAYER_PATH + "RunningFilling.png",
		"run",
		4,
		8.0,
		true
	)

	# Standing attack: 5 columns × 4 rows
	_add_directional_sheet(
		frames,
		PLAYER_PATH + "StandingAttackingFilling.png",
		"throw_idle",
		5,
		10.0,
		false
	)

	# Running attack: 5 columns × 4 rows
	_add_directional_sheet(
		frames,
		PLAYER_PATH + "RunningAttackingFilling.png",
		"throw_run",
		5,
		10.0,
		false
	)

	print("PLAYER ANIMATIONS: ", frames.get_animation_names())

	return frames


static func _add_directional_sheet(
	frames: SpriteFrames,
	path: String,
	base_name: String,
	columns: int,
	fps: float,
	loop: bool
) -> void:
	var tex := load(path) as Texture2D

	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return

	const ROWS := 4

	var directions: Array[String] = [
		"down",
		"left",
		"right",
		"up"
	]

	var frame_width := int(tex.get_width() / columns)
	var frame_height := int(tex.get_height() / ROWS)

	for row in range(ROWS):
		var anim_name := base_name + "_" + directions[row]

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)

		for column in range(columns):
			var atlas := AtlasTexture.new()

			atlas.atlas = tex
			atlas.region = Rect2(
				column * frame_width,
				row * frame_height,
				frame_width,
				frame_height
			)

			frames.add_frame(anim_name, atlas)


# ============================================================
# ENEMY - 9 COLUMNS × 4 ROWS
#
# Columns:
# 0-3 = run
# 4-6 = attack
# 7-8 = damage
#
# Rows:
# 0 = down
# 1 = left
# 2 = right
# 3 = up
# ============================================================

static func build_enemy_frames(path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D

	if tex == null:
		push_error("AnimSheetLoader: could not load enemy texture: " + path)
		return frames

	var directions: Array[String] = [
		"down",
		"left",
		"right",
		"up"
	]

	for row in range(4):
		var direction := directions[row]

		_add_grid_animation(
			frames,
			tex,
			"run_" + direction,
			row,
			0,
			4,
			8.0,
			true
		)

		_add_grid_animation(
			frames,
			tex,
			"attack_" + direction,
			row,
			4,
			3,
			10.0,
			false
		)

		_add_grid_animation(
			frames,
			tex,
			"damage_" + direction,
			row,
			7,
			2,
			8.0,
			false
		)

	return frames


static func _add_grid_animation(
	frames: SpriteFrames,
	texture: Texture2D,
	anim_name: String,
	row: int,
	start_column: int,
	frame_count: int,
	fps: float,
	loop: bool
) -> void:
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
		atlas.region = Rect2(
			column * frame_width,
			row * frame_height,
			frame_width,
			frame_height
		)

		frames.add_frame(anim_name, atlas)


# ============================================================
# SINGLE HORIZONTAL ANIMATION
#
# Used by things such as poop_splash.png
# ============================================================

static func build_single_animation(
	path: String,
	frame_count: int,
	fps: float,
	loop: bool = true
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var tex := load(path) as Texture2D

	if tex == null:
		push_error("AnimSheetLoader: could not load texture: " + path)
		return frames

	frames.add_animation("splash")
	frames.set_animation_speed("splash", fps)
	frames.set_animation_loop("splash", loop)

	var frame_width := int(tex.get_width() / frame_count)
	var frame_height := tex.get_height()

	for i in range(frame_count):
		var atlas := AtlasTexture.new()

		atlas.atlas = tex
		atlas.region = Rect2(
			i * frame_width,
			0,
			frame_width,
			frame_height
		)

		frames.add_frame("splash", atlas)

	return frames
