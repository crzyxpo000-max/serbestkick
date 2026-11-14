extends RefCounted
## Maç akışı: üretim, skor, serbest vuruşlar, baskı.

func _match(seed_value: int, mp: MatchParams = null) -> Match:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Match.generate(rng, Match.load_teams(), Match.load_commentary(), mp if mp != null else MatchParams.new())


func test_veri_dosyalari() -> Array[String]:
	var errors: Array[String] = []
	Check.is_true(errors, "en az 6 takım olmalı", Match.load_teams().size() >= 6)
	var commentary := Match.load_commentary()
	for kind: String in ["kickoff", "filler", "goal_us", "goal_them", "foul", "player_goal", "player_miss", "halftime", "fulltime"]:
		Check.is_true(errors, "spiker yazısı eksik: " + kind, commentary.has(kind) and not (commentary[kind] as Array).is_empty())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MatchParams.DATA_PATH))
	Check.is_true(errors, "data/match.json okunamadı", parsed is Dictionary)
	if parsed is Dictionary:
		var unknown := MatchParams.new().apply(parsed)
		Check.is_true(errors, "bilinmeyen anahtarlar: %s" % [unknown], unknown.is_empty())
	return errors


func test_ayni_tohum_ayni_maci_uretir() -> Array[String]:
	var errors: Array[String] = []
	var a := _match(42)
	var b := _match(42)
	Check.is_true(errors, "takımlar aynı olmalı", a.us == b.us and a.them == b.them)
	Check.is_true(errors, "olay sayısı aynı olmalı", a.events.size() == b.events.size())
	Check.is_true(errors, "skor aynı olmalı", a.final_score() == b.final_score())
	var differs := false
	for seed_value in range(1, 6):
		var other := _match(seed_value)
		if other.us != a.us or other.events.size() != a.events.size():
			differs = true
	Check.is_true(errors, "farklı tohum farklı maç üretmeli", differs)
	return errors


func test_mac_kurallari() -> Array[String]:
	var errors: Array[String] = []
	var mp := MatchParams.new()
	for seed_value in 60:
		var m := _match(seed_value)
		var label := "tohum %d: " % seed_value
		Check.is_true(errors, label + "takımlar farklı olmalı", m.us != m.them and not m.us.is_empty())
		Check.is_true(errors, label + "en fazla 2 serbest vuruş", m.free_kicks.size() <= 2)
		var previous := 0
		for event in m.events:
			Check.is_true(errors, label + "olaylar dakikaya göre sıralı ve 1–90 arası olmalı",
					event.minute >= previous and event.minute >= 1 and event.minute <= Match.LENGTH)
			Check.is_true(errors, label + "olay yazısı boş olmamalı", not event.text.is_empty())
			Check.is_true(errors, label + "yazıda doldurulmamış yer tutucu kalmamalı", not event.text.contains("{"))
			previous = event.minute
		var last_kick := -100
		for kick in m.free_kicks:
			Check.is_true(errors, label + "serbest vuruş erken çıkmamalı", kick.minute >= int(mp.first_minute))
			Check.is_true(errors, label + "serbest vuruşlar arası boşluk", kick.minute - last_kick >= int(mp.min_gap))
			Check.in_range(errors, label + "mesafe (m)", kick.distance(), mp.distance_min, mp.distance_max)
			Check.is_true(errors, label + "baraj sayısı mesafeye uygun olmalı", kick.wall_count == Wall.default_count(kick.spot))
			Check.is_true(errors, label + "top sahada, kalenin önünde olmalı", kick.spot.z > 10.0 and kick.spot.y == 0.0)
			last_kick = kick.minute
		if m.weather == Match.Weather.CLEAR:
			Check.is_true(errors, label + "açık havada rüzgar ve yağmur olmamalı", m.conditions.wind == Vector3.ZERO and not m.conditions.wet)
		elif m.weather == Match.Weather.RAIN:
			Check.is_true(errors, label + "yağmurda saha ıslak olmalı", m.conditions.wet)
		else:
			Check.in_range(errors, label + "rüzgar (m/s)", m.conditions.wind.length(), mp.wind_min - 1e-3, mp.wind_max + 1e-3)
		if errors.size() > 5:
			break
	return errors


func test_cesitlilik() -> Array[String]:
	var errors: Array[String] = []
	var kicks := {0: 0, 1: 0, 2: 0}
	var weathers := {}
	var importances := {}
	var goals := 0
	var forward := 0
	var total := 400
	for seed_value in total:
		var m := _match(seed_value + 1000)
		kicks[m.free_kicks.size()] += 1
		weathers[m.weather] = true
		importances[m.importance] = true
		var score := m.final_score()
		goals += score.x + score.y
		for kick in m.free_kicks:
			if kick.keeper_forward:
				forward += 1
	Check.in_range(errors, "serbest vuruşsuz maç oranı", kicks[0] / float(total), 0.04, 0.18)
	Check.in_range(errors, "iki serbest vuruşlu maç oranı", kicks[2] / float(total), 0.25, 0.45)
	Check.is_true(errors, "üç hava durumu da çıkmalı", weathers.size() == 3)
	Check.is_true(errors, "üç maç türü de çıkmalı", importances.size() == 3)
	Check.in_range(errors, "maç başına otomatik gol", goals / float(total), 1.8, 3.0)
	Check.is_true(errors, "bazı kaleciler öne çıkmalı", forward > 20)
	return errors


