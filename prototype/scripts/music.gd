extends Node

## Music that carries across scene changes (autoload `Music`), so the menu
## song keeps playing from the title screen into Freelancer Select. Battles
## still play their own music (main.gd).

const MENU_SONG: AudioStream = preload("res://assets/music/menu_secret_portraits.mp3")
## The menu song opens with ~0.25s of silence; start just before the sound.
const MENU_SONG_START := 0.2

var player: AudioStreamPlayer
var _fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	add_child(player)

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
