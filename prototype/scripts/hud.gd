class_name FTHud
extends CanvasLayer

## Emitted by the reward picker: the chosen item, or null if skipped.
signal choice_made(item: Resource)

@onready var ammo_row: HBoxContainer = $AmmoRow
@onready var reload_label: Label = $ReloadLabel
@onready var hit_marker: Label = $HitMarker
@onready var damage_flash: ColorRect = $DamageFlash
@onready var hits_label: Label = $HitsLabel
@onready var counter_label: Label = $CounterLabel
@onready var portrait: ColorRect = $Portrait
@onready var portrait_label: Label = $Portrait/PortraitLabel
@onready var hp_pips: Label = $HPPips
@onready var down_label: Label = $DownLabel
@onready var cleared_label: Label = $ClearedLabel
@onready var gear_row: HBoxContainer = $GearRow
@onready var gear_info: Label = $GearInfo
@onready var choice_panel: Control = $RewardChoice
@onready var choice_cards: VBoxContainer = $RewardChoice/Cards
@onready var choice_title: Label = $RewardChoice/Cards/Title
@onready var arsenal_label: Label = $ArsenalLabel
@onready var money_label: Label = $MoneyLabel
@export var reaction_seconds := 0.6
@export var gear_info_seconds := 2.5
## Reward cards ignore input this long after appearing, so a tap meant for
## the last enemy can't pick one by accident.
@export var choice_lock_seconds := 0.4
@export var counter_hold_seconds := 0.8
@export var counter_fade_seconds := 0.4
var counter_tween: Tween
var hits_taken := 0
var blocked := 0
var bullet_nodes: Array[Label] = []
var bullet_tweens := {}  # Label -> drop Tween in progress
var reload_tween: Tween
var reaction_timer: SceneTreeTimer
var low_health := false
var gear_info_timer: SceneTreeTimer

## Gear icon border colour by rarity.
const RARITY_COLORS := {
    FTGear.Rarity.COMMON: Color(0.6, 0.6, 0.62),
    FTGear.Rarity.UNCOMMON: Color(0.3, 0.6, 1.0),
    FTGear.Rarity.RARE: Color(1.0, 0.8, 0.25),
}
const GEAR_ICON_SIZE := Vector2(24, 24)

## Placeholder portrait states: [word, box colour].
const PORTRAIT_STATES := {
    "calm": ["CALM", Color(0.3, 0.35, 0.45)],
    "low": ["HURTING", Color(0.5, 0.12, 0.14)],
    "down": ["DOWN", Color(0.2, 0.2, 0.2)],
    "hit_enemy": ["NICE", Color(0.2, 0.55, 0.3)],
    "miss": ["MISSED", Color(0.4, 0.4, 0.4)],
    "counter": ["YEAH!", Color(0.8, 0.65, 0.1)],
    "kill": ["GOT 'EM", Color(0.85, 0.45, 0.1)],
    "got_hit": ["OUCH", Color(0.85, 0.15, 0.15)],
}

func setup_ammo(maximum: int) -> void:
    for child in ammo_row.get_children(): child.queue_free()
    bullet_nodes.clear()
    for i in maximum:
        # Each round sits in a fixed slot so the row never re-lays out while a
        # spent round drops; the round animates freely inside its slot.
        var slot := Control.new()
        slot.custom_minimum_size = Vector2(16, 35)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var bullet := Label.new()
        bullet.text = "▮"
        bullet.add_theme_font_size_override("font_size", 25)
        bullet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        bullet.size = slot.custom_minimum_size
        slot.add_child(bullet)
        ammo_row.add_child(slot)
        bullet_nodes.append(bullet)

## The rightmost loaded slot is the chambered round (magazine[0]), so a shot
## drops that slot and the other rounds keep their colours.
func update_ammo(magazine: Array[FTAmmoMod], maximum: int) -> void:
    if bullet_nodes.size() != maximum:
        setup_ammo(maximum)
    var current := magazine.size()
    for i in bullet_nodes.size():
        var bullet := bullet_nodes[i]
        if i < current:
            bullet.add_theme_color_override("font_color", magazine[current - 1 - i].color)
            if bullet_tweens.has(bullet):
                bullet_tweens[bullet].kill()
                bullet_tweens.erase(bullet)
            bullet.visible = true
            bullet.modulate.a = 1.0
            bullet.position = Vector2.ZERO
        elif bullet.visible and not bullet_tweens.has(bullet):
            _drop_bullet(bullet)

func update_arsenal(draw_count: int, discard_count: int) -> void:
    arsenal_label.text = "ARSENAL  %d LEFT  ·  %d SPENT" % [draw_count, discard_count]

func _drop_bullet(bullet: Label) -> void:
    var tween := create_tween()
    bullet_tweens[bullet] = tween
    tween.tween_property(bullet, "position", Vector2(3.5, -1), 0.035)
    tween.tween_property(bullet, "position", Vector2(-3, 1), 0.035)
    tween.tween_property(bullet, "position", Vector2(0, 36), 0.16).set_trans(Tween.TRANS_QUAD)
    tween.parallel().tween_property(bullet, "modulate:a", 0.0, 0.14)
    tween.tween_callback(func(): bullet.visible = false)
    tween.finished.connect(func(): bullet_tweens.erase(bullet))

