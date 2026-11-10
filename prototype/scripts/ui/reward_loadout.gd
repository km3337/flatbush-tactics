class_name FTRewardLoadout
extends Control

## The top of the reward screen: what the run has so far, so a pick has
## somewhere to land (like Vampire Survivors' inventory beside the level-up
## cards). Wallet (counts up as coins arrive), gear icons, and the arsenal as
## one chip per kind of round with its count. Display only: the HUD drives
## it and the battle updates `Run` itself.

const WIDTH := 300.0
const OUTLINE := Color8(37, 19, 26)
const GOLD := Color8(255, 213, 105)
const GOLD_DARK := Color8(209, 133, 30)
const DIM := Color8(167, 172, 186)
const RED := Color8(232, 68, 68)
const GEAR_SLOT := 24.0
const GEAR_GAP := 4.0
const CHIP_GAP := 6.0

var money_label: Label
var arsenal_label: Label
var caption: Label
var gear_row: Control
var ammo_row: Control
var make_icon: Callable
var money := 0
var shown_money := 0.0
var capacity := 20
## Kind of round (FTAmmoMod) -> chip Control, in arsenal order.
var chips := {}
var counts := {}
var caption_tween: Tween

func _init() -> void:
	size = Vector2(WIDTH, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label = _label(16, Vector2(18, 0), GOLD)
	arsenal_label = _label(8, Vector2(WIDTH - 140, 4), DIM)
	arsenal_label.size.x = 140
	arsenal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(8, Vector2(0, 24), DIM).text = "GEAR"
	gear_row = Control.new()
	gear_row.position = Vector2(40, 18)
	gear_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gear_row)
	_label(8, Vector2(0, 54), DIM).text = "AMMO"
	ammo_row = Control.new()
	ammo_row.position = Vector2(40, 48)
	ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_row)
	caption = _label(8, Vector2(0, 80), Color.WHITE)
	caption.size.x = WIDTH
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.modulate.a = 0.0

