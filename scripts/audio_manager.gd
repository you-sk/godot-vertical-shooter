extends Node
## Bundled original WAVs. Players are pooled to keep rapid shooting inexpensive.
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index := 0
var muted := false
var playback_enabled := true # Deterministic tests load assets without queuing real-time audio.

func _ready() -> void:
	for sound in ["shot", "enemy_shot", "explosion", "hit", "powerup", "victory", "menu"]:
		var path: String = "res://assets/audio/" + sound + ".wav"
		if ResourceLoader.exists(path):
			sounds[sound] = load(path)
	for i in 16:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	music = AudioStreamPlayer.new()
	music.volume_db = -12
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/bgm.wav"):
		var stream: AudioStreamWAV = load("res://assets/audio/bgm.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		music.stream = stream

func start_music() -> void:
	if music.stream and not music.playing:
		music.play()

func stop_music() -> void:
	music.stop()

func play_sfx(sound: String, volume_db: float = -10.0) -> void:
	if not playback_enabled or not sounds.has(sound) or voices.is_empty():
		return
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = sounds[sound]
	voice.volume_db = volume_db
	voice.play()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)

func set_paused(paused: bool) -> void:
	music.stream_paused = paused
	for voice in voices:
		voice.stream_paused = paused
