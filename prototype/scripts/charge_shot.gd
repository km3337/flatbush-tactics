class_name FTChargeShot
extends Resource

## A freelancer's charge shot. Hold on one enemy for `charge_seconds` (the
## reticle glows yellow and the enemy gets a yellow lock-on), then release to
## fire. Sliding off the enemy resets it. It spends one round like any shot
## (its ammo effect and gear hit hooks apply, it can counter), with the base
## damage times `damage_multiplier`; `on_hit` adds the freelancer's own effect.
## Subclass per freelancer (scripts/charge_shots/).

@export var charge_seconds := 1.2
@export var damage_multiplier := 2
## Looped while charging.
@export var charge_sound: AudioStream

## Called after the charged shot hits `enemy` (which may have just died).
func on_hit(_battle: FTBattle, _enemy: FTEnemy) -> void:
	pass
