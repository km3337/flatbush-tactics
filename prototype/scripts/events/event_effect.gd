class_name FTEventEffect
extends Resource

## Something an event outcome does to the run. Subclasses in
## `scripts/events/effects/` override `apply`, change `Run`, and return a
## short line for the result screen ("" for nothing to show).

func apply() -> String:
	return ""
