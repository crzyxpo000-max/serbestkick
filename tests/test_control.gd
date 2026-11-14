extends RefCounted
## Kontrol: kaydırma ölçümü, vuruş kurulumu, vuruş noktası, dönüşsüz vuruş, havada falso.

const H := 720.0

## p0'dan p1'e, `bulge` kadar (kirişe oranla, artı = sağa) bombeli, `duration` süren kaydırma.
func _swipe(p0: Vector2, p1: Vector2, duration: float, bulge: float = 0.0, cp: ControlParams = null) -> Swipe:
	var points := PackedVector2Array()
	var times := PackedFloat64Array()
	var chord := p1 - p0
	var right := Vector2(-chord.y, chord.x)
	for i in 21:
		var t := i / 20.0
		points.append(p0 + chord * t + right * (bulge * 4.0 * t * (1.0 - t)))
		times.append(duration * t)
	return Swipe.analyze(points, times, H, cp if cp != null else ControlParams.new())


func _no_knuckle() -> ControlParams:
	var cp := ControlParams.new()
	cp.knuckle_radius = -1.0
	return cp


func _cross(kick: BallState) -> BallSimulator:
	return Check.shoot(kick)


func test_duz_kaydirma_olcumu() -> Array[String]:
	var errors: Array[String] = []
	var swipe := _swipe(Vector2(640, 600), Vector2(700, 300), 0.2)
	Check.is_true(errors, "kaydırma geçerli olmalı", swipe.valid)
	Check.near(errors, "eğrilik", swipe.curvature, 0.0, 1e-4)
	Check.near(errors, "hız (ekran/s)", swipe.speed, Vector2(60, 300).length() / H / 0.2, 1e-3)
	Check.near(errors, "çıkış noktası bitişle aynı (x)", swipe.launch_point.x, 700.0, 0.5)
	Check.near(errors, "çıkış noktası bitişle aynı (y)", swipe.launch_point.y, 300.0, 0.5)
	return errors


func test_kisa_kaydirma_vurus_sayilmaz() -> Array[String]:
	var errors: Array[String] = []
	Check.is_true(errors, "çok kısa kaydırma geçersiz olmalı", not _swipe(Vector2(640, 600), Vector2(645, 570), 0.1).valid)
	var single := Swipe.analyze(PackedVector2Array([Vector2(1, 1)]), PackedFloat64Array([0.0]), H, ControlParams.new())
	Check.is_true(errors, "tek nokta geçersiz olmalı", not single.valid)
	return errors


func test_bekleyip_firlatinca_yalniz_son_bolum_sayilir() -> Array[String]:
	var errors: Array[String] = []
	var points := PackedVector2Array([Vector2(640, 600), Vector2(640, 600)])
	var times := PackedFloat64Array([0.0, 2.0])
	for i in range(1, 11):
		points.append(Vector2(640, 600 - 30 * i))
		times.append(2.0 + 0.02 * i)
	var swipe := Swipe.analyze(points, times, H, ControlParams.new())
	Check.is_true(errors, "kaydırma geçerli olmalı", swipe.valid)
	Check.in_range(errors, "bekleme hızı düşürmemeli (ekran/s)", swipe.speed, 1.8, 2.3)
	return errors


func test_yay_egriligi_ve_cikis_yonu() -> Array[String]:
	var errors: Array[String] = []
	var right := _swipe(Vector2(640, 600), Vector2(640, 300), 0.2, 0.15)
	var left := _swipe(Vector2(640, 600), Vector2(640, 300), 0.2, -0.15)
	Check.near(errors, "sağa bombeli yayın eğriliği", right.curvature, 0.15, 0.01)
	Check.near(errors, "sola bombeli yayın eğriliği", left.curvature, -0.15, 0.01)
	Check.is_true(errors, "sağa bombeli yay sağa çıkmalı", right.launch_point.x > 640.0 + 50.0)
	Check.near(errors, "ayna simetrisi", left.launch_point.x - 640.0, -(right.launch_point.x - 640.0), 0.5)
	return errors


