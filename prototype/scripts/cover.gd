class_name FTCover
extends CanvasLayer

## Player cover. Drawn above the world (enemies) and below the HUD. While in
## cover it hides the whole battlefield except a thin strip along the top, so
## the player can tell the fight is still going on. The biome only sets its look.
## While in cover, a "!" is drawn over each enemy that is winding up an attack,
## and flashes red when that shot is blocked.

signal entered_cover
signal exited_cover

@export var slide_seconds := 0.14
## Fraction of the screen height left visible above the cover.
@export var peek_height := 0.12
@export var warning_color := Color(1.0, 0.62, 0.1)
@export var blocked_color := Color(1.0, 0.2, 0.2)
@export var blocked_flash_seconds := 0.3
@onready var shield: ColorRect = $Shield
@onready var cover_label: Label = $Shield/CoverLabel
var in_cover := false
var biome: FTBiome
var slide_tween: Tween
var warnings := {}  # FTEnemy -> Label
var blocked_until := {}  # FTEnemy -> time (seconds) the blocked flash ends

func _ready() -> void:
	shield.visible = false

func track_enemies(enemies: Array[FTEnemy]) -> void:
	for enemy in enemies:
		var label := Label.new()
		label.text = "!"
		label.add_theme_font_size_override("font_size", 64)
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(60, 80)
		label.pivot_offset = label.size / 2.0
		label.visible = false
		add_child(label)
		warnings[enemy] = label
		enemy.attacked.connect(_on_enemy_attacked.bind(enemy))

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for enemy: FTEnemy in warnings:
		var label: Label = warnings[enemy]
		var blocked: bool = blocked_until.get(enemy, 0.0) > now
		label.visible = in_cover and enemy.alive and (enemy.winding_up or blocked)
		if not label.visible:
			continue
		label.position = enemy.get_global_rect().get_center() - label.size / 2.0
		if blocked:
			label.add_theme_color_override("font_color", blocked_color)
			label.scale = Vector2(1.4, 1.4)
			label.modulate.a = 1.0
		else:
			label.add_theme_color_override("font_color", warning_color)
			label.scale = Vector2.ONE
			label.modulate.a = 0.6 + 0.4 * sin(now * 18.0)

func _on_enemy_attacked(enemy: FTEnemy) -> void:
	if in_cover:
		blocked_until[enemy] = Time.get_ticks_msec() / 1000.0 + blocked_flash_seconds

func apply_biome(new_biome: FTBiome) -> void:
	biome = new_biome
	shield.color = biome.cover_color
	cover_label.text = "%s\n%s" % [biome.cover_name.to_upper(), biome.display_name.to_lower()]
	if in_cover:
		_kill_tween()
		_place_shield()

func enter() -> void:
	if in_cover:
		return
	in_cover = true
	_kill_tween()
	_place_shield()
	var rest_y := shield.position.y
	shield.position.y = _viewport_size().y
	shield.visible = true
	slide_tween = create_tween()
	slide_tween.tween_property(shield, "position:y", rest_y, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entered_cover.emit()

func exit() -> void:
	if not in_cover:
		return
	in_cover = false
	_kill_tween()
	slide_tween = create_tween()
	slide_tween.tween_property(shield, "position:y", _viewport_size().y, slide_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide_tween.tween_callback(func(): shield.visible = false)
	exited_cover.emit()

func _place_shield() -> void:
	var size := _viewport_size()
	shield.position = Vector2(0.0, size.y * peek_height)
	shield.size = Vector2(size.x, size.y * (1.0 - peek_height))

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _kill_tween() -> void:
	if slide_tween:
		slide_tween.kill()
