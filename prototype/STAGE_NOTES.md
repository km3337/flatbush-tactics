# Stage traversal — notes

Plan and decisions for the map/route system. Phase 1 (generator) is built:
`scripts/stage/`, config in `stages/stage_1.tres`. To check every rule over
2000 seeds, run `tests/test_stage_generator.tscn` headless; the exit code is
the number of failures.

## Decided

- **Stage.** One level. 3 train lines of ~8 stops each, all ending at a shared
  **Last Stop** (boss). Generated at stage start from the run's seed.
- **Line select.** The stage opens on a simplified MTA-style map (coloured
  lines, route bullets, station dots, transfer dots). Picking a line locks in
  its stops.
- **Stop icons.** `?` random event, one sword = battle, two swords = elite,
  `$` = shop. Some stops are **hidden** and show a construction-cone marker
  until you reach them.
- **Lines are random mixes** of stop types within the rules below (no
  express/local identity).
- **Guarantees per line:** at least 1 shop, at least 1 elite, and the stop
  right before the Last Stop is never a fight (`?` or `$`).
- **Transfers.** 1–2 stations are shared by two lines at the same stop number.
  On arriving at one, before its encounter, the player chooses to stay or
  switch to the other line's remaining stops.
- **Detours.** About one per stage, pre-rolled on a hidden stop. Reaching it
  reveals a service change and inserts 1–2 forced `?` stops, then the player
  rejoins their line where they left it.
- **Between stops.** A route screen styled after the MTA countdown screens: one
  vertical line, current stop highlighted, icons beside stops, transfer bullets
  at transfer stations. Then the transit sequence (animation by Kristian
  later: objects past the subway window, MTA-style next-stop sign, doors open),
  then the encounter.
- **Scope.** Events (`?`) and shops (`$`, with money) get real systems, not
  placeholders.

## Proposed generation rules (tunable in a stage config .tres)

- Stop type weights: battle 45%, event 25%, elite 15%, shop 15%.
- First stop is a battle. No elite in the first 2 stops. No two shops in a row.
- Transfers never at the first stop or the Last Stop.
- A few hidden stops per line; detours only on hidden stops.
- Station names from a pool of Brooklyn/Flatbush-flavoured names.

## Flow

```
Line Select → Transit → Encounter → Route screen → Transit → … → Last Stop → Stage Clear
  at a transfer station (on arrival): stay / transfer, then its encounter
  at a detour stop: SERVICE CHANGE → inserted ? stops → back on the line
```

- Transit is a scene with a fixed contract, `play(next_station)` → `finished`,
  so the real animation can replace the placeholder (a red LED "Next Stop"
  sign and a doors-open beat).
- Battles take their encounter from the station (pools by tier and depth) and
  report a result instead of reloading the scene. HP carries between stops.
  Going down shows a run-over screen. The boss is a placeholder until designed.

## Build order

1. Stage generator + data, with tests over many seeds. **Done.**
2. Line Select map screen. **Done.** `scenes/LineSelect.tscn` is the game's
   first scene. The map runs bottom to top: route bullets and first stops
   at the bottom, the Last Stop at the top. Each line has its own start.
   Tap a line or its bullet (or press 1/2/3) to highlight it. Only the
   highlighted line shows station names, plus a summary of its stop types,
   unknown stops and transfers. BOARD THE X (or Enter) locks the line in.
   Transfers are drawn as a white bracket that arches over any line in
   between. Icons are drawn in code (`FTStageMapView._draw_icon`) until there
   is art.
   - The map is about 2 screens tall (150px between stops,
     `FTStageMapView.ROW_SPACING`), so it never fits on one screen. It opens on
     the Last Stop, holds for 1s, then glides down over 3s to the first stops;
     a tap or key skips the pan. After that the player scrolls (drag, mouse
     wheel, Up/Down or W/S) and taps any part of a line to select it.
     BOARD only works once the pan is over. The screen uses the full 360x780.
