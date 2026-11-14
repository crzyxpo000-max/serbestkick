class_name Sound
extends Node
## Oyunun sesleri: kısa efektler, tribün uğultusu (döngü) ve kalp atışı. Dosyalar tools/make_sounds.py ile üretilir.

const NAMES: Array[String] = [
	"kick", "bounce", "save", "post", "net", "whistle", "crowd", "cheer", "groan", "heartbeat", "click",
]
const VOICES := 6

var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_crowd.stop()
		elif not _crowd.playing and _crowd_level > 0.0:
			_crowd.play()

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd := AudioStreamPlayer.new()
var _crowd_level := 0.0
var _beat_wait := 0.0
var _pressure := 0.0


func _ready() -> void:
	for sound_name in NAMES:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % sound_name)
		if stream != null:
			_streams[sound_name] = stream
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	if _streams.has("crowd"):
		var bed: AudioStreamWAV = _streams["crowd"].duplicate()
		bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bed.loop_end = bed.data.size() / 2
		_crowd.stream = bed
	_crowd.volume_db = -40.0
	add_child(_crowd)


func _process(delta: float) -> void:
	if not enabled or _pressure < 0.3:
		return
	_beat_wait -= delta
	if _beat_wait <= 0.0:
		_beat_wait = 60.0 / (70.0 + 60.0 * _pressure)
		play("heartbeat", lerpf(-14.0, -2.0, _pressure))


func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not _streams.has(sound_name):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Tribün uğultusu: 0 = sessiz, 1 = en yüksek.
func set_crowd(level: float) -> void:
	_crowd_level = clampf(level, 0.0, 1.0)
	if _crowd_level <= 0.0:
		_crowd.stop()
		return
	_crowd.volume_db = lerpf(-30.0, -8.0, _crowd_level)
	if enabled and not _crowd.playing and _crowd.stream != null:
		_crowd.play()


## Kalp atışı: baskı 0,3'ün üstündeyse duyulur, baskı arttıkça hızlanır.
func set_pressure(pressure: float) -> void:
	_pressure = pressure
	_beat_wait = 0.0
