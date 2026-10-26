class_name FTFreelancerSelect
extends Control

## Run start: pick a freelancer. A carousel built from the "SELECT LANCER"
## mockup (spritework/p1.aseprite): title, tall portrait, and chevrons that
## page through the roster (click them, Left/Right or A/D, or swipe). Locked
## slots show a large "?". Below the portrait: name, weapon, bio, starting
## gear, stats and starting rounds, then CHOOSE (or Enter/Space).

const ART := "res://assets/ui/freelancer_select/"
const FRAME_SIZE := Vector2(360, 780)
const INK := Color(0.1, 0.08, 0.1)
const ACCENT := Color(0.85, 0.12, 0.25)
const LOCKED_INK := Color(0.1, 0.08, 0.1, 0.18)
const RARITY_COLORS := {
	FTGear.Rarity.COMMON: Color(0.6, 0.6, 0.62),
	FTGear.Rarity.UNCOMMON: Color(0.3, 0.6, 1.0),
	FTGear.Rarity.RARE: Color(1.0, 0.8, 0.25),
}
# Chevron columns inside arrows.png (the layer holds both).
const LEFT_CHEVRON := Rect2(0, 0, 33, 174)
const RIGHT_CHEVRON := Rect2(292, 0, 48, 174)
const ARROWS_POSITION := Vector2(19, 233)

@export var roster: Array[FTFreelancer] = []
## "?" slots after the roster, for freelancers not unlocked yet.
@export var locked_slots := 2

var index := 0
var frame: Control
var portrait_holder: Control
var portrait: TextureRect
var locked_mark: Label
var name_label: Label
var weapon_label: Label
var bio_label: Label
var gear_icon: Control
var gear_label: Label
var stats_label: Label
var rounds_label: Label
var choose_button: Button
var touch_start := Vector2.ZERO

func slot_count() -> int:
	return roster.size() + locked_slots

func current() -> FTFreelancer:
	return roster[index] if index < roster.size() else null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.98, 0.97, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = -FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_art("select.png", Vector2(43, 25))
	_art("lancer.png", Vector2(74, 96))

	portrait_holder = Control.new()
	portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_holder.size = FRAME_SIZE
	frame.add_child(portrait_holder)
	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_holder.add_child(portrait)
	locked_mark = _label(portrait_holder, "?", Vector2(0, 200), Vector2(360, 360), 240, LOCKED_INK)
	locked_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var arrows: Texture2D = load(ART + "arrows.png")
	_chevron(arrows, LEFT_CHEVRON, -1)
	_chevron(arrows, RIGHT_CHEVRON, 1)

	# Info stacks under the portrait, so wrapped lines push the rest down.
	var info := VBoxContainer.new()
	info.position = Vector2(20, 598)
	info.size = Vector2(320, 136)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 3)
	frame.add_child(info)
	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	name_label = _label(name_row, "", Vector2.ZERO, Vector2.ZERO, 24, INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label = _label(name_row, "", Vector2.ZERO, Vector2.ZERO, 8, ACCENT)
	weapon_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	weapon_label.size_flags_vertical = Control.SIZE_FILL
	bio_label = _label(info, "", Vector2.ZERO, Vector2.ZERO, 8, INK)
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 8)
	info.add_child(gear_row)
	gear_icon = Control.new()
	gear_icon.custom_minimum_size = Vector2(24, 24)
	gear_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear_icon.draw.connect(_draw_gear_icon)
	gear_row.add_child(gear_icon)
	gear_label = _label(gear_row, "", Vector2.ZERO, Vector2.ZERO, 8, INK)
	gear_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label = _label(info, "", Vector2.ZERO, Vector2.ZERO, 8, INK)
	rounds_label = _label(info, "", Vector2.ZERO, Vector2.ZERO, 8, INK)
	choose_button = Button.new()
	choose_button.focus_mode = Control.FOCUS_NONE
	choose_button.position = Vector2(40, 740)
	choose_button.size = Vector2(280, 34)
	choose_button.pressed.connect(_choose)
	choose_button.draw.connect(_draw_check)
	frame.add_child(choose_button)
	_show(0, 0)

func _art(file: String, pos: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ART + file)
	rect.position = pos
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rect)
	return rect

