extends SceneTree

# Cuts the Metal Snake, Seeker and Dark Droid out of their ripped sheets
# (boxes found by find_sprites.gd) into tagged sheets + JSON for
# FTSpriteSheet, plus the droid's orb as a strip of square frames.
# (metal_snake.png / seeker.png in rips are GIFs; the .converted.png copies are
# real PNGs that Godot can read.)
# Run: Godot --headless --path prototype --script <abs path to this file>
const SRC := "D:/NULL/game dev/flatbush tactics/spritework/rips/"
const OUT := "D:/NULL/game dev/flatbush tactics/prototype/assets/enemies/"
const PAD := 2

# Each frame: [x, y, w, h, align, ms]. align: "bc" bottom-centre, "tl" / "tr"
# top-left / top-right, "c" centre.
var jobs := {
	"metal_snake": {"src": "metal_snake.converted.png", "hitbox_tag": "idle", "tags": [
		["idle", [[114, 18, 24, 35, "bc", 400], [143, 19, 24, 34, "bc", 400]]],
		["windup", [[143, 19, 24, 34, "bc", 100]]],
		["attack", [[172, 20, 24, 33, "bc", 250]]],
		["hit", [[31, 58, 24, 23, "bc", 150]]],
		["emerge", [[8, 49, 16, 4, "bc", 70], [29, 45, 22, 8, "bc", 70], [56, 34, 20, 19, "bc", 80], [82, 23, 24, 30, "bc", 90]]],
		["burrow", [[201, 28, 24, 25, "bc", 70], [230, 42, 24, 11, "bc", 70], [259, 47, 24, 6, "bc", 70], [288, 49, 16, 4, "bc", 70]]],
	]},
	"seeker": {"src": "seeker.converted.png", "hitbox_tag": "idle", "tags": [
		["idle", [[55, 3, 30, 24, "c", 90], [89, 3, 30, 24, "c", 90], [124, 3, 28, 24, "c", 90], [156, 3, 30, 24, "c", 90]]],
		["windup", [[54, 33, 30, 24, "c", 100], [89, 33, 30, 24, "c", 100], [124, 33, 28, 24, "c", 100], [156, 33, 30, 24, "c", 100]]],
		["hit", [[19, 62, 28, 24, "c", 150]]],
		["death", [[100, 62, 18, 24, "tl", 120], [132, 62, 18, 24, "tr", 120]]],
	]},
	"dark_droid": {"src": "dark_droid.png", "hitbox_tag": "idle", "tags": [
		["idle", [[10, 20, 104, 69, "c", 500]]],
		# Charge glow, flickering between the two green poses.
		["windup", [[126, 21, 104, 69, "c", 100], [240, 21, 104, 69, "c", 100], [126, 21, 104, 69, "c", 100], [240, 21, 104, 69, "c", 100], [126, 21, 104, 69, "c", 100], [240, 21, 104, 69, "c", 100]]],
	]},
}

# The droid's charged orb: square frames, centred.
var orb_frames := [[10, 290, 64, 64], [80, 290, 62, 62], [150, 290, 64, 64], [220, 290, 62, 62], [290, 290, 64, 64], [360, 290, 62, 62], [430, 290, 64, 64], [10, 369, 62, 62], [78, 369, 62, 62]]

func _init() -> void:
	for name in jobs:
		_cut_enemy(name, jobs[name])
	_cut_orb()
	quit()

func _load(file: String) -> Image:
	var img := Image.load_from_file(SRC + file)
	img.convert(Image.FORMAT_RGBA8)
	return img

# The box's pixels with its background removed: flood fill from the box's
# edges through background-coloured pixels, so the same colour inside the
# sprite (white highlights) is kept.
func _extract(src: Image, r: Rect2i) -> Image:
	var img := src.get_region(r)
	var bg := src.get_pixel(0, 0)
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x] == 1:
			continue
		seen[p.y * w + p.x] = 1
		var c := img.get_pixelv(p)
		var is_bg := c.a < 0.1 or (bg.a > 0.5 and absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) <= 0.08)
		if not is_bg:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.UP)
		stack.append(p + Vector2i.DOWN)
	return img

func _cut_enemy(name: String, job: Dictionary) -> void:
	var src := _load(job.src)
	var cell := Vector2i.ZERO
	var count := 0
	for tag in job.tags:
		for f in tag[1]:
			cell = Vector2i(maxi(cell.x, f[2]), maxi(cell.y, f[3]))
			count += 1
	var sheet := Image.create(count * (cell.x + PAD), cell.y, false, Image.FORMAT_RGBA8)
	var frames := []
	var tags := []
	var hitbox := Rect2i()
	var i := 0
	for tag in job.tags:
		var from := i
		for f in tag[1]:
			var part := _extract(src, Rect2i(f[0], f[1], f[2], f[3]))
			var off := Vector2i.ZERO
			match f[4]:
				"bc": off = Vector2i((cell.x - f[2]) / 2, cell.y - f[3])
				"c": off = Vector2i((cell.x - f[2]) / 2, (cell.y - f[3]) / 2)
				"tr": off = Vector2i(cell.x - f[2], 0)
			var ox := i * (cell.x + PAD)
			sheet.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(ox, 0) + off)
			if tag[0] == job.hitbox_tag:
				var used := Rect2i(off + part.get_used_rect().position, part.get_used_rect().size)
				hitbox = used if hitbox.size == Vector2i.ZERO else hitbox.merge(used)
			frames.append({"filename": "%s %d" % [name, i], "frame": {"x": ox, "y": 0, "w": cell.x, "h": cell.y},
				"sourceSize": {"w": cell.x, "h": cell.y}, "duration": f[5]})
			i += 1
		tags.append({"name": tag[0], "from": from, "to": i - 1, "direction": "forward"})
	sheet.save_png(OUT + name + ".png")
	var data := {"frames": frames, "meta": {"app": "flatbush cut_enemies2.gd", "image": name + ".png", "frameTags": tags,
		"slices": [{"name": "hitbox", "keys": [{"frame": 0,
			"bounds": {"x": hitbox.position.x, "y": hitbox.position.y, "w": hitbox.size.x, "h": hitbox.size.y},
			"pivot": {"x": hitbox.size.x / 2, "y": hitbox.size.y}}]}]}}
	var file := FileAccess.open(OUT + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " "))
	file.close()
	print("%s: %d frames, cell %s, hitbox %s, tags %s" % [name, count, cell, hitbox, tags.map(func(t): return t.name)])

func _cut_orb() -> void:
	var src := _load("dark_droid.png")
	var size := 64
	var strip := Image.create(orb_frames.size() * size, size, false, Image.FORMAT_RGBA8)
	for k in orb_frames.size():
		var f: Array = orb_frames[k]
		var part := _extract(src, Rect2i(f[0], f[1], f[2], f[3]))
		strip.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(k * size + (size - f[2]) / 2, (size - f[3]) / 2))
	strip.save_png(OUT + "dark_droid_orb.png")
	print("dark_droid_orb: %d frames of %dx%d" % [orb_frames.size(), size, size])
