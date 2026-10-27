class_name FTShopScreen
extends Control

## A $ stop. The station's FTShop decides what's on the shelf: gear, or ammo
## rounds (a bought round joins the arsenal; past capacity you remove one).
## Stock is rolled on arrival, each item sells once. Every shop also sells a
## heal. LEAVE (or Enter) moves on. Keys 1-5 buy the matching row.

const FRAME_SIZE := Vector2(360, 780)
const BACKGROUND := Color(0.1, 0.09, 0.08)
const ACCENT := Color(0.55, 0.9, 0.45)
const DIM := Color(0.65, 0.65, 0.7)
const RARITY_COLORS := {
	FTGear.Rarity.COMMON: Color(0.6, 0.6, 0.62),
	FTGear.Rarity.UNCOMMON: Color(0.3, 0.6, 1.0),
	FTGear.Rarity.RARE: Color(1.0, 0.8, 0.25),
}
const ROW_TOP := 236.0
const ROW_HEIGHT := 66.0

var shop: FTShop
var stock: Array[Resource] = []
var frame: Control
var status_label: Label
var message_label: Label
## One buy button per stock item, then the heal button last.
var buy_buttons: Array[Button] = []
var leave_button: Button
var remove_panel: Control

func _ready() -> void:
	FTClosingDoors.open_over(self)  # arriving: the doors slide open
	set_anchors_preset(Control.PRESET_FULL_RECT)
	shop = Run.current_station.shop if Run.current_station and Run.current_station.shop else load("res://shops/pawn_shop.tres")
	_roll_stock()
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = -FRAME_SIZE / 2.0
	frame.size = FRAME_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var header := ColorRect.new()
	header.color = Color(0.03, 0.03, 0.04)
	header.size = Vector2(360, 34)
	frame.add_child(header)
	var where := Run.current_station.display_name.to_upper() if Run.current_station else ""
	_label(header, "$  %s" % where, Vector2(12, 0), Vector2(200, 34), 8, Color.WHITE)
	status_label = _label(header, "", Vector2(150, 0), Vector2(198, 34), 8, Color.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Art goes here later.
	var art := ColorRect.new()
	art.color = Color(0.17, 0.15, 0.13)
	art.position = Vector2(20, 46)
	art.size = Vector2(320, 100)
	frame.add_child(art)
	var mark := _label(art, "$", Vector2.ZERO, art.size, 64, Color(1, 1, 1, 0.12))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(frame, shop.display_name.to_upper(), Vector2(20, 154), Vector2(320, 28), 16, Color(1.0, 0.85, 0.2))
	_label(frame, shop.greeting, Vector2(20, 184), Vector2(320, 44), 8, Color.WHITE).vertical_alignment = VERTICAL_ALIGNMENT_TOP

	for i in stock.size():
		_item_row(i, stock[i])
	_heal_row(stock.size())
	message_label = _label(frame, "", Vector2(20, ROW_TOP + (stock.size() + 1) * ROW_HEIGHT + 4), Vector2(320, 40), 8, ACCENT)
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	leave_button = Button.new()
	leave_button.text = "LEAVE"
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.position = Vector2(40, 730)
	leave_button.size = Vector2(280, 38)
	leave_button.add_theme_font_size_override("font_size", 16)
	leave_button.pressed.connect(_leave)
	frame.add_child(leave_button)
	_refresh()

func _roll_stock() -> void:
	stock.clear()
	if shop.sells == FTShop.Sells.GEAR:
		stock.assign(Run.roll_gear_choices((FTGear.Source.ELITE | FTGear.Source.EVENT) as FTGear.Source, shop.stock_size))
	else:
		stock.assign(Run.roll_ammo_choices(shop.stock_size))

func _label(parent: Control, text: String, pos: Vector2, size_: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before sizing
	label.text = text
	label.position = pos
	label.size = size_
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _row_y(i: int) -> float:
	return ROW_TOP + i * ROW_HEIGHT

func _item_row(i: int, item: Resource) -> void:
	var y := _row_y(i)
	var icon := Control.new()
	icon.position = Vector2(20, y + 8)
	icon.size = Vector2(36, 36)
	icon.draw.connect(func(): _draw_item_icon(icon, item))
	frame.add_child(icon)
	_label(frame, "%d  %s" % [i + 1, item.display_name.to_upper()], Vector2(66, y), Vector2(190, 10), 8, Color.WHITE)
	_label(frame, FTGear.Rarity.keys()[item.rarity], Vector2(66, y + 12), Vector2(190, 10), 8, RARITY_COLORS[item.rarity])
	_label(frame, item.description, Vector2(66, y + 27), Vector2(190, 32), 8, DIM).vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_buy_button(y, _buy.bind(i))

func _heal_row(i: int) -> void:
	var y := _row_y(i)
	var icon := Control.new()
	icon.position = Vector2(20, y + 8)
	icon.size = Vector2(36, 36)
	icon.draw.connect(func():
		icon.draw_rect(Rect2(Vector2.ZERO, icon.size), Color(0.75, 0.25, 0.25))
		icon.draw_string(get_theme_default_font(), Vector2(0, 25), "+HP", HORIZONTAL_ALIGNMENT_CENTER, 36, 8, Color.WHITE))
	frame.add_child(icon)
	_label(frame, "%d  %s" % [i + 1, shop.heal_name.to_upper()], Vector2(66, y), Vector2(190, 18), 8, Color.WHITE)
	_label(frame, "Restores %d HP. Buy as many as you need." % shop.heal_amount, Vector2(66, y + 20), Vector2(190, 30), 8, DIM).vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_buy_button(y, _buy_heal)

func _buy_button(y: float, action: Callable) -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(262, y + 12)
	button.size = Vector2(78, 30)
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(action)
	frame.add_child(button)
	buy_buttons.append(button)

# Same look as the battle HUD's gear icons: rarity border, colour fill,
# two letters (or the item's icon texture).
func _draw_item_icon(canvas: Control, item: Resource) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), RARITY_COLORS[item.rarity])
	var inner := Rect2(Vector2(3, 3), canvas.size - Vector2(6, 6))
	if item.icon:
		canvas.draw_texture_rect(item.icon, inner, false)
		return
	canvas.draw_rect(inner, item.color)
	canvas.draw_string(get_theme_default_font(), Vector2(3, 23), item.abbreviation, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 8, Color.WHITE)

