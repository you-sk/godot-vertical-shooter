extends Node2D
## Main owns game state, deterministic simulation, collision, scoring and presentation.
## Actors draw themselves; StageDirector owns only the authored wave schedule.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const BossScript = preload("res://scripts/boss.gd")
const EffectScript = preload("res://scripts/effect.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const DirectorScript = preload("res://scripts/stage_director.gd")
const BackgroundScript = preload("res://scripts/background.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")

enum State { TITLE, PLAYING, PAUSED, GAME_OVER, VICTORY }
var state := State.TITLE
var player: Node2D
var boss: Node2D
var director: RefCounted
var background: Node2D
var audio: Node
var actors: Node2D
var enemies: Array[Node2D] = []
var bullets: Array[Node2D] = []
var effects: Array[Node2D] = []
var pickups: Array[Node2D] = []
var score := 0
var best_score := 0
var lives := 3
var next_bonus := 15000
var elapsed := 0.0
var ui_time := 0.0
var banner := ""
var banner_timer := 0.0
var damage_flash := 0.0
var defeated := 0
var test_mode := false
var demo_mode := false
var demo_no_damage := false
var menu_selection := 0
var font: Font
var screenshot_path := ""
var screenshot_after := 0.0
var run_time := 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 50
	_setup_input()
	background = BackgroundScript.new()
	background.z_index = -20
	background.z_as_relative = false
	add_child(background)
	actors = Node2D.new()
	actors.z_as_relative = false
	add_child(actors)
	audio = AudioScript.new()
	audio.playback_enabled = not test_mode
	add_child(audio)
	if not test_mode:
		_load_best()
	for argument in OS.get_cmdline_user_args():
		if argument == "--demo": demo_mode = true
		if argument.begins_with("--capture="): screenshot_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--capture-after="): screenshot_after = float(argument.trim_prefix("--capture-after="))
	if demo_mode:
		demo_no_damage = true
		start_game()
	queue_redraw()

func _setup_input() -> void:
	_bind_key("move_left", [KEY_LEFT, KEY_A])
	_bind_key("move_right", [KEY_RIGHT, KEY_D])
	_bind_key("move_up", [KEY_UP, KEY_W])
	_bind_key("move_down", [KEY_DOWN, KEY_S])
	_bind_key("shoot", [KEY_SPACE, KEY_Z])
	_bind_key("focus", [KEY_SHIFT])
	_bind_key("pause_game", [KEY_ESCAPE, KEY_P])
	_bind_key("mute_audio", [KEY_M])
	_bind_key("confirm_game", [KEY_ENTER, KEY_KP_ENTER])
	_bind_key("retry_game", [KEY_R])
	_bind_button("shoot", JOY_BUTTON_A)
	_bind_button("focus", JOY_BUTTON_LEFT_SHOULDER)
	_bind_button("pause_game", JOY_BUTTON_START)
	_bind_button("confirm_game", JOY_BUTTON_A)
	_bind_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_bind_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_bind_button("move_up", JOY_BUTTON_DPAD_UP)
	_bind_button("move_down", JOY_BUTTON_DPAD_DOWN)
	for entry in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["move_up",JOY_AXIS_LEFT_Y,-1.0],["move_down",JOY_AXIS_LEFT_Y,1.0]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		InputMap.action_add_event(entry[0], motion)

func _bind_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action,0.22)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action,event)

