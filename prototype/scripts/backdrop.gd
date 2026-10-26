class_name FTBackdrop
extends Resource

## One battle background and where walking enemies stand in it. The texture
## is drawn at 2x, centred on the screen (made with
## spritework/tools/pixelate_backgrounds.gd).

@export var texture: Texture2D
## Floor positions for walkers, by slot name, in battlefield coordinates
## (360x640, like FTEncounterDirector.slots): feet go on the rect's
## bottom-centre, so the bottom edge sits on this photo's floor. Slots left
## out fall back to the director's default (mid-air) position. Floaters always
## use the director's positions.
@export var ground_slots: Dictionary[StringName, Rect2] = {}
