extends Node2D
## Scout, weaver, interceptor and armored gunship share a compact actor implementation.

var game: Node2D
var kind := 0
var hp := 2
var radius := 16.0
var points := 100
var alive := true
var age := 0.0
var origin_x := 0.0
var fire_timer := 1.8
var hit_flash := 0.0
var speed := 95.0
var phase := 0.0

func configure(enemy_kind: int, at: Vector2, seed_phase: float = 0.0) -> void:
	kind = enemy_kind
	position = at
	origin_x = at.x
	phase = seed_phase
	z_index = 5
	match kind:
		0: hp = 2; points = 100; speed = 115; radius = 15
		1: hp = 4; points = 220; speed = 83; radius = 18
		2: hp = 3; points = 180; speed = 160; radius = 16
		3: hp = 14; points = 650; speed = 41; radius = 29
	fire_timer = 1.3 + fposmod(seed_phase, 0.9)

func tick(delta: float) -> void:
	if not alive:
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	position.y += speed * delta
	match kind:
		1: position.x = clampf(origin_x + sin(age * 2.2 + phase) * 60, 28, 452)
		2: position.x = clampf(origin_x + sin(age * 0.85 + phase) * 100, 25, 455)
		3: position.x = clampf(origin_x + sin(age * 0.8 + phase) * 38, 40, 440)
	fire_timer -= delta
	if fire_timer <= 0 and position.y > 85 and position.y < 500:
		fire_timer = 2.5 if kind < 3 else 1.85
		fire()
	if position.y > 760:
		alive = false
	queue_redraw()

func fire() -> void:
	if not is_instance_valid(game.player):
		return
	var aim: Vector2 = (game.player.position - position).normalized()
	# Avoid unfair rear-facing point-blank shots; a single aimed shot is the default.
	if game.player.position.distance_to(position) < 95 or aim.y < 0.25:
		return
	var bullet_speed := 148.0 if kind < 3 else 135.0
	game.spawn_bullet(position + Vector2(0, 16), aim * bullet_speed, false)
	if kind == 3:
		game.spawn_bullet(position + Vector2(-17, 16), aim.rotated(-0.20) * bullet_speed, false)
		game.spawn_bullet(position + Vector2(17, 16), aim.rotated(0.20) * bullet_speed, false)

func take_damage(amount: int) -> bool:
	hp -= amount
	hit_flash = 0.075
	if hp <= 0:
		alive = false
	return not alive

func _draw() -> void:
	var color := [Color("ee7f86"), Color("c9a3ff"), Color("f6bd79"), Color("8e9abb")][kind] as Color
	if hit_flash > 0:
		color = Color("fff5de")
	if kind == 3:
		var hull := PackedVector2Array([Vector2(-29,-20),Vector2(-12,-28),Vector2(12,-28),Vector2(29,-20),Vector2(33,14),Vector2(18,25),Vector2(-18,25),Vector2(-33,14)])
		draw_colored_polygon(hull, Color("28334c"))
		draw_polyline(hull + PackedVector2Array([hull[0]]), color, 2)
		draw_rect(Rect2(-19,-14,11,28), color)
		draw_rect(Rect2(8,-14,11,28), color)
		draw_circle(Vector2(0,6),9,Color("f39e80"))
		draw_line(Vector2(0,6),Vector2(0,29),Color("e4d6c0"),5)
	else:
		var wing := 19.0 if kind == 1 else 15.0
		var hull := PackedVector2Array([Vector2(0,19),Vector2(-7,5),Vector2(-wing,-12),Vector2(-5,-6),Vector2(0,-17),Vector2(5,-6),Vector2(wing,-12),Vector2(7,5)])
		draw_colored_polygon(hull, color)
		draw_line(Vector2(0,11),Vector2(0,-8),Color("24334a"),4)
		draw_circle(Vector2(0,2),3,Color("fff1ca"))
		draw_line(Vector2(-5,-13),Vector2(-5,-20),Color("ff9c6d"),2)
		draw_line(Vector2(5,-13),Vector2(5,-20),Color("ff9c6d"),2)
