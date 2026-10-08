# Enemy sprite template

`enemy_template.aseprite`: duplicate it per enemy (e.g. `grunt.aseprite`)
and draw over the guides.

## Canvas

- 64x128, RGB, palette `lux2k.pal` (36 colours) already loaded.
- Draw each enemy once, at its **closest / largest size** (about 100px tall).
  In 2.5D the 3D view shrinks far enemies for you; never draw smaller copies.
- Facing the camera (the player). The only exception is `strafe`.

## Guides (`_guides` layer; hide before exporting)

| Guide | Where | Meaning |
|---|---|---|
| Red line | y = 120 | Ground: feet rest on it. |
| Blue dotted line | y = 20 | Top of the head for a ~100px-tall enemy. |
| Gold dots | y = 2 | Headroom: y 0–19 is for stun stars and effects. |
| Grey dotted line | x = 32 | Centre: keep the body centred on it. |
| Left-edge ticks | every 10px | Height from the ground (long tick every 50). |
| Faint mannequin | | Rough proportions only. |

The **`hitbox` slice** (cyan box, x 6–57, y 20–119) is the shootable area. Its
**pivot is the feet** (32, 120): in 2.5D that point sits on the ground, and the
sprite stands up from it. If an enemy is wider, taller or crouched, adjust the
slice to match the body, and keep the pivot on the feet.

## Layers (bottom to top)

- `_guides`: reference only.
- `shadow`: optional ground shadow under the feet. The 2.5D scene may draw its
  own, so keep it separate from the body.
- `body`: the enemy.
- `fx`: muzzle flash, the wind-up glow, hit sparks. Kept separate so the game
  can tint or flash them on their own.

## Animations (tags)

| Tag | Frames | ms/frame | Notes |
|---|---|---|---|
| `idle` | 4 | 150 | Loops. |
| `windup` | 3 | 200 | The attack tell. End on the most readable "about to fire" pose: it's what the player counters, and it must read through the cover blur. Today the game also flashes the enemy orange. |
| `attack` | 2 | 100 | The shot (muzzle flash in `fx`). |
| `hit` | 1 | 120 | Flinch when shot. |
| `stunned` | 4 | 120 | Loops while staggered. The game draws stars above the head, in the headroom. |
| `death` | 4 | 120 | Plays once. The last frame can be empty or a body on the ground. |
| `strafe` | 4 | 100 | Loops while moving sideways. Draw it **moving right**; the game mirrors it for left. |

The game can stretch or shorten a tag to match its timing (e.g. wind-up
length per enemy type), so the frame durations are a starting point.

## Exporting

From the project folder, one sheet plus data per enemy (guides left out):

```
aseprite -b spritework/grunt.aseprite --ignore-layer _guides --sheet prototype/assets/enemies/grunt.png --sheet-type horizontal --data prototype/assets/enemies/grunt.json --format json-array --list-tags --list-slices
```

The JSON keeps the tags (animations) and the hitbox slice with its pivot, so
the game can read both. (Hooking enemies up to these sheets is still to do:
`FTEnemy` is a coloured rectangle today.)

## For 2.5D later

- Enemies become flat sprites standing in a 3D scene (billboards facing the
  camera), placed by their feet pivot.
- The whole 3D scene renders at the game's low resolution (360x780), so a
  sprite up close is 1 art pixel = 1 screen pixel. Far away it shrinks, and
  its pixels stay square and on the same grid as everything else.
- Keep outlines and edges clean at 1x; avoid fine 1px detail that only
  reads up close, since far enemies lose it.
