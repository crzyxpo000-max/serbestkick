class_name DemoShot
extends RefCounted
## data/demo_shots.json içindeki bir gösterim vuruşu.

const DATA_PATH := "res://data/demo_shots.json"

var name := ""
var kick: BallState
var conditions := PitchConditions.new()
var launch_speed := 0.0


static func load_all() -> Array[DemoShot]:
	var shots: Array[DemoShot] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		return shots
	var radius := PhysicsParams.load_default().radius
	for entry: Dictionary in parsed:
		var shot := DemoShot.new()
		shot.name = entry.get("name", "")
		shot.launch_speed = entry.get("speed", 25.0)
		shot.kick = BallState.from_kick(
			Vector3(entry.get("x", 0.0), radius, entry.get("distance", 25.0)),
			shot.launch_speed, entry.get("elevation", 12.0), entry.get("azimuth", 0.0),
			entry.get("side_spin", 0.0), entry.get("top_spin", 0.0))
		shot.conditions.wet = entry.get("wet", false)
		var wind: Array = entry.get("wind", [0, 0, 0])
		shot.conditions.wind = Vector3(wind[0], wind[1], wind[2])
		shots.append(shot)
	return shots
