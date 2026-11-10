class_name FTHud
extends CanvasLayer

## Emitted by the reward picker: the chosen item, or null if skipped.
signal choice_made(item: Resource)

@onready var ammo_row: HBoxContainer = $AmmoRow
@onready var reload_sprite: TextureRect = $ReloadSprite
@onready var hit_marker: Label = $HitMarker
@onready var damage_flash: ColorRect = $DamageFlash
@onready var hits_label: Label = $HitsLabel
@onready var counter_label: Label = $CounterLabel
@onready var portrait: TextureRect = $Portrait
@onready var hp_bar: FTHpBar = $HPBar
@onready var down_label: Label = $DownLabel
@onready var cleared_label: Label = $ClearedLabel
@onready var gear_row: HBoxContainer = $GearRow
@onready var gear_info: Label = $GearInfo
@onready var choice_panel: Control = $RewardChoice
@onready var choice_cards: VBoxContainer = $RewardChoice/Cards
@onready var choice_title: Label = $RewardChoice/Cards/Title
@onready var arsenal_label: Label = $ArsenalLabel
@onready var money_label: Label = $MoneyLabel
@export var reaction_seconds := 0.6
@export var battle_start_seconds := 1.2
## Seconds the RELOAD sprite stays solid before it starts flashing.
@export var reload_nag_delay := 1.0
## One slow flash (fade out and back in).
@export var reload_flash_seconds := 1.0
var banner: TextureRect
@export var gear_info_seconds := 2.5
## Reward cards ignore input this long after appearing, so a tap meant for
## the last enemy can't pick one by accident.
@export var choice_lock_seconds := 0.4
@export var counter_hold_seconds := 0.8
@export var counter_fade_seconds := 0.4
var counter_tween: Tween
var hits_taken := 0
var blocked := 0
var bullet_nodes: Array[Label] = []
var bullet_tweens := {}  # Label -> drop Tween in progress
var reload_tween: Tween
var reaction_timer: SceneTreeTimer
var low_health := false
var gear_info_timer: SceneTreeTimer
## Reward screen (built on first use, inside RewardChoice).
var loadout: FTRewardLoadout
var cache: FTRewardCache
## Sparks, coins and flying icons, above the cards.
var fx_layer: Control
var cards: Array[FTRewardCard] = []
var choice_landing := Landing.NONE
## What taps on the reward screen do: &"cache" (shoot it), &"spin" (stop the
## reels), &"pick" (cards live), or &"" (animating; ignored).
var reward_phase := &""

## Gear icon border colour by rarity.
const RARITY_COLORS := {
    FTGear.Rarity.COMMON: Color(0.6, 0.6, 0.62),
    FTGear.Rarity.UNCOMMON: Color(0.3, 0.6, 1.0),
    FTGear.Rarity.RARE: Color(1.0, 0.8, 0.25),
}
const GEAR_ICON_SIZE := Vector2(24, 24)
const BATTLE_START_TEXTURE: Texture2D = preload("res://assets/ui/banners/battle_start.png")
const ENEMY_DELETED_TEXTURE: Texture2D = preload("res://assets/ui/banners/enemy_deleted.png")
const BATTLE_START_SFX: AudioStream = preload("res://assets/sfx/battle_start.mp3")
## Banners are drawn at a whole-number scale, centred on the screen.
const BANNER_SCALE := 2
const HIT_SPARK_SHEET: Texture2D = preload("res://assets/fx/hit_spark.png")
const HIT_SPARK_DATA: JSON = preload("res://assets/fx/hit_spark.json")
## Enemy shots landing (see assets/fx/PLACEHOLDER_CREDITS.md).
const IMPACT_SHEET: Texture2D = preload("res://assets/fx/attack_impact.png")
const IMPACT_DATA: JSON = preload("res://assets/fx/attack_impact.json")
const BITE_JAW: Texture2D = preload("res://assets/fx/attack_bite_jaw.png")
## Drawn at 2x, the same pixel size as enemies in the far slots.
const ATTACK_FX_SCALE := Vector2(2, 2)
## How far apart the jaws start (before scaling), and how long they take to
## snap shut.
const BITE_GAP := 22.0
const BITE_CLOSE_SECONDS := 0.1
const HURT_VIGNETTE_SHADER: Shader = preload("res://shaders/hurt_vignette.gdshader")
@export var hurt_flash_seconds := 0.3
@export var hurt_glow_seconds := 0.55
var hurt_glow: ColorRect

