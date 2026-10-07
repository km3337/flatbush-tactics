class_name FTStation
extends Resource

## One stop on a stage map. A transfer station is the same FTStation object in
## two lines' `stations` arrays (at the same depth); `line_indices` lists them.

enum Kind { BATTLE, ELITE, EVENT, SHOP, LAST_STOP }

const KIND_ICONS := {
	Kind.BATTLE: "⚔",
	Kind.ELITE: "⚔⚔",
	Kind.EVENT: "?",
	Kind.SHOP: "$",
	Kind.LAST_STOP: "■",
}

@export var display_name := ""
@export var kind := Kind.BATTLE
## Stops from the start of the line (0 = first stop). The Last Stop's depth
## is the line length.
@export var depth := 0
## Lines (by index in the stage map) this station is on. Two = transfer.
@export var line_indices: Array[int] = []
## Shown with a construction cone until the player arrives.
@export var hidden := false
## Forced ? stops played on the way into this station (a detour). Empty = none.
## Only ever on a hidden station.
@export var detour_stops: Array[FTStation] = []
## Fight to play here (battle, elite, Last Stop). Null for events and shops.
@export var encounter: FTEncounter
## Which shop a $ stop is (gear, ammo, ...). Revealed on arrival.
@export var shop: FTShop

func is_transfer() -> bool:
	return line_indices.size() > 1

func has_detour() -> bool:
	return not detour_stops.is_empty()

func is_fight() -> bool:
	return kind in [Kind.BATTLE, Kind.ELITE, Kind.LAST_STOP]

func icon() -> String:
	return KIND_ICONS[kind]
