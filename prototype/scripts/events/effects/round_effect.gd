class_name FTRoundEffect
extends FTEventEffect

## Add a round to the arsenal: `mod` if set, else a random ammo reward. If
## that puts the arsenal over capacity, the event screen asks which round to
## remove.

@export var mod: FTAmmoMod

func apply() -> String:
	var round_mod := mod
	if round_mod == null:
		var options := Run.roll_ammo_choices(1)
		if options.is_empty():
			return ""
		round_mod = options[0]
	Run.add_round(round_mod)
	return "ROUND: %s" % round_mod.display_name