## Ali's portrait: a strip of 64x64 frames exported from
## spritework/UI/player_hurt_RECOVERED.aseprite (minus _reference/_guides).
const PORTRAIT_SHEET: Texture2D = preload("res://assets/ui/hud/portrait_ali.png")
const PORTRAIT_SIZE := Vector2(64, 64)
## Frame in the strip per state. idle = resting; hurt = low HP or downed;
## happy = a brief reaction to a counter or a kill.
const PORTRAIT_STATES := {
    "idle": 0,
    "hurt": 1,
    "happy": 2,
}
## Which battle events show a reaction (others leave the portrait alone).
const REACTIONS := {
    "counter": "happy",
    "kill": "happy",
}

func _ready() -> void:
    # Red edge glow when hit, drawn just above the full-screen damage flash.
    hurt_glow = ColorRect.new()
    hurt_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    hurt_glow.material = ShaderMaterial.new()
    hurt_glow.material.shader = HURT_VIGNETTE_SHADER
    hurt_glow.visible = false
    add_child(hurt_glow)
    move_child(hurt_glow, damage_flash.get_index() + 1)

func setup_ammo(maximum: int) -> void:
    for child in ammo_row.get_children(): child.queue_free()
    bullet_nodes.clear()
    for i in maximum:
        # Each round sits in a fixed slot so the row never re-lays out while a
        # spent round drops; the round animates freely inside its slot.
        var slot := Control.new()
        slot.custom_minimum_size = Vector2(16, 35)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var bullet := Label.new()
        bullet.text = "|"
        bullet.add_theme_font_size_override("font_size", 24)
        bullet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        bullet.size = slot.custom_minimum_size
        slot.add_child(bullet)
        ammo_row.add_child(slot)
        bullet_nodes.append(bullet)

## The rightmost loaded slot is the chambered round (magazine[0]), so a shot
## drops that slot and the other rounds keep their colours.
func update_ammo(magazine: Array[FTAmmoMod], maximum: int) -> void:
    if bullet_nodes.size() != maximum:
        setup_ammo(maximum)
    var current := magazine.size()
    for i in bullet_nodes.size():
        var bullet := bullet_nodes[i]
        if i < current:
            bullet.add_theme_color_override("font_color", magazine[current - 1 - i].color)
            if bullet_tweens.has(bullet):
                bullet_tweens[bullet].kill()
                bullet_tweens.erase(bullet)
            bullet.visible = true
            bullet.modulate.a = 1.0
            bullet.position = Vector2.ZERO
        elif bullet.visible and not bullet_tweens.has(bullet):
            _drop_bullet(bullet)

func update_arsenal(draw_count: int, discard_count: int) -> void:
    arsenal_label.text = "ARSENAL  %d LEFT  -  %d SPENT" % [draw_count, discard_count]

func _drop_bullet(bullet: Label) -> void:
    var tween := create_tween()
    bullet_tweens[bullet] = tween
    tween.tween_property(bullet, "position", Vector2(3.5, -1), 0.035)
    tween.tween_property(bullet, "position", Vector2(-3, 1), 0.035)
    tween.tween_property(bullet, "position", Vector2(0, 36), 0.16).set_trans(Tween.TRANS_QUAD)
    tween.parallel().tween_property(bullet, "modulate:a", 0.0, 0.14)
    tween.tween_callback(func(): bullet.visible = false)
    tween.finished.connect(func(): bullet_tweens.erase(bullet))

## Magazine empty: show the RELOAD sprite. It stays solid, and if the player
## still hasn't reloaded after `reload_nag_delay` it starts flashing slowly.
## Repeated empty clicks don't restart it.
func show_reload() -> void:
    if reload_sprite.visible:
        return
    reload_sprite.visible = true
    reload_sprite.modulate.a = 1.0
    if reload_tween: reload_tween.kill()
    reload_tween = create_tween()
    reload_tween.tween_interval(reload_nag_delay)
    reload_tween.tween_callback(_flash_reload)

func _flash_reload() -> void:
    reload_tween = create_tween().set_loops()
    reload_tween.tween_property(reload_sprite, "modulate:a", 0.15, reload_flash_seconds / 2.0).set_trans(Tween.TRANS_SINE)
    reload_tween.tween_property(reload_sprite, "modulate:a", 1.0, reload_flash_seconds / 2.0).set_trans(Tween.TRANS_SINE)

