class_name FTTitleScreen
extends Control

## The first screen: the Flatbush Tactics logo flies in (FLATBUSH from the
## left, TACTICS from the right), then TAP TO START blinks. Any tap, click or
## key goes straight to Freelancer Select, even mid fly-in.
## The logo is spritework/logo.aseprite cropped to the lettering, scaled to
## 0.73x so it fits the 360px width, and split into its two words
## (assets/ui/title/logo_*.png, same width so they line up when landed); a
## logo redrawn at 360px wide or less can replace it at 1x.

const FRAME_SIZE := Vector2(360, 780)
const FLATBUSH: Texture2D = preload("res://assets/ui/title/logo_flatbush.png")
const TACTICS: Texture2D = preload("res://assets/ui/title/logo_tactics.png")
## TACTICS sits this far below the top of FLATBUSH once landed.
const TACTICS_OFFSET_Y := 29.0
const NEXT_SCENE := "res://scenes/FreelancerSelect.tscn"
# Lux2k: darkest purple and the light cream.
const BACKGROUND := Color8(37, 19, 26)
const PROMPT_INK := Color8(230, 222, 202)
const LOGO_Y := 250.0
const PROMPT_Y := 520.0

## Time for each word to fly in.
@export var fly_seconds := 0.45
## TACTICS starts this long after FLATBUSH.
@export var tactics_delay := 0.15
## One blink: shown this long, then hidden this long.
@export var blink_seconds := 0.5
## Input is ignored this long after the screen opens, so a stray tap can't
## skip it.
@export var input_delay := 0.3

var flatbush: TextureRect
var tactics: TextureRect
var prompt: Label
var opened_at := 0.0
var intro: Tween
var intro_done := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	opened_at = Time.get_ticks_msec() / 1000.0
	Music.play(Music.MENU_SONG, -6.0, Music.MENU_SONG_START)
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var rain := FTDigitalRain.new()
	rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rain)
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = -FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	flatbush = _word(frame, FLATBUSH, LOGO_Y)
	tactics = _word(frame, TACTICS, LOGO_Y + TACTICS_OFFSET_Y)
	# A strip of background behind the prompt so the rain never runs through it.
	var backing := ColorRect.new()
	backing.color = BACKGROUND
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.position = Vector2(88, PROMPT_Y - 4)
	backing.size = Vector2(FRAME_SIZE.x - 176, 32)
	frame.add_child(backing)
	prompt = Label.new()
	prompt.text = "TAP TO START"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", PROMPT_INK)
	prompt.position = Vector2(0, PROMPT_Y)
	prompt.size = Vector2(FRAME_SIZE.x, 24)
	prompt.visible = false
	frame.add_child(prompt)
	# Words wait off-screen until the music can be heard, then fly in.
	_place_off_screen()
	await Music.wait_until_audible(Music.MENU_SONG_START)
	_fly_in()

func _word(parent: Control, texture: Texture2D, y: float) -> TextureRect:
	var word := TextureRect.new()
	word.texture = texture
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.position.y = y
	parent.add_child(word)
	return word

func _landed_x() -> float:
	return roundf((FRAME_SIZE.x - FLATBUSH.get_width()) / 2.0)

# Each word starts just past its side of the window (wider windows show more
# than the 360px frame) and slides in, overshooting a little before it
# settles. Positions are rounded so the art stays on the pixel grid.
func _place_off_screen() -> void:
	var margin := maxf((get_viewport_rect().size.x - FRAME_SIZE.x) / 2.0, 0.0)
	flatbush.position.x = -margin - FLATBUSH.get_width()
	tactics.position.x = FRAME_SIZE.x + margin

func _fly_in() -> void:
	_place_off_screen()
	var from_left := flatbush.position.x
	var from_right := tactics.position.x
	intro = create_tween().set_parallel()
	intro.tween_method(func(x: float): flatbush.position.x = roundf(x), from_left, _landed_x(), fly_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_method(func(x: float): tactics.position.x = roundf(x), from_right, _landed_x(), fly_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(tactics_delay)
	intro.chain().tween_callback(_finish_intro)

func _finish_intro() -> void:
	if intro_done:
		return
	intro_done = true
	if intro:
		intro.kill()
	flatbush.position.x = _landed_x()
	tactics.position.x = _landed_x()
	prompt.visible = true
	# Hard on/off blink, arcade style.
	var blink := create_tween().set_loops()
	blink.tween_interval(blink_seconds)
	blink.tween_callback(func(): prompt.visible = not prompt.visible)

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed or Time.get_ticks_msec() / 1000.0 - opened_at < input_delay:
		return
	get_viewport().set_input_as_handled()
	Music.play_sound(Music.MENU_SELECT)
	get_tree().change_scene_to_file(NEXT_SCENE)
