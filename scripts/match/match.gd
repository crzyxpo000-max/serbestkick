class_name Match
extends RefCounted
## Bir maçın tamamı: takımlar, hava, otomatik akan olaylar ve serbest vuruş pozisyonları.
## Oyuncu yalnızca serbest vuruşlarda sahaya girer; attığı goller skora eklenir.

enum Importance { LEAGUE, DERBY, FINAL }
enum Weather { CLEAR, WINDY, RAIN }

const LENGTH := 90
const IMPORTANCE_LABELS := {Importance.LEAGUE: "Lig maçı", Importance.DERBY: "Derbi", Importance.FINAL: "Kupa finali"}
const WEATHER_LABELS := {Weather.CLEAR: "Açık hava", Weather.WINDY: "Rüzgarlı", Weather.RAIN: "Yağmurlu"}

var params: MatchParams
var us := ""
var them := ""
var home := true
var importance := Importance.LEAGUE
var weather := Weather.CLEAR
var conditions := PitchConditions.new()
var events: Array[MatchEvent] = []
var free_kicks: Array[FreeKick] = []
var commentary := {}

var _player_goals: Array[int] = []


## setup verilmezse rastgele iki takım, rastgele önem (hızlı maç). Kariyerde fikstür ve hoca güveni setup ile gelir.
static func generate(rng: RandomNumberGenerator, teams: Array, p_commentary: Dictionary,
		mp: MatchParams, setup: MatchSetup = null) -> Match:
	var m := Match.new()
	m.params = mp
	m.commentary = p_commentary
	var roll := 0.0
	var our_xg := mp.our_xg
	var their_xg := mp.their_xg
	var none_chance := mp.free_kicks_none
	var two_chance := mp.free_kicks_two
	var distance_max := mp.distance_max
	var angle_max := mp.angle_max
	if setup == null:
		var first := rng.randi_range(0, teams.size() - 1)
		var second := (first + rng.randi_range(1, teams.size() - 1)) % teams.size()
		m.us = teams[first]
		m.them = teams[second]
		m.home = rng.randf() < 0.5
		roll = rng.randf()
		if roll < mp.final_chance:
			m.importance = Importance.FINAL
		elif roll < mp.final_chance + mp.derby_chance:
			m.importance = Importance.DERBY
	else:
		m.us = setup.us
		m.them = setup.them
		m.home = setup.home
		m.importance = setup.importance
		our_xg *= setup.our_strength / setup.their_strength
		their_xg *= setup.their_strength / setup.our_strength
		if setup.trust >= 0.0:
			# Hoca güveni: güven düşükse az ve kolay pozisyon, yüksekse çok ve her mesafeden.
			var t := clampf(setup.trust / 100.0, 0.0, 1.0)
			none_chance = lerpf(mp.trust_none_low, mp.trust_none_high, t)
			two_chance = lerpf(mp.trust_two_low, mp.trust_two_high, t)
			distance_max = lerpf(mp.trust_distance_low, mp.distance_max, t)
			angle_max = lerpf(mp.trust_angle_low, mp.angle_max, t)

	roll = rng.randf()
	var wind_speed := 0.0
	if roll < mp.rain_chance:
		m.weather = Weather.RAIN
		m.conditions.wet = true
		wind_speed = rng.randf_range(0.0, mp.rain_wind_max)
	elif roll < mp.rain_chance + mp.windy_chance:
		m.weather = Weather.WINDY
		wind_speed = rng.randf_range(mp.wind_min, mp.wind_max)
	var wind_angle := rng.randf_range(0.0, TAU)
	m.conditions.wind = Vector3(cos(wind_angle), 0.0, sin(wind_angle)) * wind_speed

	var used := {}
	for minute in range(1, LENGTH + 1):
		if rng.randf() < our_xg / LENGTH:
			m.events.append(MatchEvent.make(minute, MatchEvent.Kind.GOAL_US, m._line(rng, "goal_us")))
			used[minute] = true
		if rng.randf() < their_xg / LENGTH:
			m.events.append(MatchEvent.make(minute, MatchEvent.Kind.GOAL_THEM, m._line(rng, "goal_them")))
			used[minute] = true

	roll = rng.randf()
	var count := 1
	if roll < none_chance:
		count = 0
	elif roll < none_chance + two_chance:
		count = 2
	var minutes: Array[int] = []
	var attempts := 0
	while minutes.size() < count and attempts < 200:
		attempts += 1
		var candidate := rng.randi_range(int(mp.first_minute), LENGTH)
		var free := not used.has(candidate)
		for other in minutes:
			if absi(other - candidate) < int(mp.min_gap):
				free = false
		if free:
			minutes.append(candidate)
			used[candidate] = true
	minutes.sort()
	for minute in minutes:
		var kick := FreeKick.new()
		kick.minute = minute
		var distance := rng.randf_range(mp.distance_min, distance_max)
		var angle := deg_to_rad(rng.randf_range(-angle_max, angle_max))
		kick.spot = Vector3(sin(angle) * distance, 0.0, cos(angle) * distance)
		kick.wall_count = Wall.default_count(kick.spot)
		kick.keeper_forward = rng.randf() < mp.forward_keeper_chance
		m.free_kicks.append(kick)
		m.events.append(MatchEvent.make(minute, MatchEvent.Kind.FREE_KICK, m._line(rng, "foul"), kick))

	for i in int(mp.filler_count):
		var minute := rng.randi_range(2, LENGTH - 1)
		if used.has(minute):
			continue
		used[minute] = true
		m.events.append(MatchEvent.make(minute, MatchEvent.Kind.COMMENT, m._line(rng, "filler")))

	m.events.sort_custom(func(a: MatchEvent, b: MatchEvent) -> bool:
		return a.minute < b.minute if a.minute != b.minute else a.kind < b.kind)
	return m


