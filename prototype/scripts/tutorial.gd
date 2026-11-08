class_name FTTutorial
extends Node

## First-time training, run inside the battle scene (FTBattle) instead of an
## encounter. Five gated lessons, each waiting until the player actually does
## the move: shoot, reload (flick into cover), dodge a wind-up, shoot down a
## lob, counter. After the reload lesson the magazine is quietly topped up
## before each step, so a step never stalls on an empty gun. The tutorial places its own enemies, holds their attacks
## back and cues each wind-up itself, in slow motion while the prompt is up.
## Nothing deals damage; a missed move just replays the step.
## Prompts are a banner over the bottom band (where the battle's key hints
## normally are) plus a pointing hand (FTGestureHand). SKIP (top right) ends
## it at any point. Starts after Freelancer Select on a first run, or from
## TRAINING on the title screen (Run.start_tutorial).

## Game speed while a prompt waits on a wind-up or a lob.
const SLOW_SCALE := 0.2
const RAT: FTEnemyType = preload("res://enemies/grunt.tres")
const HEAVY: FTEnemyType = preload("res://enemies/heavy.tres")
const RUNNER: FTEnemyType = preload("res://enemies/runner.tres")
# Lux2k: darkest purple, light cream; wind-up orange.
const BACKDROP := Color8(37, 19, 26)
const INK := Color8(230, 222, 202)
const WARN := Color(1.0, 0.62, 0.1)
## Banner over the bottom band, measured from the bottom of the screen.
const BANNER_TOP := -150.0
const BANNER_BOTTOM := -92.0

var battle: FTBattle
var layer: CanvasLayer
var banner: ColorRect
var headline: Label
var detail: Label
var hand: FTGestureHand
var skip_button: Button
## Touch wording (TAP / FLICK) or mouse and keyboard (CLICK / SPACE).
## Phones and phone browsers start on touch; any real touch switches to it.
var touch := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
var finished := false
## What happened since the last _reset_events(), oldest first.
var events: Array[StringName] = []

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 3  # above the HUD (2), below the reticle
	add_child(layer)
	hand = FTGestureHand.new()
	layer.add_child(hand)
	hand.hide_gesture()
	banner = ColorRect.new()
	banner.color = Color(BACKDROP, 0.92)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = 8.0
	banner.offset_right = -8.0
	banner.offset_top = BANNER_TOP
	banner.offset_bottom = BANNER_BOTTOM
	banner.visible = false
	layer.add_child(banner)
	headline = _label(16, Vector2(0, 6), 24.0)
	detail = _label(8, Vector2(0, 32), 22.0)
	skip_button = Button.new()
	skip_button.text = "SKIP >"
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override("font_size", 8)
	skip_button.add_theme_color_override("font_color", INK)
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -72.0
	skip_button.offset_right = -8.0
	skip_button.offset_top = 84.0
	skip_button.offset_bottom = 108.0
	skip_button.pressed.connect(_finish)
	layer.add_child(skip_button)

