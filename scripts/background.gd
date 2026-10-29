extends Node2D
## Original procedural orbital scenery with layered parallax and a soft navigation grid.
var elapsed := 0.0
var stars: Array[Vector3] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for i in 100:
		stars.append(Vector3(rng.randf_range(8,472),rng.randf_range(0,720),rng.randf_range(0.3,1.0)))

func tick(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,480,720),Color("081225"))
	# Subtle nebula bands and a distant, segmented orbital body.
	for i in 10:
		draw_circle(Vector2(390,180),float(205-i*17),Color(0.05,0.12,0.18,0.13))
	var orbit_y := fposmod(elapsed*9.0+120,1100)-180
	draw_circle(Vector2(385,orbit_y),119,Color("0c2334"))
	draw_arc(Vector2(385,orbit_y),120,0,TAU,80,Color("163648"),1)
	draw_arc(Vector2(385,orbit_y),132,-1.7,1.5,60,Color("204252"),2)
	draw_arc(Vector2(385,orbit_y),139,-1.6,0.8,60,Color("183449"),1)
	for star in stars:
		var y := fposmod(star.y+elapsed*(18+star.z*40),720)
		var brightness := star.z * 0.55
		draw_rect(Rect2(star.x,y,1.0+float(star.z>0.75),1.0+float(star.z>0.75)),Color(0.52,0.76,0.86,brightness))
	var terrain_y := fposmod(elapsed*30.0, 360)
	for row in range(-1,3):
		var y := row*360+terrain_y
		_draw_station(Vector2(-56,y),false)
		_draw_station(Vector2(444,y-160),true)
	# The quiet grid recedes behind the actors; it is not a collision boundary.
	for x in range(0,481,48):
		draw_line(Vector2(x,72),Vector2(x,720),Color(0.2,0.45,0.55,0.045),1)
	for y in range(0,721,48):
		var yy := fposmod(y+elapsed*18,720)
		draw_line(Vector2(0,yy),Vector2(480,yy),Color(0.2,0.45,0.55,0.045),1)

func _draw_station(at: Vector2, mirrored: bool) -> void:
	var c := Color("10283b")
	draw_rect(Rect2(at,Vector2(92,174)),c)
	draw_rect(Rect2(at+Vector2(8,8),Vector2(76,158)),Color("0a1d30"))
	draw_rect(Rect2(at+Vector2(17,24),Vector2(57,37)),Color("153146"))
	draw_rect(Rect2(at+Vector2(17,77),Vector2(57,37)),Color("153146"))
	var side := 11 if mirrored else 79
	for i in 6:
		draw_line(at+Vector2(side,18+i*25),at+Vector2(side,26+i*25),Color("376068"),2)
	draw_line(at+Vector2(0,173),at+Vector2(92,173),Color("1d394d"),1)
