extends SceneTree
## Başsız akış denemesi: ana sahneyi açar ve ekranları sırayla dolaşır (menü, kariyer, maç, maç sonu,
## mağaza, puan durumu, sezon sonu, hızlı maç, ayarlar, antrenman). Betik hatası olursa çıkış kodu 1.
##   godot --headless --path . --script res://tests/run_flow.gd

const TEMP_SAVE := "user://career.json"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
		print("KALDI " + label)
	else:
		print("GEÇTİ " + label)


func _run() -> void:
	var had_save := FileAccess.file_exists(TEMP_SAVE)
	var backup := FileAccess.get_file_as_string(TEMP_SAVE) if had_save else ""
	if had_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))

	var scene: ShotScene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var flow: MatchFlow = null
	for child in scene.get_node("UI").get_children():
		if child is MatchFlow:
			flow = child
	_check(flow != null, "akış düğümü kuruldu")
	if flow == null:
		quit(1)
		return
	_check(flow._stage == MatchFlow.Stage.MENU and flow._career == null, "açılışta menü, kayıt yok")

	flow._new_career()
	_check(flow._stage == MatchFlow.Stage.CAREER and flow._career != null, "kariyer ekranı açıldı")
	_check(FileAccess.file_exists(TEMP_SAVE), "kariyer kaydedildi")
	flow._show_shop()
	flow._show_table()
	flow._show_career()

	# Birkaç kariyer maçı: akışı sona kadar ilerlet, çıkan vuruşları sonuçlandır.
	var career := flow._career
	var shots := 0
	for match_index in 6:
		var week := career.week
		flow._start_career_match()
		_check(flow._stage == MatchFlow.Stage.TICKER and flow._in_career, "kariyer maçı %d başladı" % (match_index + 1))
		var guard := 0
		while flow._stage != MatchFlow.Stage.FULLTIME and guard < 20000:
			guard += 1
			if flow._stage == MatchFlow.Stage.CALLIN:
				flow._take_shot()
				shots += 1
				scene.set_idle()
				scene.shot_finished.emit(shots % 2 == 0)
			else:
				flow._process(0.2)
		_check(flow._stage == MatchFlow.Stage.FULLTIME and career.week > week, "maç %d bitti ve kariyere işlendi" % (match_index + 1))
		flow._show_career()
	_check(shots > 0 and career.shots == shots, "serbest vuruşlar kullanıldı ve sayıldı (%d)" % shots)

	# Sezon sonu.
	career.week = career.schedule.size()
	flow._show_career()
	_check(career.season_closed, "sezon sonu ekranı açıldı")
	career.begin_next_season(flow._rng, career.finish_season(flow._rng), false)
	flow._show_career()
	_check(career.season == 2 and career.week == 0, "yeni sezon başladı")

	# Hızlı maç, ayarlar, antrenman.
	flow._show_menu()
	flow._new_match()
	_check(flow._stage == MatchFlow.Stage.PREMATCH and not flow._in_career, "hızlı maç öncesi ekranı")
	flow._start_ticker()
	for i in 50:
		if flow._stage == MatchFlow.Stage.TICKER:
			flow._process(0.2)
	flow._show_menu()
	flow._show_settings()
	flow._confirm_new_career()
	flow._start_practice()
	_check(flow._stage == MatchFlow.Stage.PRACTICE, "antrenman açıldı")
	for i in 30:
		await process_frame
	scene.menu_requested.emit()
	_check(flow._stage == MatchFlow.Stage.MENU, "antrenmandan menüye dönüldü")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	if had_save:
		var file := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
		file.store_string(backup)
		file.close()
	scene.queue_free()
	await process_frame
	print("%d başarısız" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
