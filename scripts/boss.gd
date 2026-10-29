extends Node2D
## Three generous, telegraphed attack patterns. No contact damage during entrance.

const MAX_HP := 340
var game: Node2D
var hp := MAX_HP
var radius := 58.0
var alive := true
var age := 0.0
var fire_timer := 2.4
var volley := 0
var hit_flash := 0.0
var entering := true
var telegraph := 0.0

func _init() -> void:
	z_index = 6
	position = Vector2(240, -100)

func tick(delta: float) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	if entering:
		position.y = move_toward(position.y, 165.0, 55.0 * delta)
		if position.y >= 165:
			entering = false
	else:
		position.x = 240 + sin(age * 0.55) * 120
		position.y = 160 + sin(age * 0.9) * 18
		fire_timer -= delta
		telegraph = clampf(1.0 - fire_timer / 0.65, 0.0, 1.0)
		if fire_timer <= 0:
			fire()
			fire_timer = 1.7 if hp < MAX_HP / 2.0 else 2.1
			telegraph = 0
	queue_redraw()

func fire() -> void:
	volley += 1
	match volley % 3:
		0:
			# Five-way fan has wide escape lanes, aimed gently toward the player.
			var aim: Vector2 = (game.player.position - position).normalized()
			for i in range(-2, 3):
				game.spawn_bullet(position + Vector2(0, 45), aim.rotated(i * 0.23) * 155, false)
		1:
			for x in [-53, 53]:
				var muzzle := position + Vector2(x, 36)
				var aim: Vector2 = (game.player.position - muzzle).normalized()
				game.spawn_bullet(muzzle, aim * 190, false)
		2:
			for x in [-72, -36, 0, 36, 72]:
				game.spawn_bullet(position + Vector2(x, 35), Vector2(x * 0.25, 155), false)
	game.audio.play_sfx("enemy_shot", -16.0)

func take_damage(amount: int) -> bool:
	if entering:
		return false
	hp -= amount
	hit_flash = 0.07
	if hp <= 0:
		alive = false
	return not alive

func _draw() -> void:
	var edge := Color("f2b58b") if hit_flash <= 0 else Color("fff7dc")
	var hull := PackedVector2Array([Vector2(-78,-23),Vector2(-45,-43),Vector2(-21,-35),Vector2(0,-54),Vector2(21,-35),Vector2(45,-43),Vector2(78,-23),Vector2(86,18),Vector2(59,39),Vector2(31,29),Vector2(0,52),Vector2(-31,29),Vector2(-59,39),Vector2(-86,18)])
	draw_colored_polygon(hull,Color("30354d"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), edge, 2.0, true)
	for side in [-1,1]:
		draw_colored_polygon(PackedVector2Array([Vector2(side*27,-25),Vector2(side*65,-16),Vector2(side*66,15),Vector2(side*28,9)]), Color("756276"))
		draw_line(Vector2(side*51,-13),Vector2(side*51,32),edge,6)
		draw_circle(Vector2(side*53,34),6+telegraph*4,Color("ffb777"))
		draw_line(Vector2(side*28,-31),Vector2(side*31,-48),Color("7ee6d6"),4)
	draw_circle(Vector2.ZERO,23,Color("172536"))
	draw_arc(Vector2.ZERO,24,age,age+TAU*0.8,32,edge,2)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(12,0),Vector2(0,19),Vector2(-12,0)]), Color("ffba7a") if hp>MAX_HP/2.0 else Color("ff787e"))
	if telegraph > 0:
		draw_arc(Vector2.ZERO,32+telegraph*6,0,TAU,32,Color(1,0.6,0.4,telegraph),2)
