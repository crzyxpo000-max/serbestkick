extends RefCounted
## Krampon: dört özellik, dört tip, vuruşa etkileri.

const H := 720.0

func _boot(type: String) -> Boot:
	for boot in Boot.load_all():
		if boot.type == type:
			return boot
	return null


func _swipe(duration: float, bulge: float = 0.0) -> Swipe:
	var points := PackedVector2Array()
	var times := PackedFloat64Array()
	var p0 := Vector2(640, 600)
	var chord := Vector2(0, -300)
	var right := Vector2(-chord.y, chord.x)
	for i in 21:
		var t := i / 20.0
		points.append(p0 + chord * t + right * (bulge * 4.0 * t * (1.0 - t)))
		times.append(duration * t)
	return Swipe.analyze(points, times, H, ControlParams.new())


## Dönüşsüz vuruş kapalı: tam ortadan vuruş yalpalamaz, sonuçlar tekrarlanabilir.
func _build(boot: Boot, swipe: Swipe, strike: Vector2 = Vector2.ZERO, noise: Vector2 = Vector2.ZERO,
		target: Vector2 = Vector2(1.0, 1.2)) -> BallState:
	var cp := ControlParams.new()
	cp.knuckle_radius = -1.0
	return ShotBuilder.build(swipe, target, Check.spot(25.0), strike, cp, PhysicsParams.new(), boot, noise)


func test_dort_tip_krampon_var() -> Array[String]:
	var errors: Array[String] = []
	var boots := Boot.load_all()
	Check.is_true(errors, "4 krampon olmalı, şu an %d" % boots.size(), boots.size() == 4)
	var ids := {}
	var types := {}
	for boot in boots:
		ids[boot.id] = true
		types[boot.type] = true
		Check.is_true(errors, boot.id + ": ad boş olmamalı", not boot.name.is_empty())
		Check.is_true(errors, boot.id + ": tip tanımlı olmalı", Boot.TYPE_LABELS.has(boot.type))
		Check.in_range(errors, boot.id + " güç (m/s)", boot.power, 26.0, 35.0)
		Check.in_range(errors, boot.id + " falso (tur/sn)", boot.curl, 5.0, 11.0)
		Check.in_range(errors, boot.id + " isabet", boot.accuracy, 0.0, 1.0)
		Check.in_range(errors, boot.id + " tatlı nokta", boot.sweet_spot, 0.0, 1.0)
		Check.in_range(errors, boot.id + " havada falso", boot.aftertouch, 0.1, 0.25)
	Check.is_true(errors, "kimlikler benzersiz olmalı", ids.size() == 4)
	Check.is_true(errors, "dört ayrı tip olmalı", types.size() == 4)
	if not boots.is_empty():
		Check.is_true(errors, "ilk krampon dengeli (başlangıç) olmalı", boots[0].type == "dengeli")
	return errors


func test_her_tipin_guclu_ve_zayif_yani() -> Array[String]:
	var errors: Array[String] = []
	var boots := Boot.load_all()
	var best := {}
	var worst := {}
	for stat in Boot.STATS:
		var sorted := boots.duplicate()
		sorted.sort_custom(func(a: Boot, b: Boot) -> bool: return a.get(stat) < b.get(stat))
		worst[stat] = sorted[0].type
		best[stat] = sorted[-1].type
	Check.is_true(errors, "en sert krampon güç tipi olmalı", best["power"] == "guc")
	Check.is_true(errors, "güç tipinin isabeti en düşük olmalı", worst["accuracy"] == "guc")
	Check.is_true(errors, "en isabetli krampon kontrol tipi olmalı", best["accuracy"] == "kontrol")
	Check.is_true(errors, "en geniş tatlı nokta kontrol tipinde olmalı", best["sweet_spot"] == "kontrol")
	Check.is_true(errors, "kontrol tipi en yavaş olmalı", worst["power"] == "kontrol")
	Check.is_true(errors, "en çok kıvıran falso tipi olmalı", best["curl"] == "falso")
	for stat in Boot.STATS:
		Check.is_true(errors, "dengeli krampon %s özelliğinde en iyi olmamalı" % stat, best[stat] != "dengeli")
		Check.is_true(errors, "dengeli krampon %s özelliğinde en kötü olmamalı" % stat, worst[stat] != "dengeli")
	return errors


func test_guc_cikis_hizini_belirler() -> Array[String]:
	var errors: Array[String] = []
	var fast := _swipe(0.02)
	var slow := _swipe(2.0)
	for boot in Boot.load_all():
		Check.near(errors, boot.id + ": en sert vuruş kramponun gücü kadar", _build(boot, fast, Vector2.ZERO).velocity.length(), boot.power, 1e-3)
	var power := _build(_boot("guc"), fast, Vector2.ZERO).velocity.length()
	var control := _build(_boot("kontrol"), fast, Vector2.ZERO).velocity.length()
	Check.is_true(errors, "güç kramponu kontrol kramponundan belirgin sert vurmalı", power > control + 4.0)
	Check.near(errors, "yavaş kaydırma her kramponda aynı", _build(_boot("guc"), slow, Vector2.ZERO).velocity.length(),
			_build(_boot("kontrol"), slow, Vector2.ZERO).velocity.length(), 1e-3)
	return errors


