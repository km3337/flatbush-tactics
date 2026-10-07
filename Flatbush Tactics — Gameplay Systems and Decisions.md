# Flatbush Tactics — Gameplay Systems and Decisions

## Working design record

# Core premise

Flatbush Tactics combines a route-based roguelike structure inspired by Slay the Spire with a cover-and-shoot battle loop inspired by Time Crisis. A freelancer chooses a train line, survives encounters along its stops, and reaches a destination. The first destination is “The Last Stop,” which triggers a boss battle.

# Run loop

1\. Select a freelancer and a train line. Selecting a line commits the player to its route tree rather than letting them pick every stop.  
2\. Travel to the next stop and resolve its encounter: battle, choice-based random event, or bodega/store rest area.  
3\. Carry health, money, gear, and other run effects forward. Some events cause a detour or transfer that changes the remaining route.  
4\. Reach the destination and defeat its boss. A run ends on victory or defeat; freelancers lose all collected gear either way.

# Map and routes

The map should read as a simplified NYC MTA map: recognizable colored lines, station dots, shared transfer points, and a clear destination. Each line is a committed sequence or tree of stops. Encounters are selected randomly for stops. Transfers and detours can redirect the player to a different route; their exact frequency and degree of player choice remain open.  
A useful implementation model is a graph of station nodes and line connections, with an encounter assigned to each visited stop. The proposed approach is to generate a coherent route network at run start and reveal encounters as appropriate. This is a design proposal, not a locked decision.  
Stage decisions (see prototype/STAGE_NOTES.md): a stage offers 3 lines of about 8 stops, which all end at a shared Last Stop. Stops mix randomly, but every line has at least one shop and one elite, and the stop before the Last Stop is never a fight. Some stops are hidden behind a construction-cone marker. Players can switch lines at 1–2 transfer stations, choosing on arrival. About one detour per stage sits on a hidden stop and inserts 1–2 forced random events before the player rejoins their line. Between stops, a route screen in the style of the MTA countdown screens leads into the transit sequence.

# Encounter types

Battle — a real-time, touch/click aiming encounter with shooting, cover, and reload timing. The existing prototype has shooting and reload mechanics. The proposed extension ties reloading to moving into cover by swipe on mobile or Space on keyboard; cover helps avoid attacks while reducing visibility of enemies.  
Random event — a choice with consequences, potentially affecting resources, gear, an upcoming fight, or the route. Some events trigger a detour or transfer.  
Bodega/store rest area — a stop that gives the player a breather and access to purchases or recovery. Bodegas have different variants; their exact inventories, services, and rarity are still to be designed.

# Bosses and destination

“The Last Stop” is the first destination and ends in a boss battle. Bosses are tougher than regular enemies. They require players to observe clues, solve a small combat puzzle, and time an action to make the boss vulnerable. The specific first boss, tells, vulnerability condition, and escalation pattern are still open.

# Gear

Gear is the relic-like system: small stylistic pieces with passive effects that vary by rarity. Gear is unlocked and found during a run. Gear comes from exactly three sources: elite fights, certain events/encounters, and the start of each run. Owned gear is shown in the battle UI. It is temporary: a freelancer loses all gear when a run ends, including after a win. The game records which gear was used to win a run.  
Design direction, not yet decided: emphasize effects that change cover, reload, aiming, or timing choices; keep even common gear interesting. The exact rarity tiers, acquisition sources, stacking rules, and whether an in-run discovery changes the gear pool in later runs remain open.

# Arsenal and ammo modifiers

Every freelancer has an arsenal of rounds. Reloads draw rounds from it at random like a deck: a draw pile and a discard pile, with a reshuffle when the draw pile runs out. Unfired rounds stay in the magazine and the reload tops it up. The first freelancer has a 5-round magazine and a 20-round arsenal capacity, and starts each run with 12 plain rounds plus 1 freeze round. After every fight, regular or elite, the player picks 1 of 3 ammo modifiers or skips. A pickup adds a round, and once the arsenal is over capacity the player removes one. Modifiers include burn, toxic, freeze and thunder, which spreads attacks on hit. The loaded rounds are always visible. Some modifiers will carry over between runs; which ones, and how, is still open.

# Meta progression

Current direction: unlock additional freelancers and eventually add mechanics or gear that can be encountered. Permanent stat boosts are not part of the current decision. Persistent records can track victories and winning gear combinations without carrying equipped gear into another run. The precise unlock conditions and the meaning of a permanent gear-pool unlock still need definition.

# Decided versus open

Decided: line selection commits the route; stops have randomized encounters; encounter categories are battle, choice event, and bodega variant; events may cause detours/transfers; the first destination is The Last Stop; its boss has a timing/puzzle vulnerability; gear is passive, rarity-based, run-only, and winning gear is recorded.  
Open: run length and map scale; what route information is visible before selection; how transfers are triggered or chosen; resource economy and encounter rewards; bodega services; boss design; gear rarity and pool rules; freelancer differences; meta unlock conditions; whether additional destinations appear after The Last Stop.

# First playable slice (proposal)

One freelancer, two selectable lines, a shared transfer, a few battles and events, two bodega variants, one forced detour, a small gear pool, and one boss with a readable vulnerability cycle. This scope would test whether route commitment, cover/reload combat, and detours feel satisfying together.  
