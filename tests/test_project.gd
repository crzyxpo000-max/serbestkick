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
	var script: Script = root.get_script()
	if script == null or not script.can_instantiate():
		errors.append("ana sahnenin betiği derlenemedi")
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


func test_demo_shots_load() -> Array[String]:
	var errors: Array[String] = []
	var shots := DemoShot.load_all()
	if shots.size() < 5:
		errors.append("en az 5 gösterim vuruşu olmalı, şu an %d" % shots.size())
	for shot in shots:
		if shot.name.is_empty():
			errors.append("adsız gösterim vuruşu")
		var sim := BallSimulator.new(PhysicsParams.load_default(), shot.conditions)
		sim.kick(shot.kick)
		sim.run(60.0)
		if sim.outcome == BallSimulator.Outcome.NONE:
			errors.append("vuruş sonuçlanmadı: " + shot.name)
	return errors
