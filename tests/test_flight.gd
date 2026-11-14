extends RefCounted
## Uçuş formülleri: yerçekimi, hava direnci, Magnus, dönüş kaybı, rüzgar.

func test_havasiz_ortamda_parabol() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	p.air_density = 0.0
	var state := BallState.from_kick(Vector3(0, 5, 0), 20.0, 30.0, 0.0)
	var t := 1.0
	for i in 240:
		BallFlight.integrate(state, p.time_step, p, Vector3.ZERO)
	var vy := 20.0 * sin(deg_to_rad(30.0))
	var vz := -20.0 * cos(deg_to_rad(30.0))
	Check.near(errors, "y", state.position.y, 5.0 + vy * t - 0.5 * 9.81 * t * t, 1e-3)
	Check.near(errors, "z", state.position.z, vz * t, 1e-3)
	Check.near(errors, "süre", state.time, t, 1e-6)
	return errors


func test_hava_direnci_hizin_karesiyle_artar() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	p.gravity = 0.0
	var slow := BallFlight.acceleration(Vector3(0, 0, -15), Vector3.ZERO, p, Vector3.ZERO).length()
	var fast := BallFlight.acceleration(Vector3(0, 0, -30), Vector3.ZERO, p, Vector3.ZERO).length()
	Check.near(errors, "30 m/s ile 15 m/s direnç oranı", fast / slow, 4.0, 1e-6)
	# ½·ρ·Cd·A·v² / m = 0,5·1,225·0,2·π·0,11²·900 / 0,43
	Check.near(errors, "30 m/s'de yavaşlama", fast, 9.746, 0.01)
	return errors


func test_25_metreden_28_ms_sut_kaleye_yavaslayarak_varir() -> Array[String]:
	var errors: Array[String] = []
	var sim := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0))
	Check.is_true(errors, "top kale çizgisine ulaşmalı", sim.crossed_line)
	Check.in_range(errors, "çizgide hız (m/s)", sim.line_speed, 20.0, 23.0)
	Check.in_range(errors, "uçuş süresi (s)", sim.line_time, 0.95, 1.2)
	Check.in_range(errors, "çizgide yükseklik (m)", sim.line_crossing.y, 0.8, 1.8)
	Check.near(errors, "falsosuz şut yana sapmamalı", sim.line_crossing.x, 0.0, 1e-6)
	return errors


func test_yan_falso_topu_kivirir() -> Array[String]:
	var errors: Array[String] = []
	# Plandaki örnek: 25 m, 28 m/s, 8 tur/sn yan falso.
	var right := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0, 8.0))
	var left := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0, -8.0))
	var half := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0, 4.0))
	Check.in_range(errors, "8 tur/sn sağa sapma (m)", right.line_crossing.x, 2.3, 3.6)
	Check.near(errors, "sol falso ayna görüntüsü olmalı", left.line_crossing.x, -right.line_crossing.x, 1e-6)
	Check.in_range(errors, "4 tur/sn sapma (m)", half.line_crossing.x, 1.0, 2.0)
	Check.is_true(errors, "daha çok dönüş daha çok kıvırmalı", right.line_crossing.x > half.line_crossing.x)
	return errors


func test_ust_falso_daldirir_alt_falso_suzdurur() -> Array[String]:
	var errors: Array[String] = []
	var flat := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 16.0, 0.0))
	var top := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 16.0, 0.0, 0.0, 6.0))
	var back := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 16.0, 0.0, 0.0, -6.0))
	Check.is_true(errors, "üst falso topu alçaltmalı", top.line_crossing.y < flat.line_crossing.y - 1.0)
	Check.is_true(errors, "alt falso topu yükseltmeli", back.line_crossing.y > flat.line_crossing.y + 1.0)
	Check.near(errors, "dikey falso yana saptırmamalı", top.line_crossing.x, 0.0, 1e-6)
	return errors


func test_magnus_kuvveti_ust_sinirla_kisitli() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	p.gravity = 0.0
	p.drag_coefficient = 0.0
	var v := Vector3(0, 0, -20)
	var a_high := BallFlight.acceleration(v, Vector3.UP * 500.0, p, Vector3.ZERO)
	var a_higher := BallFlight.acceleration(v, Vector3.UP * 1000.0, p, Vector3.ZERO)
	Check.near(errors, "sınırın üstünde kuvvet artmamalı", a_higher.length(), a_high.length(), 1e-9)
	Check.near(errors, "Magnus hıza dik olmalı", a_high.dot(v), 0.0, 1e-6)
	var along := BallFlight.acceleration(v, Vector3(0, 0, -60), p, Vector3.ZERO)
	Check.near(errors, "hız eksenindeki dönüş kuvvet üretmemeli", along.length(), 0.0, 1e-9)
	return errors