func show_reload() -> void:
    reload_label.visible = true
    if reload_tween: reload_tween.kill()
    reload_tween = create_tween().set_loops()
    reload_tween.tween_property(reload_label, "modulate:a", 0.15, 0.13)
    reload_tween.tween_property(reload_label, "modulate:a", 1.0, 0.13)

func hide_reload() -> void:
    if reload_tween: reload_tween.kill()
    reload_label.visible = false
    reload_label.modulate.a = 1.0

func show_shot_feedback(screen_position: Vector2) -> void:
    hit_marker.position = screen_position - hit_marker.size / 2.0
    hit_marker.visible = true
    hit_marker.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(hit_marker, "modulate:a", 0.0, 0.18)
    tween.tween_callback(func(): hit_marker.visible = false)

func show_player_hit() -> void:
    hits_taken += 1
    _update_hits_label()
    damage_flash.visible = true
    damage_flash.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(damage_flash, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func(): damage_flash.visible = false)

func show_blocked() -> void:
    blocked += 1
    _update_hits_label()

func _update_hits_label() -> void:
    hits_label.text = "HITS TAKEN: %d
BLOCKED BY COVER: %d" % [hits_taken, blocked]

func show_counter() -> void:
    if counter_tween: counter_tween.kill()
    counter_label.visible = true
    counter_label.modulate.a = 1.0
    counter_label.scale = Vector2(1.3, 1.3)
    counter_tween = create_tween()
    counter_tween.tween_property(counter_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    counter_tween.tween_interval(counter_hold_seconds)
    counter_tween.tween_property(counter_label, "modulate:a", 0.0, counter_fade_seconds)
    counter_tween.tween_callback(func(): counter_label.visible = false)

func update_health(current: int, maximum: int, is_low: bool) -> void:
    hp_pips.text = "■".repeat(current) + "□".repeat(maximum - current)
    low_health = is_low
    if reaction_timer == null:
        _set_portrait(_resting_state())

## Briefly show a reaction, then fall back to calm / low HP.
func react(state: String) -> void:
    _set_portrait(state)
    var timer := get_tree().create_timer(reaction_seconds)
    reaction_timer = timer
    await timer.timeout
    if reaction_timer == timer:
        reaction_timer = null
        _set_portrait(_resting_state())

func show_down() -> void:
    reaction_timer = null
    _set_portrait("down")
    down_label.visible = true

## CLEARED, plus the money the fight paid.
func show_cleared(pay := 0) -> void:
    react("kill")
    cleared_label.text = "CLEARED\n+$%d" % pay if pay > 0 else "CLEARED"
    cleared_label.visible = true

func update_money(amount: int) -> void:
    money_label.text = "$%d" % amount

func set_gear(list: Array[FTGear]) -> void:
    for child in gear_row.get_children(): child.queue_free()
    for gear in list:
        add_gear(gear)

## One icon per owned gear, in pickup order: rarity-coloured border around the
## gear's icon (or placeholder letters). Hover shows a tooltip; click/tap shows
## the description. Pulses whenever the gear triggers.
func add_gear(gear: FTGear) -> void:
    var frame := _make_item_icon(gear)
    frame.tooltip_text = "%s\n%s" % [gear.display_name, gear.description]
    frame.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed:
            show_gear_info(gear))
    gear.triggered.connect(_pulse_gear.bind(frame))
    gear_row.add_child(frame)

func _make_item_icon(item: Resource) -> ColorRect:
    var frame := ColorRect.new()
    frame.custom_minimum_size = GEAR_ICON_SIZE
    frame.pivot_offset = GEAR_ICON_SIZE / 2.0
    frame.color = RARITY_COLORS[item.rarity]
    var inner_rect := Rect2(Vector2(2, 2), GEAR_ICON_SIZE - Vector2(4, 4))
    if item.icon:
        var art := TextureRect.new()
        art.texture = item.icon
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.position = inner_rect.position
        art.size = inner_rect.size
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(art)
    else:
        var fill := ColorRect.new()
        fill.color = item.color
        fill.position = inner_rect.position
        fill.size = inner_rect.size
        fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(fill)
        var letters := Label.new()
        letters.text = item.abbreviation
        letters.add_theme_font_size_override("font_size", 9)
        letters.add_theme_constant_override("outline_size", 3)
        letters.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
        letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        letters.position = inner_rect.position
        letters.size = inner_rect.size
        frame.add_child(letters)
    return frame

