extends RefCounted
## Kale: gol kararı, direkler, üst direk ve file.

const OUT := BallSimulator.Outcome.OUT
const GOAL := BallSimulator.Outcome.GOAL

func test_kale_olculeri() -> Array[String]:
	var errors: Array[String] = []
	Check.near(errors, "kale genişliği", GoalFrame.WIDTH, 7.32, 1e-9)
	Check.near(errors, "kale yüksekliği", GoalFrame.HEIGHT, 2.44, 1e-9)
	return errors


func test_ortaya_sut_gol() -> Array[String]:
	var errors: Array[String] = []
	var sim := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0))
	Check.is_true(errors, "ortaya giden şut gol olmalı", sim.outcome == GOAL)
	Check.is_true(errors, "direğe değmemeli", not sim.hit_post)
	return errors


func test_disari_ve_ustten_giden_sut_gol_degil() -> Array[String]:
	var errors: Array[String] = []
	var wide := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 12.0))
	Check.is_true(errors, "yandan dışarı giden şut OUT olmalı", wide.outcome == OUT)
	Check.is_true(errors, "dışarı giden top direğin dışından geçmeli", wide.line_crossing.x > GoalFrame.POST_X)
	var over := Check.shoot(BallState.from_kick(Check.spot(25.0), 28.0, 22.0, 0.0))
	Check.is_true(errors, "üstten giden şut OUT olmalı", over.outcome == OUT)
	Check.is_true(errors, "üstten giden top üst direğin üstünden geçmeli", over.line_crossing.y > GoalFrame.BAR_Y)
	return errors


## Düz, falsosuz ve yerçekimsiz bir topu kale düzlemindeki (x, y) noktasına yollar.
func _aimed(x: float, y: float) -> BallSimulator:
	var p := PhysicsParams.new()
	p.gravity = 0.0
	p.air_density = 0.0
	var sim := BallSimulator.new(p)
	var state := BallState.new()
	state.position = Vector3(x, y, 5.0)
	state.velocity = Vector3(0, 0, -25.0)
	sim.kick(state)
	sim.run(5.0)
	return sim


func test_direk_gelis_acisina_gore_iceri_ya_da_disari_cevirir() -> Array[String]:
	var errors: Array[String] = []
	var x := GoalFrame.POST_X
	var inner := _aimed(x - 0.13, 1.0)
	Check.is_true(errors, "direğin iç yüzüne çarpan top direğe değmeli", inner.hit_post)
	Check.is_true(errors, "direğin iç yüzünden dönen top gol olmalı", inner.outcome == GOAL)
	var outer := _aimed(x + 0.13, 1.0)
	Check.is_true(errors, "direğin dış yüzüne çarpan top direğe değmeli", outer.hit_post)
	Check.is_true(errors, "direğin dış yüzünden dönen top dışarı gitmeli", outer.outcome == OUT)
	var centre := _aimed(x, 1.0)
	Check.is_true(errors, "direğin ortasına çarpan top geri dönmeli", centre.state.velocity.z > 0.0)
	Check.is_true(errors, "geri dönen top gol olmamalı", centre.outcome != GOAL)
	Check.in_range(errors, "direkten dönüş hızı (m/s)", centre.state.velocity.length(), 14.0, 18.0)
	var clear := _aimed(x - 0.2, 1.0)
	Check.is_true(errors, "direğin içinden geçen top direğe değmemeli", not clear.hit_post)
	Check.is_true(errors, "direğin hemen içinden geçen top gol olmalı", clear.outcome == GOAL)
	return errors


func test_ust_direk() -> Array[String]:
	var errors: Array[String] = []
	var under := _aimed(0.0, GoalFrame.BAR_Y - 0.13)
	Check.is_true(errors, "üst direğin altına çarpan top direğe değmeli", under.hit_post)
	Check.is_true(errors, "üst direğin altından dönen top gol olmalı", under.outcome == GOAL)
	var above := _aimed(0.0, GoalFrame.BAR_Y + 0.13)
	Check.is_true(errors, "üst direğin üstüne çarpan top direğe değmeli", above.hit_post)
	Check.is_true(errors, "üst direğin üstünden seken top dışarı gitmeli", above.outcome == OUT)
	return errors


func test_gol_icin_topun_tamami_cizgiyi_gecmeli() -> Array[String]:
	var errors: Array[String] = []
	var sim := BallSimulator.new()
	sim.kick(BallState.from_kick(Check.spot(25.0), 28.0, 14.0, 0.0))
	while not sim.crossed_line and sim.state.time < 5.0:
		sim.step()
	Check.is_true(errors, "merkez çizgideyken henüz gol olmamalı", sim.outcome == BallSimulator.Outcome.NONE)
	sim.run()
	Check.is_true(errors, "top tamamen geçince gol olmalı", sim.outcome == GOAL)
	Check.is_true(errors, "gol anında top çizginin arkasında olmalı", sim.state.position.z <= -sim.params.radius)
	return errors


func test_file_topu_tutar() -> Array[String]:
	var errors: Array[String] = []
	var sim := Check.shoot(BallState.from_kick(Check.spot(20.0), 33.0, 6.0, 3.0, 4.0))
	Check.is_true(errors, "sert şut gol olmalı", sim.outcome == GOAL)
	var entry_speed := sim.state.velocity.length()
	for i in 240 * 3:
		sim.step()
		var pos := sim.state.position
		if pos.z < -sim.params.net_depth - 1e-6 or pos.z > 0.0 or absf(pos.x) > GoalFrame.HALF_WIDTH or pos.y > GoalFrame.HEIGHT:
			errors.append("top fileden çıktı: %s" % pos)
			break
	Check.is_true(errors, "file topu yavaşlatmalı", sim.state.velocity.length() < entry_speed * 0.1)
	Check.is_true(errors, "top filede yere inmeli", sim.state.position.y < 0.3)
	return errors
