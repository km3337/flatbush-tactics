# Flatbush Tactics — Prototype 0.1

Godot 4 starter prototype for the 2.5D rail-shooter / RPG / roguelike concept.

## Implemented
- Click/tap anywhere to fire.
- Tab to reload on desktop.
- Swipe down to reload on touch.
- Six-round visual ammo stack on the right side.
- Each spent round jerks/shakes, drops, and fades individually.
- RELOAD flashes when the magazine reaches zero.
- Temporary tap/click hit marker.
- Input, weapon state, and HUD are separated so rail movement and RPG systems can be added independently.

## Next vertical-slice steps
1. 2.5D rail/path camera and test street scene.
2. Raycast hit detection against enemy hit zones.
3. Enemy entrance/attack timeline and damage to player.
4. Weapon recoil, screen shake, audio hooks, and reload animation.
5. Encounter director + first roguelike perk selection.

The supplied `assets/mockup/mockup.png` is retained as the UI/art-direction reference.
