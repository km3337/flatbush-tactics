# Adding Aseprite art

How to get art drawn in Aseprite into the Godot prototype, focused on UI.

## 1. Draw at 1x, on the 360x780 grid

The game's base resolution is **360x780** (raised from 360x640 for the freelancer select screen; the battle's enemy layout still uses a 360x640 area centred in it). One pixel in Aseprite equals one unit in Godot, so draw at 1x and never upscale before export.

- Mock up full screens on a **360x780** canvas so you can see the whole layout (`assets/mockup/mockup.png` is 360 wide).
- Draw each piece (portrait frame, ammo round, button, panel) as its own sprite at the size it'll appear in game.
- For reference, here are the sizes of the current placeholders, in pixels:

| Element | Node / script | Size |
| --- | --- | --- |
| Portrait | `HUD/Portrait` | 65x65 at (10, 10) |
| HP pips | `HUD/HPPips` | row of 5, starting at (82, 10), about 25 tall |
| Ammo round slot | `hud.gd` `setup_ammo` | 16x35 each, 7px apart, 6 rounds |
| Hit marker | `HUD/HitMarker` | 32x32 |
| Cover warning "!" | `cover.gd` | 35x50 |
| Enemies | `main.gd` `ENEMY_LAYOUT` | 45x75 to 60x100 |
| Cover top edge | `Cover/Shield` | starts at y=224 (covers the bottom 65%, `coverage`) |

The HUD sticks to the screen edges, so on taller or wider screens the gap between edge-anchored pieces grows. Don't draw a full-screen HUD as one image. Draw it in pieces.

## 2. Where files go

```
art/                        <- repo root: .aseprite source files (not imported by Godot)
  ui/portrait.aseprite
prototype/assets/           <- exported PNGs that Godot uses
  ui/portrait.png
  ui/ammo_round.png
  enemies/...
  cover/...
  mockup/
```

Keep the same subfolder names in `art/` and `prototype/assets/` so every PNG has an obvious source. Use lowercase snake_case file names. Godot paths are case-sensitive on export.

## 3. Export from Aseprite

**Single image:** File > Export As > `.png`, scale **100%**.

**Animation:** File > Export Sprite Sheet
- Layout: *Horizontal Strip* (or *By Rows* for big ones)
- Output: check *Output File* (`.png`). Optionally check *JSON Data* with *Array* and *Tags* if you want frame timings later.
- Borders: padding 0 unless you see bleeding, then add 1px *Shape Padding*

**Command line** (handy for re-exporting everything at once; Aseprite is usually at `C:\Program Files\Aseprite\Aseprite.exe` or in your Steam folder):

```sh
# flattened PNG
aseprite -b art/ui/portrait.aseprite --save-as prototype/assets/ui/portrait.png

# animation as a horizontal sheet + frame data
aseprite -b art/ui/portrait.aseprite --sheet prototype/assets/ui/portrait_sheet.png \
  --sheet-type horizontal --data prototype/assets/ui/portrait_sheet.json --format json-array --list-tags

# one PNG per layer (e.g. a mockup split into pieces)
aseprite -b --split-layers art/ui/hud.aseprite --save-as "prototype/assets/ui/hud_{layer}.png"
```

## 4. Godot import settings (pixel art)

When Godot gets focus it imports new PNGs automatically. For crisp pixels:

- **Project-wide:** Default Texture Filter is already set to **Nearest** (Project Settings > Rendering > Textures > Canvas Textures), so nothing gets blurred.
- Per texture (Import dock, then *Reimport*): Mipmaps off, Compress Mode *Lossless*. Both are the defaults for 2D.
- Exporting the same file again overwrites the PNG, and Godot reimports it. Nodes that use it update without any re-linking.

> **Scaling.** The window opens as large as the screen allows and the game scales to fit exactly (`window/stretch/scale_mode = "fractional"`), e.g. about 1.27x on a 1080p monitor. At non-whole scales some art pixels come out 1px bigger than others, so the art is slightly uneven on screen; it is still drawn at 1x. With the `expand` aspect, leftover window space becomes extra visible area.
>
> **2.5D later.** 3D scenes render at the window's full resolution, so pixel-art 3D will need its own low-res pass: render the 3D world into a `SubViewport` at 360x780 (Nearest filter) and show it on screen. Then sprites, 3D and UI all share one pixel grid.

## 5. Using art in the UI

Swap placeholder nodes for textured ones. Keep the node names so `hud.gd` still finds them, or update the `@onready` paths.

| Need | Node | Notes |
| --- | --- | --- |
| Static picture (portrait, icon) | `TextureRect` | *Stretch Mode: Keep Centered* so it isn't scaled |
| Panel or button that resizes | `NinePatchRect` | Set *Patch Margins* to the border width you drew. In Aseprite, a Slice with *9-Slices* enabled shows you the margins |
| Several icons in one PNG | `AtlasTexture` | New AtlasTexture > Atlas = the sheet, Region = the icon's rect. Use it in any texture slot |
| Animated UI (portrait reactions) | `AnimatedSprite2D` or `TextureRect` + `AnimatedTexture` | SpriteFrames editor > *Add frames from sprite sheet*, then set H frames to the strip's frame count |
| HP bar / meters | `TextureProgressBar` | Under, progress and over textures |
| Pixel font | `Label` + `FontFile` | Drop a `.ttf` pixel font in `assets/fonts/`. In its import settings turn *Antialiasing* off and set the font size to the font's native size or a multiple of it |

### Example: portrait

Ali's HUD portrait is `spritework/UI/player_hurt_RECOVERED.aseprite`: 64x64, frame 1 idle, frame 2 hurt, frame 3 happy (the frame per state is `PORTRAIT_STATES` in `hud.gd`). After editing it, re-export the strip:

```
aseprite -b --ignore-layer _reference --ignore-layer _guides spritework/UI/player_hurt_RECOVERED.aseprite --sheet prototype/assets/ui/hud/portrait_ali.png --sheet-type horizontal
```

## 6. Git

- Commit both the `.aseprite` source and the exported `.png`. The `.import` files Godot creates next to PNGs should be committed too. The `.godot/` cache folder should not.
- `.aseprite` files are small binaries, so plain git is fine for now. Switch to Git LFS only if the art folder gets large.
