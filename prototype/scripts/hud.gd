class_name FTHud
extends CanvasLayer

@onready var ammo_column: VBoxContainer = $AmmoColumn
@onready var reload_label: Label = $ReloadLabel
@onready var hit_marker: Label = $HitMarker
var bullet_nodes: Array[Label] = []
var reload_tween: Tween

func setup_ammo(maximum: int) -> void:
    for child in ammo_column.get_children(): child.queue_free()
    bullet_nodes.clear()
    for i in maximum:
        var bullet := Label.new()
        bullet.text = "▰"
        bullet.add_theme_font_size_override("font_size", 34)
        bullet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ammo_column.add_child(bullet)
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