func _bind_button(action: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	InputMap.action_add_event(action,event)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("mute_audio"):
		audio.toggle_mute()
		queue_redraw()
		return
	if event.is_action_pressed("pause_game"):
		if state == State.PLAYING: set_paused(true)
		elif state == State.PAUSED: set_paused(false)
		elif state == State.GAME_OVER or state == State.VICTORY: return_to_title()
		return
	if state == State.PLAYING: return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		if state != State.TITLE: menu_selection = 1-menu_selection
		queue_redraw()
	if event.is_action_pressed("confirm_game") or event.is_action_pressed("retry_game"):
		_activate_menu(menu_selection)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if _button_rect(0).has_point(point): _activate_menu(0)
		elif state != State.TITLE and _button_rect(1).has_point(point): _activate_menu(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and not demo_mode and not test_mode:
		set_paused(true)

func _activate_menu(index: int) -> void:
	if state == State.TITLE:
		start_game()
	elif index == 1:
		return_to_title()
	elif state == State.PAUSED:
		set_paused(false)
	else:
		start_game()

func _physics_process(delta: float) -> void:
	ui_time += delta
	run_time += delta
	if state != State.PAUSED:
		background.tick(delta)
	if state == State.PLAYING:
		var move := Input.get_vector("move_left","move_right","move_up","move_down")
		var shooting := Input.is_action_pressed("shoot")
		if demo_mode:
			var target := Vector2(240+sin(elapsed*0.55)*160,595+sin(elapsed*0.31)*30)
			move = (target-player.position).limit_length(1.0)
			shooting = true
		step_simulation(delta,move,shooting,Input.is_action_pressed("focus"))
	queue_redraw()
	if not screenshot_path.is_empty() and run_time >= screenshot_after:
		var path := screenshot_path
		screenshot_path = ""
		_capture.call_deferred(path)

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(path)
	print("CAPTURE_RESULT ",error," ",path)

func start_game() -> void:
	_clear_actors()
	score = 0
	lives = 3
	next_bonus = 15000
	elapsed = 0
	defeated = 0
	damage_flash = 0
	menu_selection = 0
	player = PlayerScript.new()
	player.game = self
	player.position = Vector2(240,610)
	actors.add_child(player)
	director = DirectorScript.new()
	director.game = self
	state = State.PLAYING
	show_banner("SECTOR 07 / THE QUIET FRONTIER",3.8)
	audio.set_paused(false)
	if not test_mode:
		audio.start_music()
		audio.play_sfx("menu",-13)
	queue_redraw()

func set_paused(paused: bool) -> void:
	if paused and state != State.PLAYING: return
	if not paused and state != State.PAUSED: return
	state = State.PAUSED if paused else State.PLAYING
	menu_selection = 0
	audio.set_paused(paused)
	queue_redraw()

func return_to_title() -> void:
	_clear_actors()
	state = State.TITLE
	menu_selection = 0
	audio.set_paused(false)
	audio.stop_music()
	queue_redraw()

func _clear_actors() -> void:
	if is_instance_valid(actors):
		for child in actors.get_children():
			actors.remove_child(child)
			child.queue_free()
	enemies.clear()
	bullets.clear()
	effects.clear()
	pickups.clear()
	player = null
	boss = null

func step_simulation(delta: float, movement: Vector2, shooting: bool, focused: bool = false) -> void:
	if state != State.PLAYING: return
	elapsed += delta
	banner_timer = maxf(0,banner_timer-delta)
	damage_flash = maxf(0,damage_flash-delta)
	player.tick(delta,movement,shooting,focused)
	director.tick(delta)
	for enemy in enemies: enemy.tick(delta)
	if is_instance_valid(boss) and boss.alive: boss.tick(delta)
	for bullet in bullets: bullet.tick(delta)
	for pickup in pickups: pickup.tick(delta)
	for effect in effects: effect.tick(delta)
	_resolve_collisions()
	_cleanup()

func spawn_bullet(at: Vector2, velocity: Vector2, friendly: bool) -> Node2D:
	var bullet := BulletScript.new()
	bullet.configure(at,velocity,friendly)
	actors.add_child(bullet)
	bullets.append(bullet)
	return bullet

func spawn_enemy(kind: int, at: Vector2, seed_phase: float = 0.0) -> Node2D:
	var enemy := EnemyScript.new()
	enemy.game = self
	enemy.configure(kind,at,seed_phase)
	actors.add_child(enemy)
	enemies.append(enemy)
	return enemy

func spawn_pickup(at: Vector2) -> Node2D:
	var pickup := PickupScript.new()
	pickup.configure(at)
	actors.add_child(pickup)
	pickups.append(pickup)
	return pickup

func spawn_effect(at: Vector2, size: float = 1.0, tint: Color = Color("ffc18b")) -> void:
	var effect := EffectScript.new()
	effect.configure(at,size,tint)
	actors.add_child(effect)
	effects.append(effect)

func begin_boss() -> void:
	# Clear old threats for a fair, readable transition into the boss fight.
	for enemy in enemies: enemy.alive = false
	for bullet in bullets:
		if not bullet.friendly: bullet.alive = false
	boss = BossScript.new()
	boss.game = self
	actors.add_child(boss)
	show_banner("WARNING / THE WARDEN",4.5)
	audio.play_sfx("enemy_shot",-6)

func _resolve_collisions() -> void:
	for bullet in bullets:
		if not bullet.alive: continue
		if bullet.friendly:
			for enemy in enemies:
				if enemy.alive and bullet.position.distance_squared_to(enemy.position) < pow(bullet.radius+enemy.radius,2):
					bullet.alive = false
					if enemy.take_damage(bullet.damage): _enemy_defeated(enemy)
					break
			if bullet.alive and is_instance_valid(boss) and boss.alive and not boss.entering:
				if bullet.position.distance_squared_to(boss.position) < pow(bullet.radius+boss.radius,2):
					bullet.alive = false
					if boss.take_damage(bullet.damage): _boss_defeated()
		else:
			if bullet.position.distance_squared_to(player.position) < pow(bullet.radius+player.HIT_RADIUS,2):
				bullet.alive = false
				_damage_player()
		if state != State.PLAYING: return
	for enemy in enemies:
		if enemy.alive and enemy.position.distance_squared_to(player.position) < pow(enemy.radius+player.HIT_RADIUS,2):
			_damage_player()
			if state != State.PLAYING: return
	if is_instance_valid(boss) and boss.alive and not boss.entering:
		if boss.position.distance_squared_to(player.position) < pow(boss.radius+player.HIT_RADIUS,2): _damage_player()
	if state != State.PLAYING: return
	for pickup in pickups:
		if pickup.alive and pickup.position.distance_squared_to(player.position) < pow(pickup.radius+14.0,2):
			pickup.alive = false
			player.weapon_level = mini(3,player.weapon_level+1)
			add_score(500)
			show_banner("WEAPON UPGRADE / LEVEL %d" % player.weapon_level,2.0)
			spawn_effect(pickup.position,0.6,Color("9af6c4"))
			audio.play_sfx("powerup",-10)

func _enemy_defeated(enemy: Node2D) -> void:
	add_score(enemy.points)
	defeated += 1
	spawn_effect(enemy.position,1.6 if enemy.kind==3 else 0.75)
	audio.play_sfx("explosion",-17 if enemy.kind<3 else -10)

func _damage_player() -> void:
	if player.invulnerable > 0 or demo_no_damage: return
	lives -= 1
	player.invulnerable = 2.8
	player.weapon_level = maxi(1,player.weapon_level-1)
	damage_flash = 0.22
	spawn_effect(player.position,1.6,Color("8ff3e6"))
	audio.play_sfx("hit",-8)
	# A hit clears nearby bullets and respawns centrally. The run keeps moving.
	for bullet in bullets:
		if not bullet.friendly and bullet.position.distance_to(player.position) < 160: bullet.alive = false
	player.position = Vector2(240,610)
	if lives <= 0:
		state = State.GAME_OVER
		_save_best()
		audio.stop_music()
		menu_selection = 0
	else:
		show_banner("SHIELD RESTORED / KEEP GOING",2.0)

func _boss_defeated() -> void:
	add_score(10000)
	for bullet in bullets: bullet.alive = false
	spawn_effect(boss.position,4.0)
	audio.play_sfx("victory",-8)
	state = State.VICTORY
	menu_selection = 0
	_save_best()
	audio.stop_music()

func add_score(amount: int) -> void:
	score += amount
	if score >= next_bonus:
		lives = mini(5,lives+1)
		next_bonus += 15000
		show_banner("BONUS / EXTRA SHIELD",2.0)
		audio.play_sfx("powerup",-10)

func _cleanup() -> void:
	for collection in [enemies,bullets,effects,pickups]:
		for index in range(collection.size()-1,-1,-1):
			var actor: Node2D = collection[index]
			if not actor.alive:
				collection.remove_at(index)
				actor.queue_free()

func show_banner(text: String, seconds: float) -> void:
	banner = text
	banner_timer = seconds

func _load_best() -> void:
	var save := ConfigFile.new()
	if save.load("user://scores.cfg") == OK:
		best_score = maxi(0,int(save.get_value("scores","best",0)))

func _save_best() -> void:
	best_score = maxi(best_score,score)
	if test_mode or demo_mode: return
	var save := ConfigFile.new()
	save.set_value("scores","best",best_score)
	save.save("user://scores.cfg")

func _text(text: String, at: Vector2, size: int, color: Color = Color("e6f1e8")) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(text: String, y: float, size: int, color: Color = Color("e6f1e8")) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(text,Vector2((480-width)/2,y),size,color)

func _draw() -> void:
	if font == null: return
	if state == State.TITLE:
		_draw_title()
		return
	_draw_hud()
	if damage_flash > 0:
		draw_rect(Rect2(0,72,480,648),Color(1.0,0.35,0.3,damage_flash*0.5))
	if state == State.PLAYING and banner_timer > 0:
		var alpha := minf(1,banner_timer)
		draw_rect(Rect2(34,270,412,44),Color(0.02,0.07,0.13,alpha*0.88))
		_center(banner,297,15,Color(0.69,0.96,0.89,alpha))
	if state == State.PAUSED: _draw_panel("FLIGHT PAUSED","Take a breath. Your flight is safe.","RESUME FLIGHT")
	elif state == State.GAME_OVER: _draw_panel("SIGNAL LOST","One more flight. One better run.","RETRY FLIGHT")
	elif state == State.VICTORY: _draw_panel("SECTOR CLEAR","The frontier is quiet again.","FLY AGAIN")

func _draw_hud() -> void:
	draw_rect(Rect2(0,0,480,76),Color("091629"))
	draw_line(Vector2(16,75),Vector2(464,75),Color("254656"),1)
	_text("SCORE",Vector2(20,22),10,Color("779da8"))
	_text("%07d" % score,Vector2(19,49),24)
	_text("SHIELDS",Vector2(354,22),10,Color("779da8"))
	for i in range(5):
		var at := Vector2(361+i*19,39)
		var color := Color("8fe9d5") if i<lives else Color("25384c")
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(5,3),at+Vector2(0,8),at+Vector2(-5,3)]),color)
	_text("SECTOR 07",Vector2(189,22),10,Color("779da8"))
	_text("%02d:%02d" % [int(elapsed / 60.0),int(elapsed)%60],Vector2(198,47),20,Color("bed5d4"))
	_text("WPN %d" % player.weapon_level,Vector2(20,65),10,Color("8fe9d5"))
	_text("M: %s" % ("MUTED" if audio.muted else "AUDIO"),Vector2(353,65),10,Color("779da8"))
	var progress := minf(elapsed/DirectorScript.STAGE_DURATION,1)
	draw_rect(Rect2(0,74,480*progress,2),Color("73cfc0"))
	if is_instance_valid(boss) and boss.alive:
		_text("THE WARDEN",Vector2(112,94),10,Color("efb490"))
		draw_rect(Rect2(112,101,256,5),Color("283048"))
		draw_rect(Rect2(112,101,256*maxf(0,float(boss.hp)/boss.MAX_HP),5),Color("eeac85"))
	_text("MOVE  WASD / ARROWS      FIRE  Z / SPACE      PAUSE  ESC",Vector2(32,707),10,Color("5e8492"))

