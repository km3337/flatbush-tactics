class_name FTHpBar
extends Control

## The player's HP bar (Kristian's art: assets/ui/hud/hp_bar.png). The art
## shows all 17 pips; lost HP is painted over from the right with the bar's
## solid background green. The full bar is always max HP, so pips shown =
## 17 x HP / max HP, rounded. Pips that were just lost flash white briefly.

const TEXTURE: Texture2D = preload("res://assets/ui/hud/hp_bar.png")
# Pip layout in the art.
const PIP_COUNT := 17
const FIRST_PIP_X := 14
const PIP_STEP := 6
const PIP_RECT := Rect2(0, 4, 4, 18)  # one pip, offset by its x
const EMPTY := Color("1f3736")
const FLASH := Color.WHITE
const FLASH_SECONDS := 0.25

var shown := PIP_COUNT
var _flash_from := PIP_COUNT  # pips >= this and < _flash_to are flashing
var _flash_to := PIP_COUNT
var _flash_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TEXTURE.get_size()
	size = TEXTURE.get_size()

## How many pips `hp` out of `max_hp` shows.
static func pips_for(hp: int, max_hp: int) -> int:
	if max_hp <= 0 or hp <= 0:
		return 0
	return clampi(roundi(float(PIP_COUNT) * hp / max_hp), 1, PIP_COUNT)

func set_hp(hp: int, max_hp: int) -> void:
	var pips := pips_for(hp, max_hp)
	if pips < shown:
		_flash_from = pips
		_flash_to = shown
		if _flash_tween:
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_interval(FLASH_SECONDS)
		_flash_tween.tween_callback(func(): _flash_from = PIP_COUNT; _flash_to = PIP_COUNT; queue_redraw())
	shown = pips
	queue_redraw()

func _draw() -> void:
	draw_texture(TEXTURE, Vector2.ZERO)
	for i in range(shown, PIP_COUNT):
		var color := FLASH if i >= _flash_from and i < _flash_to else EMPTY
		draw_rect(Rect2(PIP_RECT.position + Vector2(FIRST_PIP_X + i * PIP_STEP, 0), PIP_RECT.size), color)
