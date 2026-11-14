class_name Career
extends RefCounted
## Kariyer: kulüp, sezon (lig + kupa), puan durumu, hoca güveni, ün, prim, krampon ve oyuncu gelişimi.
## Kurallar burada; ekranlar `MatchFlow` içinde. Durum `user://career.json` dosyasına kaydedilir.

const SAVE_PATH := "user://career.json"
const SKILLS: Array[String] = ["power", "curl", "accuracy", "composure"]
const SKILL_LABELS := {"power": "Güç", "curl": "Falso", "accuracy": "İsabet", "composure": "Soğukkanlılık"}
const CUP_ROUNDS: Array[String] = ["Kupa çeyrek finali", "Kupa yarı finali", "Kupa finali"]
## Kupa maçları bu lig haftalarından sonra oynanır.
const CUP_AFTER_ROUND: Array[int] = [4, 9, 14]

var params: CareerParams
var leagues: Array = []            ## [{name, teams}], alt ligden üste
var tier := 0
var club := ""
var season := 1
var week := 0                      ## fikstürdeki sıradaki maç
var schedule: Array = []           ## [{kind, round, opponent, home, label}]
var rounds: Array = []             ## lig haftaları: her biri [ev sahibi, deplasman] çiftleri
var table := {}                    ## takım → {played, won, drawn, lost, gf, ga, points}
var strengths := {}                ## takım → güç (1 civarı)
var trust := 50.0
var fame := 0.0
var money := 0
var owned_boots: Array = ["baslangic"]
var boot_id := "baslangic"
var skills := {"power": 0, "curl": 0, "accuracy": 0, "composure": 0}
var goals := 0
var shots := 0
var cup_alive := true
var cup_won := false
var season_closed := false         ## sezon sonu ödülleri verildi mi (ekran yeniden açılırsa iki kez verilmesin)


static func create(rng: RandomNumberGenerator, p_leagues: Array, cp: CareerParams) -> Career:
	var career := Career.new()
	career.params = cp
	career.leagues = p_leagues.duplicate(true)
	career.trust = cp.start_trust
	var teams: Array = career.leagues[0]["teams"]
	career.club = teams[rng.randi_range(0, teams.size() - 1)]
	for league: Dictionary in career.leagues:
		for team: String in league["teams"]:
			career.strengths[team] = 1.0 + rng.randf_range(-cp.strength_spread, cp.strength_spread)
	career.start_season(rng)
	return career


func league_name() -> String:
	return leagues[tier]["name"]


func teams() -> Array:
	return leagues[tier]["teams"]


## Yeni sezon: puan durumu sıfırlanır, çift devreli lig ve kupa fikstürü kurulur.
func start_season(rng: RandomNumberGenerator) -> void:
	week = 0
	cup_alive = true
	cup_won = false
	season_closed = false
	table.clear()
	for team: String in teams():
		table[team] = {"played": 0, "won": 0, "drawn": 0, "lost": 0, "gf": 0, "ga": 0, "points": 0}
	rounds = _round_robin(rng)
	schedule.clear()
	var cup_index := 0
	for i in rounds.size():
		for pair: Array in rounds[i]:
			if pair[0] == club or pair[1] == club:
				var at_home: bool = pair[0] == club
				schedule.append({"kind": "league", "round": i, "opponent": pair[1] if at_home else pair[0],
						"home": at_home, "label": "%s · %d. hafta" % [league_name(), i + 1]})
		if cup_index < CUP_AFTER_ROUND.size() and i + 1 == CUP_AFTER_ROUND[cup_index]:
			var others := teams().filter(func(team: String) -> bool: return team != club)
			schedule.append({"kind": "cup", "round": cup_index, "opponent": others[rng.randi_range(0, others.size() - 1)],
					"home": rng.randf() < 0.5, "label": CUP_ROUNDS[cup_index]})
			cup_index += 1


## Çift devreli lig: her takım diğerleriyle bir kez evinde, bir kez deplasmanda oynar.
func _round_robin(rng: RandomNumberGenerator) -> Array:
	var order := teams().duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: String = order[i]
		order[i] = order[j]
		order[j] = swap
	var count := order.size()
	var first_half: Array = []
	for round_index in count - 1:
		var pairs: Array = []
		for i in count / 2:
			var a: String = order[i]
			var b: String = order[count - 1 - i]
			pairs.append([a, b] if (round_index + i) % 2 == 0 else [b, a])
		first_half.append(pairs)
		order.insert(1, order.pop_back())
	var all := first_half.duplicate(true)
	for pairs: Array in first_half:
		all.append(pairs.map(func(pair: Array) -> Array: return [pair[1], pair[0]]))
	return all


func is_season_over() -> bool:
	return week >= schedule.size()


func next_fixture() -> Dictionary:
	return schedule[week] if not is_season_over() else {}


## Rakip: ligde bir sonraki sıradaki takım (derbi).
func rival() -> String:
	var list := teams()
	return list[(list.find(club) + 1) % list.size()]