func _draw_title() -> void:
	_text("AN ORIGINAL ARCADE FLIGHT",Vector2(25,35),10,Color("7b9ba7"))
	_text("01 / 01",Vector2(407,35),10,Color("7b9ba7"))
	draw_line(Vector2(25,47),Vector2(455,47),Color("254656"),1)
	_center("S T A R F A L L",188,40,Color("e9f4e7"))
	_center("S E C T O R   0 7",221,15,Color("85ded1"))
	_center("A small ship. A wide frontier.",263,15,Color("9cb9c0"))
	# A large emblem anchors the title without borrowing existing game artwork.
	var center := Vector2(240,359)
	draw_arc(center,64,ui_time*0.15,ui_time*0.15+TAU*0.7,70,Color("274b59"),1)
	draw_arc(center,72,-ui_time*0.1,-ui_time*0.1+TAU*0.35,40,Color("58847d"),2)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-44),center+Vector2(43,27),center+Vector2(16,18),center+Vector2(0,38),center+Vector2(-16,18),center+Vector2(-43,27)]),Color("86e2d4"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-29),center+Vector2(8,10),center+Vector2(0,21),center+Vector2(-8,10)]),Color("173a50"))
	draw_line(center+Vector2(-8,41),center+Vector2(-3,53+sin(ui_time*8)*5),Color("ffc38f"),3)
	draw_line(center+Vector2(8,41),center+Vector2(3,53+sin(ui_time*8)*5),Color("ffc38f"),3)
	_draw_button(0,"START FLIGHT",true)
	_center("ENTER / A TO LAUNCH",542,10,Color("7a9ca7"))
	_center("MOVE  WASD / ARROWS     FIRE  Z / SPACE",588,12,Color("c3d6d7"))
	_center("SHIFT  SLOW     ESC  PAUSE     M  MUTE",613,12,Color("8baeb7"))
	_center("GAMEPAD: STICK / D-PAD + A  |  LB: SLOW",638,10,Color("6d939e"))
	_center("BEST  %07d  /  144s APPROACH + BOSS" % best_score,682,10,Color("739ba6"))

