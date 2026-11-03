-- Cuts the placeholder enemy attack effects out of spritework/rips/FX.png
-- (Pokémon Ruby/Sapphire move effects) into prototype/assets/fx:
--   attack_bite_jaw.png: one row of fangs (Bite); the game flips it for the lower jaw.
--   attack_impact.png/.json: an impact burst, 4 frames (Pound-style hit).
-- Each cut's background colour (sampled at its corner) becomes transparent.
--   aseprite -b --script spritework/tools/make_attack_fx.lua
local here = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local rip = Image{ fromFile = app.fs.joinPath(here, "..", "rips", "FX.png") }
local out = app.fs.joinPath(here, "..", "..", "prototype", "assets", "fx")
local clear = app.pixelColor.rgba(0, 0, 0, 0)

-- The rip's pixels inside `r`, with the colour at (bgx, bgy) cleared.
local function cut(r, bgx, bgy)
	local bg = rip:getPixel(bgx, bgy)
	local img = Image(r.width, r.height, ColorMode.RGB)
	img:drawImage(rip, Point(-r.x, -r.y))
	for it in img:pixels() do
		if it() == bg then
			it(clear)
		end
	end
	return img
end

cut(Rectangle(292, 464, 62, 16), 292, 441):saveAs(app.fs.joinPath(out, "attack_bite_jaw.png"))

-- Impact frames (measured blob bounds), centred in 32x32 cells.
local CELL = 32
local impact = {
	{ Rectangle(418, 1165, 10, 20), 40 },
	{ Rectangle(413, 1193, 20, 28), 50 },
	{ Rectangle(408, 1223, 31, 30), 70 },
	{ Rectangle(411, 1264, 24, 14), 60 },
}
local strip = Image(CELL * #impact, CELL, ColorMode.RGB)
local frames = {}
for i, f in ipairs(impact) do
	local r = f[1]
	local img = cut(r, 409, 1162)
	local x = (i - 1) * CELL
	strip:drawImage(img, Point(x + (CELL - r.width) // 2, (CELL - r.height) // 2))
	frames[#frames + 1] = string.format(
		'  {"filename": "impact %d", "duration": %d, "frame": {"x": %d, "y": 0, "w": %d, "h": %d}, "sourceSize": {"w": %d, "h": %d}}',
		i - 1, f[2], x, CELL, CELL, CELL, CELL)
end
strip:saveAs(app.fs.joinPath(out, "attack_impact.png"))
local json = io.open(app.fs.joinPath(out, "attack_impact.json"), "w")
json:write('{\n "frames": [\n' .. table.concat(frames, ",\n") .. '\n ],\n')
json:write(string.format(' "meta": {"app": "make_attack_fx.lua", "image": "attack_impact.png", "frameTags": [{"name": "default", "from": 0, "to": %d, "direction": "forward"}]}\n}\n', #impact - 1))
json:close()
print("ok")
