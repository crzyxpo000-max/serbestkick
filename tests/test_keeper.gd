extends RefCounted
## Kaleci ve baraj.

const GOAL := BallSimulator.Outcome.GOAL
const SAVED := BallSimulator.Outcome.SAVED

## Falsosuz, kale düzleminde `target` noktasına nişanlanmış vuruş.
func _kick_at(spot: Vector3, speed: float, target: Vector2, side: float = 0.0) -> BallState:
	var azimuth := rad_to_deg(atan2(target.x - spot.x, spot.z))
	var elevation := ShotBuilder.solve_elevation(spot, speed, azimuth, target.y, PhysicsParams.new())
	return BallState.from_kick(spot, speed, elevation, azimuth, side)


func _sim(spot: Vector3, with_wall: bool, with_keeper: bool, kp: KeeperParams = null) -> BallSimulator:
	var params := kp if kp != null else KeeperParams.new()
	var sim := BallSimulator.new()
	var wall := Wall.new(params)
	wall.place(spot, Wall.default_count(spot))
	if with_wall:
		sim.wall = wall
	if with_keeper:
		sim.keeper = Keeper.new(params)
		sim.keeper.reset(-wall.near_post_sign * params.start_offset)
	return sim


func _play(sim: BallSimulator, kick: BallState) -> BallSimulator:
	sim.kick(kick)
	sim.run(8.0)
	return sim


func test_baraj_yerlesimi() -> Array[String]:
	var errors: Array[String] = []
	var kp := KeeperParams.new()
	var spot := Check.spot(24.0, 6.0)
	var wall := Wall.new(kp)
	wall.place(spot, 4)
	Check.is_true(errors, "barajda 4 oyuncu olmalı", wall.centres.size() == 4)
	Check.near(errors, "sağdan vuruşta yakın direk sağ direk", wall.near_post_sign, 1.0, 1e-9)
	var ball := Vector3(spot.x, 0, spot.z)
	var to_goal := (-ball).normalized()
	for centre in wall.centres:
		Check.near(errors, "baraj 9,15 m uzakta", (centre - ball).dot(to_goal), 9.15, 1e-3)
	Check.near(errors, "oyuncular omuz omuza", wall.centres[0].distance_to(wall.centres[1]), kp.wall_player_width, 1e-4)
	# Top–yakın direk çizgisi barajın içinden geçmeli.
	var post := Vector3(GoalFrame.HALF_WIDTH, 0, 0)
	var edge := ball + (post - ball) * (9.15 / (post - ball).dot(to_goal))
	var along_first := (edge - wall.centres[0]).dot(wall.axis)
	var along_last := (edge - wall.centres[3]).dot(wall.axis)
	Check.is_true(errors, "baraj yakın direği kapatmalı", absf(along_first) < kp.wall_player_width and absf(along_last) > absf(along_first))
	var left := Wall.new(kp)
	left.place(Check.spot(24.0, -6.0), 4)
	Check.near(errors, "soldan vuruşta yakın direk sol direk", left.near_post_sign, -1.0, 1e-9)
	Check.near(errors, "sol/sağ ayna yerleşim", left.centres[0].x, -wall.centres[0].x, 1e-3)
	return errors


func test_baraj_sayisi_mesafeye_gore() -> Array[String]:
	var errors: Array[String] = []
	Check.is_true(errors, "yakından 5", Wall.default_count(Check.spot(19.0)) == 5)
	Check.is_true(errors, "25 m'den 4", Wall.default_count(Check.spot(25.0)) == 4)
	Check.is_true(errors, "30 m'den 3", Wall.default_count(Check.spot(30.0)) == 3)
	Check.is_true(errors, "uzaktan 2", Wall.default_count(Check.spot(35.0)) == 2)
	return errors


func test_baraj_ziplar() -> Array[String]:
	var errors: Array[String] = []
	var kp := KeeperParams.new()
	var wall := Wall.new(kp)
	Check.near(errors, "vuruştan önce yerde", wall.jump_offset(0.05), 0.0, 1e-9)
	var peak := 0.0
	for i in 100:
		peak = maxf(peak, wall.jump_offset(i * 0.01))
	Check.in_range(errors, "zıplama yüksekliği (m)", peak, 0.3, 0.4)
	Check.near(errors, "sonra yere iner", wall.jump_offset(1.0), 0.0, 1e-9)
	return errors


func test_baraj_alcak_sutu_keser_yuksek_sut_gecer() -> Array[String]:
	var errors: Array[String] = []
	var spot := Check.spot(25.0)
	var probe := Wall.new()
	probe.place(spot, 4)
	var middle := (probe.centres[1] + probe.centres[2]) * 0.5
	# Barajın ortasından geçen doğrultuda kale düzlemindeki x
	var aim_x := middle.x * spot.z / (spot.z - middle.z)
	var low := _play(_sim(spot, true, false), _kick_at(spot, 30.0, Vector2(aim_x, 0.4)))
	Check.is_true(errors, "alçak şut baraja çarpmalı", low.hit_wall)
	Check.is_true(errors, "baraja çarpan şut gol olmamalı", low.outcome != GOAL)
	var high := _play(_sim(spot, true, false), _kick_at(spot, 24.0, Vector2(aim_x, 2.2)))
	Check.is_true(errors, "yüksek şut barajı aşmalı", not high.hit_wall)
	Check.is_true(errors, "barajı aşan şut kaleye gitmeli", high.outcome == GOAL)
	var open_side := _play(_sim(spot, true, false), _kick_at(spot, 30.0, Vector2(3.0, 0.4)))
	Check.is_true(errors, "barajın yanından geçen şut çarpmamalı", not open_side.hit_wall)
	return errors


