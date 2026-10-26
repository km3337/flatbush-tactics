class_name FTBiome
extends Resource

## Per-map data for a battle. The biome changes the background and how cover
## looks; cover always hides the battlefield the same way. Cover art is a
## placeholder rectangle.

@export var display_name := "Street"
## Battle backgrounds and their floor spawn positions; each battle picks one
## at random.
@export var backdrops: Array[FTBackdrop] = []
@export var cover_name := "Parked Car"
@export var cover_color := Color(0.16, 0.36, 0.86, 1)