func test_falso_ozelligi_kivrilmayi_belirler() -> Array[String]:
	var errors: Array[String] = []
	var arc := _swipe(0.15, 0.5)
	var aim := Vector2(3.0, 1.2)
	var curl := _build(_boot("falso"), arc, Vector2.ZERO, Vector2.ZERO, aim)
	var power := _build(_boot("guc"), arc, Vector2.ZERO, Vector2.ZERO, aim)
	Check.near(errors, "tam eğri kaydırmada falso kramponunun dönüşü", absf(curl.spin.y) / TAU, _boot("falso").curl, 1e-3)
	Check.near(errors, "tam eğri kaydırmada güç kramponunun dönüşü", absf(power.spin.y) / TAU, _boot("guc").curl, 1e-3)
	var straight_x := Check.shoot(_build(_boot("falso"), _swipe(0.15), Vector2.ZERO, Vector2.ZERO, aim)).line_crossing.x
	var bend := absf(Check.shoot(curl).line_crossing.x - straight_x)
	Check.in_range(errors, "falso kramponuyla en büyük kıvrılma (m)", bend, 2.5, 5.5)
	var side := _build(_boot("falso"), _swipe(0.15), Vector2(0.8, 0))
	var side_power := _build(_boot("guc"), _swipe(0.15), Vector2(0.8, 0))
	Check.is_true(errors, "vuruş noktası falsosu da kramponla artmalı", absf(side.spin.y) > absf(side_power.spin.y) * 1.4)
	return errors


func test_isabet_hatayi_affeder() -> Array[String]:
	var errors: Array[String] = []
	var swipe := _swipe(0.08)
	var noise := Vector2(1.0, 1.0)
	var misses := {}
	for boot in Boot.load_all():
		var exact := Check.shoot(_build(boot, swipe)).line_crossing
		var off := Check.shoot(_build(boot, swipe, Vector2.ZERO, noise)).line_crossing
		misses[boot.type] = off.distance_to(exact)
		Check.near(errors, boot.id + ": sapma yokken top nişana gitmeli (x)", exact.x, 1.0, 0.05)
	Check.is_true(errors, "güç kramponu en çok sapmalı", misses["guc"] > misses["dengeli"] and misses["dengeli"] > misses["kontrol"])
	Check.in_range(errors, "güç kramponunda sapma (m)", misses["guc"], 0.25, 0.8)
	Check.in_range(errors, "kontrol kramponunda sapma (m)", misses["kontrol"], 0.0, 0.12)
	var cp := ControlParams.new()
	var gentle := ShotBuilder.scatter_degrees(_boot("guc"), cp, 0.0, 0.0, false)
	var hard := ShotBuilder.scatter_degrees(_boot("guc"), cp, 1.0, 0.0, false)
	Check.is_true(errors, "sert vuruş daha çok sapmalı", hard > gentle * 2.0)
	var perfect := Boot.neutral(cp)
	Check.near(errors, "kramponsuz hesapta sapma yok", ShotBuilder.scatter_degrees(perfect, cp, 1.0, 1.0, true), 0.0, 1e-9)
	return errors


func test_tatli_nokta() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	var control := _boot("kontrol")
	var power := _boot("guc")
	var fast := _swipe(0.02)
	var strike := Vector2(0.5, 0)
	Check.near(errors, "tatlı noktanın içinde vuruş", control.mishit(strike), 0.0, 1e-9)
	Check.is_true(errors, "dar tatlı noktada aynı vuruş dışarıda kalmalı", power.mishit(strike) > 0.2)
	Check.near(errors, "topun kenarı tam dışarıda", power.mishit(Vector2(1, 0)), 1.0, 1e-6)
	Check.near(errors, "kontrol: tatlı noktada güç kaybı yok", _build(control, fast, strike).velocity.length(), control.power, 1e-3)
	Check.is_true(errors, "güç: tatlı nokta dışında güç kaybı", _build(power, fast, strike).velocity.length() < power.power - 0.3)
	var inside := ShotBuilder.scatter_degrees(power, cp, 0.5, 0.0, false)
	var outside := ShotBuilder.scatter_degrees(power, cp, 0.5, power.mishit(Vector2(0.9, 0)), false)
	Check.is_true(errors, "tatlı nokta dışında sapma artmalı", outside > inside + 0.3)
	return errors


func test_islak_sahada_isabet_duser() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	for boot in Boot.load_all():
		var dry := ShotBuilder.scatter_degrees(boot, cp, 1.0, 0.0, false)
		var wet := ShotBuilder.scatter_degrees(boot, cp, 1.0, 0.0, true)
		Check.is_true(errors, boot.id + ": ıslak sahada sapma artmalı", wet > dry)
	var power := _boot("guc")
	var control := _boot("kontrol")
	Check.is_true(errors, "güç kramponu ıslakta daha çok etkilenmeli", power.wet_penalty > control.wet_penalty)
	Check.near(errors, "ıslakta isabet", power.effective_accuracy(true), power.accuracy - power.wet_penalty, 1e-6)
	return errors


func test_havada_falso_krampona_bagli() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	for boot in [_boot("falso"), _boot("guc")]:
		var sim := BallSimulator.new()
		var kick := BallState.from_kick(Check.spot(25.0), 27.0, 15.0, 0.0, 6.0)
		sim.kick(kick)
		var touch := Aftertouch.new(cp)
		touch.limit = boot.aftertouch
		touch.begin(kick)
		var before := sim.state.spin.length()
		touch.apply(sim, Vector2(9, 0))
		Check.near(errors, boot.id + ": havada falso sınırı", sim.state.spin.length() / before, 1.0 + boot.aftertouch, 1e-4)
	Check.is_true(errors, "falso kramponunun havada falsosu daha güçlü olmalı", _boot("falso").aftertouch > _boot("guc").aftertouch)
	return errors


func test_ozellik_cubuklari() -> Array[String]:
	var errors: Array[String] = []
	for boot in Boot.load_all():
		for stat in Boot.STATS:
			Check.in_range(errors, "%s %s çubuğu" % [boot.id, stat], boot.rating(stat), 0.05, 1.0)
	Check.is_true(errors, "güç çubuğu sıralaması", _boot("guc").rating("power") > _boot("kontrol").rating("power") + 0.3)
	return errors
