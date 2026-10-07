class_name FTLine
extends Resource

## One train line on a stage map: a route bullet and its stops in order. The
## last entry in `stations` is the stage's shared Last Stop.

@export var bullet := "Q"
@export var color := Color(0.99, 0.8, 0.04)
## Bullet text colour (dark on light lines like the yellow Q).
@export var text_color := Color.BLACK
@export var stations: Array[FTStation] = []

## Stops before the Last Stop.
func length() -> int:
	return stations.size() - 1
