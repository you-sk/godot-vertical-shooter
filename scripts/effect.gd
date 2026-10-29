extends Node2D
## Procedural debris and ring sparks, never requiring sprite assets.
var elapsed := 0.0
var duration := 0.55
var scale_factor := 1.0
var tint := Color("ffc18b")
var alive := true
var directions: Array[Vector2] = []

func configure(at: Vector2, size: float, color: Color) -> void:
	position = at
	scale_factor = size
	tint = color
	z_index = 12
	for i in 10:
		directions.append(Vector2.from_angle(i * TAU / 10 + size) * (22 + fposmod(i * 17.0, 35)))

func tick(delta: float) -> void:
	elapsed += delta
	alive = elapsed < duration
	queue_redraw()

func _draw() -> void:
	var t := elapsed / duration
	var color := Color(tint, 1.0 - t)
	draw_arc(Vector2.ZERO, maxf(1.0, t * 38 * scale_factor), 0, TAU, 28, color, 2.0 * (1.0 - t) + 0.5)
	for direction in directions:
		var at := direction * t * scale_factor
		draw_line(at, at + direction.normalized() * 5 * (1.0 - t), color, 2)
	if t < 0.3:
		draw_circle(Vector2.ZERO, (1 - t / 0.3) * 13 * scale_factor, Color("fff2c9"))
