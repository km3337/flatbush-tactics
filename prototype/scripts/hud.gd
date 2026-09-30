class_name FTHud
extends CanvasLayer

@onready var ammo_row: HBoxContainer = $AmmoRow
@onready var reload_label: Label = $ReloadLabel
@onready var hit_marker: Label = $HitMarker
@onready var damage_flash: ColorRect = $DamageFlash
@onready var hits_label: Label = $HitsLabel
@onready var counter_label: Label = $CounterLabel
@onready var portrait: ColorRect = $Portrait
@onready var portrait_label: Label = $Portrait/PortraitLabel
@onready var hp_pips: Label = $HPPips
@onready var down_label: Label = $DownLabel
@export var reaction_seconds := 0.6
@export var counter_hold_seconds := 0.8
@export var counter_fade_seconds := 0.4
var counter_tween: Tween
var hits_taken := 0
var blocked := 0
var bullet_nodes: Array[Label] = []
var reload_tween: Tween
var reaction_timer: SceneTreeTimer
var low_health := false

## Placeholder portrait states: [word, box colour].
const PORTRAIT_STATES := {
    "calm": ["CALM", Color(0.3, 0.35, 0.45)],
    "low": ["HURTING", Color(0.5, 0.12, 0.14)],
    "down": ["DOWN", Color(0.2, 0.2, 0.2)],
    "hit_enemy": ["NICE", Color(0.2, 0.55, 0.3)],
    "miss": ["MISSED", Color(0.4, 0.4, 0.4)],
    "counter": ["YEAH!", Color(0.8, 0.65, 0.1)],
    "kill": ["GOT 'EM", Color(0.85, 0.45, 0.1)],
    "got_hit": ["OUCH", Color(0.85, 0.15, 0.15)],
}

func setup_ammo(maximum: int) -> void:
    for child in ammo_row.get_children(): child.queue_free()
    bullet_nodes.clear()
    for i in maximum:
        var bullet := Label.new()
        bullet.text = "▮"
        bullet.add_theme_font_size_override("font_size", 34)
        bullet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ammo_row.add_child(bullet)
        bullet_nodes.append(bullet)

func update_ammo(current: int, maximum: int) -> void:
    if bullet_nodes.size() != maximum:
        setup_ammo(maximum)
    for i in bullet_nodes.size():
        var bullet := bullet_nodes[i]
        if i < current:
            bullet.visible = true
            bullet.modulate.a = 1.0
            bullet.position = Vector2.ZERO
        elif bullet.visible:
            _drop_bullet(bullet)

func _drop_bullet(bullet: Label) -> void:
    var start := bullet.position
    var tween := create_tween()
    tween.tween_property(bullet, "position", start + Vector2(7, -2), 0.035)
    tween.tween_property(bullet, "position", start + Vector2(-6, 2), 0.035)
    tween.tween_property(bullet, "position", start + Vector2(0, 72), 0.16).set_trans(Tween.TRANS_QUAD)
    tween.parallel().tween_property(bullet, "modulate:a", 0.0, 0.14)
    tween.tween_callback(func(): bullet.visible = false)

func show_reload() -> void:
    reload_label.visible = true
    if reload_tween: reload_tween.kill()
    reload_tween = create_tween().set_loops()
    reload_tween.tween_property(reload_label, "modulate:a", 0.15, 0.13)
    reload_tween.tween_property(reload_label, "modulate:a", 1.0, 0.13)

func hide_reload() -> void:
    if reload_tween: reload_tween.kill()
    reload_label.visible = false
    reload_label.modulate.a = 1.0

func show_shot_feedback(screen_position: Vector2) -> void:
    hit_marker.position = screen_position - hit_marker.size / 2.0
    hit_marker.visible = true
    hit_marker.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(hit_marker, "modulate:a", 0.0, 0.18)
    tween.tween_callback(func(): hit_marker.visible = false)

func show_player_hit() -> void:
    hits_taken += 1
    _update_hits_label()
    damage_flash.visible = true
    damage_flash.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_property(damage_flash, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func(): damage_flash.visible = false)

func show_blocked() -> void:
    blocked += 1
    _update_hits_label()

func _update_hits_label() -> void:
    hits_label.text = "HITS TAKEN: %d
BLOCKED BY COVER: %d" % [hits_taken, blocked]

func show_counter() -> void:
    if counter_tween: counter_tween.kill()
    counter_label.visible = true
    counter_label.modulate.a = 1.0
    counter_label.scale = Vector2(1.3, 1.3)
    counter_tween = create_tween()
    counter_tween.tween_property(counter_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    counter_tween.tween_interval(counter_hold_seconds)
    counter_tween.tween_property(counter_label, "modulate:a", 0.0, counter_fade_seconds)
    counter_tween.tween_callback(func(): counter_label.visible = false)

func update_health(current: int, maximum: int, is_low: bool) -> void:
    hp_pips.text = "■".repeat(current) + "□".repeat(maximum - current)
    low_health = is_low
    if reaction_timer == null:
        _set_portrait(_resting_state())

## Briefly show a reaction, then fall back to calm / low HP.
func react(state: String) -> void:
    _set_portrait(state)
    var timer := get_tree().create_timer(reaction_seconds)
    reaction_timer = timer
    await timer.timeout
    if reaction_timer == timer:
        reaction_timer = null
        _set_portrait(_resting_state())

func show_down() -> void:
    reaction_timer = null
    _set_portrait("down")
    down_label.visible = true

func _resting_state() -> String:
    return "low" if low_health else "calm"

func _set_portrait(state: String) -> void:
    # Once downed, the portrait stays on DOWN until the restart.
    if down_label.visible:
        return
    portrait_label.text = PORTRAIT_STATES[state][0]
    portrait.color = PORTRAIT_STATES[state][1]
