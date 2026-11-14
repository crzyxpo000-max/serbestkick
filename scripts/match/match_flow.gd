class_name MatchFlow
extends Control
## Menü ve maç akışı: maç öncesi, hızlı akan maç, oyuna alınma, vuruş, maç sonu.
## Maçın kuralları `Match` içindedir; bu sınıf yalnızca ekranları ve zamanlamayı yürütür.

enum Stage { MENU, PREMATCH, TICKER, CALLIN, SHOT, FULLTIME, PRACTICE }

const MAX_LINES := 5

var _scene: ShotScene
var _mp := MatchParams.load_default()
var _teams := Match.load_teams()
var _commentary := Match.load_commentary()
var _rng := RandomNumberGenerator.new()

var _stage := Stage.MENU
var _match: Match
var _minute := 0.0
var _event_index := 0
var _pause := 0.0
var _half_time_said := false
var _lines: Array[String] = []
var _kick: FreeKick

var _score_label: Label
var _minute_label: Label
var _lines_label: Label
var _boot_button: Button


func _init(scene: ShotScene) -> void:
	_scene = scene


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_scene.shot_finished.connect(_on_shot_finished)
	_scene.menu_requested.connect(_show_menu)
	_scene.boot_changed.connect(_refresh_boot_button)
	_show_menu()


func _process(delta: float) -> void:
	if _stage != Stage.TICKER:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	_minute += delta / _mp.seconds_per_minute
	if not _half_time_said and _minute >= 45.0:
		_half_time_said = true
		_say(45, _match.line(_rng, "halftime"))
		_pause = _mp.event_pause
	while _event_index < _match.events.size() and _match.events[_event_index].minute <= _minute:
		var event := _match.events[_event_index]
		_event_index += 1
		_say(event.minute, event.text)
		if event.kind == MatchEvent.Kind.FREE_KICK:
			_minute = event.minute
			_kick = event.free_kick
			_refresh_ticker()
			_show_call_in()
			return
		_pause = _mp.event_pause
		break
	if _minute >= Match.LENGTH and _event_index >= _match.events.size() and _pause <= 0.0:
		_minute = Match.LENGTH
		_say(Match.LENGTH, _match.line(_rng, "fulltime"))
		_show_full_time()
		return
	_refresh_ticker()


# --- Ekranlar ---

func _show_menu() -> void:
	_stage = Stage.MENU
	_scene.set_idle()
	var box := _panel(0.72, 460)
	box.add_child(_text("Serbest Kick", 52))
	box.add_child(_text("Takımın duran top uzmanısın.\nKritik anda oyuna girer, tek vuruşunu kullanırsın.", 22, Color(1, 1, 1, 0.8)))
	box.add_child(_button("Maç", _new_match))
	box.add_child(_button("Antrenman", _start_practice))


func _start_practice() -> void:
	_stage = Stage.PRACTICE
	_clear()
	_scene.start_practice()


func _new_match() -> void:
	_match = Match.generate(_rng, _teams, _commentary, _mp)
	_stage = Stage.PREMATCH
	var box := _panel(0.72, 560)
	box.add_child(_text(_match.importance_label(), 24, Color(1.0, 0.85, 0.3)))
	box.add_child(_text(_match.scoreline(0).replace(" 0 – 0 ", "  –  "), 36))
	var details := "%s · %s" % ["İç saha" if _match.home else "Deplasman", _match.weather_label()]
	box.add_child(_text(details, 22, Color(1, 1, 1, 0.8)))
	box.add_child(_text("Takımın: %s\nKramponunu şimdi seç; maç başlayınca değiştiremezsin." % _match.us, 20, Color(1, 1, 1, 0.8)))
	_boot_button = _button("", _scene.open_picker)
	box.add_child(_boot_button)
	_refresh_boot_button()
	box.add_child(_button("Maça başla", _start_ticker))
	box.add_child(_button("Menü", _show_menu))


func _refresh_boot_button() -> void:
	if _stage == Stage.PREMATCH and is_instance_valid(_boot_button) and _scene.boot() != null:
		_boot_button.text = "Krampon: %s (%s) · değiştir" % [_scene.boot().name, _scene.boot().type_label()]


