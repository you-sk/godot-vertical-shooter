extends Node2D
## A light-weight projectile. Simulation and circle collisions are owned by Main.

var velocity := Vector2.ZERO
var friendly := true
var damage := 1
var radius := 4.0
var alive := true
var age := 0.0

func configure(at: Vector2, speed: Vector2, from_player: bool) -> void:
	position = at
	velocity = speed
	friendly = from_player
	radius = 4.0 if friendly else 5.5
	z_index = 4 if friendly else 8
	queue_redraw()

func tick(delta: float) -> void:
	position += velocity * delta
	age += delta
	if position.y < -45.0 or position.y > 760.0 or position.x < -50.0 or position.x > 530.0:
		alive = false

func _draw() -> void:
	if friendly:
		draw_line(Vector2(0, 9), Vector2(0, -9), Color("247b91"), 7)
		draw_line(Vector2(0, 7), Vector2(0, -8), Color("b7ffec"), 3)
	else:
		draw_circle(Vector2.ZERO, 8, Color(1.0, 0.36, 0.23, 0.16))
		draw_circle(Vector2.ZERO, 5.5, Color("ff946d"))
		draw_circle(Vector2.ZERO, 2.3, Color("fff0c4"))
