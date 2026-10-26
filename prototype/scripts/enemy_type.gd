class_name FTEnemyType
extends Resource

## Stats and behaviour for one kind of enemy. Where it stands comes from the
## spawn slot, not from here. Telegraph colours (wind-up, stun) live on FTEnemy
## so every enemy reads the same way.

## How it arrives: WOBBLE grows in from the back, waddling into its slot;
## DIGITIZE builds in place line by line like a monitor drawing it. It can't
## be shot or attack until it has arrived.
enum Entrance { NONE, WOBBLE, DIGITIZE }

## SHOT: an instant attack that cover blocks. LOB: a projectile arcs toward
## the player over `lob_seconds`; one shot pops it, and if it lands it deals
## `lob_damage` even behind cover.
enum Attack { SHOT, LOB }

@export var display_name := "Grunt"
## Floaters use the director's mid-air slot positions; everything else
## stands on the floor of the current backdrop (FTBackdrop.ground_slots).
@export var floats := false
@export var entrance := Entrance.NONE
@export var attack := Attack.SHOT
@export var lob_seconds := 1.5
@export var lob_damage := 2
## Charged lob: instead of circling, the projectile sits in front of the
## enemy and swells over the wind-up.
@export var lob_charge := false
## Size multiplier for the projectile (circling/charging and in flight).
@export var lob_size := 1.0
@export var lob_color := Color(0.95, 0.45, 0.62)
## Optional art for the projectile: a horizontal strip of square frames,
## drawn at the projectile's size and looped at `lob_fps` (else a blob of
## `lob_color` drawn in code).
@export var lob_sheet: Texture2D
@export var lob_sheet_frames := 1
@export var lob_fps := 12.0
## Whether a thrown projectile can still be shot down in flight.
@export var lob_shootable_in_flight := true
## Hits during one wind-up (on the enemy, or on its circling/charging
## projectile) that cancel the attack. 0 = the old rule: staggerable enemies
## are cancelled by one hit, others fire anyway.
@export var counter_hits := 0
@export var max_health := 3
@export var attack_interval := Vector2(2.5, 5.0)
@export var windup_seconds := 0.7
## Countering a staggerable enemy cancels its attack and stuns it.
@export var staggerable := false
@export var stun_seconds := 1.5
## Horizontal patrol distance in pixels; 0 stands still.
@export var sway := 0.0
@export var sway_speed := 1.2
## Slow hover along a U-shaped arc: `arc_size.x` pixels either side of its
## slot, rising `arc_size.y` at the ends. (0, 0) = no arc.
@export var arc_size := Vector2.ZERO
## Radians per second along the arc (one full swing = TAU / arc_speed s).
@export var arc_speed := 0.5
## Burrow-hop: rises out of the ground (its entrance), attacks once, sinks,
## stays underground (unhittable) for `burrow_seconds`, then rises again in a
## free floor slot elsewhere. Sheet tags: emerge, burrow (else it stretches
## up out of / squashes into the floor).
@export var burrows := false
@export var burrow_seconds := 1.2
## Tint during the wind-up (used when the sheet has no windup animation, or
## always when `windup_flash` is on).
@export var windup_tint := Color(1.0, 0.6, 0.25)
## Blink the wind-up tint on and off instead of holding it.
@export var windup_flash := false
## Summoner: once its health is at or below `summon_below_health` (share of
## max), it keeps `summon_count` of `summon_type` alive, replacing each one
## `summon_refill_seconds` after it dies. Summons take free slots.
@export var summon_type: FTEnemyType
@export var summon_count := 0
@export var summon_below_health := 0.5
@export var summon_refill_seconds := 4.0
@export var base_color := Color(0.82, 0.18, 0.2)
## Art: an Aseprite export (sheet + JSON with tags and a "hitbox" slice; see
## spritework/templates/ENEMY_TEMPLATE.md). Without it the enemy is a
## `base_color` rectangle.
@export var sheet: Texture2D
@export var sheet_data: JSON