func test_kaleci_tepki_suresinden_once_kipirdamaz() -> Array[String]:
	var errors: Array[String] = []
	var kp := KeeperParams.new()
	var spot := Check.spot(25.0)
	var sim := _sim(spot, false, true)
	var start := sim.keeper.hands
	sim.kick(_kick_at(spot, 28.0, Vector2(3.0, 2.0)))
	var previous := start
	while sim.outcome == BallSimulator.Outcome.NONE and sim.state.time < 5.0:
		sim.step()
		var hands := sim.keeper.hands
		if sim.state.time < kp.reaction_time - 1e-3 and hands != start:
			errors.append("kaleci %.2f sn'de hareket etti" % sim.state.time)
			break
		if hands.distance_to(previous) > kp.hand_speed * sim.params.time_step + 1e-4:
			errors.append("eller hız sınırını aştı")
			break
		if hands.distance_to(Vector2(sim.keeper.feet_x, 0)) > kp.reach + 1e-4:
			errors.append("eller erişim sınırını aştı")
			break
		previous = hands
	Check.is_true(errors, "kaleci topa doğru hareket etmiş olmalı", sim.keeper.hands.x > start.x + 1.0)
	return errors


func test_kolay_sut_kurtarilir() -> Array[String]:
	var errors: Array[String] = []
	var spot := Check.spot(25.0)
	for target: Vector2 in [Vector2(0.8, 1.2), Vector2(2.0, 1.6), Vector2(1.5, 0.4)]:
		var sim := _play(_sim(spot, false, true), _kick_at(spot, 21.0, target))
		Check.is_true(errors, "%s noktasına yavaş şut kurtarılmalı" % target, sim.hit_keeper and sim.outcome != GOAL)
	var caught := _play(_sim(spot, false, true), _kick_at(spot, 20.0, Vector2(1.0, 1.4)))
	Check.is_true(errors, "yavaş şutu kaleci tutmalı", caught.outcome == SAVED and caught.keeper.holding)
	Check.near(errors, "tutulan top durmalı", caught.state.velocity.length(), 0.0, 1e-9)
	return errors


func test_iyi_sut_gol_olur() -> Array[String]:
	var errors: Array[String] = []
	var spot := Check.spot(25.0)
	for target: Vector2 in [Vector2(3.3, 2.1), Vector2(-3.3, 2.1)]:
		var sim := _play(_sim(spot, false, true), _kick_at(spot, 29.0, target))
		Check.is_true(errors, "%s köşesine sert şut gol olmalı" % target, sim.outcome == GOAL)
	return errors


func test_sert_sut_tutulmaz_celinir() -> Array[String]:
	var errors: Array[String] = []
	var spot := Check.spot(20.0)
	var sim := _sim(spot, false, true)
	_play(sim, _kick_at(spot, 32.0, Vector2(sim.keeper.feet_x, 1.0)))
	Check.is_true(errors, "kaleciye gelen sert şut kaleciye çarpmalı", sim.hit_keeper)
	Check.is_true(errors, "sert şut tutulmamalı", not sim.keeper.holding and sim.outcome != SAVED)
	return errors


func _first_read_error(spin_read: float) -> float:
	var kp := KeeperParams.new()
	kp.spin_read = spin_read
	var spot := Check.spot(25.0)
	var kick := _kick_at(spot, 27.0, Vector2(-1.0, 1.8), 7.0)
	var truth := BallSimulator.new()
	truth.kick(kick)
	while truth.state.position.z > kp.depth:
		truth.step()
	var sim := _sim(spot, false, true, kp)
	sim.kick(kick)
	while not sim.keeper.has_target and sim.state.time < 2.0:
		sim.step()
	return absf(sim.keeper.target.x - truth.state.position.x)


func test_falso_kaleciyi_yaniltir() -> Array[String]:
	var errors: Array[String] = []
	Check.in_range(errors, "falsoyu yarım okuyan kalecinin ilk tahmin hatası (m)", _first_read_error(0.35), 0.4, 2.5)
	Check.in_range(errors, "falsoyu tam okuyan kalecinin hatası (m)", _first_read_error(1.0), 0.0, 0.05)
	return errors


func test_disari_giden_topa_uzanmaz() -> Array[String]:
	var errors: Array[String] = []
	var spot := Check.spot(25.0)
	var sim := _sim(spot, false, true)
	var start := sim.keeper.hands
	_play(sim, _kick_at(spot, 28.0, Vector2(9.0, 1.5)))
	Check.is_true(errors, "açığa giden topta kaleci yerinde kalmalı", sim.keeper.hands == start)
	Check.is_true(errors, "top auta gitmeli", sim.outcome == BallSimulator.Outcome.OUT and not sim.hit_keeper)
	return errors


func test_ayar_dosyasi_gecerli() -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KeeperParams.DATA_PATH))
	Check.is_true(errors, "data/keeper.json okunamadı", parsed is Dictionary)
	if parsed is Dictionary:
		var unknown := KeeperParams.new().apply(parsed)
		Check.is_true(errors, "bilinmeyen anahtarlar: %s" % [unknown], unknown.is_empty())
	Check.near(errors, "baraj mesafesi", KeeperParams.load_default().wall_distance, 9.15, 1e-9)
	return errors
