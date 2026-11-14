extends Node3D
## Aşama 0: boş sahne. Sürümü ve çalışan platformu gösterir.

@onready var _info: Label = $UI/Info


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	_info.text = "Aşama 0 · v%s · %s" % [version, OS.get_name()]
