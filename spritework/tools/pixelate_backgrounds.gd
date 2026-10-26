extends SceneTree

## Turns photos into battle backgrounds: crop a tall slice, average down to
## SIZE, darken, then snap every pixel to the nearest Lux2k colour (no
## dithering). The game shows them at 2x.
##
## Run from the repo root:
##   Godot --headless --path prototype --script spritework/tools/pixelate_backgrounds.gd
## (use the absolute path to this file if Godot can't find it).

const SIZE := Vector2i(200, 420)  # 400x840 on screen, a margin around 360x780
const DARKEN := 0.82
## Before darkening, each photo's brightness is stretched so its darkest /
## brightest LEVELS_CLIP share of pixels hit black / white (dark, hazy photos
## otherwise collapse into the palette's darkest colour).
const LEVELS_CLIP := 0.01
const SATURATION := 1.3
const PALETTE_FILE := "../spritework/lux2k.pal"
const PHOTO_DIR := "../spritework/backgrounds/photos/"
const OUT_DIR := "res://assets/backgrounds/"
## [photo, output name, horizontal centre of the crop (0-1)].
const JOBS := [
	["city_hall_station.webp", "city_hall_station", 0.47],
	["graffiti_wall.jpg", "graffiti_wall", 0.47],
	["graffiti_corridor.jpg", "graffiti_corridor", 0.36],
]

func _init() -> void:
	var palette := _load_palette(ProjectSettings.globalize_path("res://" + PALETTE_FILE))
	for job in JOBS:
		var photo := Image.load_from_file(ProjectSettings.globalize_path("res://" + PHOTO_DIR + job[0]))
		photo.convert(Image.FORMAT_RGB8)
		var img := _crop(photo, job[2])
		while img.get_width() >= SIZE.x * 2 and img.get_height() >= SIZE.y * 2:
			img.shrink_x2()  # box average, so detail blends instead of aliasing
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_CUBIC)
		_grade(img)
		_quantize(img, palette)
		var out: String = OUT_DIR + job[1] + ".png"
		img.save_png(ProjectSettings.globalize_path(out))
		print("wrote ", out)
	quit()

## The widest slice with SIZE's shape, using the full photo height.
func _crop(photo: Image, centre: float) -> Image:
	var h := photo.get_height()
	var w := mini(photo.get_width(), roundi(h * float(SIZE.x) / SIZE.y))
	var x := clampi(roundi(photo.get_width() * centre - w / 2.0), 0, photo.get_width() - w)
	return photo.get_region(Rect2i(x, 0, w, h))

## Auto-levels, saturation boost, then darken.
func _grade(img: Image) -> void:
	var lums: Array[float] = []
	for y in img.get_height():
		for x in img.get_width():
			lums.append(img.get_pixel(x, y).get_luminance())
	lums.sort()
	var lo := lums[int(lums.size() * LEVELS_CLIP)]
	var hi := lums[int(lums.size() * (1.0 - LEVELS_CLIP)) - 1]
	var span := maxf(hi - lo, 0.01)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c = Color((c.r - lo) / span, (c.g - lo) / span, (c.b - lo) / span).clamp()
			var grey := c.get_luminance()
			c = Color(grey, grey, grey).lerp(c, SATURATION).clamp()
			img.set_pixel(x, y, Color(c.r * DARKEN, c.g * DARKEN, c.b * DARKEN))

func _quantize(img: Image, palette: Array[Color]) -> void:
	var cache := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var key := c.to_rgba32()
			if not cache.has(key):
				cache[key] = _nearest(c, palette)
			img.set_pixel(x, y, cache[key])

## "Redmean" weighted RGB distance: cheap and close to how eyes judge colour.
func _nearest(c: Color, palette: Array[Color]) -> Color:
	var best := palette[0]
	var best_d := INF
	for p in palette:
		var rm := (c.r + p.r) * 0.5
		var dr := c.r - p.r
		var dg := c.g - p.g
		var db := c.b - p.b
		var d := (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db
		if d < best_d:
			best_d = d
			best = p
	return best

func _load_palette(path: String) -> Array[Color]:
	var colors: Array[Color] = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in range(3, lines.size()):  # JASC-PAL header is 3 lines
		var parts := lines[i].strip_edges().split(" ", false)
		if parts.size() >= 3:
			colors.append(Color8(int(parts[0]), int(parts[1]), int(parts[2])))
	return colors
