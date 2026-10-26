class_name FTFreelancer
extends Resource

## A playable character: who they are (shown on Freelancer Select), base
## stats, starting gear and starting arsenal. Gear modifies the stats through
## the stat hooks (magazine_size, reload_seconds, max_health,
## arsenal_capacity).

@export var display_name := "Freelancer"
## Fixed per freelancer; can't be changed during a run.
@export var weapon_name := ""
@export_multiline var bio := ""
## Tall select-screen portrait, drawn at `portrait_position` in the 360-wide
## select frame.
@export var portrait: Texture2D
@export var portrait_position := Vector2.ZERO
@export var max_health := 5
## Rounds loaded per reload.
@export var magazine_size := 5
@export var reload_seconds := 0.65
## Minimum time between shots.
@export var fire_cooldown := 0.4
## Played on every shot fired (not on dry fire).
@export var fire_sound: AudioStream
## Most rounds the arsenal can hold; past this, a pickup means removing one.
@export var arsenal_capacity := 20
@export var starting_money := 20
## Signature gear every run starts with. Null = a random common instead.
@export var starting_gear: FTGear
@export var starting_arsenal: Array[FTAmmoMod] = []