func _button_rect(index: int) -> Rect2:
	return Rect2(100,478+index*56,280,44)

func _draw_button(index: int, text: String, selected: bool) -> void:
	var rectangle := _button_rect(index)
	var hover := rectangle.has_point(get_global_mouse_position())
	var active := selected or hover
	draw_style_box(_button_style(active),rectangle)
	_center(text,rectangle.position.y+28,14,Color("102c38") if active else Color("b5c9ce"))

func _button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("93e4d3") if active else Color("15283c")
	style.border_color = Color("8edccd") if active else Color("375364")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _draw_panel(title: String, subtitle: String, primary: String) -> void:
	draw_rect(Rect2(0,76,480,644),Color(0.025,0.055,0.10,0.91))
	draw_line(Vector2(72,230),Vector2(408,230),Color("38606b"),1)
	_center("S T A R F A L L",259,11,Color("77b7b5"))
	_center(title,323,32)
	_center(subtitle,357,14,Color("9bb9c0"))
	if state != State.PAUSED:
		_center("SCORE  %07d   /   BEST  %07d" % [score,best_score],405,14,Color("9ce4d4"))
		_center("%d HOSTILES CLEARED  |  %02d:%02d FLIGHT" % [defeated,int(elapsed / 60.0),int(elapsed)%60],432,11,Color("779da8"))
	else:
		_center("ESC / P / START TO RESUME",411,11,Color("779da8"))
	_draw_button(0,primary,menu_selection==0)
	_draw_button(1,"RETURN TO TITLE",menu_selection==1)
	_center("ENTER / A TO SELECT   |   UP / DOWN TO CHOOSE",620,10,Color("71949e"))
