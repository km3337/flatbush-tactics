# Player icons template

`player_icons_template.aseprite`: the freelancer's HUD portrait, one pose per
reaction. Duplicate it per freelancer (e.g. `spritework/Ali/ali_icons.aseprite`).

## Canvas

- 64x64, RGB, palette `lux2k.pal`. The HUD slot is 65x65 today and will be
  set to 64x64 when the art goes in.
- One frame per portrait; each frame is a tag named after the game's state,
  so the export maps straight onto the HUD:

| Tag | Shown when | Placeholder now |
|---|---|---|
| `idle` | Resting | IDLE |
| `hurt` | At 2 HP or less, and when downed | HURT |
| `happy` | Briefly (0.6s) after a counter or a kill, and on CLEARED | HAPPY |

Other events (hits, misses, taking damage) don't change the portrait.
## Layers (bottom to top)

- `_reference`: the current placeholder (colour + word) for that portrait.
- `background`: behind the face (the HUD shows the whole 64x64 square).
- `character`: the freelancer.
- `fx`: sweat drops, sparkles, stars...
- `_guides`: red border, blue dotted 2px safe margin (keep important detail
  inside it; the HUD may frame the edge), grey centre lines. Hide before
  exporting.

## Exporting

```
aseprite -b --ignore-layer _guides --ignore-layer _reference spritework/Ali/ali_icons.aseprite --sheet prototype/assets/freelancers/ali_icons.png --sheet-type horizontal --data prototype/assets/freelancers/ali_icons.json --format json-array --list-tags
```

The HUD still shows the placeholder boxes until the portrait is hooked up to
the exported sheet.