class_name FTGearEffect
extends FTEventEffect

## Give a gear: `gear` if set (skipped if already owned), else a random one
## from the event pool limited to `rarity` (-1 = any rarity).

@export var gear: FTGear
@export var rarity := -1

func apply() -> String:
	var got: FTGear = null
	if gear:
		if not Run.has_gear(gear.id):
			got = Run.add_gear(gear, FTGear.Source.EVENT)
	else:
		var options := Run.roll_gear_choices(FTGear.Source.EVENT, 99).filter(func(g: FTGear): return rarity < 0 or g.rarity == rarity)
		if not options.is_empty():
			got = Run.add_gear(options[0], FTGear.Source.EVENT)
	return "GEAR: %s" % got.display_name if got else ""
