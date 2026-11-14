extends RefCounted
## Kariyer: sezon, puan durumu, hoca güveni, prim, mağaza, kayıt.

func _rng(seed_value: int = 5) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _career(seed_value: int = 5) -> Career:
	return Career.create(_rng(seed_value), Career.load_leagues(), CareerParams.new())


## Kariyerin sıradaki maçını üretir; `score_all` ise çıkan her serbest vuruş gol sayılır.
func _play(career: Career, rng: RandomNumberGenerator, score_all: bool = false, take: bool = true) -> Match:
	var played := Match.generate(rng, [], Match.load_commentary(), MatchParams.new(), career.match_setup(career.next_fixture()))
	if take:
		for kick in played.free_kicks:
			played.record_shot(kick, score_all)
	return played


func test_veri_dosyalari() -> Array[String]:
	var errors: Array[String] = []
	var leagues := Career.load_leagues()
	Check.is_true(errors, "3 lig olmalı", leagues.size() == 3)
	var names := {}
	for league: Dictionary in leagues:
		Check.is_true(errors, "her ligde 8 takım olmalı", (league["teams"] as Array).size() == 8)
		for team: String in league["teams"]:
			names[team] = true
	Check.is_true(errors, "takım adları benzersiz olmalı", names.size() == 24)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CareerParams.DATA_PATH))
	Check.is_true(errors, "data/career.json okunamadı", parsed is Dictionary)
	if parsed is Dictionary:
		var unknown := CareerParams.new().apply(parsed)
		Check.is_true(errors, "bilinmeyen anahtarlar: %s" % [unknown], unknown.is_empty())
	for boot in Boot.load_all():
		Check.is_true(errors, boot.id + ": fiyat", boot.price == 0 if boot.type == "dengeli" else boot.price > 0)
	return errors


func test_yeni_kariyer() -> Array[String]:
	var errors: Array[String] = []
	var career := _career()
	Check.is_true(errors, "kulüp en alt ligden olmalı", career.tier == 0 and career.teams().has(career.club))
	Check.near(errors, "başlangıç güveni", career.trust, 50.0, 1e-9)
	Check.is_true(errors, "başlangıçta yalnızca başlangıç kramponu", career.owned_boots == ["baslangic"] and career.money == 0)
	Check.is_true(errors, "24 takımın gücü olmalı", career.strengths.size() == 24)
	for team: String in career.strengths:
		Check.in_range(errors, team + " gücü", career.strengths[team], 0.8, 1.2)
	return errors


func test_fikstur() -> Array[String]:
	var errors: Array[String] = []
	var career := _career()
	var league := career.schedule.filter(func(f: Dictionary) -> bool: return f["kind"] == "league")
	var cup := career.schedule.filter(func(f: Dictionary) -> bool: return f["kind"] == "cup")
	Check.is_true(errors, "14 lig maçı olmalı, şu an %d" % league.size(), league.size() == 14)
	Check.is_true(errors, "3 kupa maçı olmalı", cup.size() == 3)
	Check.is_true(errors, "son maç kupa finali olmalı", career.schedule[-1]["label"] == "Kupa finali")
	var home := 0
	var meetings := {}
	for fixture: Dictionary in league:
		if fixture["home"]:
			home += 1
		meetings[fixture["opponent"]] = meetings.get(fixture["opponent"], 0) + 1
		Check.is_true(errors, "kendimizle oynamamalıyız", fixture["opponent"] != career.club)
	Check.is_true(errors, "7 iç saha maçı olmalı, şu an %d" % home, home == 7)
	Check.is_true(errors, "7 rakiple ikişer kez oynanmalı", meetings.size() == 7 and meetings.values().min() == 2)
	Check.is_true(errors, "14 lig haftası olmalı", career.rounds.size() == 14)
	for pairs: Array in career.rounds:
		var seen := {}
		for pair: Array in pairs:
			seen[pair[0]] = true
			seen[pair[1]] = true
		Check.is_true(errors, "her hafta 8 takım da oynamalı", pairs.size() == 4 and seen.size() == 8)
	var setup := career.match_setup(career.schedule[-1])
	Check.is_true(errors, "kupa finali final öneminde olmalı", setup.importance == Match.Importance.FINAL)
	for fixture: Dictionary in league:
		var expected := Match.Importance.DERBY if fixture["opponent"] == career.rival() else Match.Importance.LEAGUE
		Check.is_true(errors, "rakiple maç derbi olmalı", career.match_setup(fixture).importance == expected)
	return errors


