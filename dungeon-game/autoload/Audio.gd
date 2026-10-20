## Audio (autoload "Audio") — background music + sound effects.
##
## Music: one looping track. Keeps playing through pauses (inventory, P freeze) and
## scene reloads (death), since autoloads live outside the scene.
## SFX: Audio.play_sfx(stream) from anywhere. A small pool of players so sounds can
## overlap (fast fire rates), each with a little random pitch so repeats don't sound
## identical. SFX pause with the game.
##
## To swap the placeholder audio: replace the files at MUSIC_PATH / SHOOT_PATH
## (same names), or point these constants at new files.
extends Node

# Paths + load() (not preload) so a missing/not-yet-imported file never breaks the
# autoload: the game just runs without that sound.
const MUSIC_PATH := "res://assets/audio/music/sewer_theme.ogg"
const BOSS_MUSIC_PATH := "res://assets/audio/music/boss_theme.ogg"
const SHOOT_PATH := "res://assets/audio/sfx/shoot_plop.wav"

## Loudness in dB (0 = full, -6 = about half as loud, -80 = silent).
const MUSIC_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -8.0
## Extra adjustment for the shot sound only (it plays a lot). Negative = quieter.
const SHOOT_VOLUME_DB := -10.0
## Seconds to fade between the normal and the boss track.
const MUSIC_FADE_TIME := 0.8
const SFX_VOICES := 8

var shoot_sound: AudioStream

var _music: AudioStreamPlayer
var _normal_music: AudioStream
var _boss_music: AudioStream
var _fade: Tween
## The track that should be playing (may still be fading in). Compared instead of
## _music.stream so leave-then-enter in the same frame (R restart, death in the
## arena) ends on the right track.
var _target_music: AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


## Players are built in _init, not _ready: when a scene is run directly (F6) its nodes
## can enter the tree before this autoload's _ready, and they may already ask for a
## track (the boss arena does).
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # music keeps going while the game is paused

	shoot_sound = _load_stream(SHOOT_PATH)
	_normal_music = _looping(_load_stream(MUSIC_PATH))
	_boss_music = _looping(_load_stream(BOSS_MUSIC_PATH))
	_target_music = _normal_music

	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)

	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE  # effects freeze with the game
		add_child(voice)
		_voices.append(voice)


func _ready() -> void:
	# Whatever was asked for before we were ready (normal music, or the boss theme
	# when the arena scene is the one being run).
	_music.stream = _target_music
	if _music.stream:
		_music.play()


## Plays a one-shot effect. volume_db is added on top of SFX_VOLUME_DB.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.08) -> void:
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = SFX_VOLUME_DB + volume_db
	voice.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	voice.play()


func play_shoot() -> void:
	play_sfx(shoot_sound, SHOOT_VOLUME_DB)


## The final boss arena calls these when it's entered / left / the boss dies.
func play_boss_music() -> void:
	_switch_music(_boss_music)


func play_normal_music() -> void:
	_switch_music(_normal_music)


## Fades the current track out, then starts `stream` from the top and fades it in.
## Does nothing if that track is already the one playing.
func _switch_music(stream: AudioStream) -> void:
	if stream == null or stream == _target_music:
		return
	_target_music = stream
	if not is_inside_tree() or not is_node_ready():
		return  # _ready starts _target_music
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _music.playing:
		_fade.tween_property(_music, "volume_db", -40.0, MUSIC_FADE_TIME * 0.5)
	_fade.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	_fade.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_TIME * 0.5)


func set_music_playing(on: bool) -> void:
	if on and not _music.playing and _music.stream:
		_music.play()
	elif not on:
		_music.stop()


static func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


static func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Audio: missing " + path)
		return null
	return load(path) as AudioStream
