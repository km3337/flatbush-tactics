# Event screen template

`event_screen_template.aseprite`: draw the `?` stop screens over the current
layout. The game uses your art as soon as it's exported.

## Canvas

- 360x780 (the game's base resolution), RGB, palette `lux2k.pal`.
- Six frames (tags), each with a screenshot of that screen as it looks now:
  - `churro_lady`, `delayed_train`, `lost_metrocard`, `subway_acrobat`,
    `traveling_poet`: one per event. The tag name is the event's `id`.
  - `outcome`: what the screen looks like after a choice, for reference.

## Layers (bottom to top)

- `_reference`: the screenshot, faded. Hide it or lower its opacity as you go.
- `background`: the whole screen behind everything. One drawing, shared by
  every frame. Used by the game.
- `art`: the event's picture, drawn inside `event_art`. Different on every
  frame. Used by the game.
- `ui`: for mocking up the header, panels and buttons. One drawing, shared by
  every frame. **Not used by the game yet.**
- `_labels`: outlines of each area below.

## Areas (named slices, View > Show Slices)

Measured from the running game at 360x780.

| Slice | Size | What it is now |
|---|---|---|
| `event_header` | 360x34 at (0, 70) | Stop name, HP, money |
| `event_art` | 320x130 at (20, 116) | The event's picture. Anything drawn outside it is cut off. |
| `event_title` | 320x30 at (20, 254) | Title, 16px text |
| `event_text` | 320x190 at (20, 290) | The event's text, 8px |
| `event_effects` | 320x90 at (20, 482) | After a choice: what changed |
| `choice_1..3` | 300x44 | Choice buttons. With 2 choices they fill the lower two; CONTINUE sits where `choice_3` is. |

The text, buttons and header bar are drawn by the game on top of `background`,
so leave those areas calm enough to read 8px white text. The 360x640 layout
sits at y 70–710; y 0–69 and y 711–779 are only yours to fill.

## Exporting

From the repo root (Steam's Aseprite is at
`C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe`):

```
aseprite -b spritework/templates/event_screen_template.aseprite --script spritework/tools/export_event_art.lua
```

It writes:

- `prototype/assets/events/<event id>.png`: the `art` layer of each frame,
  cropped to `event_art` (320x130).
- `prototype/assets/ui/event/background.png`: the `background` layer (360x780).

Empty layers are skipped, so events you haven't drawn keep the placeholder `?`
box. Open the project in Godot once so it imports the new files.

## New events

Add a frame, tag it with the event's `id`, and draw on `art`. Rebuilding the
template (`spritework/tools/make_event_template.lua`) is only for layout changes,
and it overwrites the file, so export or copy your drawings out first.