func match_setup(fixture: Dictionary) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.us = club
	setup.them = fixture["opponent"]
	setup.home = fixture["home"]
	setup.our_strength = strengths[club]
	setup.their_strength = strengths[setup.them]
	setup.trust = trust
	if fixture["kind"] == "cup" and fixture["round"] == CUP_ROUNDS.size() - 1:
		setup.importance = Match.Importance.FINAL
	elif setup.them == rival():
		setup.importance = Match.Importance.DERBY
	return setup


func tier_multiplier() -> float:
	return 1.0 + params.tier_bonus_step * tier


## Oynanan maçı işler: puan durumu, haftanın diğer maçları, kupa, güven, ün ve prim.
## Özet döndürür: {bonus, trust_change, fame_change, cup_text}.
func apply_result(rng: RandomNumberGenerator, played: Match) -> Dictionary:
	var fixture := next_fixture()
	var score := played.final_score()
	var trust_before := trust
	var fame_before := fame
	var taken := 0
	for kick in played.free_kicks:
		if not kick.taken:
			continue
		taken += 1
		if kick.scored:
			trust += params.trust_goal
			if played.pressure_for(kick) >= params.clutch_pressure:
				trust += params.trust_clutch
			fame += params.fame_goal * tier_multiplier()
		else:
			trust -= params.trust_miss
	trust = clampf(trust, 0.0, 100.0)
	shots += taken
	goals += played.player_goals()

	var bonus := played.player_goals() * params.bonus_goal
	if taken > 0:
		bonus += params.bonus_appearance
	if score.x > score.y:
		bonus += params.bonus_win
	var earned := roundi(bonus * tier_multiplier())
	money += earned

	var cup_text := ""
	if fixture["kind"] == "league":
		_record(club, fixture["opponent"], score.x, score.y)
		for pair: Array in rounds[fixture["round"]]:
			if pair[0] == club or pair[1] == club:
				continue
			var result := _simulate(rng, pair[0], pair[1])
			_record(pair[0], pair[1], result.x, result.y)
	else:
		var through := score.x > score.y or (score.x == score.y and rng.randf() < 0.5)
		if score.x == score.y:
			cup_text = "Penaltılarla turladınız." if through else "Penaltılarla elendiniz."
		if not through:
			cup_alive = false
			cup_text = cup_text if not cup_text.is_empty() else "Kupadan elendiniz."
		elif fixture["round"] == CUP_ROUNDS.size() - 1:
			cup_won = true
			fame += params.fame_champion
			cup_text = "KUPA SİZİN!"
	week += 1
	while not is_season_over() and schedule[week]["kind"] == "cup" and not cup_alive:
		week += 1
	return {"bonus": earned, "trust_change": trust - trust_before, "fame_change": fame - fame_before, "cup_text": cup_text}


func _simulate(rng: RandomNumberGenerator, home_team: String, away_team: String) -> Vector2i:
	var ratio: float = strengths[home_team] / strengths[away_team]
	return Vector2i(_goals(rng, 1.35 * ratio), _goals(rng, 1.15 / ratio))


func _goals(rng: RandomNumberGenerator, expected: float) -> int:
	var count := 0
	for i in 9:
		if rng.randf() < expected / 9.0:
			count += 1
	return count


func _record(team_a: String, team_b: String, goals_a: int, goals_b: int) -> void:
	for entry: Array in [[team_a, goals_a, goals_b], [team_b, goals_b, goals_a]]:
		var row: Dictionary = table[entry[0]]
		row["played"] += 1
		row["gf"] += entry[1]
		row["ga"] += entry[2]
		if entry[1] > entry[2]:
			row["won"] += 1
			row["points"] += 3
		elif entry[1] == entry[2]:
			row["drawn"] += 1
			row["points"] += 1
		else:
			row["lost"] += 1


## Puan durumu: puan, averaj, atılan gol sırasıyla. Her satır: {team, played, …, points}.
func standings() -> Array:
	var rows: Array = []
	for team: String in table:
		var row: Dictionary = table[team].duplicate()
		row["team"] = team
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		var diff_a: int = a["gf"] - a["ga"]
		var diff_b: int = b["gf"] - b["ga"]
		if diff_a != diff_b:
			return diff_a > diff_b
		if a["gf"] != b["gf"]:
			return a["gf"] > b["gf"]
		return a["team"] < b["team"])
	return rows


func position() -> int:
	var rows := standings()
	for i in rows.size():
		if rows[i]["team"] == club:
			return i + 1
	return rows.size()


## Sezonu kapatır. Özet: {position, champion, promoted, offer}. `offer` üst ligden teklif eden kulüp (yoksa "").
## Yeni sezonu başlatmak için ardından `begin_next_season` çağrılır.
func finish_season(rng: RandomNumberGenerator) -> Dictionary:
	var place := position()
	var champion := place == 1
	if not season_closed:
		season_closed = true
		if champion:
			fame += params.fame_champion
		elif place == 2:
			fame += params.fame_top_two
	var promoted := place <= 2 and tier < leagues.size() - 1
	var offer := ""
	if not promoted and tier < leagues.size() - 1 and fame >= params.offer_fame * (tier + 1):
		var upper: Array = leagues[tier + 1]["teams"]
		offer = upper[rng.randi_range(0, upper.size() - 1)]
	return {"position": place, "champion": champion, "promoted": promoted, "offer": offer}


