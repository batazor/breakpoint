extends Node
class_name MusicManager

## Manages background music playback with crossfading between tracks

signal music_changed(track_name: String)

@export var world_music_path: String = "res://assets/music/world/JDSherbert - Ambiences Music Pack - Desert Sirocco.ogg"
@export var city_music_path: String = "res://assets/music/city/JDSherbert - Ambiences Music Pack - The Blackpenny Pub.ogg"
@export var fade_duration: float = 2.0
@export var default_volume_db: float = -10.0
@export var autoplay: bool = true

enum MusicTrack {
	NONE,
	WORLD,
	CITY
}

var _current_track: MusicTrack = MusicTrack.NONE
var _audio_player1: AudioStreamPlayer
var _audio_player2: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _fading_player: AudioStreamPlayer
var _fade_timer: float = 0.0
var _is_fading: bool = false
var _target_volume: float = 0.0
var _fade_in: bool = false


func _ready() -> void:
	_setup_audio_players()
	
	if autoplay:
		play_world_music()


func _setup_audio_players() -> void:
	# Create two audio players for crossfading
	_audio_player1 = AudioStreamPlayer.new()
	_audio_player1.name = "MusicPlayer1"
	_audio_player1.volume_db = default_volume_db
	_audio_player1.bus = "Master"
	add_child(_audio_player1)
	
	_audio_player2 = AudioStreamPlayer.new()
	_audio_player2.name = "MusicPlayer2"
	_audio_player2.volume_db = -80.0  # Start silent
	_audio_player2.bus = "Master"
	add_child(_audio_player2)
	
	_active_player = _audio_player1


func _process(delta: float) -> void:
	if _is_fading:
		_update_fade(delta)


func _update_fade(delta: float) -> void:
	_fade_timer += delta
	var progress := minf(_fade_timer / fade_duration, 1.0)
	
	if _fade_in:
		# Fade in active player, fade out fading player
		_active_player.volume_db = lerpf(-80.0, default_volume_db, progress)
		if _fading_player != null:
			_fading_player.volume_db = lerpf(default_volume_db, -80.0, progress)
	else:
		# Fade out only
		_active_player.volume_db = lerpf(default_volume_db, -80.0, progress)
	
	if progress >= 1.0:
		_finish_fade()


func _finish_fade() -> void:
	_is_fading = false
	_fade_timer = 0.0
	
	if _fading_player != null:
		_fading_player.stop()
		_fading_player.volume_db = -80.0
		_fading_player = null
	
	if not _fade_in:
		_active_player.stop()


func play_world_music() -> void:
	_play_track(MusicTrack.WORLD, world_music_path)


func play_city_music() -> void:
	_play_track(MusicTrack.CITY, city_music_path)


func stop_music() -> void:
	if _active_player.playing:
		_start_fade_out()


func set_volume(volume_db: float) -> void:
	default_volume_db = volume_db
	if not _is_fading and _active_player != null:
		_active_player.volume_db = volume_db


func get_current_track() -> MusicTrack:
	return _current_track


func is_playing() -> bool:
	return _active_player != null and _active_player.playing


func _play_track(track: MusicTrack, path: String) -> void:
	if track == _current_track and _active_player.playing:
		return  # Already playing this track
	
	# Load the music file
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("MusicManager: Failed to load music: %s" % path)
		return
	
	_current_track = track
	
	# Determine which player to use for new track
	var new_player: AudioStreamPlayer
	if _active_player == _audio_player1:
		new_player = _audio_player2
	else:
		new_player = _audio_player1
	
	# Set up new player
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	
	# Start crossfade
	_fading_player = _active_player
	_active_player = new_player
	_start_fade_in()
	
	emit_signal("music_changed", path.get_file().get_basename())


func _start_fade_in() -> void:
	_is_fading = true
	_fade_in = true
	_fade_timer = 0.0


func _start_fade_out() -> void:
	_is_fading = true
	_fade_in = false
	_fade_timer = 0.0
	_current_track = MusicTrack.NONE
