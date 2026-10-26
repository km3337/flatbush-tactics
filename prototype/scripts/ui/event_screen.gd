class_name FTEventScreen
extends Control

## A ? stop. Picks an event (Run.pick_event), shows its text and choices,
## then the rolled outcome's text and what changed. If a new round puts the
## arsenal over capacity, asks which round to remove. CONTINUE moves on.
## Keys: 1/2/3 choose, Space/Enter continue.

const BACKGROUND := Color(0.09, 0.1, 0.13)
const ACCENT := Color(1.0, 0.85, 0.2)
const GOOD := Color(0.55, 0.9, 0.45)
const BAD := Color(1.0, 0.45, 0.4)

var event: FTEvent
var frame: Control
var status_label: Label
var text_label: Label
var effects_label: Label
var buttons: Array[Button] = []
var continue_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	event = Run.pick_event()
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = -Vector2(180, 320)
	frame.size = Vector2(360, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var header := ColorRect.new()
	header.color = Color(0.03, 0.03, 0.04)
	header.size = Vector2(360, 34)
	frame.add_child(header)
	var where := Run.current_station.display_name.to_upper() if Run.current_station else ""
	var detour := Run.current_station and Run.current_station not in Run.current_line().stations
	_label(header, "?  %s%s" % ["DETOUR · " if detour else "", where], Vector2(12, 0), Vector2(220, 34), 8)
	status_label = _label(header, "", Vector2(150, 0), Vector2(198, 34), 8)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_status()

	# Art goes here later; for now a framed box with the title.
	var art := ColorRect.new()
	art.color = Color(0.14, 0.16, 0.22)
	art.position = Vector2(20, 46)
	art.size = Vector2(320, 130)
	frame.add_child(art)
	var art_mark := _label(art, "?", Vector2.ZERO, art.size, 64)
	art_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.15))
	var title := _label(frame, event.title.to_upper(), Vector2(20, 184), Vector2(320, 30), 16)
	title.add_theme_color_override("font_color", ACCENT)
	text_label = _label(frame, event.text, Vector2(20, 220), Vector2(320, 190), 8)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	effects_label = _label(frame, "", Vector2(20, 412), Vector2(320, 90), 8)
	effects_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	for i in event.choices.size():
		var choice := event.choices[i]
		var affordable := Run.money >= choice.requires_money
		var button := _button("%d  %s%s" % [i + 1, choice.label, "" if affordable else "  (NO CASH)"], Vector2(30, 640 - 56 - (event.choices.size() - 1 - i) * 52))
		button.disabled = not affordable
		button.pressed.connect(_choose.bind(choice))
		buttons.append(button)

func _label(parent: Control, text: String, pos: Vector2, size_: Vector2, font_size: int) -> Label:
	var label := Label.new()
	# Wrap before sizing, or the label widens to fit the text on one line.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size_
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(text: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = pos
	button.size = Vector2(300, 44)
	button.add_theme_font_size_override("font_size", 8)
	frame.add_child(button)
	return button

func _update_status() -> void:
	status_label.text = "HP %d/%d   $%d" % [Run.current_hp(), Run.max_hp(), Run.money]

func _clear_buttons() -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()

func _choose(choice: FTEventChoice) -> void:
	if buttons.is_empty():
		return
	_clear_buttons()
	var outcome := choice.roll(Run.rng)
	text_label.text = outcome.text
	var lines := outcome.apply()
	effects_label.text = "\n".join(lines)
	var bad := Array(lines).any(func(l: String): return l.begins_with("-"))
	effects_label.add_theme_color_override("font_color", BAD if bad else GOOD)
	_update_status()
	if Run.is_arsenal_over_capacity():
		_ask_remove_round()
	else:
		_show_continue()

# Same rule as fight rewards: past capacity, remove one round (no skip).
func _ask_remove_round() -> void:
	effects_label.text += "\nARSENAL FULL: REMOVE A ROUND"
	var kinds: Array[FTAmmoMod] = []
	for mod in Run.arsenal:
		if mod not in kinds:
			kinds.append(mod)
	var top := 640 - 16 - kinds.size() * 40
	for i in kinds.size():
		var button := _button("%d  %s  x%d" % [i + 1, kinds[i].display_name.to_upper(), Run.arsenal.count(kinds[i])], Vector2(30, top + i * 40))
		button.size.y = 34
		button.pressed.connect(_remove.bind(kinds[i]))
		buttons.append(button)

func _remove(mod: FTAmmoMod) -> void:
	if buttons.is_empty():
		return
	_clear_buttons()
	Run.remove_round(mod)
	effects_label.text = effects_label.text.replace("ARSENAL FULL: REMOVE A ROUND", "REMOVED 1 %s" % mod.display_name.to_upper())
	_show_continue()

func _show_continue() -> void:
	continue_button = _button("CONTINUE", Vector2(30, 584))
	continue_button.pressed.connect(_continue)

func _continue() -> void:
	if continue_button == null or continue_button.disabled:
		return
	continue_button.disabled = true
	Run.complete_stop()

func _unhandled_input(event_: InputEvent) -> void:
	if not (event_ is InputEventKey and event_.pressed and not event_.echo):
		return
	if continue_button and event_.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_continue()
		return
	var index: int = event_.physical_keycode - KEY_1
	if index >= 0 and index < buttons.size() and not buttons[index].disabled:
		get_viewport().set_input_as_handled()
		buttons[index].pressed.emit()