## (bizim gol, rakip gol): `minute` dahil o ana kadar. Oyuncunun golleri dahildir.
func score_at(minute: int) -> Vector2i:
	var ours := 0
	var theirs := 0
	for event in events:
		if event.minute > minute:
			break
		if event.kind == MatchEvent.Kind.GOAL_US:
			ours += 1
		elif event.kind == MatchEvent.Kind.GOAL_THEM:
			theirs += 1
	for goal_minute in _player_goals:
		if goal_minute <= minute:
			ours += 1
	return Vector2i(ours, theirs)


func final_score() -> Vector2i:
	return score_at(LENGTH)


## Ev sahibi önce yazılır: "Kıyıspor 1 – 0 Yeşilova".
func scoreline(minute: int) -> String:
	var score := score_at(minute)
	if home:
		return "%s %d – %d %s" % [us, score.x, score.y, them]
	return "%s %d – %d %s" % [them, score.y, score.x, us]


func record_shot(kick: FreeKick, scored: bool) -> void:
	kick.taken = true
	kick.scored = scored
	if scored:
		_player_goals.append(kick.minute)


func shots_taken() -> int:
	return free_kicks.filter(func(kick: FreeKick) -> bool: return kick.taken).size()


func player_goals() -> int:
	return _player_goals.size()


## Vuruş anındaki baskı (0–1): maçın önemi, dakika ve skor. Skor vuruştan önceki durumdur.
func pressure_for(kick: FreeKick) -> float:
	var score := score_at(kick.minute - 1)
	return pressure(importance, kick.minute, score.x - score.y, params)


static func pressure(p_importance: Importance, minute: int, goal_difference: int, mp: MatchParams) -> float:
	var value := mp.pressure_league
	if p_importance == Importance.DERBY:
		value = mp.pressure_derby
	elif p_importance == Importance.FINAL:
		value = mp.pressure_final
	if minute >= 85:
		value += mp.pressure_late_85
	elif minute >= 75:
		value += mp.pressure_late_75
	if goal_difference == 0:
		value += mp.pressure_level
	elif goal_difference == -1:
		value += mp.pressure_behind_one
	elif goal_difference < -1:
		value += mp.pressure_behind_more
	return clampf(value, 0.0, 1.0)


func result_label() -> String:
	var score := final_score()
	if score.x > score.y:
		return "Galibiyet"
	if score.x < score.y:
		return "Mağlubiyet"
	return "Beraberlik"


func importance_label() -> String:
	return IMPORTANCE_LABELS[importance]


func weather_label() -> String:
	return WEATHER_LABELS[weather]


## Verilen türden rastgele bir spiker cümlesi.
func line(rng: RandomNumberGenerator, kind: String) -> String:
	return _line(rng, kind)


func _line(rng: RandomNumberGenerator, kind: String) -> String:
	var options: Array = commentary.get(kind, [])
	if options.is_empty():
		return ""
	var text: String = options[rng.randi_range(0, options.size() - 1)]
	return text.replace("{us}", us).replace("{them}", them)


static func load_teams() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/teams.json"))
	return parsed if parsed is Array else []


static func load_commentary() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/commentary.json"))
	return parsed if parsed is Dictionary else {}
