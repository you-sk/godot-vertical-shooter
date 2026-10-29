extends SceneTree
## Deterministic engine-level smoke/regression tests. No plugins or third-party runner.
var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func step(frames: int, movement: Vector2 = Vector2.ZERO, shooting: bool = false) -> void:
	for i in frames:
		game.step_simulation(1.0/60.0,movement,shooting)

func clear_threats() -> void:
	for enemy in game.enemies: enemy.alive = false
	for bullet in game.bullets: bullet.alive = false
	game._cleanup()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(game.state == game.State.TITLE,"boot opens title")
	check(game.audio.sounds.size() == 7 and game.audio.music.stream != null,"all eight original audio files load")
	check(game.audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"BGM loops")
	check(InputMap.has_action("shoot") and InputMap.action_get_events("move_left").size() >= 4,"keyboard and gamepad actions installed")
	game.start_game()
	check(game.state == game.State.PLAYING and game.lives == 3 and game.score == 0,"new run initializes state")
	game.player.invulnerable = 0
	var origin: Vector2 = game.player.position
	step(1,Vector2(1,1))
	check(is_equal_approx(game.player.position.distance_to(origin),game.player.SPEED/60.0),"diagonal speed normalized")
	step(240,Vector2(-1,-1))
	check(game.player.position.x >= 22 and game.player.position.y >= 96,"top-left movement bounds")
	step(240,Vector2(1,1))
	check(game.player.position.x <= 458 and game.player.position.y <= 674,"bottom-right movement bounds")
	clear_threats()
	game.player.position = Vector2(240,610)
	step(1,Vector2.ZERO,true)
	check(game.bullets.size() == 2,"base weapon fires twin shots")
	var first_bullet: Node2D = game.bullets[0]
	var first_y: float = first_bullet.position.y
	step(1)
	check(first_bullet.position.y < first_y,"friendly shots travel upward")
	clear_threats()
	for kind in 4:
		var enemy: Node2D = game.spawn_enemy(kind,Vector2(240,250),0)
		check(enemy.hp > 0 and enemy.radius > 0,"enemy type %d initializes" % kind)
		enemy.fire_timer = 0
		enemy.tick(1.0/60.0)
		check(game.bullets.size() > 0,"enemy type %d shoots" % kind)
		clear_threats()
	var target: Node2D = game.spawn_enemy(0,Vector2(240,250),0)
	target.hp = 1
	var score_before: int = game.score
	game.spawn_bullet(target.position,Vector2.ZERO,true)
	game._resolve_collisions()
	check(not target.alive and game.score == score_before+100,"friendly collision destroys enemy and awards score once")
	game._resolve_collisions()
	check(game.score == score_before+100,"dead enemy cannot score twice")
	game.start_game()
	game.player.invulnerable = 0
	game.spawn_bullet(game.player.position,Vector2.ZERO,false)
	game._resolve_collisions()
	check(game.lives == 2 and game.player.invulnerable > 2,"enemy bullet costs one shield and grants invulnerability")
	game._damage_player()
	check(game.lives == 2,"invulnerability prevents repeated damage")
	clear_threats()
	game.player.invulnerable = 0
	game.spawn_enemy(0,game.player.position)
	game._resolve_collisions()
	check(game.lives == 1,"enemy contact damage")
	clear_threats()
	game.player.invulnerable = 0
	game._damage_player()
	check(game.state == game.State.GAME_OVER and game.lives == 0,"third lost shield reaches game over")
	game.start_game()
	check(game.state == game.State.PLAYING and game.lives==3 and game.enemies.is_empty(),"retry clears old actors and resets run")
	var old_time: float = game.elapsed
	var old_position: Vector2 = game.player.position
	game.set_paused(true)
	step(120,Vector2.RIGHT,true)
	check(game.elapsed == old_time and game.player.position == old_position and game.bullets.is_empty(),"pause freezes simulation and shots")
	game.set_paused(false)
	step(1)
	check(game.elapsed > old_time,"resume advances simulation")
	game.audio.toggle_mute()
	check(game.audio.muted and AudioServer.is_bus_mute(0),"mute toggles bus")
	game.audio.toggle_mute()
	check(not AudioServer.is_bus_mute(0),"unmute restores bus")
	for i in 4:
		game.spawn_pickup(game.player.position)
		game._resolve_collisions()
		game._cleanup()
	check(game.player.weapon_level == 3 and game.score == 2000,"pickups upgrade to capped level three and score")
	clear_threats()
	game.player.fire()
	check(game.bullets.size()==5,"max weapon fires five projectiles")
	game.add_score(13000)
	check(game.lives==4 and game.next_bonus==30000,"15000-point bonus awards a shield")
	var stray: Node2D = game.spawn_bullet(Vector2(200,-50),Vector2.UP,true)
	stray.tick(0.1)
	check(not stray.alive,"offscreen bullets expire")
	# A retiring enemy must never fire after the boss-transition bullet clear.
	game.start_game()
	game.director.elapsed = 143.99
	var retiring_enemy: Node2D = game.spawn_enemy(3,Vector2(240,300),0)
	retiring_enemy.fire_timer = 0
	game.step_simulation(1.0/60.0,Vector2.ZERO,false)
	var hostile_count := 0
	for projectile in game.bullets:
		if projectile.alive and not projectile.friendly: hostile_count += 1
	check(game.director.boss_spawned and game.enemies.is_empty() and hostile_count==0,"boss transition cannot resurrect hostile bullets")
	game.return_to_title()
	check(game.state==game.State.TITLE and game.actors.get_child_count()==0,"return to title removes actors")
	game.start_game()
	game.demo_no_damage = true
	var maximum_enemies := 0
	var maximum_bullets := 0
	for frame in range(60*150):
		var target_x: float = 240+sin(game.elapsed*0.55)*155
		var movement: Vector2 = (Vector2(target_x,605)-game.player.position).limit_length(1)
		game.step_simulation(1.0/60.0,movement,true)
		maximum_enemies = maxi(maximum_enemies,game.enemies.size())
		maximum_bullets = maxi(maximum_bullets,game.bullets.size())
		if frame%60 == 0: await process_frame
	check(game.director.boss_spawned and is_instance_valid(game.boss),"full 144-second stage transitions to boss")
	check(game.director.wave_index>=30 and game.director.pickup_index==4,"authored waves and all four pickups scheduled")
	check(maximum_enemies<40 and maximum_bullets<150,"actor counts remain bounded over full stage")
	check(not game.boss.entering,"boss completes protected entrance")
	clear_threats()
	var boss_health: int = game.boss.hp
	game.boss.entering = true
	game.boss.take_damage(10)
	check(game.boss.hp==boss_health,"boss is protected during entrance")
	game.boss.entering = false
	for pattern in 3:
		var previous: int = game.bullets.size()
		game.boss.fire()
		check(game.bullets.size()>previous,"boss attack pattern %d fires" % pattern)
	clear_threats()
	game.boss.hp = 1
	game.spawn_bullet(game.boss.position,Vector2.ZERO,true)
	game._resolve_collisions()
	check(game.state==game.State.VICTORY and not game.boss.alive,"boss collision reaches victory")
	check(game.best_score==game.score,"victory updates best score")
	game.start_game()
	check(game.score==0 and game.boss==null and game.director.elapsed==0,"replay after victory resets boss and director")
	# Let the full-health boss lose HP only through normal base-weapon collisions.
	game.begin_boss()
	game.director.elapsed = 144
	game.director.boss_spawned = true
	var boss_fight_frames := 0
	while game.state==game.State.PLAYING and boss_fight_frames < 60*100:
		var aim_movement := Vector2(clampf((game.boss.position.x-game.player.position.x)/20.0,-1.0,1.0),0)
		game.step_simulation(1.0/60.0,aim_movement,true)
		boss_fight_frames += 1
		if boss_fight_frames%60==0: await process_frame
	check(game.state==game.State.VICTORY,"full-health boss is beatable with ordinary base-weapon shots")
	print("METRIC base_weapon_boss_seconds=",boss_fight_frames/60.0)
	game.return_to_title()
	# Exercise actual input routing, not just direct function calls.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	game._input(key)
	check(game.state==game.State.PLAYING,"Enter input launches from title")
	key.physical_keycode = KEY_ESCAPE
	game._input(key)
	check(game.state==game.State.PAUSED,"Escape input pauses")
	game._input(key)
	check(game.state==game.State.PLAYING,"Escape input resumes")
	game.free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
