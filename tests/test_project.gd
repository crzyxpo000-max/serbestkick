extends RefCounted
## Aşama 0 denetimi: proje ayarları ve ana sahne.

func test_main_scene_loads() -> Array[String]:
	var errors: Array[String] = []
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene: PackedScene = load(path)
	if scene == null:
		errors.append("ana sahne yüklenemedi: " + path)
		return errors
	var root := scene.instantiate()
	for node_path: String in ["Ball", "Camera", "UI/Info"]:
		if not root.has_node(node_path):
			errors.append("sahnede eksik düğüm: " + node_path)
	root.free()
	return errors


func test_physics_tick_rate() -> Array[String]:
	var errors: Array[String] = []
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	if ticks < 120:
		errors.append("fizik adımı en az 120 Hz olmalı, şu an %d" % ticks)
	return errors
