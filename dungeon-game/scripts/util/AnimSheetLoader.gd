class_name AnimSheetLoader
extends RefCounted

## Slices Pixel Crawler's Body_A sprite sheets into a SpriteFrames resource at runtime.
## Avoids hand-building 9+ animations in the editor and keeps everything git-diffable as code.

const BASE_PATH := "res://assets/sprites/player/Body_A/Animations/"

static func build_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add(frames, "idle_down", BASE_PATH + "Idle_Base/Idle_Down-Sheet.png", 4, 6.0)
	_add(frames, "idle_side", BASE_PATH + "Idle_Base/Idle_Side-Sheet.png", 4, 6.0)
	_add(frames, "idle_up",   BASE_PATH + "Idle_Base/Idle_Up-Sheet.png",   4, 6.0)

	_add(frames, "run_down", BASE_PATH + "Run_Base/Run_Down-Sheet.png", 6, 6.0)
	_add(frames, "run_side", BASE_PATH + "Run_Base/Run_Side-Sheet.png", 6, 6.0)
	_add(frames, "run_up",   BASE_PATH + "Run_Base/Run_Up-Sheet.png",   6, 6.0)

	_add(frames, "shoot_run_down", BASE_PATH + "Carry_Run/Carry_Run_Down-Sheet.png", 6, 6.0, false)
	_add(frames, "shoot_run_side", BASE_PATH + "Carry_Run/Carry_Run_Side-Sheet.png", 6, 6.0, false)
	_add(frames, "shoot_run_up",   BASE_PATH + "Carry_Run/Carry_Run_Up-Sheet.png",  6, 6.0, false)

	_add(frames, "shoot_idle_down", BASE_PATH + "Carry_Idle/Carry_Idle_Down-Sheet.png", 4, 6.0, false)
	_add(frames, "shoot_idle_side", BASE_PATH + "Carry_Idle/Carry_Idle_Side-Sheet.png", 4, 6.0, false)
	_add(frames, "shoot_idle_up",   BASE_PATH + "Carry_Idle/Carry_Idle_Up-Sheet.png",  4, 6.0, false)
	
	_add(frames, "player_death_down",   BASE_PATH + "Death_Base/Death_Down-Sheet.png",  8, 6.0, false)
	_add(frames, "player_death_side",   BASE_PATH + "Death_Base/Death_Side-Sheet.png",  8, 6.0, false)
	_add(frames, "player_death_up",   BASE_PATH + "Death_Base/Death_Up-Sheet.png",  8, 6.0, false)

	
	return frames

static func _add(frames: SpriteFrames, anim_name: String, path: String, frame_count: int, fps: float, loop: bool = true, target_height: int = -1) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("AnimSheetLoader: missing texture at %s" % path)
		return

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)

	var native_height := tex.get_height()
	var frame_width := int(tex.get_width() / frame_count)
	var frame_height := target_height if target_height > 0 else native_height
	var y_offset := frame_height - native_height  # padding needed above the real art

	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_width, -y_offset, frame_width, frame_height)
		frames.add_frame(anim_name, atlas)


static func build_enemy_frames(sheets: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for anim_name in sheets.keys():
		var entry: Dictionary = sheets[anim_name]
		_add(frames, anim_name, entry["path"], entry["count"], 10.0, anim_name != "death", 64)

	return frames