func test_duz_vurus_nisan_alinan_noktaya_gider() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var cp := _no_knuckle()
	var fast := _swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.0, cp)
	for case: Array in [[25.0, 0.0, Vector2(2.5, 1.8)], [20.0, -6.0, Vector2(-3.0, 0.6)], [32.0, 8.0, Vector2(0.0, 2.2)]]:
		var spot := Check.spot(case[0], case[1])
		var target: Vector2 = case[2]
		var kick := ShotBuilder.build(fast, target, spot, Vector2.ZERO, cp, pp)
		var sim := _cross(kick)
		var label := "%d m'den %s" % [case[0], target]
		Check.near(errors, label + " x", sim.line_crossing.x, target.x, 0.05)
		Check.near(errors, label + " y", sim.line_crossing.y, target.y, 0.05)
		Check.is_true(errors, label + " gol olmalı", sim.outcome == BallSimulator.Outcome.GOAL)
	return errors


func test_kaydirma_hizi_gucu_belirler() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var cp := ControlParams.new()
	var target := Vector2(0, 1.5)
	var speeds: Array[float] = []
	for duration: float in [2.0, 0.4, 0.2, 0.12, 0.02]:
		cp.swipe_window = 5.0
		var swipe := _swipe(Vector2(640, 600), Vector2(640, 300), duration, 0.0, cp)
		speeds.append(ShotBuilder.build(swipe, target, Check.spot(25.0), Vector2.ZERO, cp, pp).velocity.length())
	Check.near(errors, "en yavaş kaydırma en düşük güç", speeds[0], cp.min_speed, 1e-3)
	Check.near(errors, "en hızlı kaydırma en yüksek güç", speeds[4], cp.max_speed, 1e-3)
	for i in range(1, speeds.size()):
		Check.is_true(errors, "hızlı kaydırma daha sert olmalı (%d)" % i, speeds[i] >= speeds[i - 1])
	Check.is_true(errors, "ara hızlar ara güç vermeli", speeds[2] > cp.min_speed + 2.0 and speeds[2] < cp.max_speed - 2.0)
	return errors


func test_vurus_noktasi() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var cp := ControlParams.new()
	var swipe := _swipe(Vector2(640, 600), Vector2(640, 300), 0.15)
	var target := Vector2(0.0, 1.2)
	var spot := Check.spot(25.0)
	var centre := ShotBuilder.build(swipe, target, spot, Vector2.ZERO, cp, pp)
	var low := ShotBuilder.build(swipe, target, spot, Vector2(0, -0.8), cp, pp)
	var high := ShotBuilder.build(swipe, target, spot, Vector2(0, 0.8), cp, pp)
	var right := ShotBuilder.build(swipe, target, spot, Vector2(0.8, 0), cp, pp)
	var left := ShotBuilder.build(swipe, target, spot, Vector2(-0.8, 0), cp, pp)
	Check.near(errors, "tam orta: dönüş yok", centre.spin.length(), 0.0, 1e-6)
	Check.is_true(errors, "tam orta: dönüşsüz vuruş", centre.knuckle > 0.0)
	Check.is_true(errors, "tam orta en sert vuruş olmalı", centre.velocity.length() > low.velocity.length() + 1.0)
	Check.is_true(errors, "kenardan vuruş dönüşsüz olmamalı", low.knuckle == 0.0 and right.knuckle == 0.0)
	var y_centre := _cross(centre).line_crossing.y
	Check.is_true(errors, "alttan vuruş topu yükseltmeli", _cross(low).line_crossing.y > y_centre + 1.0)
	Check.is_true(errors, "üstten vuruş topu alçaltmalı", _cross(high).line_crossing.y < y_centre - 0.5)
	var x_right := _cross(right).line_crossing.x
	Check.in_range(errors, "topun sağına vuruş sola kıvırmalı (m)", x_right, -3.0, -0.5)
	Check.near(errors, "sol/sağ simetri", _cross(left).line_crossing.x, -x_right, 1e-3)
	var outside := ShotBuilder.build(swipe, target, spot, Vector2(3, 0), cp, pp)
	var edge := ShotBuilder.build(swipe, target, spot, Vector2(1, 0), cp, pp)
	Check.near(errors, "disk dışındaki vuruş noktası kenara çekilmeli", outside.spin.length(), edge.spin.length(), 1e-4)
	return errors