3. Run flow: route screen, transit placeholder, battles wired in, HP carry,
   transfers, detours, Last Stop, Stage Clear. **Done.** `Run` drives the
   screens: Line Select → Transit → stop → Route → Transit → … → Last Stop →
   Stage Clear (going down → Run Over → New Run).
   - Route screen (`scenes/Route.tscn`): countdown-screen style, with the
     current stop in a white pill, "Previous stops" chevrons, icons, transfer
     bullets, orange detour rows, and HP / gear / arsenal. NEXT STOP (or
     Space/Enter) leaves.
   - Transit (`scenes/Transit.tscn`): a placeholder window and LED "Next Stop"
     sign (blinking SERVICE CHANGE on detours), then doors opening; tap to
     skip. The contract for the real animation is at the top of
     `scripts/ui/transit.gd`. At a transfer station, the stay/transfer prompt
     appears here, before the encounter.
   - Detours trigger when you leave for the hidden station that holds one;
     its ? stops play first, then the station. Hidden stops reveal on arrival.
   - HP carries between stops (`Run.hp`), with no healing. Battles are always
     the street biome for now.
   - `?` and `$` stops open a placeholder (`scenes/StopPlaceholder.tscn`)
     until phases 4 and 5.
   - Winning saves a record to `user://records.json` (`FTRecords`): seed,
     freelancer, gear, arsenal, stops cleared, HP left.
4. Event system + sample events. **Done.**
   - Data: `FTEvent` (title, text, choices) → `FTEventChoice` (label,
     `requires_money`, weighted outcomes) → `FTEventOutcome` (text, effects).
     Effects in `scripts/events/effects/`: money (can't go below $0; if you
     can't cover it, you pay all you have), HP (damage never goes below 1 HP,
     so events can't end a run), +max HP (also heals), gear, round (the
     remove-a-round step if the arsenal is full), and ambush (extra enemies
     in the next battle's first wave, announced when that fight starts).
   - Odds are never shown; risk is hinted in the writing.
   - `events/*.tres`, listed in `events/event_pool.tres`. `Run.pick_event()`
     won't repeat an event until every event has been seen this run.
   - Event screen (`scenes/Event.tscn`): header with stop, HP and money; an
     art box; title and text; choice buttons (1/2/3), disabled with "NO
     CASH" when unaffordable; then the outcome text, coloured effect lines,
     and CONTINUE.
   - Money (placeholder numbers): start $20 (`FTFreelancer.starting_money`);
     battles pay $10–15 and elites $25–35 (`stages/stage_1.tres`). Shown on
     the battle HUD, on CLEARED and on the route screen.
   - New rare round: Explosive (1 splash damage to every enemy within 80px
     of the target). The Acrobat's pole seat can drop it, and it's also in the
     ammo reward pool at rare weight.
   - Events: Traveling Poet, Showtime (Subway Acrobat), Lost MetroCard,
     Train Traffic Ahead, Churro Lady. Kristian to review and rewrite.
5. Money + shops. **Done (placeholder).**
   - Shop kinds are `FTShop` resources in `shops/`. Each $ stop is assigned
     one at random when the stage is generated (`FTStageConfig.shops`), and
     the player finds out which on arrival. Two for now:
     - **Pawn Shop:** 3 gear from the elite/event pools (never signature gear
       or gear you own).
     - **Hardware Store:** 4 different ammo rounds. A bought round joins the
       arsenal; past capacity, the player removes one before leaving.
   - Prices by rarity (common/uncommon/rare): gear $35/$55/$80, rounds
     $15/$25/$40. Each item sells once.
   - Every shop sells a heal (Chopped Cheese: +2 HP for $10), buyable again
     while hurt.
   - Shop screen: `scenes/Shop.tscn`, laid out in the full 360x780 frame.
   - New shop variants = new `FTShop` .tres files added to the stage config.
     Variants that sell other things will need a new `Sells` value.

## Events as built

- **Traveling Poet.** Buy his book ($5–9 usually, $15–25 sometimes;
  sometimes the book also gives +1 max HP or a common gear), or ignore him
  (50% chance: +1 enemy in the next fight).
- **Showtime (Subway Acrobat).** Three seats. The door is safe. The middle
  always hurts (2–3 damage, never below 1 HP). The pole is a toss-up: 50%
  1 damage, 40% nothing, 10% the Explosive round. It can't end the run.
- **Lost MetroCard.** Pocket it ($10–20, or an ambush) or give it back
  (nothing, or a random round).
- **Train Traffic Ahead.** Wait (+1 HP) or walk the tracks ($10–25, or 1–2
  damage).
- **Churro Lady.** One churro ($1, +1 HP), the whole bag ($6, usually +3
  HP), or keep walking.
## Open questions

- Shop variants: which shops exist, and what each sells (names are placeholders).
- Tuning: money per fight, prices, heal cost.


- Last Stop boss design.
