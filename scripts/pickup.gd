extends Node2D
var alive := true
var age := 0.0
var radius := 18.0
var origin_x := 0.0

func configure(at: Vector2) -> void:
	position = at
	origin_x = at.x
	z_index = 9

func tick(delta: float) -> void:
	age += delta
	position.y += 68 * delta
	position.x = clampf(origin_x + sin(age * 2) * 14, 25, 455)
	if position.y > 750:
		alive = false
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 18+sin(age*5)*2, 0, TAU, 24, Color(0.43,1,0.8,0.35), 1)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(13,0),Vector2(0,13),Vector2(-13,0)]), Color("95f2ba"))
	draw_line(Vector2(-4,6),Vector2(-4,-6),Color("193e42"),2)
	draw_polyline(PackedVector2Array([Vector2(-4,-6),Vector2(4,-6),Vector2(4,0),Vector2(-4,0)]),Color("193e42"),2)
