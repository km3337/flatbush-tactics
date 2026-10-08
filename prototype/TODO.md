# Art & UI checklist

Placeholder art pass. Everything is drawn at 1x for the 360x780 base
resolution (see `assets/README.md`), with Nearest filtering and integer
scaling only.

## [ ] Placeholder sprite for a basic enemy

Replace the coloured rectangles (`FTEnemy` is a `ColorRect` today).

- [x] Drawing template: `spritework/templates/enemy_template.aseprite`
      (64x128, lux2k palette, guides, hitbox slice with a feet pivot, tags
      for idle/windup/attack/hit/stunned/death/strafe). How to use it:
      `spritework/templates/ENEMY_TEMPLATE.md`.
- [ ] Load enemy sheets (PNG + JSON) in `FTEnemy` instead of the rectangle.

- [ ] Grunt sprite: idle pose.
- [ ] Wind-up tell: currently the whole rect turns orange; needs a readable
      pose/flash that still reads through the cover blur.
- [ ] Stunned look (stars already orbit the head) and a hit flash.
- [ ] Death (currently a 0.2s fade).
- [ ] Fit the spawn slots: far slots are 45x75, near slots up to 60x100.
      Pixel art can't scale down, so either one sprite per size or slots
      resized to the sprite.
- [ ] Heavy / Runner / Enforcer: recolours of the grunt for now?

Open: who draws it (a code-generated placeholder vs. Aseprite), and the
near/far sizing approach.

## [ ] Better in-game UI (battle HUD)

- [ ] Portrait + HP pips + money (top left) restyled.
- [ ] Gear row and gear pop-up.
- [ ] Ammo row (coloured rounds) + arsenal counter (bottom).
- [ ] Wave / ELITE label; CLEARED / DOWN / AMBUSH banners.
- [ ] Reward picker cards.
- [ ] Remove or hide the debug text (prototype title, HITS TAKEN / BLOCKED,
      key hints).
- [ ] Use the full 780px height (the battle still lays out for 640).

Open: style direction (match the SELECT LANCER pixel font? MTA signage?),
and what stays visible during a fight.

## [ ] Placeholder for the cover system

- [ ] Cover art for the bottom 65% (360x507), replacing the blue rectangle.
- [ ] One per biome: Parked Car (street), Support Pillar (subway platform),
      Seat Row (subway car). Only street is used in runs for now.
- [ ] The slide-in/out still works with an image.

Open: one biome first or all three; how much the art should show of the
player (hands, gun-fingers?).

## [ ] Find a good font

Every screen uses Godot's default smooth font at assorted sizes (9–26),
which clashes with the pixel art.

- [ ] Pick a pixel font: an existing one (m5x7, m6x11, Pixel Operator...)
      or draw one. In Aseprite, a white glyph grid can be imported as
      "Font Data (Image Font)" (fixed width), or use BitFontMaker2 for a
      variable-width .ttf.
- [ ] Set it as the project's default theme font, with antialiasing off,
      hinting none and subpixel positioning off.
- [ ] Replace the assorted font sizes with the font's native size and whole
      multiples of it (e.g. 8 / 16).
- Big titles (like SELECT LANCER) stay hand-drawn images.

## [ ] Low-colour sprites for basic gear

Gear icons are 20x20 inside the 24x24 rarity frame (`FTGear.icon`; HUD,
reward cards and shops already use it when set).

- [ ] Speed Loader
- [ ] Extended Mag
- [ ] Puffer Jacket
- [ ] Brass Knuckles
- [ ] Bodega Cat Charm
- [ ] Last Round
- [ ] Walkman
- [ ] Pilon Cannon (Ali's)

Open: palette (how many colours; shared palette across all icons?), and
whether ammo rounds (Burn, Toxic, Freeze, Thunder, Explosive) get icons too.