func test_egri_kaydirma_falso_verir() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var cp := ControlParams.new()
	var spot := Check.spot(25.0)
	var target := Vector2(2.0, 1.5)
	var straight := _cross(ShotBuilder.build(_swipe(Vector2(640, 600), Vector2(640, 300), 0.15), target, spot, Vector2(0, -0.3), cp, pp))
	var arc := ShotBuilder.build(_swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.25), target, spot, Vector2(0, -0.3), cp, pp)
	Check.in_range(errors, "sağa bombeli yay sola kıvırmalı (m)", _cross(arc).line_crossing.x - straight.line_crossing.x, -3.0, -0.8)
	var extreme := ShotBuilder.build(_swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.6), target, spot, Vector2(1, 0), cp, pp)
	Check.is_true(errors, "yan falso üst sınırı aşmamalı", absf(extreme.spin.y) / TAU <= cp.max_side_spin + 1e-3)
	var shaky := ShotBuilder.build(_swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.03), target, spot, Vector2(0, -0.3), cp, pp)
	Check.near(errors, "el titremesi kadar eğrilik falso vermemeli", shaky.spin.y, 0.0, 1e-6)
	Check.near(errors, "el titremesi nişanı kaydırmamalı", _swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.03).launch_point.x, 640.0, 0.5)
	var curved_centre := ShotBuilder.build(_swipe(Vector2(640, 600), Vector2(640, 300), 0.15, 0.12), target, spot, Vector2.ZERO, cp, pp)
	Check.is_true(errors, "eğri kaydırma dönüşsüz vuruş vermemeli", curved_centre.knuckle == 0.0 and curved_centre.spin.length() > 1.0)
	return errors


func test_yetismeyen_sut_kisa_kalir() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var elevation := ShotBuilder.solve_elevation(Check.spot(35.0), 12.0, 0.0, 2.0, pp)
	Check.near(errors, "yetişmeyen şutta en yüksek açı", elevation, ShotBuilder.MAX_ELEVATION, 1e-6)
	var reachable := ShotBuilder.solve_elevation(Check.spot(25.0), 28.0, 0.0, 1.3, pp)
	Check.in_range(errors, "25 m, 28 m/s, 1,3 m için açı (derece)", reachable, 12.0, 16.0)
	return errors


func test_donussuz_vurus_yalpalar() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var cp := ControlParams.new()
	var swipe := _swipe(Vector2(640, 600), Vector2(640, 300), 0.12)
	var target := Vector2(0.0, 1.4)
	var kick := ShotBuilder.build(swipe, target, Check.spot(30.0), Vector2.ZERO, cp, pp)
	var a := _cross(kick)
	var b := _cross(kick)
	var drift := a.line_crossing.distance_to(target)
	Check.in_range(errors, "yalpalama sapması (m)", drift, 0.05, 1.2)
	Check.is_true(errors, "aynı vuruş aynı yalpalamalı", a.line_crossing == b.line_crossing)
	var spinning := kick.duplicate_state()
	spinning.spin = Vector3.UP * 40.0
	Check.near(errors, "dönen top yalpalamamalı", BallFlight.knuckle_acceleration(spinning, pp, Vector3.ZERO).length(), 0.0, 1e-9)
	var wobble := BallFlight.knuckle_acceleration(kick, pp, Vector3.ZERO)
	Check.near(errors, "yalpalama hıza dik olmalı", wobble.normalized().dot(kick.velocity.normalized()), 0.0, 1e-4)
	return errors


