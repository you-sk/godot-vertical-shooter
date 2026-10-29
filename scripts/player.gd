extends Node2D
## Small readable hitbox; normalized diagonal movement; invulnerability after damage.

const SPEED := 265.0
const HIT_RADIUS := 6.0
var game: Node2D
var shot_timer := 0.0
var invulnerable := 2.4
var weapon_level := 1
var bank := 0.0
var thruster_time := 0.0

func _init() -> void:
	z_index = 10

func tick(delta: float, movement: Vector2, shooting: bool, focused: bool) -> void:
	invulnerable = maxf(0.0, invulnerable - delta)
	shot_timer = maxf(0.0, shot_timer - delta)
	var input_vector := movement.limit_length(1.0)
	position += input_vector * SPEED * (0.52 if focused else 1.0) * delta
	position.x = clampf(position.x, 22, 458)
	position.y = clampf(position.y, 96, 674)
	bank = lerpf(bank, input_vector.x, minf(delta * 12.0, 1.0))
	thruster_time += delta
	if shooting and shot_timer <= 0:
		fire()
		shot_timer = 0.14 if weapon_level == 1 else 0.125
	queue_redraw()

func fire() -> void:
	game.spawn_bullet(position + Vector2(-7, -18), Vector2(0, -625), true)
	game.spawn_bullet(position + Vector2(7, -18), Vector2(0, -625), true)
	if weapon_level >= 2:
		game.spawn_bullet(position + Vector2(-13, -9), Vector2(-95, -600), true)
		game.spawn_bullet(position + Vector2(13, -9), Vector2(95, -600), true)
	if weapon_level >= 3:
		game.spawn_bullet(position + Vector2(0, -25), Vector2(0, -700), true)
	game.audio.play_sfx("shot", -22.0)

func _draw() -> void:
	if invulnerable > 0 and fmod(invulnerable, 0.16) < 0.06:
		return
	var tail := 12.0 + sin(thruster_time * 31.0) * 5.0
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 15), Vector2(0, 15 + tail), Vector2(5, 15)]), Color("ffb777"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 14), Vector2(0, 24), Vector2(3, 14)]), Color("fff1ce"))
	var hull := PackedVector2Array([Vector2(0, -24), Vector2(10, -6), Vector2(22 - absf(bank) * 3, 13), Vector2(9, 10), Vector2(6, 18), Vector2(-6, 18), Vector2(-9, 10), Vector2(-22 + absf(bank) * 3, 13), Vector2(-10, -6)])
	draw_colored_polygon(hull, Color("78e9de"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("ddfff1"), 1.2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(5, 0), Vector2(0, 7), Vector2(-5, 0)]), Color("123249"))
	draw_line(Vector2(-12, 5), Vector2(-17, 11), Color("30738b"), 3)
	draw_line(Vector2(12, 5), Vector2(17, 11), Color("30738b"), 3)
	draw_circle(Vector2.ZERO, 2, Color("fff6d8"))
	if Input.is_action_pressed("focus"):
		draw_arc(Vector2.ZERO, HIT_RADIUS, 0, TAU, 20, Color(1, 1, 1, 0.7), 1)
	if invulnerable > 0:
		draw_arc(Vector2.ZERO, 29, 0, TAU, 32, Color(0.5, 1.0, 0.9, 0.45), 1)