func _label(font_size: int, at: Vector2, height: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.anchor_right = 1.0
	label.offset_left = 8.0
	label.offset_right = -8.0
	label.offset_top = at.y
	label.offset_bottom = at.y + height
	banner.add_child(label)
	return label

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch = true

## Called by the battle once the doors are open.
func begin(owner_battle: FTBattle) -> void:
	battle = owner_battle
	battle.hud.get_node("Instructions").visible = false  # the banner replaces them
	battle.attack_resolved.connect(func(_e, blocked: bool): _note(&"blocked" if blocked else &"hit"))
	battle.enemy_countered.connect(func(_e): _note(&"countered"))
	battle.lob_popped.connect(_note.bind(&"lob_popped"))
	battle.lob_hit_player.connect(_note.bind(&"lob_hit"))
	battle.cover.entered_cover.connect(_on_entered_cover)
	battle.cover.exited_cover.connect(_note.bind(&"cover_out"))
	_run()

func _run() -> void:
	await _say_for("TRAINING", "LEARN THE BASICS BEFORE YOUR FIRST RUN. SKIP ANY TIME (TOP RIGHT).", 2.6)
	for lesson: Callable in [_lesson_shoot, _lesson_reload, _lesson_dodge, _lesson_lob, _lesson_counter]:
		if finished:
			return
		await lesson.call()
	if finished:
		return
	await _say_for("TRAINING COMPLETE", "GOOD LUCK OUT THERE.", 2.2)
	if finished:
		return
	banner.visible = false
	skip_button.visible = false
	await FTClosingDoors.add_to(battle.hud).close()
	_finish()

# --- Lessons ------------------------------------------------------------------

func _lesson_shoot() -> void:
	var rat := await _spawn(RAT, &"far_center")
	if finished:
		return
	_reset_events()
	_say(_t("TAP TO SHOOT", "CLICK TO SHOOT"), "DELETE THE RAT. KEEP SHOOTING UNTIL IT'S GONE.")
	hand.show_tap(_enemy_point(rat), _enemy_point.bind(rat))
	await _wait_for([&"died"])
	hand.hide_gesture()
	await _say_for("NICE SHOOTING!", "", 1.2)

func _lesson_reload() -> void:
	await _leave_cover()
	if finished:
		return
	battle.weapon.empty_magazine()
	_reset_events()
	_say("OUT OF AMMO!", _t("FLICK DOWN, LEFT OR RIGHT TO DUCK INTO COVER AND RELOAD.", "PRESS SPACE TO DUCK INTO COVER AND RELOAD."))
	if touch:
		hand.show_flick(_screen_point(0.5, 0.45))
	await _wait_for([&"cover_in"])
	hand.hide_gesture()
	if finished:
		return
	_say("RELOADING...", "YOU'RE SAFE BEHIND COVER WHILE YOU RELOAD.")
	await _wait_until(func(): return not battle.weapon.is_reloading)
	await _leave_cover()
	if finished:
		return
	await _say_for("GOOD!", "FLICK TO RELOAD WHENEVER YOU'RE RUNNING LOW." if touch else "PRESS SPACE TO RELOAD WHENEVER YOU'RE RUNNING LOW.", 1.8)

func _lesson_dodge() -> void:
	var rat := await _spawn(RAT, &"near_center")
	if finished:
		return
	await _say_for("LOOK FOR THE WARNING SIGN!", "IT POPS UP OVER AN ENEMY RIGHT BEFORE IT ATTACKS.", 2.4)
	while not finished:
		await _leave_cover()
		rat = await _ready_enemy(rat, RAT, &"near_center")
		if finished:
			return
		_reset_events()
		battle.weapon.refill()
		rat.start_windup()
		_slow(true)
		_say("INCOMING!", _t("FLICK TO DODGE INTO COVER.", "PRESS SPACE TO DODGE INTO COVER."), true)
		if touch:
			hand.show_flick(_screen_point(0.5, 0.45))
		var outcome := await _wait_for([&"blocked", &"hit", &"countered", &"died"])
		_slow(false)
		hand.hide_gesture()
		match outcome:
			&"blocked":
				break
			&"hit":
				await _say_for("TOO SLOW!", "GET INTO COVER WHILE THE WARNING SIGN IS UP.", 1.8, true)
			&"countered", &"died":
				await _say_for("THAT WAS A COUNTER!", "MORE ON THOSE SOON. THIS TIME, DODGE INTO COVER.", 2.2)
	if finished:
		return
	await _say_for("BLOCKED!", "COVER STOPS NORMAL ATTACKS.", 1.6)
	await _finish_off(rat)

func _lesson_lob() -> void:
	var heavy := await _spawn(HEAVY, &"far_center", 2)
	if finished:
		return
	await _say_for("LOBBED ATTACKS", "SOME ENEMIES LOB BLOBS. COVER WON'T STOP THOSE: SHOOT THEM DOWN.", 2.6)
	while not finished:
		await _leave_cover()
		heavy = await _ready_enemy(heavy, HEAVY, &"far_center", 2)
		if finished:
			return
		_reset_events()
		battle.weapon.refill()
		heavy.start_windup()
		var lob = battle.orbiting.get(heavy)  # appears with the wind-up
		_slow(true)
		_say("SHOOT THE BLOB!", _t("TAP IT BEFORE IT LANDS.", "CLICK IT BEFORE IT LANDS."), true)
		if lob:
			hand.show_tap(_node_point(lob), _node_point.bind(lob))
		var outcome := await _wait_for([&"lob_popped", &"lob_hit", &"died"])
		_slow(false)
		hand.hide_gesture()
		match outcome:
			&"lob_popped":
				break
			&"lob_hit":
				await _say_for("IT HIT YOU!", "SHOOT THE BLOB, EVEN WHILE IT'S STILL CIRCLING.", 1.8, true)
	if finished:
		return
	await _say_for("POPPED IT!", "", 1.2)
	await _finish_off(heavy)

func _lesson_counter() -> void:
	var runner := await _spawn(RUNNER, &"near_center")
	if finished:
		return
	await _say_for("COUNTERS", "SHOOT AN ENEMY WHILE ITS WARNING SIGN IS UP TO CANCEL ITS ATTACK.", 2.6)
	while not finished:
		await _leave_cover()
		runner = await _ready_enemy(runner, RUNNER, &"near_center")
		if finished:
			return
		_reset_events()
		battle.weapon.refill()
		runner.start_windup()
		_slow(true)
		_say("NOW! SHOOT IT", "WHILE THE WARNING SIGN IS UP.", true)
		hand.show_tap(_enemy_point(runner), _enemy_point.bind(runner))
		var outcome := await _wait_for([&"countered", &"blocked", &"hit"])
		_slow(false)
		hand.hide_gesture()
		if outcome == &"countered":
			break
		await _say_for("MISSED THE WINDOW", "SHOOT WHILE THE WARNING SIGN IS UP, NOT AFTER.", 1.8, true)
	if finished:
		return
	await _say_for("COUNTER!", "ITS ATTACK IS CANCELLED AND IT'S STUNNED.", 2.0)
	await _finish_off(runner)

# --- Steps shared by lessons --------------------------------------------------

## Out of cover before the next step: says so if the player is still in it.
func _leave_cover() -> void:
	if not battle.cover.in_cover:
		return
	_say(_t("TAP TO LEAVE COVER", "CLICK TO LEAVE COVER"), "" if touch else "OR PRESS SPACE.")
	hand.show_tap(_screen_point(0.5, 0.45))
	await _wait_until(func(): return not battle.cover.in_cover)
	hand.hide_gesture()

## Finish a lesson's enemy (if it's still up). A tap in cover leaves and
## fires there.
func _finish_off(enemy) -> void:  # untyped: may already be freed
	if finished or not _is_up(enemy):
		return
	_reset_events()
	battle.weapon.refill()
	_say("FINISH IT", _t("TAP IT UNTIL IT'S GONE.", "CLICK IT UNTIL IT'S GONE."))
	hand.show_tap(_enemy_point(enemy), _enemy_point.bind(enemy))
	await _wait_until(func(): return not _is_up(enemy))
	hand.hide_gesture()

## The lesson's enemy, ready for a cued wind-up: replaced if it died, and
## not stunned.
func _ready_enemy(enemy, type: FTEnemyType, slot: StringName, hp := 0) -> FTEnemy:  # untyped: may already be freed
	if not _is_up(enemy):
		await _wait_until(func(): return not is_instance_valid(enemy))  # slot frees after the fade
		enemy = await _spawn(type, slot, hp)
	await _wait_until(func(): return not _is_up(enemy) or enemy.stun_timer <= 0.0)
	return enemy

func _spawn(type: FTEnemyType, slot: StringName, hp := 0) -> FTEnemy:
	var enemy := battle.director.spawn_enemy(type, slot)
	enemy.attacks_paused = true
	if hp > 0:
		enemy.set_health(hp)
	enemy.died.connect(_note.bind(&"died"))
	await _wait_until(func(): return not enemy.entering)
	return enemy

func _is_up(enemy) -> bool:
	return is_instance_valid(enemy) and enemy.alive

# --- Prompts ------------------------------------------------------------------

func _t(touch_text: String, desktop_text: String) -> String:
	return touch_text if touch else desktop_text

func _say(head: String, body := "", warn := false) -> void:
	headline.text = head
	headline.add_theme_color_override("font_color", WARN if warn else INK)
	detail.text = body
	if not banner.visible:
		banner.visible = true
		banner.pivot_offset = banner.size / 2.0
		banner.scale = Vector2(1, 0)
		create_tween().set_ignore_time_scale(true).tween_property(banner, "scale:y", 1.0, 0.12)

func _say_for(head: String, body: String, seconds: float, warn := false) -> void:
	_say(head, body, warn)
	await _sleep(seconds)

func _slow(on: bool) -> void:
	Engine.time_scale = SLOW_SCALE if on else 1.0

func _on_entered_cover() -> void:
	_slow(false)  # dodged: back to full speed for the block
	_note(&"cover_in")

# --- Points on screen (the hand's layer is screen space) ----------------------

func _screen_point(x: float, y: float) -> Vector2:
	var size := battle.get_viewport().get_visible_rect().size
	return (size * Vector2(x, y)).round()

func _enemy_point(enemy) -> Variant:
	if not _is_up(enemy):
		return null
	return enemy.get_global_transform_with_canvas() * (enemy.size / 2.0)

func _node_point(node) -> Variant:
	if not is_instance_valid(node):
		return null
	return node.get_global_transform_with_canvas().origin

# --- Waiting ------------------------------------------------------------------

func _note(event: StringName) -> void:
	events.append(event)

func _reset_events() -> void:
	events.clear()

## Waits until one of `names` happens (since the last _reset_events) and
## returns it; returns &"" if the tutorial ended first.
func _wait_for(names: Array) -> StringName:
	while not finished:
		for event in events:
			if event in names:
				_reset_events()
				return event
		await get_tree().process_frame
	return &""

func _wait_until(condition: Callable) -> void:
	while not finished and not condition.call():
		await get_tree().process_frame

## Real seconds, whatever the game speed.
func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _finish() -> void:
	if finished:
		return
	finished = true
	_slow(false)
	Run.finish_tutorial()