func _label(font_size: int, at: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

## `icon_maker(item) -> Control` builds a gear/round icon (the HUD's).
func setup(gear: Array, arsenal: Array, arsenal_capacity: int, start_money: int, icon_maker: Callable) -> void:
	make_icon = icon_maker
	capacity = arsenal_capacity
	money = start_money
	shown_money = start_money
	for child in gear_row.get_children():
		child.queue_free()
	for child in ammo_row.get_children():
		child.queue_free()
	chips.clear()
	counts.clear()
	for g in gear:
		_add_gear_icon(g)
	for mod in arsenal:
		counts[mod] = counts.get(mod, 0) + 1
	for mod in counts:
		_add_chip(mod)
	_refresh()

# --- Wallet ----------------------------------------------------------------

## Global position coins fly to.
func wallet_target() -> Vector2:
	return global_position + Vector2(6, 8)

## One coin arrived: the counter steps towards `money`.
func add_money(amount: int) -> void:
	money += amount
	var tween := create_tween()
	tween.tween_property(self, "shown_money", float(money), 0.12)
	money_label.scale = Vector2(1.25, 1.25)
	var pop := create_tween()
	pop.tween_property(money_label, "scale", Vector2.ONE, 0.12)

# --- Gear ------------------------------------------------------------------

func gear_target() -> Vector2:
	var index := gear_row.get_child_count()
	return gear_row.global_position + Vector2(index * (GEAR_SLOT + GEAR_GAP) + GEAR_SLOT / 2.0, GEAR_SLOT / 2.0)

func land_gear(gear: Resource) -> void:
	var icon := _add_gear_icon(gear)
	_pop(icon)

func _add_gear_icon(gear: Resource) -> Control:
	var icon: Control = make_icon.call(gear)
	icon.position = Vector2(gear_row.get_child_count() * (GEAR_SLOT + GEAR_GAP), 0)
	icon.pivot_offset = Vector2(GEAR_SLOT, GEAR_SLOT) / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_row.add_child(icon)
	return icon

# --- Arsenal ---------------------------------------------------------------

## Where a round of `mod` lands: its chip, or the next free spot.
func ammo_target(mod: Resource) -> Vector2:
	if chips.has(mod):
		var chip: Control = chips[mod]
		return chip.global_position + Vector2(6, 12)
	return ammo_row.global_position + Vector2(_next_chip_x() + 6, 12)

## `delta` rounds of `mod` arrive (+1) or are scrapped (-1).
func land_ammo(mod: Resource, delta: int) -> void:
	counts[mod] = counts.get(mod, 0) + delta
	if not chips.has(mod):
		_add_chip(mod)
	var chip: Control = chips[mod]
	if counts[mod] <= 0:
		counts.erase(mod)
		chips.erase(mod)
		var fade := create_tween()
		fade.tween_property(chip, "modulate:a", 0.0, 0.2)
		fade.tween_callback(chip.queue_free)
	else:
		chip.get_child(1).text = "x%d" % counts[mod]
		_pop(chip)
		if delta < 0:
			chip.modulate = RED * 1.5
			create_tween().tween_property(chip, "modulate", Color.WHITE, 0.3)
	_refresh()

func _next_chip_x() -> float:
	var x := 0.0
	for mod in chips:
		x = maxf(x, chips[mod].position.x + chips[mod].size.x + CHIP_GAP)
	return x

# One kind of round: a little shell in its colour, then the count.
func _add_chip(mod: Resource) -> void:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(_next_chip_x(), 0)
	chip.size = Vector2(36, 24)
	chip.pivot_offset = Vector2(6, 12)
	var shell := Control.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.draw.connect(func():
		shell.draw_rect(Rect2(1, 2, 10, 20), OUTLINE)
		shell.draw_rect(Rect2(2, 3, 8, 18), mod.color)
		shell.draw_rect(Rect2(2, 3, 8, 5), mod.color.lightened(0.4))
		shell.draw_rect(Rect2(2, 17, 8, 2), mod.color.darkened(0.4)))
	chip.add_child(shell)
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 8)
	count.add_theme_constant_override("outline_size", 4)
	count.add_theme_color_override("font_outline_color", OUTLINE)
	count.position = Vector2(13, 8)
	count.text = "x%d" % counts.get(mod, 0)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(count)
	ammo_row.add_child(chip)
	chips[mod] = chip

func _refresh() -> void:
	var total := 0
	for mod in counts:
		total += counts[mod]
	arsenal_label.text = "ARSENAL %d/%d" % [total, capacity]
	arsenal_label.add_theme_color_override("font_color", RED if total > capacity else DIM)

# --- Caption ---------------------------------------------------------------

## A line under the loadout naming what just happened ("+1 BURN ROUND").
func show_caption(text: String, color: Color) -> void:
	caption.text = text
	caption.add_theme_color_override("font_color", color)
	caption.modulate.a = 1.0
	caption.position.y = 86
	if caption_tween:
		caption_tween.kill()
	caption_tween = create_tween()
	caption_tween.tween_property(caption, "position:y", 80.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	caption_tween.tween_interval(1.6)
	caption_tween.tween_property(caption, "modulate:a", 0.0, 0.3)

func _pop(node: Control) -> void:
	node.scale = Vector2(1.8, 1.8)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_delta: float) -> void:
	money_label.text = "$%d" % roundi(shown_money)
	queue_redraw()

func _draw() -> void:
	# Coin beside the wallet.
	draw_rect(Rect2(1, 2, 10, 12), OUTLINE)
	draw_rect(Rect2(0, 4, 12, 8), OUTLINE)
	draw_rect(Rect2(2, 3, 8, 10), GOLD)
	draw_rect(Rect2(1, 5, 10, 6), GOLD)
	draw_rect(Rect2(5, 5, 2, 6), GOLD_DARK)
	# Divider under the loadout.
	draw_rect(Rect2(0, 76, WIDTH, 1), Color(DIM, 0.35))