func test_sezon_boyunca_puan_durumu_tutarli() -> Array[String]:
	var errors: Array[String] = []
	var rng := _rng(11)
	var career := _career(11)
	var guard := 0
	while not career.is_season_over() and guard < 40:
		guard += 1
		var fixture := career.next_fixture()
		var before: int = career.table[career.club]["played"]
		var played := _play(career, rng)
		career.apply_result(rng, played)
		if fixture["kind"] == "league":
			Check.is_true(errors, "lig maçı oynanan maç sayısını artırmalı", career.table[career.club]["played"] == before + 1)
			var counts := {}
			for team: String in career.table:
				counts[career.table[team]["played"]] = true
			Check.is_true(errors, "hafta sonunda herkes aynı sayıda maç oynamış olmalı", counts.size() == 1)
		else:
			Check.is_true(errors, "kupa maçı puan durumunu değiştirmemeli", career.table[career.club]["played"] == before)
	Check.is_true(errors, "sezon bitmeli", career.is_season_over())
	var goals_for := 0
	var goals_against := 0
	for team: String in career.table:
		var row: Dictionary = career.table[team]
		Check.is_true(errors, team + ": 14 maç", row["played"] == 14 and row["won"] + row["drawn"] + row["lost"] == 14)
		Check.is_true(errors, team + ": puan hesabı", row["points"] == row["won"] * 3 + row["drawn"])
		goals_for += row["gf"]
		goals_against += row["ga"]
	Check.is_true(errors, "atılan ve yenen goller eşit olmalı", goals_for == goals_against)
	var rows := career.standings()
	for i in range(1, rows.size()):
		Check.is_true(errors, "puan durumu sıralı olmalı", rows[i - 1]["points"] >= rows[i]["points"])
	Check.is_true(errors, "sıramız 1–8 arasında", career.position() >= 1 and career.position() <= 8)
	Check.is_true(errors, "sıramız tablodaki yerimizle aynı", rows[career.position() - 1]["team"] == career.club)
	return errors


func test_hoca_guveni_ve_prim() -> Array[String]:
	var errors: Array[String] = []
	var cp := CareerParams.new()
	var rng := _rng(3)
	var scorer := _career(3)
	var misser := _career(3)
	var scored_kicks := 0
	var missed_kicks := 0
	for i in 6:
		var a := _play(scorer, rng, true)
		scored_kicks += a.shots_taken()
		var summary := scorer.apply_result(rng, a)
		var expected := a.player_goals() * cp.bonus_goal + (cp.bonus_appearance if a.shots_taken() > 0 else 0.0)
		if a.final_score().x > a.final_score().y:
			expected += cp.bonus_win
		Check.is_true(errors, "prim hesabı (maç %d)" % i, summary["bonus"] == roundi(expected))
		var b := _play(misser, rng, false)
		missed_kicks += b.shots_taken()
		misser.apply_result(rng, b)
	Check.is_true(errors, "denemede serbest vuruş çıkmış olmalı", scored_kicks > 0 and missed_kicks > 0)
	Check.is_true(errors, "gol atan oyuncunun güveni artmalı", scorer.trust > 50.0)
	Check.is_true(errors, "kaçıran oyuncunun güveni düşmeli", misser.trust < 50.0)
	Check.near(errors, "kaçan her vuruş sabit düşüş", misser.trust, maxf(50.0 - cp.trust_miss * missed_kicks, 0.0), 1e-4)
	Check.is_true(errors, "gol sayacı", scorer.goals == scored_kicks and scorer.shots == scored_kicks and misser.goals == 0)
	Check.is_true(errors, "gol ün kazandırmalı", scorer.fame > 0.0 and misser.fame == 0.0)
	Check.is_true(errors, "prim cüzdana eklenmeli", scorer.money > misser.money)
	for i in 30:
		scorer.apply_result(rng, _play(scorer, rng, true)) if not scorer.is_season_over() else null
	Check.in_range(errors, "güven 0–100 arasında kalmalı", scorer.trust, 0.0, 100.0)
	return errors