## Prices, SOLD and affordability on every button, plus the header.
func _refresh() -> void:
	status_label.text = "HP %d/%d   $%d" % [Run.current_hp(), Run.max_hp(), Run.money]
	for i in stock.size():
		var button := buy_buttons[i]
		if stock[i] == null:
			button.text = "SOLD"
			button.disabled = true
		else:
			var price := shop.price_of(stock[i])
			button.text = "$%d" % price
			button.disabled = Run.money < price or remove_panel != null
	var heal := buy_buttons[stock.size()]
	heal.text = "FULL HP" if Run.current_hp() >= Run.max_hp() else "$%d" % shop.heal_price
	heal.disabled = Run.current_hp() >= Run.max_hp() or Run.money < shop.heal_price or remove_panel != null
	leave_button.disabled = remove_panel != null

func _buy(i: int) -> void:
	var item := stock[i]
	if item == null or remove_panel or Run.money < shop.price_of(item):
		return
	Run.money -= shop.price_of(item)
	stock[i] = null
	if item is FTGear:
		Run.add_gear(item, FTGear.Source.EVENT)
		message_label.text = "BOUGHT: %s" % item.display_name.to_upper()
	else:
		Run.add_round(item)
		message_label.text = "ADDED TO ARSENAL: %s" % item.display_name.to_upper()
		if Run.is_arsenal_over_capacity():
			_ask_remove_round()
	_refresh()

func _buy_heal() -> void:
	if remove_panel or Run.money < shop.heal_price or Run.current_hp() >= Run.max_hp():
		return
	Run.money -= shop.heal_price
	Run.hp = mini(Run.current_hp() + shop.heal_amount, Run.max_hp())
	message_label.text = "+%d HP" % shop.heal_amount
	_refresh()

# Arsenal over capacity: pick a kind of round to remove one of (no skip).
func _ask_remove_round() -> void:
	remove_panel = ColorRect.new()
	remove_panel.color = Color(0.03, 0.03, 0.05, 0.95)
	remove_panel.position = Vector2(10, 220)
	remove_panel.size = Vector2(340, 340)
	frame.add_child(remove_panel)
	var title := _label(remove_panel, "ARSENAL FULL\nREMOVE A ROUND", Vector2(0, 10), Vector2(340, 44), 16, Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kinds: Array[FTAmmoMod] = []
	for mod in Run.arsenal:
		if mod not in kinds:
			kinds.append(mod)
	for i in kinds.size():
		var button := Button.new()
		button.text = "%d  %s  x%d" % [i + 1, kinds[i].display_name.to_upper(), Run.arsenal.count(kinds[i])]
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(30, 66 + i * 40)
		button.size = Vector2(280, 34)
		button.pressed.connect(_remove.bind(kinds[i]))
		remove_panel.add_child(button)

func _remove(mod: FTAmmoMod) -> void:
	if remove_panel == null:
		return
	Run.remove_round(mod)
	remove_panel.queue_free()
	remove_panel = null
	message_label.text += "\nREMOVED 1 %s" % mod.display_name.to_upper()
	_refresh()

func _leave() -> void:
	if leave_button.disabled:
		return
	leave_button.disabled = true
	await FTClosingDoors.add_to(self).close()
	Run.complete_stop()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = event.physical_keycode - KEY_1
	if remove_panel:
		var buttons := remove_panel.get_children().filter(func(c): return c is Button)
		if index >= 0 and index < buttons.size():
			get_viewport().set_input_as_handled()
			buttons[index].pressed.emit()
	elif index >= 0 and index < buy_buttons.size():
		get_viewport().set_input_as_handled()
		if not buy_buttons[index].disabled:
			buy_buttons[index].pressed.emit()
	elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_leave()
