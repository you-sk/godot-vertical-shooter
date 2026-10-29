extends RefCounted
## Data-like, deterministic wave schedule. The boss arrives at 144 seconds.
const STAGE_DURATION := 144.0
var game: Node2D
var elapsed := 0.0
var next_wave := 2.0
var wave_index := 0
var pickup_index := 0
var boss_spawned := false
var pickup_times := [26.0, 62.0, 102.0, 132.0]

func tick(delta: float) -> void:
	elapsed += delta
	if elapsed >= STAGE_DURATION:
		if not boss_spawned:
			boss_spawned = true
			game.begin_boss()
		return
	if pickup_index < pickup_times.size() and elapsed >= pickup_times[pickup_index]:
		game.spawn_pickup(Vector2(240 + sin(pickup_index * 2.4) * 130, -18))
		pickup_index += 1
	if elapsed >= next_wave and elapsed < STAGE_DURATION - 9:
		spawn_wave()
		wave_index += 1
		next_wave = elapsed + (4.5 if elapsed < 48 else 3.7)

func spawn_wave() -> void:
	var section := mini(2, int(elapsed / 48.0))
	var mode := wave_index % 5
	match mode:
		0:
			for i in 4:
				game.spawn_enemy(0, Vector2(70+i*110, -25-i*28), i*0.35)
		1:
			for i in range(2 + section):
				game.spawn_enemy(1, Vector2(95+i*95, -30-i*48), i*1.4)
		2:
			for i in 4:
				game.spawn_enemy(2, Vector2(90 if wave_index%2==0 else 390, -30-i*75), i*0.5)
		3:
			game.spawn_enemy(3, Vector2(145 if wave_index%2==0 else 335, -45), 0.0)
			if section > 0:
				game.spawn_enemy(0, Vector2(70, -70), 1.0)
				game.spawn_enemy(0, Vector2(410, -90), 2.0)
		4:
			for i in 5:
				game.spawn_enemy(0 if section==0 else 1, Vector2(80+i*80, -25-abs(i-2)*38), i*0.6)