func _start_ticker() -> void:
	_minute = 0.0
	_event_index = 0
	_half_time_said = false
	_lines.clear()
	_say(1, _match.line(_rng, "kickoff"))
	_pause = _mp.event_pause * 0.5
	_show_ticker()


func _show_ticker() -> void:
	_stage = Stage.TICKER
	var box := _panel(0.45, 640)
	box.add_child(_text("%s · %s" % [_match.importance_label(), _match.weather_label()], 20, Color(1.0, 0.85, 0.3)))
	_score_label = _text("", 38)
	box.add_child(_score_label)
	_minute_label = _text("", 30, Color(0.6, 1.0, 0.6))
	box.add_child(_minute_label)
	_lines_label = _text("", 21, Color(1, 1, 1, 0.85))
	_lines_label.custom_minimum_size = Vector2(0, 170)
	_lines_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(_lines_label)
	_refresh_ticker()


func _refresh_ticker() -> void:
	if not is_instance_valid(_score_label):
		return
	var minute := mini(int(_minute), Match.LENGTH)
	_score_label.text = _match.scoreline(minute)
	_minute_label.text = "%d'" % minute
	_lines_label.text = "\n".join(_lines)


func _show_call_in() -> void:
	_stage = Stage.CALLIN
	var pressure := _match.pressure_for(_kick)
	var box := _panel(0.6, 640)
	box.add_child(_text("%d. dakika · FAUL!" % _kick.minute, 30, Color(1.0, 0.85, 0.3)))
	box.add_child(_text("Teknik direktör seni çağırıyor.", 34))
	box.add_child(_text(_match.scoreline(_kick.minute - 1), 28))
	var facts: Array[String] = [
		"%d metre" % roundi(_kick.distance()),
		"barajda %d oyuncu" % _kick.wall_count,
		"kaleci öne çıkıyor" if _kick.keeper_forward else "kaleci çizgide",
	]
	box.add_child(_text(" · ".join(facts), 22, Color(1, 1, 1, 0.85)))
	box.add_child(_text("%s · Baskı: %s" % [_match.weather_label(), _pressure_label(pressure)], 22, Color(1, 1, 1, 0.85)))
	box.add_child(_button("Sahaya çık", _take_shot))


func _take_shot() -> void:
	_stage = Stage.SHOT
	_clear()
	var header := "%d' · %s" % [_kick.minute, _match.scoreline(_kick.minute - 1)]
	var depth := _mp.forward_depth if _kick.keeper_forward else -1.0
	_scene.begin_shot(_kick, _match.conditions, _match.pressure_for(_kick), header, depth)


func _on_shot_finished(scored: bool) -> void:
	if _stage != Stage.SHOT:
		return
	_match.record_shot(_kick, scored)
	_say(_kick.minute, _match.line(_rng, "player_goal" if scored else "player_miss"))
	_pause = _mp.event_pause
	_show_ticker()


func _show_full_time() -> void:
	_stage = Stage.FULLTIME
	var box := _panel(0.72, 600)
	box.add_child(_text("Maç bitti · %s" % _match.result_label(), 30, Color(1.0, 0.85, 0.3)))
	box.add_child(_text(_match.scoreline(Match.LENGTH), 40))
	var shots := _match.shots_taken()
	var summary := "Bu maçta serbest vuruş çıkmadı."
	if shots > 0:
		summary = "Senin vuruşların: %d gol / %d vuruş" % [_match.player_goals(), shots]
	box.add_child(_text(summary, 24, Color(1, 1, 1, 0.85)))
	box.add_child(_button("Yeni maç", _new_match))
	box.add_child(_button("Menü", _show_menu))


# --- Yardımcılar ---

func _say(minute: int, text: String) -> void:
	if text.is_empty():
		return
	_lines.append("%d' %s" % [minute, text])
	while _lines.size() > MAX_LINES:
		_lines.pop_front()


func _pressure_label(pressure: float) -> String:
	if pressure < 0.25:
		return "düşük"
	if pressure < 0.5:
		return "orta"
	if pressure < 0.75:
		return "yüksek"
	return "çok yüksek"


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_score_label = null
	_minute_label = null
	_lines_label = null
	_boot_button = null


## Ekranı karartır ve ortada bir kutu açar; içine eklenecek dikey kutuyu döndürür.
func _panel(dim: float, width: float) -> VBoxContainer:
	_clear()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(width, 0)
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	return box


func _text(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	return button
