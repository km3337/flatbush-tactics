class_name FTRewardCard
extends Button

## One reward card. The Button is just the hit area the VBox lays out; the
## visible card is `face`, which moves freely (flies in, lifts on hover,
## punches on lock, falls away when not picked).
## `spin()` runs it like a slot reel: the face flickers through other items
## in the pool, slowing down, then locks on the real one with a flash and a
## burst sized by rarity. Placeholder drawn in code.

signal locked

const SIZE := Vector2(300, 72)
const BG := Color8(37, 19, 26)
const BG_HOVER := Color8(61, 37, 59)
const ICON_AT := Vector2(12, 18)
const ICON_SIZE := 36.0
const OUTLINE := Color8(37, 19, 26)
const GOLD := Color8(255, 213, 105)
const RED := Color8(232, 68, 68)

## The real item (FTGear / FTAmmoMod), and the one the face shows right now
## (differs while the reel spins).
var item: Resource
var shown: Resource
var number := 1
var suffix := ""
## Small tag top-right: "NEW!", "OWNED x3"...
var note := ""
var rarity_colors: Dictionary
var face: Control
var name_label: Label
var rarity_label: Label
var description_label: Label
var note_label: Label
var spinning := false
var fast_forward := false
var hovered := false
var flash := 0.0
var flash_color := Color.WHITE
## Reel scroll: the icon and name slide down into place after each tick.
var scroll := 0.0
var time := 0.0
var lift_tween: Tween
## Where lock bursts go (above every card); the HUD sets it.
var fx_parent: Node

func _init(card_item: Resource, card_number: int, card_suffix: String, card_note: String, colors: Dictionary) -> void:
	item = card_item
	number = card_number
	suffix = card_suffix
	note = card_note
	rarity_colors = colors
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	disabled = true
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	face = Control.new()
	face.size = SIZE
	face.pivot_offset = SIZE / 2.0
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	face.draw.connect(_draw_face)
	add_child(face)
	name_label = _label(16, Vector2(60, 4), Vector2(230, 16))
	rarity_label = _label(8, Vector2(60, 22), Vector2(120, 8))
	description_label = _label(8, Vector2(60, 36), Vector2(232, 32))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label = _label(8, Vector2(200, 22), Vector2(92, 8))
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_show_item(item)

