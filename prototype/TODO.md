# Art & UI checklist

Placeholder art pass. Everything is drawn at 1x for the 360x780 base
resolution (see `assets/README.md`), with Nearest filtering.

## [x] Placeholder sprite for a basic enemy

Enemies with art draw an animated sprite (`FTEnemyType.sheet` +
`sheet_data`); the rest are still coloured rectangles.

- [x] Drawing template: `spritework/templates/enemy_template.aseprite`
      (64x128, lux2k palette, guides, hitbox slice with a feet pivot, tags
      for idle/windup/attack/hit/stunned/death/strafe). How to use it:
      `spritework/templates/ENEMY_TEMPLATE.md`.
- [x] Load enemy sheets (PNG + JSON) in `FTEnemy` instead of the rectangle.
- [x] Mutated Rat (replaces the Grunt): idle, windup, attack, hit drawn.
- [x] Stun: glitch shader on the sprite (no stun animation needed).
- [ ] Rat: death and strafe (fall back to fade / idle until drawn). Its
      first `stunned` frame is a copy of `hit`; the tag is ignored.
- [ ] Shared stun effect: `assets/fx/stun_fx.png` + `.json` (stars until then).
- [x] Placeholder art for Heavy (tentacle brain), Runner (spider) and Enforcer
      (carnivorous flower), cut from ripped Shin Megami Tensei sheets.
- [ ] **Replace the Shin Megami Tensei placeholders before any public
      release** (© Atlus; see `assets/enemies/PLACEHOLDER_CREDITS.md`).
- Enemies without windup frames tint orange while winding up.
- Enemy art draws at 2x (far slots) / 3x (near slots) for now; the 2.5D view
  will handle depth later.
## [ ] Better in-game UI (battle HUD)

- [ ] Portrait + HP pips + money (top left) restyled. Portrait (Ali) and HP bar done; money still placeholder text.
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

## [x] Find a good font

Nokia Cellphone FC (`assets/fonts/nokiafc22.ttf`, from fatorcaos.com.br) is
the project's default theme font, imported with antialiasing off, hinting
none and subpixel positioning off. It's drawn on an 8px grid (7px capitals),
so every text size is 8, 16, 24, 32, 40, 56 or 240.

- [ ] Symbols the font doesn't have fall back to a system font and look
      off: ● (enemy HP), ■ □ (player HP), ★ (stun), ▮ (ammo row), ✕ (hit
      marker). Draw these as sprites or shapes.
- [ ] Check the font's licence before shipping.
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
