class_name Settings
extends RefCounted
## Oyuncu ayarları; `user://settings.json` dosyasında saklanır.

const SAVE_PATH := "user://settings.json"
const KEYS: Array[String] = ["sound", "vibration", "aftertouch"]
const LABELS := {"sound": "Ses", "vibration": "Titreşim", "aftertouch": "Havada falso"}

var sound := true
var vibration := true
var aftertouch := true   ## kapalı = simülasyon modu: top havadayken yönlendirilemez


func toggle(key: String) -> void:
	set(key, not get(key))


func to_dict() -> Dictionary:
	return {"sound": sound, "vibration": vibration, "aftertouch": aftertouch}


static func from_dict(data: Dictionary) -> Settings:
	var settings := Settings.new()
	for key in KEYS:
		if data.has(key):
			settings.set(key, bool(data[key]))
	return settings


func save(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


static func load_saved(path: String = SAVE_PATH) -> Settings:
	if not FileAccess.file_exists(path):
		return Settings.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed) if parsed is Dictionary else Settings.new()
