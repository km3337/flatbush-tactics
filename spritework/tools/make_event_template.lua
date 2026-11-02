-- Builds spritework/templates/event_screen_template.aseprite. Only needed if the
-- event screen's layout changes (it overwrites the file, so copy drawn art out
-- first). Reference screenshots come from a folder of event_<id>.png files at
-- 360x780 (one per event, plus event_outcome.png):
--   aseprite -b --script-param shots=<folder> --script spritework/tools/make_event_template.lua
local here = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local shots = app.params.shots
local events = { "churro_lady", "delayed_train", "lost_metrocard", "subway_acrobat", "traveling_poet" }
local frames = { table.unpack(events) }
frames[#frames + 1] = "outcome"

-- Measured from the running game at 360x780 (the event screen's 360x640 frame
-- starts at y 70). The same areas as scripts/ui/event_screen.gd.
local areas = {
	{ "event_header", 0, 70, 360, 34 },
	{ "event_art", 20, 116, 320, 130 },
	{ "event_title", 20, 254, 320, 30 },
	{ "event_text", 20, 290, 320, 190 },
	{ "event_effects", 20, 482, 320, 90 },
	{ "choice_1", 30, 550, 300, 44 },
	{ "choice_2", 30, 602, 300, 44 },
	{ "choice_3", 30, 654, 300, 44 },
}

local spr = Sprite(360, 780, ColorMode.RGB)
spr:setPalette(Palette{ fromFile = app.fs.joinPath(here, "..", "lux2k.pal") })
for i = 2, #frames do
	spr:newEmptyFrame(i)
end

local reference = spr.layers[1]
reference.name = "_reference"
reference.opacity = 110
local background = spr:newLayer()
background.name = "background"
background.isContinuous = true  -- one drawing shared by every frame
local art = spr:newLayer()
art.name = "art"
local ui = spr:newLayer()
ui.name = "ui"
ui.isContinuous = true
local labels = spr:newLayer()
labels.name = "_labels"

for i, name in ipairs(frames) do
	local path = app.fs.joinPath(shots, "event_" .. name .. ".png")
	spr:newCel(reference, i, Image{ fromFile = path }, Point(0, 0))
	local tag = spr:newTag(i, i)
	tag.name = name
end

-- Outlines of each area, one colour for all, on every frame.
local outline = Image(spr.width, spr.height, ColorMode.RGB)
local cyan = app.pixelColor.rgba(155, 240, 253, 255)
for _, a in ipairs(areas) do
	local x, y, w, h = a[2], a[3], a[4], a[5]
	for px = x, x + w - 1 do
		outline:drawPixel(px, y, cyan)
		outline:drawPixel(px, y + h - 1, cyan)
	end
	for py = y, y + h - 1 do
		outline:drawPixel(x, py, cyan)
		outline:drawPixel(x + w - 1, py, cyan)
	end
	local slice = spr:newSlice(Rectangle(x, y, w, h))
	slice.name = a[1]
end
labels.isContinuous = true
spr:newCel(labels, 1, outline, Point(0, 0))
for i = 2, #frames do
	spr:newCel(labels, i, outline:clone(), Point(0, 0))
end

spr:saveAs(app.fs.joinPath(here, "..", "templates", "event_screen_template.aseprite"))
