class_name FTStageConfig
extends Resource

## Tunable rules for generating a stage. See STAGE_NOTES.md.

@export_group("Shape")
@export var line_count := 3
## Stops per line before the Last Stop.
@export var stops_per_line := 8
@export var transfer_count := Vector2i(1, 2)
@export var hidden_per_line := Vector2i(1, 2)
@export var detour_count := 1
@export var detour_length := Vector2i(1, 2)

@export_group("Stop weights")
@export var battle_weight := 45.0
@export var event_weight := 25.0
@export var elite_weight := 15.0
@export var shop_weight := 15.0
## No elite before this depth (0-based): 2 = never the first two stops.
@export var first_elite_depth := 2

@export_group("Money")
## Paid when a fight is cleared (placeholder numbers; tune with shops).
@export var battle_money := Vector2i(10, 15)
@export var elite_money := Vector2i(25, 35)

@export_group("Content")
## Enemy added to a battle's first wave per event ambush.
@export var ambush_enemy: FTEnemyType
@export var battle_encounters: Array[FTEncounter] = []
@export var elite_encounters: Array[FTEncounter] = []
## Shop kinds a $ stop can be, picked at random per stop.
@export var shops: Array[FTShop] = []
## Placeholder until the boss is designed.
@export var last_stop_encounter: FTEncounter
@export var last_stop_name := "Last Stop"
## Route bullets to draw from: "label|#line_colour|#text_colour".
@export var bullets: PackedStringArray = []
## Station names to draw from; needs at least one per stop on the map.
@export var station_names: PackedStringArray = []
