extends RefCounted
## Zemin: sekme, sürtünme, ıslak saha, yuvarlanma ve durma.

func _drop(height: float, wet: bool = false) -> BallSimulator:
	var conditions := PitchConditions.new()
	conditions.wet = wet
	var sim := BallSimulator.new(null, conditions)
	var state := BallState.new()
	state.position = Vector3(0, height, 30)
	sim.kick(state)
	return sim


func _peak_after_first_bounce(sim: BallSimulator) -> float:
	while sim.bounces == 0 and sim.state.time < 5.0:
		sim.step()
	var peak := 0.0
	while sim.state.velocity.y > 0.0 and sim.state.time < 5.0:
		sim.step()
		peak = maxf(peak, sim.state.position.y)
	return peak - sim.params.radius


func test_birakilan_top_daha_alcaga_seker() -> Array[String]:
	var errors: Array[String] = []
	var peak := _peak_after_first_bounce(_drop(2.11))
	# Sekme katsayısı 0,6 → yükseklik 0,36 katı; hava direnci biraz daha düşürür.
	Check.in_range(errors, "2 m'den bırakılan topun sekme yüksekliği (m)", peak, 0.62, 0.72)
	var wet_peak := _peak_after_first_bounce(_drop(2.11, true))
	Check.is_true(errors, "ıslak sahada top daha az sekmeli", wet_peak < peak)
	return errors


func test_her_sekmede_hiz_kaybeder_ve_sonunda_durur() -> Array[String]:
	var errors: Array[String] = []
	var sim := BallSimulator.new()
	sim.kick(BallState.from_kick(Vector3(0, 0.11, 60), 18.0, 25.0, 0.0))
	var speeds: Array[float] = []
	var seen := 0
	while not sim.resting and sim.state.time < 120.0:
		sim.step()
		if sim.bounces > seen:
			seen = sim.bounces
			speeds.append(sim.state.velocity.length())
	Check.is_true(errors, "top en az 3 kez sekmeli", speeds.size() >= 3)
	for i in range(1, speeds.size()):
		if speeds[i] >= speeds[i - 1]:
			errors.append("%d. sekmede hız azalmadı" % (i + 1))
	Check.is_true(errors, "top sonunda durmalı", sim.resting)
	Check.is_true(errors, "kaleye varmadan duran top STOPPED olmalı", sim.outcome == BallSimulator.Outcome.STOPPED)
	Check.near(errors, "duran top yerde olmalı", sim.state.position.y, sim.params.radius, 1e-6)
	Check.is_true(errors, "top yerin altına inmemeli", sim.state.position.y >= sim.params.radius - 1e-6)
	return errors


func test_islak_sahada_top_kayar() -> Array[String]:
	var errors: Array[String] = []
	var kick := BallState.from_kick(Check.spot(25.0), 22.0, 2.0, 0.0)
	var wet := PitchConditions.new()
	wet.wet = true
	var on_dry := Check.shoot(kick)
	var on_wet := Check.shoot(kick, wet)
	Check.is_true(errors, "yerden şut kaleye varmadan sekmeli", on_dry.bounces >= 1)
	Check.is_true(errors, "ıslak sahada top çizgiye daha hızlı varmalı", on_wet.line_speed > on_dry.line_speed + 0.5)
	return errors


func test_sekme_falsoyu_hiza_cevirir() -> Array[String]:
	var errors: Array[String] = []
	var p := PhysicsParams.new()
	# Aynı düşüş; biri üst falsolu, biri alt falsolu.
	var top := BallState.from_kick(Vector3(0, 0.11, 30), 10.0, -30.0, 0.0, 0.0, 8.0)
	var back := BallState.from_kick(Vector3(0, 0.11, 30), 10.0, -30.0, 0.0, 0.0, -8.0)
	BallCollision.bounce(top, Vector3.UP, p.ground_restitution, p.ground_friction, p.radius)
	BallCollision.bounce(back, Vector3.UP, p.ground_restitution, p.ground_friction, p.radius)
	Check.is_true(errors, "üst falsolu top sekince ileri fırlamalı", -top.velocity.z > -back.velocity.z + 1.0)
	Check.near(errors, "dikey hız sekme katsayısıyla dönmeli", top.velocity.y, 0.6 * 10.0 * sin(deg_to_rad(30.0)), 1e-6)
	var away := BallState.new()
	away.velocity = Vector3(0, 3, -5)
	Check.is_true(errors, "uzaklaşan top sekmemeli", not BallCollision.bounce(away, Vector3.UP, 0.6, 0.5, p.radius))
	return errors
