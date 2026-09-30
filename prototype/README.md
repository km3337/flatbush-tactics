# Flatbush Tactics — Prototype 0.1

Godot 4 starter prototype for the 2.5D rail-shooter / RPG / roguelike concept.

## Implemented
- Click/tap anywhere to fire.
- Space (desktop) / swipe down (touch) ducks into cover and reloads.
- While in cover, a blue placeholder rectangle hides the whole battlefield except a thin strip at the top (`peek_height` on the Cover node), so no enemies are visible. Shooting is disabled; you're locked in cover for the reload, then press Space / swipe down again to leave.
- The biome (`biomes/*.tres`, `FTBiome` resource) only changes the cover's look: colour and name label (Street → Parked Car, Subway Platform → Support Pillar, Subway Car → Seat Row). Press B to cycle biomes while testing.
- Open battle-mechanic ideas are tracked in `BATTLE_NOTES.md`.
- Five placeholder enemies (red rectangles, two strafing) with 3 HP each; shoot them to kill, they respawn after 2.5s.
- Enemies turn orange to telegraph an attack, then fire. Out of cover you take a hit (red flash); in cover it's blocked. Hit/blocked counts are top-right.
- Player HP: 5 pips top-left next to a placeholder portrait (coloured box + word). The portrait reacts to hitting (NICE), missing (MISSED), countering (YEAH!), killing (GOT 'EM) and getting hit (OUCH), and shows HURTING at 2 HP or less. At 0 HP, DOWN shows and the battle restarts after 1.5s.
- Counter: shooting an enemy while it's orange shows COUNTER on the left. Staggerable enemies (far left, centre, right strafer) also get their attack cancelled and are stunned (grey, with ★ stars orbiting their head) for 1.5s.
- While in cover, a pulsing orange "!" is drawn on the cover over each enemy winding up an attack; it flashes red when the shot is blocked.
- Portrait mode (720x1280, 9:16; taller screens get extra space). Desktop window opens at 450x800.
- Six-round visual ammo row along the bottom.
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
