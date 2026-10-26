# Placeholder enemy sprites

These sheets are cut from ripped Shin Megami Tensei sprites (© Atlus),
ripped by Deathbringer on The Spriters Resource. They're stand-ins while
prototyping. **Replace them before any public release.**

| File | Used by | Source sheet |
|---|---|---|
| `tentacle_brain.png/.json` | Heavy | Shin Megami Tensei If... (PSX), Amatsukami sheet, row 2 (5 frames) |
| `spider.png/.json` | Runner | Shin Megami Tensei II (PSX), Virus sheet, middle pair |
| `carnivorous_flower.png/.json` | Enforcer | Shin Megami Tensei II (PSX), Youju sheet, last pair |
| `metal_snake.png/.json` | Metal Snake | `spritework/rips/metal_snake.png` (source not yet noted) |
| `seeker.png/.json` | Seeker | `spritework/rips/seeker.png` (source not yet noted) |
| `dark_droid.png/.json`, `dark_droid_orb.png` | Dark Droid (boss) and its lob | Dark Elf P. Aqua, Mega Man Zero 3 (GBA, (c) Capcom), ripped by Don Andy, who asks for credit |

Each sheet has one `idle` tag (no windup frames, so these enemies tint orange
while winding up) and a `hitbox` slice around the sprite, with its feet as the
pivot. `mutated_rat.png/.json` is original art (Kristian).

The Metal Snake, Seeker and Dark Droid sheets (cut by `spritework/tools/cut_enemies2.gd`) have more tags: snake `idle`, `windup`, `attack`, `hit`, `emerge`, `burrow`; seeker `idle`, `windup` (glowing eye), `hit`, `death`; droid `idle`, `windup` (green charge glow). The two `spritework/rips` files for the snake and seeker are GIFs with a .png name; Godot can't read them, so the cutter uses the `.converted.png` copies next to them.
