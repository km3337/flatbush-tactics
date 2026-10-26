extends Node

## Music that carries across scene changes (autoload `Music`), so the menu
## song keeps playing from the title screen into Freelancer Select. Battles
## still play their own music (main.gd). Also plays menu sounds, which would
## be cut off if the screen that triggered them owned the player.

const MENU_SONG: AudioStream = preload("res://assets/music/menu_secret_portraits.mp3")
## Confirm sound for menus (tap to start, start run, board a line): from a
## Mega Man Zero SFX collection at 0:10 (spritework/sfx/).
const MENU_SELECT: AudioStream = preload("res://assets/sfx/menu_select.wav")
## Start the menu song just before the section that hits at 6.1s (skipping
## the slow intro, which fades to near-silence from about 5.2s).
const MENU_SONG_START := 6.05

var player: AudioStreamPlayer
var _sound: AudioStreamPlayer
var _fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	add_child(player)
	_sound = AudioStreamPlayer.new()
	_sound.max_polyphony = 2
	add_child(_sound)

## A one-off sound that survives scene changes (menu confirms).
func play_sound(stream: AudioStream) -> void:
	_sound.stream = stream
	_sound.play()

## Loops `stream`, starting `from` seconds in. If it's already playing, it
## just carries on (and any fade-out in progress is cancelled).
func play(stream: AudioStream, volume_db := -6.0, from := 0.0) -> void:
	if _fade:
		_fade.kill()
	player.volume_db = volume_db
	if player.playing and player.stream == stream:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player.stream = stream
	player.play(from)

## Waits until the current song is actually coming out of the speakers
## (mixed past `from`, plus the audio device's output delay and one mix
## buffer of margin), or `limit` seconds at most, so a machine without audio
## never stalls.
func wait_until_audible(from := 0.0, limit := 1.5) -> void:
	var waited := 0.0
	while waited < limit:
		if player.playing and player.get_playback_position() >= from + AudioServer.get_output_latency() + 0.05:
			return
		await get_tree().process_frame
		waited += get_process_delta_time()

func fade_out(seconds := 1.5) -> void:
	if not player.playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(player, "volume_db", -60.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_fade.tween_callback(player.stop)