func test_skor_ve_oyuncu_golu() -> Array[String]:
	var errors: Array[String] = []
	var m: Match = null
	for seed_value in 200:
		m = _match(seed_value)
		if m.free_kicks.size() == 2:
			break
	Check.is_true(errors, "iki serbest vuruşlu maç bulunmalı", m.free_kicks.size() == 2)
	var before := m.final_score()
	Check.is_true(errors, "başlangıçta skor 0–0", m.score_at(0) == Vector2i.ZERO)
	var first := m.free_kicks[0]
	var at_kick := m.score_at(first.minute)
	m.record_shot(first, true)
	m.record_shot(m.free_kicks[1], false)
	Check.is_true(errors, "oyuncunun golü skora eklenmeli", m.final_score() == before + Vector2i(1, 0))
	Check.is_true(errors, "gol dakikasından önceki skor değişmemeli", m.score_at(first.minute - 1).x <= at_kick.x)
	Check.is_true(errors, "gol dakikasında skor artmalı", m.score_at(first.minute) == at_kick + Vector2i(1, 0))
	Check.is_true(errors, "kaçan vuruş skoru değiştirmemeli", m.final_score().y == before.y)
	Check.is_true(errors, "vuruş sayacı", m.shots_taken() == 2 and m.player_goals() == 1)
	var line := m.scoreline(Match.LENGTH)
	var score := m.final_score()
	var expected := "%s %d – %d %s" % ([m.us, score.x, score.y, m.them] if m.home else [m.them, score.y, score.x, m.us])
	Check.is_true(errors, "skor satırı ev sahibini önce yazmalı: " + line, line == expected)
	var labels := {true: "Galibiyet", false: "Mağlubiyet"}
	if score.x != score.y:
		Check.is_true(errors, "sonuç etiketi", m.result_label() == labels[score.x > score.y])
	else:
		Check.is_true(errors, "sonuç etiketi", m.result_label() == "Beraberlik")
	return errors


func test_baski() -> Array[String]:
	var errors: Array[String] = []
	var mp := MatchParams.new()
	var calm := Match.pressure(Match.Importance.LEAGUE, 30, 2, mp)
	var tense := Match.pressure(Match.Importance.FINAL, 89, -1, mp)
	Check.near(errors, "rahat an: öndeyken erken lig maçı", calm, mp.pressure_league, 1e-6)
	Check.near(errors, "en gergin an: finalde son dakika, geride", tense, 1.0, 1e-6)
	Check.is_true(errors, "son dakikalar baskıyı artırmalı",
			Match.pressure(Match.Importance.LEAGUE, 86, 0, mp) > Match.pressure(Match.Importance.LEAGUE, 76, 0, mp)
			and Match.pressure(Match.Importance.LEAGUE, 76, 0, mp) > Match.pressure(Match.Importance.LEAGUE, 40, 0, mp))
	Check.is_true(errors, "gerideyken baskı öndeyken olduğundan yüksek olmalı",
			Match.pressure(Match.Importance.LEAGUE, 40, -1, mp) > Match.pressure(Match.Importance.LEAGUE, 40, 1, mp))
	Check.is_true(errors, "derbi lig maçından gergin olmalı",
			Match.pressure(Match.Importance.DERBY, 40, 1, mp) > Match.pressure(Match.Importance.LEAGUE, 40, 1, mp))
	for minute in [10, 80, 90]:
		for difference in [-3, -1, 0, 2]:
			for importance in [Match.Importance.LEAGUE, Match.Importance.DERBY, Match.Importance.FINAL]:
				Check.in_range(errors, "baskı 0–1 arasında", Match.pressure(importance, minute, difference, mp), 0.0, 1.0)
	return errors


func test_vurus_anindaki_baski_o_andaki_skora_bakar() -> Array[String]:
	var errors: Array[String] = []
	for seed_value in 300:
		var m := _match(seed_value)
		for kick in m.free_kicks:
			var score := m.score_at(kick.minute - 1)
			Check.near(errors, "tohum %d baskı" % seed_value, m.pressure_for(kick),
					Match.pressure(m.importance, kick.minute, score.x - score.y, m.params), 1e-6)
		if errors.size() > 3:
			break
	return errors


func test_one_cikan_kaleci() -> Array[String]:
	var errors: Array[String] = []
	var kp := KeeperParams.new()
	var keeper := Keeper.new(kp)
	keeper.reset(0.0)
	Check.near(errors, "varsayılan kaleci çizgide", keeper.depth, kp.depth, 1e-9)
	keeper.reset(0.0, 0.0, 2.0)
	Check.near(errors, "öne çıkan kaleci", keeper.depth, 2.0, 1e-9)
	Check.near(errors, "gövde o derinlikte", keeper.body_segment()[0].z, 2.0, 1e-6)
	var sim := BallSimulator.new()
	sim.keeper = keeper
	sim.kick(BallState.from_kick(Check.spot(25.0), 21.0, 10.0, 0.0))
	sim.run(8.0)
	Check.is_true(errors, "öne çıkan kaleci ortaya gelen yavaş şutu kurtarmalı", sim.hit_keeper)
	Check.is_true(errors, "top kaleciye çizginin önünde değmeli", sim.state.position.z > 1.5 or sim.outcome != BallSimulator.Outcome.SAVED)
	return errors
