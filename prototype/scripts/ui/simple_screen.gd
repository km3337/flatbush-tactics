class_name FTSimpleScreen
extends Control

## A full-screen message with a title, body text and one button, centred in
## the 360x640 frame. Subclasses fill it in `_setup()` and react in
## `_on_button()`. Space / Enter press the button.

var background_color := Color(0.04, 0.08, 0.16)
var title_color := Color.WHITE
var title := ""
var body := ""
var button_text := "CONTINUE"
var button: Button

func _setup() -> void:
	pass

func _on_button() -> void:
	pass

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup()
	var bg := ColorRect.new()
	bg.color = background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = -Vector2(180, 320)
	frame.size = Vector2(360, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.position = Vector2(20, 120)
	title_label.size = Vector2(320, 80)
	frame.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.add_theme_font_size_override("font_size", 12)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.position = Vector2(24, 220)
	body_label.size = Vector2(312, 300)
	frame.add_child(body_label)
	button = Button.new()
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.position = Vector2(40, 560)
	button.size = Vector2(280, 40)
	button.pressed.connect(_press)
	frame.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_press()

func _press() -> void:
	if button.disabled:
		return
	button.disabled = true
	_on_button()