func hide_reload() -> void:
    if reload_tween: reload_tween.kill()
    reload_sprite.visible = false
    reload_sprite.modulate.a = 1.0

## A shot connected: play the hit spark (assets/fx/hit_spark) centred there.
func show_hit_effect(screen_position: Vector2) -> void:
    var sheet := FTSpriteSheet.load_sheet(HIT_SPARK_SHEET, HIT_SPARK_DATA)
    var spark := AnimatedSprite2D.new()
    spark.sprite_frames = sheet.frames
    spark.position = screen_position.round()
    add_child(spark)
    spark.play(&"default")
    # Untagged sheets loop, so remove it after one play-through.
    get_tree().create_timer(sheet.length(&"default")).timeout.connect(spark.queue_free)

## A shot missed: the old marker.
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
    tween.tween_property(damage_flash, "modulate:a", 0.0, hurt_flash_seconds)
    tween.tween_callback(func(): damage_flash.visible = false)
    hurt_glow.material.set_shader_parameter("size", hurt_glow.size)
    hurt_glow.visible = true
    hurt_glow.modulate.a = 1.0
    var glow := create_tween()
    glow.tween_property(hurt_glow, "modulate:a", 0.0, hurt_glow_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    glow.tween_callback(func(): hurt_glow.visible = false)

## An enemy's instant shot lands at `screen_position` (on the player, or on
## the pillar when blocked): an impact burst, or jaws snapping shut.
func show_attack_fx(kind: FTEnemyType.AttackFx, screen_position: Vector2) -> void:
    var at := screen_position.round()
    if kind == FTEnemyType.AttackFx.BITE:
        _play_bite(at)
        return
    var sheet := FTSpriteSheet.load_sheet(IMPACT_SHEET, IMPACT_DATA)
    var impact := AnimatedSprite2D.new()
    impact.sprite_frames = sheet.frames
    impact.position = at
    impact.scale = ATTACK_FX_SCALE
    add_child(impact)
    impact.play(&"default")
    get_tree().create_timer(sheet.length(&"default")).timeout.connect(impact.queue_free)

# Upper and lower jaw (the same row of fangs, flipped) slide shut, judder,
# then fade. Whole-pixel steps so they stay on the pixel grid.
func _play_bite(at: Vector2) -> void:
    var bite := Node2D.new()
    bite.position = at
    bite.scale = ATTACK_FX_SCALE
    add_child(bite)
    var jaws: Array[Sprite2D] = []
    for side in [-1.0, 1.0]:
        var jaw := Sprite2D.new()
        jaw.texture = BITE_JAW
        jaw.flip_v = side > 0.0
        jaw.offset = Vector2(0, side * BITE_JAW.get_height() / 2.0)
        jaw.position = Vector2(0, side * BITE_GAP)
        bite.add_child(jaw)
        jaws.append(jaw)
    var tween := create_tween()
    for jaw in jaws:
        tween.parallel().tween_property(jaw, "position:y", 0.0, BITE_CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    for x in [2.0, -2.0, 1.0, 0.0]:
        tween.tween_property(bite, "position:x", at.x + x, 0.03)
    tween.tween_property(bite, "modulate:a", 0.0, 0.15)
    tween.tween_callback(bite.queue_free)

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
    hp_bar.set_hp(current, maximum)
    low_health = is_low
    if reaction_timer == null:
        _set_portrait(_resting_state())

## A battle event ("counter", "kill", "miss"...). Events in REACTIONS show
## their portrait briefly, then it falls back to idle / hurt; the rest are
## ignored.
func react(event: String) -> void:
    if not REACTIONS.has(event):
        return
    _set_portrait(REACTIONS[event])
    var timer := get_tree().create_timer(reaction_seconds)
    reaction_timer = timer
    await timer.timeout
    if reaction_timer == timer:
        reaction_timer = null
        _set_portrait(_resting_state())

func show_down() -> void:
    reaction_timer = null
    _set_portrait("hurt")
    down_label.visible = true

## The fight is won: the ENEMY DELETED banner (stays until the next screen
## or the reward picker).
func show_cleared() -> void:
    react("kill")
    _show_banner(ENEMY_DELETED_TEXTURE)

## The fight opens: the BATTLE START banner for `battle_start_seconds`.
## Await it; the battle starts once it's gone.
func show_battle_start() -> void:
    _show_banner(BATTLE_START_TEXTURE)
    _play_sfx(BATTLE_START_SFX)
    await get_tree().create_timer(battle_start_seconds).timeout
    banner.visible = false

## Fire-and-forget sound: a one-off player that frees itself when done.
func _play_sfx(stream: AudioStream) -> void:
    var player := AudioStreamPlayer.new()
    player.stream = stream
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _show_banner(texture: Texture2D) -> void:
    if banner == null:
        banner = TextureRect.new()
        banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
        banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        banner.stretch_mode = TextureRect.STRETCH_SCALE
        add_child(banner)
    banner.texture = texture
    banner.size = texture.get_size() * BANNER_SCALE
    banner.position = ((get_viewport().get_visible_rect().size - banner.size) / 2.0).floor()
    banner.visible = true

func update_money(amount: int) -> void:
    money_label.text = "$%d" % amount

func set_gear(list: Array[FTGear]) -> void:
    for child in gear_row.get_children(): child.queue_free()
    for gear in list:
        add_gear(gear)

## One icon per owned gear, in pickup order: rarity-coloured border around the
## gear's icon (or placeholder letters). Hover shows a tooltip; click/tap shows
## the description. Pulses whenever the gear triggers.
func add_gear(gear: FTGear) -> void:
    var frame := _make_item_icon(gear)
    frame.tooltip_text = "%s\n%s" % [gear.display_name, gear.description]
    frame.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed:
            show_gear_info(gear))
    gear.triggered.connect(_pulse_gear.bind(frame))
    gear_row.add_child(frame)

func _make_item_icon(item: Resource) -> ColorRect:
    var frame := ColorRect.new()
    frame.custom_minimum_size = GEAR_ICON_SIZE
    frame.pivot_offset = GEAR_ICON_SIZE / 2.0
    frame.color = RARITY_COLORS[item.rarity]
    var inner_rect := Rect2(Vector2(2, 2), GEAR_ICON_SIZE - Vector2(4, 4))
    if item.icon:
        var art := TextureRect.new()
        art.texture = item.icon
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.position = inner_rect.position
        art.size = inner_rect.size
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(art)
    else:
        var fill := ColorRect.new()
        fill.color = item.color
        fill.position = inner_rect.position
        fill.size = inner_rect.size
        fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(fill)
        var letters := Label.new()
        letters.text = item.abbreviation
        letters.add_theme_font_size_override("font_size", 8)
        letters.add_theme_constant_override("outline_size", 3)
        letters.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
        letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        letters.position = inner_rect.position
        letters.size = inner_rect.size
        frame.add_child(letters)
    return frame

# --- Reward screen -----------------------------------------------------------
# After a fight, over the shut doors: a loadout strip at the top (wallet,
# gear, arsenal), a cache to shoot open, then reel cards to shoot one of.
# Picks fly into the loadout. See README "Reward screen".

## Where a picked card's icon flies to.
enum Landing { NONE, GEAR, AMMO, SCRAP }

## Starts the reward screen: dims the screen and shows the loadout with
## `start_money` in the wallet (coins from `open_cache` count it up).
func begin_rewards(start_money: int) -> void:
    if banner:
        banner.visible = false
    _ensure_reward_nodes()
    FTRewardSfx.prewarm()
    loadout.setup(Run.gear, Run.arsenal, Run.arsenal_capacity(), start_money, _make_item_icon)
    loadout.position = Vector2(roundf((choice_panel.size.x - loadout.size.x) / 2.0), 24)
    choice_cards.visible = false
    choice_panel.visible = true

## Drops the cache; the player shoots it `hits` times to open it. Its glow
## shows `rarity` (the best reward inside). `pay` comes out as coins that fly
## into the wallet. Await it: returns once the lid is off.
func open_cache(pay: int, rarity: FTGear.Rarity, hits := 3) -> void:
    if cache:
        cache.queue_free()
    cache = FTRewardCache.new()
    cache.rarity = rarity
    cache.hits_needed = hits
    choice_panel.add_child(cache)
    choice_panel.move_child(cache, fx_layer.get_index())
    var land := (choice_panel.size / 2.0 - cache.size / 2.0).round()
    await cache.drop_in(land)
    reward_phase = &"cache"
    await cache.opened
    reward_phase = &""
    _screen_flash(Color.WHITE, 0.5, 0.25)
    _spill_coins(pay, cache.global_position + cache.size / 2.0)
    # Let the beam fade before the cards fly out of it.
    await get_tree().create_timer(0.75).timeout

## Picker for rewards (gear, ammo) and for removing a round. `items` are
## FTGear or FTAmmoMod (anything with display_name, description, rarity,
## color, abbreviation, icon). Shoot (click/tap) a card or press its number;
## with `can_skip`, a Skip button (or S) picks nothing. Emits `choice_made`
## with the item, or null when skipped, once the pick has landed.
## `name_suffixes` adds text after a card's name (e.g. "x12"); `notes` adds a
## tag top-right ("NEW!"). With a `reel_pool`, each card spins through it like
## a slot reel before locking on its item (a tap stops them early).
## `landing` says where the picked item flies. Cards can't take keyboard
## focus, so Space (cover/reload) never picks one by accident.
func show_choice(items: Array, title: String, can_skip := false, name_suffixes: Array = [], reel_pool: Array = [], notes: Array = [], landing := Landing.NONE) -> void:
    _ensure_reward_nodes()
    if not choice_panel.visible:
        begin_rewards(Run.money)
    for child in choice_cards.get_children():
        if child != choice_title:
            choice_cards.remove_child(child)
            child.queue_free()
    cards.clear()
    choice_landing = landing
    choice_title.text = title
    choice_cards.visible = true
    for i in items.size():
        var suffix: String = name_suffixes[i] if i < name_suffixes.size() else ""
        var note: String = notes[i] if i < notes.size() else ""
        var card := FTRewardCard.new(items[i], i + 1, suffix, note, RARITY_COLORS)
        card.fx_parent = fx_layer
        card.pressed.connect(func(): _pick(card, card.global_position + card.get_local_mouse_position()))
        card.locked.connect(_on_card_locked.bind(card))
        if not reel_pool.is_empty():
            card.prepare_spin(reel_pool)
        choice_cards.add_child(card)
        cards.append(card)
    var skip: Button = null
    if can_skip:
        skip = Button.new()
        skip.text = "SKIP (S)"
        skip.name = "Skip"
        skip.focus_mode = Control.FOCUS_NONE
        skip.disabled = true
        skip.modulate.a = 0.0
        skip.custom_minimum_size = Vector2(300, 32)
        skip.add_theme_font_size_override("font_size", 8)
        skip.pressed.connect(_skip)
        choice_cards.add_child(skip)
    # Cards fly out of the cache (or the middle of the screen).
    choice_title.pivot_offset = choice_title.size / 2.0
    choice_title.scale = Vector2(1.5, 1.5)
    create_tween().tween_property(choice_title, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await get_tree().process_frame  # let the VBox place the cards
    var from := choice_panel.global_position + choice_panel.size / 2.0
    for i in cards.size():
        cards[i].fly_in(from, i * 0.07)
    FTRewardSfx.play(self, &"whoosh", 1.2, -12.0)
    if reel_pool.is_empty():
        await get_tree().create_timer(choice_lock_seconds).timeout
    else:
        await get_tree().create_timer(0.3).timeout
        reward_phase = &"spin"
        for i in cards.size():
            cards[i].spin(reel_pool, 0.5 + i * 0.4)
        while cards.any(func(c: FTRewardCard): return c.spinning):
            await get_tree().process_frame
        await get_tree().create_timer(0.15).timeout
    reward_phase = &"pick"
    for card in cards:
        card.disabled = false
    if skip:
        skip.disabled = false
        create_tween().tween_property(skip, "modulate:a", 1.0, 0.15)

func _ensure_reward_nodes() -> void:
    if fx_layer:
        return
    loadout = FTRewardLoadout.new()
    choice_panel.add_child(loadout)
    fx_layer = Control.new()
    fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
    fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    choice_panel.add_child(fx_layer)
    choice_panel.gui_input.connect(_on_reward_panel_input)

func _on_card_locked(card: FTRewardCard) -> void:
    if card.item.rarity == FTGear.Rarity.RARE:
        _screen_flash(RARITY_COLORS[FTGear.Rarity.RARE], 0.35, 0.3)

# Clicks/taps that land on the panel rather than a card.
func _on_reward_panel_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
        return
    var at: Vector2 = choice_panel.global_position + event.position
    match reward_phase:
        &"cache":
            _reward_shot(at, cache.get_global_rect().grow(28).has_point(at))
        &"spin":
            _fast_forward_reels()

func _fast_forward_reels() -> void:
    for card in cards:
        card.fast_forward = true

# A shot on the reward screen: the freelancer's shot sound and the reticle,
# a spark if it hit; on the cache phase, a hit cracks it.
func _reward_shot(at: Vector2, hit: bool) -> void:
    if Run.freelancer and Run.freelancer.fire_sound:
        _play_sfx(Run.freelancer.fire_sound)
    Reticle.fired()
    if not hit:
        return
    Reticle.hit_confirmed()
    show_hit_effect(at)
    if reward_phase == &"cache" and cache.hit():
        reward_phase = &""

func _pick(card: FTRewardCard, at: Vector2) -> void:
    if reward_phase != &"pick" or card.disabled:
        return
    reward_phase = &""
    _reward_shot(at, true)
    _dismiss_others(card)
    card.play_chosen()
    var item := card.item
    match choice_landing:
        Landing.GEAR, Landing.AMMO:
            var to := loadout.gear_target() if choice_landing == Landing.GEAR else loadout.ammo_target(item)
            await _fly_to_loadout(item, card.icon_center(), to)
        Landing.SCRAP:
            card.play_scrapped()
            FTRewardSfx.play(self, &"scrap")
            await get_tree().create_timer(0.2).timeout
            loadout.land_ammo(item, -1)
            loadout.show_caption("-1 %s ROUND" % item.display_name.to_upper(), Color8(232, 68, 68))
            await get_tree().create_timer(0.2).timeout
        _:
            await get_tree().create_timer(0.3).timeout
    _finish_choice(item)

func _skip() -> void:
    if reward_phase != &"pick":
        return
    reward_phase = &""
    _dismiss_others(null)
    FTRewardSfx.play(self, &"whoosh")
    await get_tree().create_timer(0.3).timeout
    _finish_choice(null)

func _dismiss_others(kept: FTRewardCard) -> void:
    var delay := 0.0
    for card in cards:
        if card != kept:
            card.play_dismissed(delay)
            delay += 0.04
    var skip := choice_cards.get_node_or_null("Skip")
    if skip:
        skip.disabled = true
        create_tween().tween_property(skip, "modulate:a", 0.0, 0.1)

func _finish_choice(item: Resource) -> void:
    choice_cards.visible = false
    choice_made.emit(item)

# The picked item's icon arcs from the card into the loadout, trailing
# sparkles, and lands with a pop.
func _fly_to_loadout(item: Resource, from: Vector2, to: Vector2) -> void:
    var icon := _make_item_icon(item)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.scale = Vector2(1.5, 1.5)
    fx_layer.add_child(icon)
    var color: Color = RARITY_COLORS[item.rarity]
    var bend := (from + to) / 2.0 + Vector2(randf_range(-60.0, 60.0), -90.0)
    var step := 0
    var move := func(t: float):
        var p := from.lerp(bend, t).lerp(bend.lerp(to, t), t)
        icon.position = (p - GEAR_ICON_SIZE / 2.0).round()
        step += 1
        if step % 2 == 0:
            FTRewardBurst.spawn(fx_layer, p, [color, Color.WHITE], 2, Vector2(0, 25), 0.3, Vector2.DOWN, TAU, 2.0, 0.0)
    move.call(0.0)
    FTRewardSfx.play(self, &"whoosh", 1.4, -12.0)
    var tween := create_tween().set_parallel()
    tween.tween_method(move, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(icon, "scale", Vector2.ONE, 0.45)
    await tween.finished
    icon.queue_free()
    FTRewardSfx.play(self, &"pickup")
    FTRewardBurst.spawn(fx_layer, to, [color, Color.WHITE, RARITY_COLORS[FTGear.Rarity.RARE]], 18, Vector2(50, 140), 0.5)
    if item is FTGear:
        loadout.land_gear(item)
        loadout.show_caption("GOT %s" % item.display_name.to_upper(), color)
    else:
        loadout.land_ammo(item, 1)
        loadout.show_caption("+1 %s ROUND" % item.display_name.to_upper(), color)
    await get_tree().create_timer(0.25).timeout

# Coins burst out of the cache and home in on the wallet one by one; each
# one counts the wallet up.
func _spill_coins(pay: int, from: Vector2) -> void:
    if pay <= 0:
        return
    var count := clampi(pay / 2, 5, 14)
    for i in count:
        var value := pay / count + (1 if i < pay % count else 0)
        _fly_coin(from, value, i * 0.05, i)

func _fly_coin(from: Vector2, value: int, delay: float, index: int) -> void:
    var coin := Control.new()
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coin.draw.connect(func():
        coin.draw_rect(Rect2(-3, -4, 6, 8), Color8(37, 19, 26))
        coin.draw_rect(Rect2(-4, -3, 8, 6), Color8(37, 19, 26))
        coin.draw_rect(Rect2(-2, -3, 4, 6), Color8(255, 213, 105))
        coin.draw_rect(Rect2(-3, -2, 6, 4), Color8(255, 213, 105))
        coin.draw_rect(Rect2(-1, -2, 1, 4), Color8(209, 133, 30)))
    coin.position = from
    fx_layer.add_child(coin)
    var to := loadout.wallet_target()
    var bend := from + Vector2(randf_range(-110.0, 110.0), randf_range(-150.0, -60.0))
    var move := func(t: float):
        coin.position = from.lerp(bend, t).lerp(bend.lerp(to, t), t).round()
        coin.scale.x = 0.5 if int(t * 12.0) % 3 == 1 else 1.0  # spinning
    var tween := create_tween()
    tween.tween_interval(delay)
    tween.tween_method(move, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    await tween.finished
    coin.queue_free()
    loadout.add_money(value)
    FTRewardSfx.play(self, &"coin", 1.0 + index * 0.03, -13.0)
    FTRewardBurst.spawn(fx_layer, to, [Color8(255, 213, 105), Color.WHITE], 4, Vector2(30, 80), 0.3)

func _screen_flash(color: Color, alpha: float, seconds: float) -> void:
    var flash := ColorRect.new()
    flash.color = Color(color, alpha)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    fx_layer.add_child(flash)
    var tween := create_tween()
    tween.tween_property(flash, "modulate:a", 0.0, seconds)
    tween.tween_callback(flash.queue_free)

func _unhandled_input(event: InputEvent) -> void:
    if not choice_panel.visible or not (event is InputEventKey and event.pressed and not event.echo):
        return
    var key: int = event.physical_keycode
    var shoot_key := key == KEY_ENTER or key == KEY_KP_ENTER or (key >= KEY_1 and key <= KEY_9)
    match reward_phase:
        &"cache":
            if shoot_key:
                get_viewport().set_input_as_handled()
                _reward_shot(cache.global_position + cache.size / 2.0 + Vector2(randf_range(-20, 20), randf_range(-10, 10)), true)
        &"spin":
            if shoot_key or key == KEY_S:
                get_viewport().set_input_as_handled()
                _fast_forward_reels()
        &"pick":
            if key == KEY_S and choice_cards.get_node_or_null("Skip"):
                get_viewport().set_input_as_handled()
                _skip()
            elif key >= KEY_1 and key - KEY_1 < cards.size():
                get_viewport().set_input_as_handled()
                var card: FTRewardCard = cards[key - KEY_1]
                _pick(card, card.icon_center())


## Shows a gear's or round's name and description under the gear row for a moment.
func show_gear_info(gear: Resource, header := "") -> void:
    show_info_text(header, "%s: %s" % [gear.display_name.to_upper(), gear.description])

## The same pop-up for any message, e.g. an ambush warning.
func show_info_text(header: String, text: String) -> void:
    gear_info.text = "%s\n%s" % [header, text] if header else text
    gear_info.visible = true
    var timer := get_tree().create_timer(gear_info_seconds)
    gear_info_timer = timer
    await timer.timeout
    if gear_info_timer == timer:
        gear_info.visible = false

func _pulse_gear(frame: Control) -> void:
    frame.scale = Vector2(1.5, 1.5)
    frame.modulate = Color(2, 2, 2)
    var tween := create_tween().set_parallel()
    tween.tween_property(frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(frame, "modulate", Color.WHITE, 0.25)

func _resting_state() -> String:
    return "hurt" if low_health else "idle"

func _set_portrait(state: String) -> void:
    # Once downed, the portrait stays on hurt until the restart.
    if down_label.visible:
        return
    var frame := AtlasTexture.new()
    frame.atlas = PORTRAIT_SHEET
    frame.region = Rect2(Vector2(PORTRAIT_STATES[state] * PORTRAIT_SIZE.x, 0), PORTRAIT_SIZE)
    portrait.texture = frame
