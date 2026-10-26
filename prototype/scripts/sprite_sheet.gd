class_name FTSpriteSheet
extends RefCounted

## An Aseprite export (sheet PNG + JSON with --format json-array --list-tags
## --list-slices) turned into Godot animations. Each tag becomes an
## animation with Aseprite's frame durations; a sheet without tags gets one
## looping "default" animation. A tag with any blank frame counts as missing
## (`has()` is false), so a half-drawn animation never blinks out; callers
## fall back instead. The `hitbox` slice
## (with its pivot on the feet) gives the shootable area. Loaded sheets are
## cached.

## Tags that loop; everything else plays once and holds its last frame.
const LOOPING := ["idle", "stunned", "strafe", "default"]

var frames := SpriteFrames.new()
## Size of one frame (the Aseprite canvas).
var frame_size := Vector2.ZERO
## Shootable area in frame coordinates (whole frame if there's no slice).
var hitbox := Rect2()
## Feet, in frame coordinates: where the sprite stands.
var pivot := Vector2.ZERO
var _present := {}

static var _cache := {}

static func load_sheet(sheet: Texture2D, data: JSON) -> FTSpriteSheet:
	var key := "%s|%s" % [sheet.resource_path, data.resource_path]
	if not _cache.has(key):
		var loaded := FTSpriteSheet.new()
		loaded._build(sheet, data.data)
		_cache[key] = loaded
	return _cache[key]

## True if the animation exists and every one of its frames has art.
func has(animation: StringName) -> bool:
	return _present.get(animation, false)

## Total length of an animation in seconds.
func length(animation: StringName) -> float:
	var total := 0.0
	for i in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, i)
	return total / frames.get_animation_speed(animation)

func _build(sheet: Texture2D, json: Dictionary) -> void:
	var image := sheet.get_image()
	var regions: Array[Rect2] = []
	var durations: Array[float] = []
	var blank: Array[bool] = []
	for f in json.frames:
		var r := Rect2(f.frame.x, f.frame.y, f.frame.w, f.frame.h)
		regions.append(r)
		durations.append(f.duration / 1000.0)
		blank.append(image.get_region(Rect2i(r)).get_used_rect().size == Vector2i.ZERO)
	frame_size = Vector2(json.frames[0].sourceSize.w, json.frames[0].sourceSize.h)
	var tags: Array = json.meta.get("frameTags", [])
	if tags.is_empty():
		tags = [{"name": "default", "from": 0, "to": regions.size() - 1}]
	frames.remove_animation(&"default")
	for tag in tags:
		var anim := StringName(tag.name)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 1.0)  # durations below are seconds
		frames.set_animation_loop(anim, String(anim) in LOOPING)
		var all_drawn := true
		for i in range(int(tag.from), int(tag.to) + 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = regions[i]
			frames.add_frame(anim, atlas, durations[i])
			all_drawn = all_drawn and not blank[i]
		_present[anim] = all_drawn
	hitbox = Rect2(Vector2.ZERO, frame_size)
	pivot = Vector2(frame_size.x / 2.0, frame_size.y)
	for s in json.meta.get("slices", []):
		if s.name == "hitbox" and not s["keys"].is_empty():
			var key: Dictionary = s["keys"][0]
			hitbox = Rect2(key.bounds.x, key.bounds.y, key.bounds.w, key.bounds.h)
			if key.has("pivot"):
				pivot = hitbox.position + Vector2(key.pivot.x, key.pivot.y)
