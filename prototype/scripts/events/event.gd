class_name FTEvent
extends Resource

## A `?` stop: some text and a few choices. Each choice rolls one of its
## weighted outcomes. Odds are never shown as numbers, so hint at risk in the
## writing. Events live in `events/*.tres` and are listed in the event pool.

@export var id: StringName = &""
@export var title := "Event"
@export_multiline var text := ""
@export var choices: Array[FTEventChoice] = []
## Relative chance of being picked for a ? stop.
@export var weight := 1.0
