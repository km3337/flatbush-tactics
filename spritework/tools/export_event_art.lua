-- Exports what's drawn in event_screen_template.aseprite to where the game
-- picks it up. Empty cels are skipped, so unfinished events keep the placeholder:
--   the `art` layer of each event's frame -> prototype/assets/events/<event id>.png
--   the `background` layer -> prototype/assets/ui/event/background.png
--   aseprite -b spritework/templates/event_screen_template.aseprite --script spritework/tools/export_event_art.lua
local here = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local assets = app.params.out or app.fs.joinPath(here, "..", "..", "prototype", "assets")
local spr = app.sprite

local function layer_named(name)
	for _, layer in ipairs(spr.layers) do
		if layer.name == name then
			return layer
		end
	end
end

local function slice_named(name)
	for _, slice in ipairs(spr.slices) do
		if slice.name == name then
			return slice
		end
	end
end

-- The cel's pixels cropped to `bounds`, saved as a PNG. Nil if nothing's drawn.
local function export(layer, frame, bounds, path)
	local cel = layer:cel(frame)
	if cel == nil or cel.image:isEmpty() then
		return
	end
	local out = Image(bounds.width, bounds.height, ColorMode.RGB)
	out:drawImage(cel.image, Point(cel.position.x - bounds.x, cel.position.y - bounds.y))
	app.fs.makeAllDirectories(app.fs.filePath(path))
	out:saveAs(path)
	print("exported " .. path)
end

local art = layer_named("art")
local box = slice_named("event_art").bounds
for _, tag in ipairs(spr.tags) do
	if tag.name ~= "outcome" then
		export(art, tag.fromFrame.frameNumber, box, app.fs.joinPath(assets, "events", tag.name .. ".png"))
	end
end
export(layer_named("background"), 1, Rectangle(0, 0, spr.width, spr.height),
	app.fs.joinPath(assets, "ui", "event", "background.png"))
