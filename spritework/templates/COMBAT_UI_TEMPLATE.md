# Combat UI template

`combat_ui_template.aseprite`: draw the battle screen's UI over the current
placeholder layout.

## Canvas

- 360x780 (the game's base resolution), RGB, palette `lux2k.pal`.
- Three frames, one per state (tags):
  - `combat`: out of cover, the HUD as it is now.
  - `in_cover`: ducked; the cover covers the bottom 65%.
  - `reward`: the after-fight reward picker.

## Layers (bottom to top)

- `_reference`: a screenshot of that state as it looks now (faded). Hide it or
  lower its opacity as you go.
- `background`: the scene behind the enemies (the battlefield is the middle
  360x640, y 70–710).
- `cover`: the cover art (`in_cover` frame): 360x507, from y 273 down.
- `hud`: the HUD pieces.
- `fx`: hit spark, reticle, flashes.
- `_labels`: each mocked-up area outlined and named. Hide before exporting.

## Labelled areas (also named slices, View > Show Slices)

Positions are measured from the running game at 360x780.

| Slice | Frame | What it is now |
|---|---|---|
| `hud_portrait` | combat | Freelancer portrait; swaps word/colour for reactions (CALM, NICE, MISSED, YEAH!, GOT 'EM, OUCH, HURTING, DOWN) |
| `hud_hp` | combat | HP pips (■ □) |
| `hud_money` | combat | Money ($) |
| `hud_debug` | combat | Prototype title, biome/wave, hits taken/blocked: debug text, likely removed |
| `hud_gear_row` | combat | Owned gear icons, 24x24 each with a rarity border |
| `hud_gear_popup` | combat | Pop-up for new gear / ambush warnings |
| `hud_counter` | combat | "COUNTER" flash on the left |
| `hud_reload` | combat | "RELOAD" flash when the magazine is empty |
| `hud_banner` | combat | DOWN / CLEARED (+$) banner |
| `hud_key_hints` | combat | Key hints, probably removed |
| `hud_ammo` | combat | Ammo row: 5 rounds in 16x35 slots, coloured by modifier; the rightmost fires next |
| `hud_arsenal` | combat | Rounds left / spent in the arsenal |
| `enemy_hp` / `enemy_status` | combat | Above / below each enemy: HP dots and status tags (BURN, TOX2, FRZ) |
| `fx_hit_spark` / `fx_reticle` | combat | Size guides: hit spark 72x48, reticle about 36x36 with its cooldown bar |
| `cover_shield` | in_cover | The cover (biome art); its name text is debug |
| `cover_peek` | in_cover | The top 35% that stays visible, blurred |
| `cover_warning` | in_cover | "!" over each enemy winding up (35x50) |
| `reward_title`, `reward_card_1..3`, `reward_skip` | reward | Picker title, 300x72 cards, 300x32 skip button |

The slices export with `--list-slices`, so drawn pieces can later be placed
in the game by these names.