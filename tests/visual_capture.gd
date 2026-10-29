extends Node
## Run this scene with F6 in a graphical Godot session to regenerate QA screenshots.
## It is not part of the game, never connects to the network and never saves scores.
var game: Node2D

func _ready() -> void:
	call_deferred("capture_all")

func save_frame(filename: String) -> void:
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://artifacts"
	DirAccess.make_dir_recursive_absolute(directory)
	var error := get_viewport().get_texture().get_image().save_png(directory+"/"+filename+".png")
	print("VISUAL_CAPTURE ",filename," result=",error)

func capture_all() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	add_child(game)
	game.set_physics_process(false)
	await save_frame("01-title")
	game.start_game()
	game.demo_no_damage = true
	game.player.weapon_level = 2
	for frame in 60*44:
		game.step_simulation(1.0/60.0,Vector2(sin(frame/260.0),0),true)
		game.background.tick(1.0/60.0)
		if frame%120==0: await get_tree().process_frame
	game.player.position = Vector2(240,610)
	game.banner_timer = 0
	await save_frame("02-gameplay")
	game.set_paused(true)
	await save_frame("03-pause")
	game.set_paused(false)
	game.begin_boss()
	game.director.elapsed = 150
	game.director.boss_spawned = true
	for frame in 60*7:
		game.step_simulation(1.0/60.0,Vector2.ZERO,false)
		if frame%60==0: await get_tree().process_frame
	game.elapsed = 151
	game.boss.fire()
	for frame in 60:
		game.step_simulation(1.0/60.0,Vector2.ZERO,true)
	game.banner_timer = 0
	await save_frame("04-boss")
	game.boss.hp = 0
	game.boss.alive = false
	game._boss_defeated()
	await save_frame("05-clear")
	game.start_game()
	game.demo_no_damage = false
	for i in 3:
		game.player.invulnerable = 0
		game._damage_player()
	await save_frame("06-game-over")
	print("VISUAL_CAPTURE COMPLETE")
