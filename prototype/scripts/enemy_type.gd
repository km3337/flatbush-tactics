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
@export var entrance := Entrance.NONE
@export var attack := Attack.SHOT
@export var lob_seconds := 1.5
@export var lob_damage := 2
@export var max_health := 3
@export var attack_interval := Vector2(2.5, 5.0)
@export var windup_seconds := 0.7
## Countering a staggerable enemy cancels its attack and stuns it.
@export var staggerable := false
@export var stun_seconds := 1.5
## Horizontal patrol distance in pixels; 0 stands still.
@export var sway := 0.0
@export var sway_speed := 1.2
@export var base_color := Color(0.82, 0.18, 0.2)
## Art: an Aseprite export (sheet + JSON with tags and a "hitbox" slice; see
## spritework/templates/ENEMY_TEMPLATE.md). Without it the enemy is a
## `base_color` rectangle.
@export var sheet: Texture2D
@export var sheet_data: JSON
