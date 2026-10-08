class_name FTGear
extends Resource

## Passive run item (like a Slay the Spire relic). Subclasses override the
## hooks below; the run (`Run` autoload) calls them on every owned gear.
## Owned gear is a duplicate of the .tres, so per-run state (counters,
## once-per-battle flags) can live in plain vars on the subclass.
## Emit `triggered` whenever the gear visibly does something, so its HUD
## icon pulses.

signal triggered

enum Rarity { COMMON, UNCOMMON, RARE }
## Where this gear can come from. A gear can have several.
enum Source { START = 1, ELITE = 2, EVENT = 4 }

@export var id: StringName = &""
@export var display_name := "Gear"
@export_multiline var description := ""
@export var rarity := Rarity.COMMON
@export_flags("Start of run:1", "Elite:2", "Event:4") var sources := 7
## Placeholder icon: two letters on a coloured square, until `icon` is set.
@export var abbreviation := "GR"
@export var color := Color(0.3, 0.35, 0.45)
@export var icon: Texture2D

## Passive stat changes. Stats: &"magazine_size", &"reload_seconds",
## &"fire_cooldown", &"max_health", &"arsenal_capacity".
func modify_stat(_stat: StringName, value: float) -> float:
	return value

## Damage one shot deals to `enemy`. `countered` is true if it landed during
## the enemy's wind-up.
func modify_shot_damage(_battle: FTBattle, _enemy: FTEnemy, _countered: bool, damage: int) -> int:
	return damage

## Damage the player takes from one enemy shot that got past cover.
func modify_damage_taken(_battle: FTBattle, amount: int) -> int:
	return amount

func on_battle_start(_battle: FTBattle) -> void:
	pass

## After a shot lands on `enemy` (and its round's effect); it may be dead.
func on_shot_hit(_battle: FTBattle, _enemy: FTEnemy) -> void:
	pass

func on_counter(_battle: FTBattle, _enemy: FTEnemy) -> void:
	pass

func on_kill(_battle: FTBattle, _enemy: FTEnemy) -> void:
	pass