## summary: finish_season'ın döndürdüğü özet. accept_offer: teklif kabul edildi mi.
func begin_next_season(rng: RandomNumberGenerator, summary: Dictionary, accept_offer: bool) -> void:
	if summary["promoted"]:
		# Kulübümüz üst ligin en zayıf takımıyla yer değiştirir.
		var upper: Array = leagues[tier + 1]["teams"]
		var weakest: String = upper[0]
		for team: String in upper:
			if strengths[team] < strengths[weakest]:
				weakest = team
		upper[upper.find(weakest)] = club
		var lower: Array = leagues[tier]["teams"]
		lower[lower.find(club)] = weakest
		strengths[club] = maxf(strengths[club], 1.0)
		tier += 1
	elif accept_offer and not (summary["offer"] as String).is_empty():
		club = summary["offer"]
		tier += 1
		trust = params.start_trust
	season += 1
	start_season(rng)


# --- Mağaza ve gelişim ---

func owns(boot: Boot) -> bool:
	return owned_boots.has(boot.id)


func buy_boot(boot: Boot) -> bool:
	if owns(boot) or money < boot.price:
		return false
	money -= boot.price
	owned_boots.append(boot.id)
	return true


func upgrade_cost(skill: String) -> int:
	return roundi(params.skill_cost * (int(skills[skill]) + 1))


func can_upgrade(skill: String) -> bool:
	return int(skills[skill]) < int(params.skill_max) and money >= upgrade_cost(skill)


func upgrade(skill: String) -> bool:
	if not can_upgrade(skill):
		return false
	money -= upgrade_cost(skill)
	skills[skill] = int(skills[skill]) + 1
	return true


## Oyuncu özellikleri eklenmiş krampon.
func effective_boot(boot: Boot) -> Boot:
	var result := boot.duplicate_boot()
	result.power += params.skill_power * int(skills["power"])
	result.curl += params.skill_curl * int(skills["curl"])
	result.accuracy = minf(result.accuracy + params.skill_accuracy * int(skills["accuracy"]), 1.0)
	return result


## Soğukkanlılık baskının etkisini azaltır.
func felt_pressure(pressure: float) -> float:
	return pressure * maxf(1.0 - params.skill_composure * int(skills["composure"]), 0.0)


# --- Kayıt ---

func to_dict() -> Dictionary:
	return {
		"version": 1, "leagues": leagues, "tier": tier, "club": club, "season": season, "week": week,
		"schedule": schedule, "rounds": rounds, "table": table, "strengths": strengths, "trust": trust,
		"fame": fame, "money": money, "owned_boots": owned_boots, "boot_id": boot_id, "skills": skills,
		"goals": goals, "shots": shots, "cup_alive": cup_alive, "cup_won": cup_won,
		"season_closed": season_closed,
	}


static func from_dict(data: Dictionary, cp: CareerParams) -> Career:
	if not data.has("club") or not data.has("leagues") or not data.has("schedule"):
		return null
	var career := Career.new()
	career.params = cp
	career.leagues = data["leagues"]
	career.tier = int(data.get("tier", 0))
	career.club = data["club"]
	career.season = int(data.get("season", 1))
	career.week = int(data.get("week", 0))
	career.schedule = data["schedule"]
	for fixture: Dictionary in career.schedule:
		fixture["round"] = int(fixture["round"])
	career.rounds = data.get("rounds", [])
	career.table = data.get("table", {})
	for team: String in career.table:
		var row: Dictionary = career.table[team]
		for key: String in row:
			row[key] = int(row[key])
	career.strengths = data.get("strengths", {})
	career.trust = float(data.get("trust", cp.start_trust))
	career.fame = float(data.get("fame", 0.0))
	career.money = int(data.get("money", 0))
	career.owned_boots = data.get("owned_boots", ["baslangic"])
	career.boot_id = data.get("boot_id", "baslangic")
	var saved_skills: Dictionary = data.get("skills", {})
	for skill in SKILLS:
		career.skills[skill] = int(saved_skills.get(skill, 0))
	career.goals = int(data.get("goals", 0))
	career.shots = int(data.get("shots", 0))
	career.cup_alive = bool(data.get("cup_alive", true))
	career.cup_won = bool(data.get("cup_won", false))
	career.season_closed = bool(data.get("season_closed", false))
	return career


func save(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


static func load_saved(cp: CareerParams, path: String = SAVE_PATH) -> Career:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed, cp) if parsed is Dictionary else null


static func load_leagues() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/leagues.json"))
	return parsed if parsed is Array else []