func test_donus_ucarken_azalir() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	var state := BallState.from_kick(Vector3(0, 50, 0), 25.0, 10.0, 0.0, 8.0)
	var initial := state.spin.length()
	var previous := initial
	for i in 240:
		BallFlight.integrate(state, p.time_step, p, Vector3.ZERO)
		if state.spin.length() > previous:
			errors.append("dönüş arttı (adım %d)" % i)
			break
		previous = state.spin.length()
	Check.near(errors, "1 sn sonra dönüş oranı", state.spin.length() / initial, exp(-p.spin_decay), 1e-4)
	Check.in_range(errors, "1 sn'de dönüş kaybı (%)", (1.0 - state.spin.length() / initial) * 100.0, 5.0, 25.0)
	return errors


func test_ruzgar_topu_iter() -> Array[String]:
	var errors: Array[String] = []
	var kick := BallState.from_kick(Check.spot(25.0), 28.0, 12.0, 0.0)
	var calm := Check.shoot(kick)
	var tail := PitchConditions.new()
	tail.wind = Vector3(0, 0, -10)
	var head := PitchConditions.new()
	head.wind = Vector3(0, 0, 10)
	var cross := PitchConditions.new()
	cross.wind = Vector3(10, 0, 0)
	var with_tail := Check.shoot(kick, tail)
	var with_head := Check.shoot(kick, head)
	var with_cross := Check.shoot(kick, cross)
	Check.is_true(errors, "arkadan rüzgar topu hızlandırmalı", with_tail.line_speed > calm.line_speed + 1.0)
	Check.is_true(errors, "karşıdan rüzgar topu yavaşlatmalı", with_head.line_speed < calm.line_speed - 1.0)
	Check.in_range(errors, "10 m/s yan rüzgarda sapma (m)", with_cross.line_crossing.x, 0.5, 2.5)
	return errors


func test_ucusta_enerji_artmaz() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	var state := BallState.from_kick(Vector3(0, 0.11, 30), 32.0, 20.0, 5.0, 9.0, 3.0)
	var energy := 0.5 * state.velocity.length_squared() + p.gravity * state.position.y
	for i in 360:
		BallFlight.integrate(state, p.time_step, p, Vector3.ZERO)
		var now := 0.5 * state.velocity.length_squared() + p.gravity * state.position.y
		if now > energy + 1e-6:
			errors.append("enerji arttı (adım %d): %.6f → %.6f" % [i, energy, now])
			break
		energy = now
	return errors


func test_ayni_vurus_ayni_sonucu_verir() -> Array[String]:
	var errors: Array[String] = []
	var kick := BallState.from_kick(Check.spot(27.0, 3.0), 29.0, 13.0, -4.0, 7.0, 2.0)
	var a := Check.shoot(kick)
	var b := Check.shoot(kick)
	Check.is_true(errors, "iki benzetim aynı noktada bitmeli", a.state.position == b.state.position)
	Check.is_true(errors, "kare süresi sonucu değiştirmemeli", _framed(kick, 1.0 / 60.0) == _framed(kick, 1.0 / 144.0))
	return errors


func _framed(kick: BallState, frame: float) -> Vector2:
	var sim := BallSimulator.new()
	sim.kick(kick)
	while sim.outcome == BallSimulator.Outcome.NONE and sim.state.time < 30.0:
		sim.advance(frame)
	return sim.line_crossing


func test_ayar_dosyasi_gecerli() -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PhysicsParams.DATA_PATH))
	Check.is_true(errors, "data/physics.json okunamadı", parsed is Dictionary)
	if parsed is Dictionary:
		var unknown := PhysicsParams.new().apply(parsed)
		Check.is_true(errors, "bilinmeyen anahtarlar: %s" % [unknown], unknown.is_empty())
	var p := PhysicsParams.load_default()
	Check.near(errors, "top kütlesi", p.mass, 0.43, 1e-9)
	Check.near(errors, "top yarıçapı", p.radius, 0.11, 1e-9)
	Check.near(errors, "yerçekimi", p.gravity, 9.81, 1e-9)
	return errors
