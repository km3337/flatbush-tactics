class_name FTDigitalRain
extends Control

## Falling columns of pixel glyphs ("digital rain"), drawn on the pixel grid
## in Lux2k colours: a near-white head, then a trail that steps down through
## the palette's greens (or blues for about 1 column in 6). Glyphs are small
## blocky 5x7 shapes generated at startup (the Nokia font has no katakana).
## Fills its own rect; put it behind other UI.

const GLYPH := Vector2i(5, 7)
## One cell: a glyph plus spacing.
const CELL := Vector2i(8, 9)
const GLYPH_COUNT := 48
const HEAD := Color8(230, 222, 202)
## Trail colours from just behind the head to the faint tail (Lux2k).
const GREENS: Array[Color] = [Color8(204, 246, 31), Color8(150, 198, 65), Color8(128, 165, 63), Color8(66, 127, 59), Color8(42, 90, 57), Color8(31, 55, 54)]
const BLUES: Array[Color] = [Color8(155, 240, 253), Color8(98, 171, 212), Color8(88, 128, 204), Color8(64, 54, 159), Color8(61, 37, 59)]

## Whole-number draw scale for the glyphs (2 = chunky, like far enemies).
@export var glyph_scale := 2
## Share of columns that are falling at any moment (the rest wait above the
## screen for a moment before starting again).
@export_range(0.0, 1.0) var density := 0.8
## Share of columns that are blue instead of green.
@export_range(0.0, 1.0) var blue_share := 0.15
## Cells per second, min..max per column.
@export var speed_range := Vector2(5.0, 16.0)
## Trail length in cells, min..max per column.
@export var trail_range := Vector2i(6, 22)
## Chance per second that a trail glyph changes.
@export var flicker_rate := 0.6

var _atlas: ImageTexture
var _columns: Array[Dictionary] = []
var _rows := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atlas = _make_glyph_atlas()
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_rows = ceili(size.y / (CELL.y * glyph_scale)) + 1
	var count := ceili(size.x / (CELL.x * glyph_scale))
	_columns.clear()
	for i in count:
		var column := {}
		_respawn(column, true)
		_columns.append(column)

# A column starts above the screen (anywhere down it on the first layout, so
# the screen isn't empty at first) with a new speed, length and colour.
func _respawn(column: Dictionary, anywhere: bool) -> void:
	column.speed = randf_range(speed_range.x, speed_range.y)
	column.trail = randi_range(trail_range.x, trail_range.y)
	column.blue = randf() < blue_share
	# Waiting gap above the screen: shorter = denser rain.
	var gap := _rows * (1.0 - density)
	column.head = randf_range(-gap, _rows) if anywhere else -randf_range(0.0, gap)
	var glyphs := PackedInt32Array()
	glyphs.resize(_rows + trail_range.y + 1)
	for i in glyphs.size():
		glyphs[i] = randi() % GLYPH_COUNT
	column.glyphs = glyphs

func _process(delta: float) -> void:
	for column in _columns:
		column.head += column.speed * delta
		if column.head - column.trail > _rows:
			_respawn(column, false)
		var glyphs: PackedInt32Array = column.glyphs
		var flips := int(flicker_rate * delta * column.trail + randf())
		for i in flips:
			glyphs[randi() % glyphs.size()] = randi() % GLYPH_COUNT
	queue_redraw()

func _draw() -> void:
	for x in _columns.size():
		var column: Dictionary = _columns[x]
		var head_row := int(column.head)
		var trail: int = column.trail
		var steps: Array[Color] = BLUES if column.blue else GREENS
		var glyphs: PackedInt32Array = column.glyphs
		for i in trail:
			var row := head_row - i
			if row < 0 or row >= _rows:
				continue
			var color := HEAD if i == 0 else steps[mini((i - 1) * steps.size() / maxi(trail - 1, 1), steps.size() - 1)]
			var glyph := glyphs[row % glyphs.size()]
			var dest := Rect2(Vector2(x * CELL.x + 1, row * CELL.y + 1) * glyph_scale, GLYPH * glyph_scale)
			draw_texture_rect_region(_atlas, dest, Rect2(Vector2(glyph * GLYPH.x, 0), GLYPH), color)

# White 5x7 glyphs side by side; drawing modulates them to palette colours.
# Each is mirrored left-right or built from strokes so it reads as a
# character rather than noise.
func _make_glyph_atlas() -> ImageTexture:
	var img := Image.create(GLYPH.x * GLYPH_COUNT, GLYPH.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # same glyph set every run
	for g in GLYPH_COUNT:
		var bits := []
		for y in GLYPH.y:
			bits.append([false, false, false, false, false])
		# A few strokes: horizontal bars, vertical bars, a diagonal.
		for s in rng.randi_range(2, 4):
			match rng.randi() % 3:
				0:
					var y := rng.randi_range(0, GLYPH.y - 1)
					for x in range(rng.randi_range(0, 1), rng.randi_range(3, 4) + 1):
						bits[y][x] = true
				1:
					var x := rng.randi_range(0, GLYPH.x - 1)
					for y in range(rng.randi_range(0, 2), rng.randi_range(4, GLYPH.y - 1) + 1):
						bits[y][x] = true
				2:
					var x0 := rng.randi_range(0, 2)
					for y in range(rng.randi_range(0, 2), GLYPH.y):
						var x := x0 + (y / 2)
						if x < GLYPH.x:
							bits[y][x] = true
		var mirror := rng.randf() < 0.4
		for y in GLYPH.y:
			for x in GLYPH.x:
				var on: bool = bits[y][x] or (mirror and bits[y][GLYPH.x - 1 - x])
				if on:
					img.set_pixel(g * GLYPH.x + x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