func _label(parent: Control, text: String, pos: Vector2, size_: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before sizing
	label.text = text
	label.position = pos
	label.size = size_
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# One chevron from arrows.png, clickable, nudging on hover.
func _chevron(arrows: Texture2D, region: Rect2, direction: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = arrows
	atlas.region = region
	var button := TextureButton.new()
	button.texture_normal = atlas
	button.focus_mode = Control.FOCUS_NONE
	button.position = ARROWS_POSITION + region.position
	button.size = region.size
	var rest := button.position
	button.mouse_entered.connect(func(): button.position = rest + Vector2(3 * direction, 0))
	button.mouse_exited.connect(func(): button.position = rest)
	button.pressed.connect(cycle.bind(direction))
	frame.add_child(button)

func cycle(direction: int) -> void:
	_show(posmod(index + direction, slot_count()), direction)

# Show slot `new_index`, sliding in from the side we moved towards.
func _show(new_index: int, direction: int) -> void:
	index = new_index
	var f := current()
	portrait.visible = f != null and f.portrait != null
	locked_mark.visible = f == null
	if f:
		portrait.texture = f.portrait
		portrait.position = f.portrait_position
		portrait.size = f.portrait.get_size() if f.portrait else Vector2.ZERO
		name_label.text = f.display_name.to_upper()
		weapon_label.text = f.weapon_name.to_upper()
		bio_label.text = f.bio
		var gear := f.starting_gear
		gear_label.text = "%s: %s" % [gear.display_name.to_upper(), gear.description] if gear else "STARTING GEAR: RANDOM COMMON"
		stats_label.text = "HP %d · MAG %d · SHOT %.1fs · RELOAD %.2fs · ARSENAL %d/%d" % [f.max_health, f.magazine_size, f.fire_cooldown, f.reload_seconds, f.starting_arsenal.size(), f.arsenal_capacity]
		rounds_label.text = "ROUNDS: " + _rounds_text(f.starting_arsenal)
		choose_button.tooltip_text = "Choose %s" % f.display_name
		choose_button.disabled = false
	else:
		name_label.text = "???"
		weapon_label.text = "LOCKED"
		bio_label.text = "Not available yet."
		gear_label.text = ""
		stats_label.text = ""
		rounds_label.text = ""
		choose_button.tooltip_text = "Locked"
		choose_button.disabled = true
	choose_button.queue_redraw()
	gear_icon.visible = f != null and f.starting_gear != null
	gear_icon.queue_redraw()
	if direction != 0:
		portrait_holder.position.x = 40.0 * direction
		portrait_holder.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(portrait_holder, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait_holder, "modulate:a", 1.0, 0.15)

func _rounds_text(rounds: Array[FTAmmoMod]) -> String:
	var counts := {}
	for mod in rounds:
		counts[mod.display_name] = counts.get(mod.display_name, 0) + 1
	var parts := PackedStringArray()
	for name in counts:
		parts.append("%s x%d" % [name, counts[name]])
	return ", ".join(parts)

# Placeholder gear icon, matching the battle HUD's: rarity border, colour
# fill, two letters (or the gear's icon texture).
func _draw_gear_icon() -> void:
	var f := current()
	if f == null or f.starting_gear == null:
		return
	var gear := f.starting_gear
	gear_icon.draw_rect(Rect2(Vector2.ZERO, gear_icon.size), RARITY_COLORS[gear.rarity])
	var inner := Rect2(Vector2(2, 2), gear_icon.size - Vector2(4, 4))
	if gear.icon:
		gear_icon.draw_texture_rect(gear.icon, inner, false)
		return
	gear_icon.draw_rect(inner, gear.color)
	gear_icon.draw_string(get_theme_default_font(), Vector2(2, 16), gear.abbreviation, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 8, Color.WHITE)

# The CHOOSE button's label: a pixel check mark (the font has no ✓), greyed
# out on locked slots.
func _draw_check() -> void:
	var c := (choose_button.size / 2.0).floor()
	var points := PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-4, 8), c + Vector2(12, -8)])
	if choose_button.disabled:
		choose_button.draw_polyline(points, Color(0.55, 0.54, 0.52), 4.0)
		return
	choose_button.draw_polyline(points, Color(0.06, 0.05, 0.08), 8.0)
	choose_button.draw_polyline(points, Color.WHITE, 4.0)

func _choose() -> void:
	var f := current()
	if f == null or choose_button.disabled:
		return
	choose_button.disabled = true
	Run.choose_freelancer(f)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_LEFT, KEY_A:
				cycle(-1)
			KEY_RIGHT, KEY_D:
				cycle(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_choose()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:  # swipe left/right to cycle
		if event.pressed:
			touch_start = event.position
		elif absf(event.position.x - touch_start.x) > 60.0:
			cycle(-1 if event.position.x > touch_start.x else 1)