func _label(font_size: int, at: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.position = at
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(label)
	return label

func _rarity_color(of: Resource) -> Color:
	return rarity_colors[of.rarity]

func _show_item(which: Resource) -> void:
	shown = which
	var real := which == item
	name_label.text = "%d  %s%s" % [number, which.display_name.to_upper(), suffix if real else ""]
	rarity_label.text = FTGear.Rarity.keys()[which.rarity]
	rarity_label.add_theme_color_override("font_color", _rarity_color(which))
	# The description and tag only show once the reel has stopped.
	description_label.text = which.description if real and not spinning else ""
	note_label.text = note if real and not spinning else ""
	note_label.add_theme_color_override("font_color", GOLD if note.begins_with("NEW") else Color8(167, 172, 186))
	face.queue_redraw()

## Card flies in from `from` (global) to its slot.
func fly_in(from: Vector2, delay: float) -> void:
	face.position = from - global_position - SIZE / 2.0
	face.scale = Vector2(0.2, 0.2)
	face.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(face, "position", Vector2.ZERO, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "scale", Vector2.ONE, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "modulate:a", 1.0, 0.1).set_delay(delay)

## Before the card shows: start it on a random other item from the reel, so
## the real one isn't seen until it locks.
func prepare_spin(pool: Array) -> void:
	spinning = true
	var others := pool.filter(func(r): return r != item)
	_show_item(others.pick_random() if not others.is_empty() else item)

## Slot-reel: flicker through `pool` for about `seconds`, slowing down, then
## lock on `item`. `fast_forward` (set by a tap) stops it at the next tick.
func spin(pool: Array, seconds: float) -> void:
	spinning = true
	var others := pool.filter(func(r): return r != item)
	if others.is_empty():
		others = [item]
	var elapsed := 0.0
	while elapsed < seconds and not fast_forward:
		var t := elapsed / seconds
		var interval := lerpf(0.04, 0.2, t * t)
		await get_tree().create_timer(interval).timeout
		elapsed += interval
		var next: Resource = others.pick_random()
		if others.size() > 1:
			while next == shown:
				next = others.pick_random()
		_show_item(next)
		scroll = -10.0
		FTRewardSfx.play(self, &"tick", randf_range(0.95, 1.08), -14.0)
	spinning = false
	_lock()

func _lock() -> void:
	_show_item(item)
	scroll = -14.0
	flash = 1.0
	flash_color = Color.WHITE
	face.scale = Vector2(1.12, 1.12)
	var punch := create_tween()
	punch.tween_property(face, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FTRewardSfx.play(self, &"lock")
	var color := _rarity_color(item)
	var parent: Node = fx_parent if fx_parent else get_parent()
	var center := face.global_position + SIZE / 2.0
	match item.rarity:
		FTGear.Rarity.UNCOMMON:
			FTRewardSfx.play(self, &"shine", 1.0, -11.0)
			_edge_burst(parent, center, [color, Color.WHITE], 24)
		FTGear.Rarity.RARE:
			FTRewardSfx.play(self, &"rare", 1.0, -10.0)
			_edge_burst(parent, center, [color, Color.WHITE, Color8(209, 133, 30)], 44)
			_stamp("RARE!")
		_:
			_edge_burst(parent, center, [color], 10)
	locked.emit()

func _edge_burst(parent: Node, center: Vector2, colors: Array, count: int) -> void:
	for side in [-1.0, 1.0]:
		FTRewardBurst.spawn(parent, center + Vector2(side * SIZE.x / 2.0, 0), colors, count / 2, Vector2(60, 200), 0.6, Vector2(side, -0.6), PI * 0.7)

# A word slammed onto the card's corner.
func _stamp(text: String) -> void:
	var stamp := Label.new()
	stamp.text = text
	stamp.add_theme_font_size_override("font_size", 16)
	stamp.add_theme_color_override("font_color", GOLD)
	stamp.add_theme_constant_override("outline_size", 4)
	stamp.add_theme_color_override("font_outline_color", OUTLINE)
	stamp.size = Vector2(80, 16)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.pivot_offset = stamp.size / 2.0
	stamp.position = Vector2(SIZE.x - 70, -10)
	stamp.rotation = -0.2
	stamp.scale = Vector2(3, 3)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stamp)
	var tween := create_tween()
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_hover(entered: bool) -> void:
	if disabled and entered:
		return
	hovered = entered
	if entered:
		FTRewardSfx.play(self, &"hover", 1.0, -16.0)
	if lift_tween:
		lift_tween.kill()
	lift_tween = create_tween()
	lift_tween.tween_property(face, "position:y", -4.0 if entered else 0.0, 0.08)

## The player took this one: white flash and a punch. The HUD flies its icon
## to the loadout.
func play_chosen() -> void:
	disabled = true
	flash = 1.0
	flash_color = Color.WHITE
	face.scale = Vector2(1.1, 1.1)
	var tween := create_tween()
	tween.tween_property(face, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(face, "modulate:a", 0.0, 0.18)

## Not picked: drops away.
func play_dismissed(delay: float) -> void:
	disabled = true
	hovered = false
	var tween := create_tween().set_parallel()
	tween.tween_property(face, "position:y", 48.0, 0.25).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(face, "modulate:a", 0.0, 0.25).set_delay(delay)

## Removing a round: red flash, a shudder, then it tips and falls.
func play_scrapped() -> void:
	disabled = true
	flash = 1.0
	flash_color = RED
	var tween := create_tween()
	for x in [4.0, -4.0, 3.0, -2.0, 0.0]:
		tween.tween_property(face, "position:x", x, 0.035)
	tween.tween_property(face, "rotation", 0.25, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(face, "position:y", 90.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(face, "modulate:a", 0.0, 0.3)

## Global centre of the icon, where its flight starts.
func icon_center() -> Vector2:
	return face.global_position + ICON_AT + Vector2(ICON_SIZE, ICON_SIZE) / 2.0

func _process(delta: float) -> void:
	time += delta
	flash = maxf(0.0, flash - delta * 4.0)
	scroll = minf(0.0, scroll + delta * 90.0)
	name_label.position.y = 4 + roundf(scroll * 0.5)
	face.queue_redraw()

func _draw_face() -> void:
	var color := _rarity_color(shown)
	var rect := Rect2(Vector2.ZERO, SIZE)
	face.draw_rect(rect, BG_HOVER if hovered else BG)
	# Shine: a diagonal band sweeps across uncommon and rare cards.
	if not spinning and shown.rarity > FTGear.Rarity.COMMON:
		var period := 2.4 if shown.rarity == FTGear.Rarity.UNCOMMON else 1.4
		var x := fmod(time, period) / 0.6 * (SIZE.x + 80.0) - 40.0
		var band := Color(1, 1, 1, 0.1 if shown.rarity == FTGear.Rarity.UNCOMMON else 0.16)
		face.draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + 18, 0), Vector2(x - 6, SIZE.y), Vector2(x - 24, SIZE.y)]), band)
	# Border: dim rarity colour, full when aimed at.
	var border := color if hovered or spinning else color.lerp(BG, 0.45)
	face.draw_rect(rect.grow(-1), border, false, 2.0)
	if hovered:
		face.draw_rect(rect.grow(-4), Color(color, 0.35), false, 1.0)
	# Icon, sliding with the reel.
	var icon_rect := Rect2(ICON_AT + Vector2(0, roundf(scroll)), Vector2(ICON_SIZE, ICON_SIZE))
	face.draw_rect(icon_rect, color)
	var inner := icon_rect.grow(-3)
	if shown.icon:
		face.draw_texture_rect(shown.icon, inner, false)
	else:
		face.draw_rect(inner, shown.color)
		var font := get_theme_default_font()
		face.draw_string_outline(font, inner.position + Vector2(0, 21), shown.abbreviation, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, 4, OUTLINE)
		face.draw_string(font, inner.position + Vector2(0, 21), shown.abbreviation, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16)
	# Rare: sparkles twinkling on the corners.
	if not spinning and shown.rarity == FTGear.Rarity.RARE:
		var spots := [Vector2(6, 6), Vector2(SIZE.x - 7, 9), Vector2(SIZE.x - 12, SIZE.y - 7), Vector2(52, SIZE.y - 6)]
		for i in spots.size():
			var phase := fmod(time * 1.6 + i * 0.37, 1.0)
			if phase < 0.5:
				var r := 1.0 + roundf(sin(phase * TAU) * 2.0)
				face.draw_rect(Rect2(spots[i] - Vector2(r, 0.5), Vector2(r * 2.0 + 1.0, 1)), GOLD)
				face.draw_rect(Rect2(spots[i] - Vector2(0.5, r), Vector2(1, r * 2.0 + 1.0)), GOLD)
	if flash > 0.0:
		face.draw_rect(rect, Color(flash_color, flash * 0.7))
