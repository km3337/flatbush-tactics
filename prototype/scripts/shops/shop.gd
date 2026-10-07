class_name FTShop
extends Resource

## A kind of shop for $ stops. Each $ station is given one when the stage is
## generated (from FTStageConfig.shops); the player finds out which on
## arrival. Stock is rolled when they walk in. Placeholder numbers; more
## variants are just more of these .tres files.

enum Sells { GEAR, AMMO }

@export var id: StringName = &""
@export var display_name := "Shop"
@export_multiline var greeting := ""
@export var sells := Sells.GEAR
## How many different items are on the shelf.
@export var stock_size := 3
## Price by rarity: [common, uncommon, rare].
@export var gear_prices := PackedInt32Array([35, 55, 80])
@export var round_prices := PackedInt32Array([15, 25, 40])
## Every shop sells a heal; buyable again while you're hurt.
@export var heal_name := "Chopped Cheese"
@export var heal_amount := 2
@export var heal_price := 10

func price_of(item: Resource) -> int:
	var prices := gear_prices if item is FTGear else round_prices
	return prices[clampi(item.rarity, 0, prices.size() - 1)]