## Picker for rewards (gear, ammo) and for removing a round. `items` are
## FTGear or FTAmmoMod (anything with display_name, description, rarity,
## color, abbreviation, icon). Click/tap a card or press its number; with
## `can_skip`, a Skip button (or S) picks nothing. Emits `choice_made` with
## the item, or null when skipped. `name_suffixes` adds text after a card's
## name (e.g. "x12"). Cards can't take keyboard focus, so Space
## (cover/reload) never picks one by accident.
func show_choice(items: Array, title: String, can_skip := false, name_suffixes: Array = []) -> void:
    for child in choice_cards.get_children():
        if child != choice_title:
            choice_cards.remove_child(child)
            child.queue_free()
    choice_title.text = title
    cleared_label.visible = false
    var buttons: Array[Button] = []
    for i in items.size():
        var suffix: String = name_suffixes[i] if i < name_suffixes.size() else ""
        var card := _make_choice_card(items[i], i + 1, suffix)
        choice_cards.add_child(card)
        buttons.append(card)
    if can_skip:
        var skip := Button.new()
        skip.text = "SKIP (S)"
        skip.name = "Skip"
        skip.focus_mode = Control.FOCUS_NONE
        skip.disabled = true
        skip.custom_minimum_size = Vector2(300, 32)
        skip.add_theme_font_size_override("font_size", 12)
        skip.pressed.connect(_choose.bind(null))
        choice_cards.add_child(skip)
        buttons.append(skip)
    choice_panel.visible = true
    await get_tree().create_timer(choice_lock_seconds).timeout
    for button in buttons:
        button.disabled = false

func _make_choice_card(item: Resource, number: int, suffix: String) -> Button:
    var card := Button.new()
    card.custom_minimum_size = Vector2(300, 72)
    card.focus_mode = Control.FOCUS_NONE
    card.disabled = true
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.11, 0.12, 0.16)
    style.set_border_width_all(2)
    style.border_color = Color(0.2, 0.22, 0.28)
    var hover_style := style.duplicate()
    hover_style.border_color = RARITY_COLORS[item.rarity]
    hover_style.bg_color = Color(0.15, 0.16, 0.21)
    for state in ["normal", "disabled"]:
        card.add_theme_stylebox_override(state, style)
    for state in ["hover", "pressed"]:
        card.add_theme_stylebox_override(state, hover_style)
    var icon := _make_item_icon(item)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.position = Vector2(12, 18)
    icon.scale = Vector2(1.5, 1.5)
    card.add_child(icon)
    var name_label := Label.new()
    name_label.text = "%d  %s%s" % [number, item.display_name.to_upper(), suffix]
    name_label.add_theme_font_size_override("font_size", 14)
    name_label.position = Vector2(60, 4)
    card.add_child(name_label)
    var rarity_label := Label.new()
    rarity_label.text = FTGear.Rarity.keys()[item.rarity]
    rarity_label.add_theme_font_size_override("font_size", 9)
    rarity_label.add_theme_color_override("font_color", RARITY_COLORS[item.rarity])
    rarity_label.position = Vector2(60, 22)
    card.add_child(rarity_label)
    var description_label := Label.new()
    description_label.text = item.description
    description_label.add_theme_font_size_override("font_size", 10)
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.position = Vector2(60, 36)
    description_label.size = Vector2(232, 32)
    card.add_child(description_label)
    card.pressed.connect(_choose.bind(item))
    return card

func _choose(item: Resource) -> void:
    if not choice_panel.visible:
        return
    choice_panel.visible = false
    choice_made.emit(item)

func _unhandled_input(event: InputEvent) -> void:
    if not choice_panel.visible or not (event is InputEventKey and event.pressed and not event.echo):
        return
    var buttons := choice_cards.get_children().filter(func(c): return c is Button)
    var target: Button = null
    if event.physical_keycode == KEY_S:
        target = choice_cards.get_node_or_null("Skip")
    else:
        var index: int = event.physical_keycode - KEY_1
        var cards := buttons.filter(func(b): return b.name != "Skip")
        if index >= 0 and index < cards.size():
            target = cards[index]
    if target and not target.disabled:
        get_viewport().set_input_as_handled()
        target.pressed.emit()

## Shows a gear's or round's name and description under the gear row for a moment.
func show_gear_info(gear: Resource, header := "") -> void:
    show_info_text(header, "%s: %s" % [gear.display_name.to_upper(), gear.description])

## The same pop-up for any message, e.g. an ambush warning.
func show_info_text(header: String, text: String) -> void:
    gear_info.text = "%s\n%s" % [header, text] if header else text
    gear_info.visible = true
    var timer := get_tree().create_timer(gear_info_seconds)
    gear_info_timer = timer
    await timer.timeout
    if gear_info_timer == timer:
        gear_info.visible = false

func _pulse_gear(frame: Control) -> void:
    frame.scale = Vector2(1.5, 1.5)
    frame.modulate = Color(2, 2, 2)
    var tween := create_tween().set_parallel()
    tween.tween_property(frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(frame, "modulate", Color.WHITE, 0.25)

func _resting_state() -> String:
    return "low" if low_health else "calm"

func _set_portrait(state: String) -> void:
    # Once downed, the portrait stays on DOWN until the restart.
    if down_label.visible:
        return
    portrait_label.text = PORTRAIT_STATES[state][0]
    portrait.color = PORTRAIT_STATES[state][1]