func test_guven_pozisyon_sayisini_ve_zorlugunu_belirler() -> Array[String]:
	var errors: Array[String] = []
	var mp := MatchParams.new()
	var totals := {0.0: 0, 100.0: 0}
	var farthest := {0.0: 0.0, 100.0: 0.0}
	for trust: float in [0.0, 100.0]:
		var rng := _rng(21)
		for i in 300:
			var setup := MatchSetup.new()
			setup.us = "A"
			setup.them = "B"
			setup.trust = trust
			var m := Match.generate(rng, [], Match.load_commentary(), mp, setup)
			totals[trust] += m.free_kicks.size()
			for kick in m.free_kicks:
				farthest[trust] = maxf(farthest[trust], kick.distance())
	Check.is_true(errors, "güven yüksekken çok daha fazla pozisyon verilmeli", totals[100.0] > totals[0.0] * 1.8)
	Check.in_range(errors, "güven düşükken en uzak pozisyon (m)", farthest[0.0], 18.0, mp.trust_distance_low + 1e-3)
	Check.is_true(errors, "güven yüksekken uzak pozisyonlar da gelmeli", farthest[100.0] > 30.0)
	return errors


func test_takim_gucu_skoru_etkiler() -> Array[String]:
	var errors: Array[String] = []
	var rng := _rng(8)
	var difference := 0
	for i in 300:
		var setup := MatchSetup.new()
		setup.us = "A"
		setup.them = "B"
		setup.our_strength = 1.2
		setup.their_strength = 0.8
		var score := Match.generate(rng, [], Match.load_commentary(), MatchParams.new(), setup).final_score()
		difference += score.x - score.y
	Check.is_true(errors, "güçlü takım ortalamada daha çok gol atmalı", difference > 150)
	return errors


func test_magaza_ve_gelisim() -> Array[String]:
	var errors: Array[String] = []
	var cp := CareerParams.new()
	var career := _career()
	var boots := Boot.load_all()
	var power: Boot = boots.filter(func(b: Boot) -> bool: return b.type == "guc")[0]
	Check.is_true(errors, "para yokken krampon alınamamalı", not career.buy_boot(power) and not career.owns(power))
	career.money = power.price + 50
	Check.is_true(errors, "para varken krampon alınmalı", career.buy_boot(power) and career.owns(power))
	Check.is_true(errors, "bedel düşülmeli", career.money == 50)
	career.money = 5000
	Check.is_true(errors, "aynı krampon ikinci kez alınamamalı", not career.buy_boot(power) and career.money == 5000)
	Check.is_true(errors, "ilk seviye bedeli", career.upgrade_cost("power") == roundi(cp.skill_cost))
	Check.is_true(errors, "yükseltme yapılmalı", career.upgrade("power") and career.skills["power"] == 1)
	Check.is_true(errors, "bedel her seviyede artmalı", career.upgrade_cost("power") == roundi(cp.skill_cost * 2))
	career.money = 1000000
	for i in 10:
		career.upgrade("composure")
	Check.is_true(errors, "seviye üst sınırı", career.skills["composure"] == int(cp.skill_max) and not career.can_upgrade("composure"))
	career.upgrade("curl")
	career.upgrade("accuracy")
	var base := boots[0]
	var boosted := career.effective_boot(base)
	Check.near(errors, "güç yükseltmesi", boosted.power, base.power + cp.skill_power, 1e-4)
	Check.near(errors, "falso yükseltmesi", boosted.curl, base.curl + cp.skill_curl, 1e-4)
	Check.near(errors, "isabet yükseltmesi", boosted.accuracy, base.accuracy + cp.skill_accuracy, 1e-4)
	Check.near(errors, "asıl krampon değişmemeli", base.power, Boot.load_all()[0].power, 1e-6)
	Check.near(errors, "soğukkanlılık baskıyı azaltmalı", career.felt_pressure(1.0), 1.0 - cp.skill_composure * cp.skill_max, 1e-4)
	Check.near(errors, "soğukkanlılık yokken baskı aynı", _career().felt_pressure(0.7), 0.7, 1e-6)
	return errors