## Sağa falsolu vuruşun, falsosuz aynı vuruşa göre kale çizgisindeki kıvrılması (m).
func _aftertouch_run(drag: Vector2, cp: ControlParams, late: bool = false) -> float:
	var straight := Check.shoot(BallState.from_kick(Check.spot(25.0), 27.0, 15.0, -5.0)).line_crossing.x
	var sim := BallSimulator.new()
	var kick := BallState.from_kick(Check.spot(25.0), 27.0, 15.0, -5.0, 6.0)
	sim.kick(kick)
	var touch := Aftertouch.new(cp)
	touch.begin(kick)
	while sim.outcome == BallSimulator.Outcome.NONE and sim.state.time < 10.0:
		if not late or sim.state.position.z < 10.0:
			touch.apply(sim, drag)
		sim.step()
	return sim.line_crossing.x - straight


func test_havada_falso_sinirli() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	var none := _aftertouch_run(Vector2.ZERO, cp)
	var more := _aftertouch_run(Vector2(5.0, 0), cp)
	var less := _aftertouch_run(Vector2(-5.0, 0), cp)
	var small := _aftertouch_run(Vector2(0.05, 0), cp)
	Check.is_true(errors, "falso yönüne sürüklemek daha çok kıvırmalı", more > none + 0.1)
	Check.is_true(errors, "ters yöne sürüklemek daha az kıvırmalı", less < none - 0.1)
	Check.is_true(errors, "küçük sürükleme küçük etki vermeli", small > none and small < more)
	Check.in_range(errors, "havada falsonun en büyük etkisi (m)", more - none, 0.1, 0.6)
	Check.in_range(errors, "falsolu vuruşun kıvrılması (m)", none, 1.2, 3.0)
	Check.is_true(errors, "ters sürükleme falsonun yönünü çevirmemeli", less > 0.7 * none)
	Check.near(errors, "uçuşun ikinci yarısında etkisiz olmalı", _aftertouch_run(Vector2(5.0, 0), cp, true), none, 1e-6)
	var off := ControlParams.new()
	off.aftertouch_enabled = 0.0
	Check.near(errors, "kapalıyken etkisiz olmalı", _aftertouch_run(Vector2(5.0, 0), off), none, 1e-6)
	return errors


func test_havada_falso_donus_orani() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	var sim := BallSimulator.new()
	var kick := BallState.from_kick(Check.spot(25.0), 27.0, 15.0, 0.0, -6.0, 3.0)
	sim.kick(kick)
	var touch := Aftertouch.new(cp)
	touch.begin(kick)
	var before := sim.state.spin
	touch.apply(sim, Vector2(-9, 9))
	touch.apply(sim, Vector2(-9, 9))
	Check.near(errors, "en fazla %20 artış", sim.state.spin.length() / before.length(), 1.2, 1e-4)
	touch.apply(sim, Vector2(9, -9))
	Check.near(errors, "en fazla %20 azalış", sim.state.spin.length() / before.length(), 0.8, 1e-4)
	Check.is_true(errors, "dönüş ekseni değişmemeli", sim.state.spin.normalized().dot(before.normalized()) > 0.9999)
	var still := BallSimulator.new()
	var flat := BallState.from_kick(Check.spot(25.0), 27.0, 15.0, 0.0)
	still.kick(flat)
	touch.begin(flat)
	touch.apply(still, Vector2(9, 0))
	Check.near(errors, "dönüşsüz topa etki etmemeli", still.state.spin.length(), 0.0, 1e-9)
	return errors


func test_ayar_dosyasi_gecerli() -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ControlParams.DATA_PATH))
	Check.is_true(errors, "data/controls.json okunamadı", parsed is Dictionary)
	if parsed is Dictionary:
		var unknown := ControlParams.new().apply(parsed)
		Check.is_true(errors, "bilinmeyen anahtarlar: %s" % [unknown], unknown.is_empty())
	Check.near(errors, "havada falso sınırı", ControlParams.load_default().aftertouch_limit, 0.2, 1e-9)
	return errors
