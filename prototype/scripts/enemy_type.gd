class_name FTEnemyType
extends Resource

## Stats and behaviour for one kind of enemy. Where it stands comes from the
## spawn slot, not from here. Telegraph colours (wind-up, stun) live on FTEnemy
## so every enemy reads the same way.

@export var display_name := "Grunt"
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