func test_kayit_ve_yukleme() -> Array[String]:
	var errors: Array[String] = []
	var rng := _rng(17)
	var career := _career(17)
	for i in 5:
		career.apply_result(rng, _play(career, rng, i % 2 == 0))
	career.money += 900
	career.buy_boot(Boot.load_all()[3])
	career.boot_id = "yay"
	career.upgrade("power")
	var path := "user://test_career.json"
	Check.is_true(errors, "kayıt yazılmalı", career.save(path))
	var loaded := Career.load_saved(CareerParams.new(), path)
	Check.is_true(errors, "kayıt okunmalı", loaded != null)
	if loaded != null:
		Check.is_true(errors, "yüklenen kariyer aynı olmalı", JSON.stringify(loaded.to_dict()) == JSON.stringify(career.to_dict()))
		Check.is_true(errors, "sıra korunmalı", loaded.position() == career.position() and loaded.week == career.week)
		Check.is_true(errors, "krampon ve gelişim korunmalı", loaded.boot_id == "yay" and loaded.owns(Boot.load_all()[3]) and loaded.skills["power"] == 1)
		loaded.apply_result(rng, _play(loaded, rng))
		Check.is_true(errors, "yüklenen kariyerle devam edilebilmeli", loaded.week > career.week)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Check.is_true(errors, "kayıt yokken null dönmeli", Career.load_saved(CareerParams.new(), "user://yok.json") == null)
	Check.is_true(errors, "bozuk kayıt reddedilmeli", Career.from_dict({"club": "x"}, CareerParams.new()) == null)
	return errors


func test_kupada_elenince_kupa_maclari_atlanir() -> Array[String]:
	var errors: Array[String] = []
	var rng := _rng(4)
	var career := _career(4)
	career.strengths[career.club] = 0.8
	var eliminated := false
	var guard := 0
	while not career.is_season_over() and guard < 40:
		guard += 1
		var fixture := career.next_fixture()
		Check.is_true(errors, "elendikten sonra kupa maçı gelmemeli", not (eliminated and fixture["kind"] == "cup"))
		var played := _play(career, rng, false)
		var summary := career.apply_result(rng, played)
		if fixture["kind"] == "cup" and not career.cup_alive:
			eliminated = true
			Check.is_true(errors, "elenme yazısı olmalı", not (summary["cup_text"] as String).is_empty())
	Check.is_true(errors, "sezon bitmeli", career.is_season_over())
	return errors


func test_sezon_sonu() -> Array[String]:
	var errors: Array[String] = []
	var cp := CareerParams.new()
	var rng := _rng(9)
	var career := _career(9)
	# Şampiyonluk: kulübümüze bol puan ver.
	career.table[career.club]["points"] = 99
	career.week = career.schedule.size()
	var old_club := career.club
	var summary := career.finish_season(rng)
	Check.is_true(errors, "şampiyon olmalı", summary["position"] == 1 and summary["champion"])
	Check.is_true(errors, "ilk iki yükselmeli", summary["promoted"])
	Check.near(errors, "şampiyonluk ünü", career.fame, cp.fame_champion, 1e-6)
	career.begin_next_season(rng, summary, false)
	Check.is_true(errors, "üst lige çıkmalı", career.tier == 1 and career.club == old_club and career.teams().has(old_club))
	Check.is_true(errors, "alt ligde yerimize bir takım gelmeli", not (career.leagues[0]["teams"] as Array).has(old_club) and (career.leagues[0]["teams"] as Array).size() == 8)
	Check.is_true(errors, "yeni sezon sıfırdan başlamalı", career.season == 2 and career.week == 0 and career.table[old_club]["played"] == 0)
	Check.is_true(errors, "üst ligde primler artmalı", career.tier_multiplier() > 1.0)

	# Teklif: yükselemeyen ama ünlü oyuncu.
	var other := _career(9)
	other.table[other.club]["points"] = -5
	other.fame = cp.offer_fame + 1.0
	other.trust = 80.0
	var second := other.finish_season(rng)
	Check.is_true(errors, "son sıradaki takım yükselmemeli", not second["promoted"] and second["position"] == 8)
	Check.is_true(errors, "ünlü oyuncuya üst ligden teklif gelmeli", (other.leagues[1]["teams"] as Array).has(second["offer"]))
	var declined := Career.from_dict(JSON.parse_string(JSON.stringify(other.to_dict())), cp)
	declined.begin_next_season(rng, second, false)
	Check.is_true(errors, "teklif reddedilince aynı kulüpte kalmalı", declined.tier == 0 and declined.club == other.club and declined.season == 2)
	other.begin_next_season(rng, second, true)
	Check.is_true(errors, "teklif kabul edilince üst ligdeki kulübe geçmeli", other.tier == 1 and other.club == second["offer"])
	Check.near(errors, "yeni kulüpte güven baştan başlar", other.trust, cp.start_trust, 1e-6)

	var unknown := _career(9)
	unknown.table[unknown.club]["points"] = -5
	Check.is_true(errors, "ünsüz oyuncuya teklif gelmemeli", (unknown.finish_season(rng)["offer"] as String).is_empty())
	return errors
