# Battle mechanics — notes

Notes on battle systems that are planned but not built yet. The prototype only
implements the basics listed under "In the prototype now".

## Decided

- **Reload = cover.** Reloading (Space / swipe down) moves the player into cover.
- **Cover hides every enemy.** The cover fills almost the whole screen; a thin
  strip at the top stays visible so players can tell things are still happening.
- **Biome only changes the cover's look.** Cover works the same everywhere; the
  biome decides the visual (placeholder: blue shade + name label).
- **Locked in cover for the reload.** Once in cover, the player can't leave until
  their character's reload time has passed.
- **Reload differs per character.** Characters will have varying reload times
  and reload mechanics.
- **Gear can augment reloading.** Picked-up gear can modify reload behaviour.
- **Leaving cover.** Space (swipe down on touch) leaves cover once the reload
  lock ends. Tapping in cover does nothing.
- **Counters.** Hitting an enemy during its attack warning (wind-up) is a
  counter, and "COUNTER" shows on the left side of the screen, then fades.
  COUNTER shows for any enemy, but only certain enemies are staggerable.
- **Stagger.** A countered staggerable enemy has its attack cancelled and is
  stunned briefly (can't move or attack). A star animation rotates over its
  head while staggered.
- **Cover warnings.** While in cover, a warning icon shows over each attacking
  enemy's position during its wind-up, and flashes when the shot is blocked.
  Not shown out of cover (the enemy's own tell is visible then).
- **Player HP** is shown as pips at the top left, next to the player portrait.
  At 0 HP the battle restarts (prototype).
- **Portrait reactions.** The portrait reacts to hitting an enemy, missing,
  countering, killing an enemy, and getting hit, and changes at low HP.

## In the prototype now

- Single fixed reload time (`reload_seconds` on the Weapon node, 0.65s).
- After the reload finishes, the player stays in cover until they press Space /
  swipe down again.
- Stun lasts 1.5s (`stun_seconds` on FTEnemy); stunned enemies turn grey.
  COUNTER holds 0.8s then fades over 0.4s (on the HUD).
- Staggerable placeholder enemies: far left, centre, and the right-hand
  strafer. A countered non-staggerable enemy still fires.
- 5 HP, 1 damage per enemy shot; low HP at 2 or less (`max_health`,
  `low_health_threshold` on the Player node). Reactions last 0.6s; DOWN shows
  for 1.5s before the restart.
- Cover fully blocks enemy attacks.
- Placeholder enemies (shoot back, strafe, respawn) and a B debug key to cycle
  biomes, for testing only.

## Open questions

- Can the player enter cover without reloading (e.g. with a full magazine)?
- Does cover always block attacks completely, or can some attacks get through?
- What kinds of "reload mechanics" should vary between characters (beyond reload
  time)?
- Which reload/cover properties can gear modify, and how do effects stack?
- What should be visible in the top strip while in cover?
- Should a counter against a non-staggerable enemy do anything beyond showing
  COUNTER (bonus damage, cancel the attack, a resource)?
- How should players tell staggerable enemies apart?
- Do counters feed into anything else (score, gear triggers, combos)?
