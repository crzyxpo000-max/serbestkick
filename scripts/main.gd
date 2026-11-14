class_name ShotScene
extends Node3D
## Vuruş sahnesi: vuruş noktasını seç, kaleye doğru kaydır; barajı aş, kaleciyi geç.
## Antrenmanda hedef halkası ve sınırsız deneme vardır; maçta tek vuruş hakkı, baskı ve ağır çekim tekrar.
## Menü ve maç akışı `MatchFlow` içindedir; bu sahneyi `start_practice`, `begin_shot`, `set_idle` ile sürer.

signal shot_finished(scored: bool)
signal menu_requested
signal boot_changed

enum Phase { AIM, FLIGHT, RESULT, REPLAY }
enum Touch { NONE, STRIKE, SWIPE, AFTERTOUCH }

const RESULT_TIME := 2.0
const MAX_FLIGHT_TIME := 6.0
const DEFLECTION_TIME := 1.2
const REPLAY_SPEED := 0.35
const REPLAY_TAIL := 0.5      ## s, sonuçtan sonra tekrarda gösterilen süre
const CAMERA_BACK := 4.0
const CAMERA_HEIGHT := 1.3
const CAMERA_MIN_Z := 6.0
const LOOK_AT := Vector3(0.0, 1.2, 0.0)
const TARGET_RADIUS := 0.7
const TARGETS: Array[Vector2] = [
	Vector2(-2.8, 1.75), Vector2(2.8, 1.75), Vector2(-2.8, 0.7), Vector2(2.8, 0.7), Vector2(0.0, 1.75),
]
const FRAME_COLOR := Color(0.95, 0.95, 0.95)
const LINE_COLOR := Color(0.9, 0.95, 0.9)

@onready var _ball: MeshInstance3D = $Ball
@onready var _camera: Camera3D = $Camera
@onready var _title: Label = $UI/Title
@onready var _info: Label = $UI/Info

var _pp := PhysicsParams.load_default()
var _cp := ControlParams.load_default()
var _kp := KeeperParams.load_default()
var _mp := MatchParams.load_default()
var _sim := BallSimulator.new(_pp)
var _wall := Wall.new(_kp)
var _keeper := Keeper.new(_kp)
var _boots := Boot.load_all()
var _boot: Boot
var _picker: BootPicker
var _wall_nodes: Array[MeshInstance3D] = []
var _keeper_body: MeshInstance3D
var _keeper_hands: MeshInstance3D
var _aftertouch := Aftertouch.new(_cp)
var _assist := AimAssist.new(_cp)
var _rng := RandomNumberGenerator.new()
var _hud: PracticeHud
var _target_node: MeshInstance3D

var _phase := Phase.AIM
var _timer := 0.0
var _spot := Vector3(0.0, 0.11, 25.0)
var _target := TARGETS[0]
var _shots := 0
var _hits := 0
var _goals := 0
var _last_hit := false
var _launch_text := ""
var _deflected_for := 0.0

var _active := false          ## false iken sahne girdi almaz (menü ya da maç akışı ekranda)
var _practice := true
var _pressure := 0.0
var _header := ""
var _wall_count := -1         ## eksi = mesafeye göre
var _keeper_depth := -1.0     ## eksi = ayarlardaki değer
var _scored := false
var _practice_buttons: Array[Control] = []
var _record: Array = []       ## tekrar için kareler: [süre, top konumu, top yönü, kaleci ayak x, kaleci elleri]
var _replay_time := 0.0
var _replay_index := 0
var _replay_end := 0.0

var _touch := Touch.NONE
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _points := PackedVector2Array()
var _times := PackedFloat64Array()

var _trail := ImmediateMesh.new()
var _trail_points := PackedVector3Array()
var _trail_material := StandardMaterial3D.new()


func _ready() -> void:
	_rng.randomize()
	_spot.y = _pp.radius
	_build_goal()
	_build_lines()
	_build_target()
	_build_keeper()
	_sim.wall = _wall
	_assist.wall = _wall
	_sim.keeper = _keeper
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.albedo_color = Color(1.0, 0.85, 0.2)
	var trail_node := MeshInstance3D.new()
	trail_node.name = "Trail"
	trail_node.mesh = _trail
	add_child(trail_node)
	_hud = PracticeHud.new()
	$UI.add_child(_hud)
	var button := Button.new()
	button.text = "Yeni konum"
	button.add_theme_font_size_override("font_size", 22)
	button.position = Vector2(16, 12)
	button.pressed.connect(_new_spot)
	$UI.add_child(button)
	_practice_buttons.append(button)
	var boot_button := Button.new()
	boot_button.text = "Krampon"
	boot_button.add_theme_font_size_override("font_size", 22)
	boot_button.position = Vector2(16, 64)
	boot_button.pressed.connect(open_picker)
	$UI.add_child(boot_button)
	_practice_buttons.append(boot_button)
	var menu_button := Button.new()
	menu_button.text = "Menü"
	menu_button.add_theme_font_size_override("font_size", 22)
	menu_button.position = Vector2(16, 116)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	$UI.add_child(menu_button)
	_practice_buttons.append(menu_button)
	$UI.add_child(MatchFlow.new(self))
	_picker = BootPicker.new(_boots)
	_picker.visible = false
	_picker.picked.connect(_pick_boot)
	$UI.add_child(_picker)
	_pick_boot(_boots[0] if not _boots.is_empty() else Boot.neutral(_cp))
	_place_target()
	_reset_shot()
	set_idle()


## Antrenman: hedef halkası, rastgele konum, sınırsız deneme.
func start_practice() -> void:
	_practice = true
	_active = true
	_pressure = 0.0
	_wall_count = -1
	_keeper_depth = -1.0
	_sim.conditions = PitchConditions.new()
	_last_hit = false
	_show_practice_ui(true)
	_reset_shot()


## Maçtaki tek vuruş. Bitince (tekrardan sonra) `shot_finished` yayılır.
func begin_shot(kick: FreeKick, conditions: PitchConditions, pressure: float, header: String,
		keeper_depth: float) -> void:
	_practice = false
	_active = true
	_pressure = pressure
	_header = header
	_spot = Vector3(kick.spot.x, _pp.radius, kick.spot.z)
	_wall_count = kick.wall_count
	_keeper_depth = keeper_depth
	_sim.conditions = conditions
	_show_practice_ui(false)
	_reset_shot()


## Sahneyi bekletir: girdi almaz, vuruş arayüzü gizlenir.
func set_idle() -> void:
	_active = false
	_touch = Touch.NONE
	_touch_index = -1
	_show_practice_ui(false)
	_hud.show_disc = false
	_hud.pressure = 0.0
	_hud.swipe_points = PackedVector2Array()
	_title.text = ""
	_info.text = ""


func boot() -> Boot:
	return _boot


func _show_practice_ui(shown: bool) -> void:
	for control in _practice_buttons:
		control.visible = shown
	_target_node.visible = shown


func _process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	match _phase:
		Phase.AIM:
			_sway_camera()
		Phase.REPLAY:
			_replay(delta)
		Phase.FLIGHT:
			_fly(delta)
			if _aftertouch.is_active(_sim) and _touch == Touch.AFTERTOUCH:
				_info.text = "%s · havada falso %+d%%" % [_launch_text, roundi((_aftertouch.factor() - 1.0) * 100.0)]
			# Baraj, kaleci ya da direkten dönen top için sonucu çok bekletme.
			if _sim.hit_wall or _sim.hit_keeper or _sim.hit_post:
				_deflected_for += delta
			if _sim.outcome != BallSimulator.Outcome.NONE or _sim.state.time > MAX_FLIGHT_TIME \
					or _deflected_for > DEFLECTION_TIME:
				_finish_shot()
		Phase.RESULT:
			if _sim.outcome != BallSimulator.Outcome.SAVED:
				_fly(delta)
			if _timer >= RESULT_TIME:
				if _practice:
					_reset_shot()
				else:
					_start_replay()
	# Sonuç belli olunca kamera yerinde kalır.
	if _phase == Phase.FLIGHT:
		var target := _camera_position(_sim.state.position)
		_camera.position = _camera.position.lerp(target, 1.0 - exp(-5.0 * delta))
		_camera.look_at(LOOK_AT)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		elif event.index == _touch_index:
			_touch_up()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_touch_move(event.position)


func _touch_down(index: int, at: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_touch_start = at
	match _phase:
		Phase.AIM:
			if _hud.in_disc(at):
				_touch = Touch.STRIKE
				_hud.strike = _hud.strike_from(at)
			else:
				_touch = Touch.SWIPE
				_points = PackedVector2Array([at])
				_times = PackedFloat64Array([_now()])
		Phase.FLIGHT:
			_touch = Touch.AFTERTOUCH
		Phase.RESULT:
			_touch = Touch.NONE
			if _practice:
				_reset_shot()
			else:
				_start_replay()
		Phase.REPLAY:
			_touch = Touch.NONE
			_end_match_shot()


func _touch_move(at: Vector2) -> void:
	match _touch:
		Touch.STRIKE:
			_hud.strike = _hud.strike_from(at)
		Touch.SWIPE:
			_points.append(at)
			_times.append(_now())
			_hud.swipe_points = _points
		Touch.AFTERTOUCH:
			_aftertouch.apply(_sim, (at - _touch_start) / _screen_height())


func _touch_up() -> void:
	if _touch == Touch.SWIPE and _phase == Phase.AIM:
		_shoot()
	_touch = Touch.NONE
	_touch_index = -1
	_hud.swipe_points = PackedVector2Array()


func _shoot() -> void:
	var swipe := Swipe.analyze(_points, _times, _screen_height(), _cp)
	if not swipe.valid:
		_info.text = "Daha uzun kaydır"
		return
	# Baskı altında kaydırma toleransı daralır: aynı hata daha çok sapma verir.
	var noise := Vector2(_rng.randfn(), _rng.randfn()).limit_length(2.5) * (1.0 + _pressure * _mp.pressure_scatter)
	var kick := ShotBuilder.build(swipe, _goal_plane_point(swipe.launch_point), _spot, _hud.strike, _cp, _pp,
			_boot, noise, _sim.conditions.wet, _assist)
	_record.clear()
	_sim.kick(kick)
	_aftertouch.begin(kick)
	_shots += 1
	_phase = Phase.FLIGHT
	_timer = 0.0
	_hud.show_disc = false
	var spin_rate := kick.spin.length() / TAU
	_launch_text = "çıkış %d km/sa · %s" % [
		roundi(kick.velocity.length() * 3.6),
		"dönüşsüz" if kick.knuckle > 0.0 else ("falso %s tur/sn" % _decimal(spin_rate))]
	_info.text = _launch_text
	_update_title()


func _finish_shot() -> void:
	_phase = Phase.RESULT
	_replay_end = _sim.state.time + REPLAY_TAIL
	_timer = 0.0
	var parts: Array[String] = []
	_last_hit = false
	_scored = _sim.outcome == BallSimulator.Outcome.GOAL
	if _scored:
		_goals += 1
		_last_hit = _practice and _sim.line_crossing.distance_to(_target) <= TARGET_RADIUS
		parts.append("HEDEF!" if _last_hit else "GOL")
	elif _sim.hit_keeper:
		parts.append("KALECİ KURTARDI")
	elif _sim.hit_wall:
		parts.append("BARAJ")
	elif _sim.outcome == BallSimulator.Outcome.OUT:
		parts.append("AUT")
	else:
		parts.append("KAÇTI")
	if _last_hit:
		_hits += 1
	if _sim.hit_post:
		parts.append("direk")
	if _sim.crossed_line:
		parts.append("çizgide %d km/sa" % roundi(_sim.line_speed * 3.6))
	parts.append(_launch_text)
	_info.text = " · ".join(parts)
	_update_title()


func _reset_shot() -> void:
	if _last_hit:
		_place_target()
		_last_hit = false
	var rest := BallState.new()
	rest.position = _spot
	_sim.kick(rest)
	_wall.place(_spot, _wall_count if _wall_count > 0 else Wall.default_count(_spot))
	_keeper.reset(-_wall.near_post_sign * _kp.start_offset, _rng.randf_range(-1.0, 1.0), _keeper_depth)
	_place_wall_nodes()
	_show_defenders(0.0)
	_phase = Phase.AIM
	_timer = 0.0
	_deflected_for = 0.0
	_trail_points.clear()
	_trail.clear_surfaces()
	_ball.position = _spot
	_ball.basis = Basis.IDENTITY
	_camera.position = _camera_position(_spot)
	_camera.look_at(LOOK_AT)
	_hud.show_disc = true
	_hud.pressure = _pressure
	var distance := roundi(Vector2(_spot.x, _spot.z).length())
	if _practice:
		_info.text = "%d m · vuruş noktasını soldan seç, kaleye doğru kaydır" % distance
	else:
		var notes: Array[String] = ["%d m" % distance, "tek vuruş hakkın var"]
		var wind := _wind_text()
		if not wind.is_empty():
			notes.append(wind)
		if _sim.conditions.wet:
			notes.append("ıslak saha")
		_info.text = " · ".join(notes)
	_update_title()


## Krampon yalnızca vuruştan önce değiştirilebilir; maçta pozisyon çıkınca değiştirilemez.
func open_picker() -> void:
	if _phase != Phase.AIM or _touch != Touch.NONE or (_active and not _practice):
		return
	_picker.select(_boot)
	_picker.visible = true


func _pick_boot(boot: Boot) -> void:
	_boot = boot
	_aftertouch.limit = boot.aftertouch
	_hud.boot = boot
	_picker.visible = false
	boot_changed.emit()


func _new_spot() -> void:
	var distance := _rng.randf_range(18.0, 35.0)
	var angle := deg_to_rad(_rng.randf_range(-30.0, 30.0))
	_spot = Vector3(sin(angle) * distance, _pp.radius, cos(angle) * distance)
	_last_hit = false
	_place_target()
	_reset_shot()


func _place_target() -> void:
	var options := TARGETS.filter(func(candidate: Vector2) -> bool: return candidate != _target)
	_target = options[_rng.randi_range(0, options.size() - 1)]
	_target_node.position = Vector3(_target.x, _target.y, 0.0)


func _update_title() -> void:
	if _practice:
		_title.text = "Gol: %d · Hedef: %d · Vuruş: %d" % [_goals, _hits, _shots]
	else:
		_title.text = _header


## Rüzgarın vurucuya göre yönü: "rüzgar 22 km/sa soldan sağa".
func _wind_text() -> String:
	var wind := _sim.conditions.wind
	if wind.length() < 0.5:
		return ""
	var forward := (-Vector3(_spot.x, 0.0, _spot.z)).normalized()
	var right := forward.cross(Vector3.UP)
	var across := wind.dot(right)
	var along := wind.dot(forward)
	var direction := ""
	if absf(across) >= absf(along):
		direction = "soldan sağa" if across > 0.0 else "sağdan sola"
	else:
		direction = "arkadan" if along > 0.0 else "karşıdan"
	return "rüzgar %d km/sa %s" % [roundi(wind.length() * 3.6), direction]


## Baskı altında nişan hafifçe titrer.
func _sway_camera() -> void:
	_camera.look_at(LOOK_AT)
	if _pressure <= 0.0:
		return
	var amount := deg_to_rad(_mp.pressure_sway) * _pressure
	_camera.rotate_object_local(Vector3.UP, amount * (sin(_timer * 1.7) + 0.5 * sin(_timer * 3.1)))
	_camera.rotate_object_local(Vector3.RIGHT, amount * 0.6 * (cos(_timer * 2.3) + 0.5 * sin(_timer * 4.3)))


func _start_replay() -> void:
	if _record.size() < 2:
		_end_match_shot()
		return
	_phase = Phase.REPLAY
	_replay_time = _record[0][0]
	_replay_index = 0
	_trail_points.clear()
	_trail.clear_surfaces()
	# Barajın kapatmadığı taraftan, kaleye yakın bir açı.
	_camera.position = Vector3(-_wall.near_post_sign * 7.5, 2.0, 7.0)
	_camera.look_at(Vector3(0.0, 1.1, -0.5))
	_info.text = "TEKRAR · " + _info.text


func _replay(delta: float) -> void:
	_replay_time += delta * REPLAY_SPEED
	while _replay_index < _record.size() - 1 and _record[_replay_index + 1][0] <= _replay_time:
		_replay_index += 1
	var frame: Array = _record[_replay_index]
	_ball.position = frame[1]
	_ball.basis = frame[2]
	_keeper.feet_x = frame[3]
	_keeper.hands = frame[4]
	_show_defenders(frame[0])
	if _trail_points.is_empty() or _trail_points[-1].distance_to(_ball.position) > 0.05:
		_trail_points.append(_ball.position)
		_draw_trail()
	if _replay_time >= minf(_record[-1][0], _replay_end):
		_end_match_shot()


func _end_match_shot() -> void:
	set_idle()
	shot_finished.emit(_scored)


func _fly(delta: float) -> void:
	_sim.advance(delta)
	_show_defenders(_sim.state.time)
	_ball.position = _sim.state.position
	var spin := _sim.state.spin
	var rate := spin.length()
	if rate > 0.01:
		_ball.basis = (Basis(spin / rate, rate * delta) * _ball.basis).orthonormalized()
	if _trail_points.is_empty() or _trail_points[-1].distance_to(_ball.position) > 0.05:
		_trail_points.append(_ball.position)
		_draw_trail()
	if not _practice:
		_record.append([_sim.state.time, _ball.position, _ball.basis, _keeper.feet_x, _keeper.hands])


func _draw_trail() -> void:
	_trail.clear_surfaces()
	if _trail_points.size() < 2:
		return
	_trail.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _trail_material)
	for point in _trail_points:
		_trail.surface_add_vertex(point)
	_trail.surface_end()


## Kamera topun arkasında, top–kale doğrultusunda durur.
func _camera_position(ball: Vector3) -> Vector3:
	var back := Vector3(_spot.x, 0.0, _spot.z).normalized()
	var target := ball + back * CAMERA_BACK
	target.y = maxf(ball.y + CAMERA_HEIGHT - _pp.radius, CAMERA_HEIGHT)
	target.z = maxf(target.z, CAMERA_MIN_Z)
	return target


## Ekran noktasından çıkan ışının kale düzlemini (z = 0) kestiği nokta (x, y).
func _goal_plane_point(screen_point: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_point)
	var normal := _camera.project_ray_normal(screen_point)
	if normal.z > -1e-4:
		return Vector2(signf(normal.x) * ShotBuilder.TARGET_LIMIT_X, ShotBuilder.TARGET_LIMIT_Y)
	var point := origin + normal * (-origin.z / normal.z)
	return Vector2(point.x, point.y)


func _screen_height() -> float:
	return get_viewport().get_visible_rect().size.y


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


func _build_target() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = TARGET_RADIUS - 0.08
	mesh.outer_radius = TARGET_RADIUS
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.3, 0.2)
	_target_node = MeshInstance3D.new()
	_target_node.name = "Target"
	_target_node.mesh = mesh
	_target_node.material_override = material
	_target_node.rotation.x = PI / 2.0
	add_child(_target_node)


func _build_keeper() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.75, 0.1)
	var body := CapsuleMesh.new()
	body.radius = _kp.body_radius
	body.height = _kp.body_length
	_keeper_body = MeshInstance3D.new()
	_keeper_body.name = "Keeper"
	_keeper_body.mesh = body
	_keeper_body.material_override = material
	add_child(_keeper_body)
	var glove_material := StandardMaterial3D.new()
	glove_material.albedo_color = Color(0.95, 0.95, 0.95)
	var glove := SphereMesh.new()
	glove.radius = 0.16
	glove.height = 0.32
	_keeper_hands = MeshInstance3D.new()
	_keeper_hands.mesh = glove
	_keeper_hands.material_override = glove_material
	add_child(_keeper_hands)


## Baraj oyuncularını (kutular) yerleştirir; sayı değiştiyse yeniden kurar.
func _place_wall_nodes() -> void:
	while _wall_nodes.size() > _wall.centres.size():
		_wall_nodes.pop_back().queue_free()
	while _wall_nodes.size() < _wall.centres.size():
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.3, 0.75)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(_kp.wall_player_width * 0.92, _kp.wall_player_height, _kp.wall_player_depth)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		add_child(node)
		_wall_nodes.append(node)
	for node in _wall_nodes:
		node.basis = Basis(_wall.axis, Vector3.UP, _wall.facing)


## Barajı ve kaleciyi benzetimdeki durumlarına göre çizer.
func _show_defenders(time: float) -> void:
	var lift := _wall.jump_offset(time) if _phase != Phase.AIM else 0.0
	for i in _wall_nodes.size():
		_wall_nodes[i].position = _wall.centres[i] + Vector3.UP * (lift + _kp.wall_player_height / 2.0)
	var segment := _keeper.body_segment()
	var along := segment[1] - segment[0]
	_keeper_body.position = (segment[0] + segment[1]) * 0.5
	_keeper_body.basis = Basis(Quaternion(Vector3.UP, along.normalized()))
	_keeper_body.scale = Vector3(1.0, (along.length() + 2.0 * _kp.body_radius) / _kp.body_length, 1.0)
	_keeper_hands.position = Vector3(_keeper.hands.x, _keeper.hands.y, _keeper.depth)


func _build_goal() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = FRAME_COLOR
	for segment: Array in GoalFrame.segments():
		var from: Vector3 = segment[0]
		var to: Vector3 = segment[1]
		var mesh := CylinderMesh.new()
		mesh.top_radius = GoalFrame.POST_RADIUS
		mesh.bottom_radius = GoalFrame.POST_RADIUS
		mesh.height = from.distance_to(to)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.position = (from + to) * 0.5
		if absf((to - from).normalized().y) < 0.5:
			node.rotation.z = PI / 2.0
		add_child(node)
	var net_material := StandardMaterial3D.new()
	net_material.albedo_color = Color(1.0, 1.0, 1.0, 0.18)
	net_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var net_mesh := BoxMesh.new()
	net_mesh.size = Vector3(GoalFrame.WIDTH, GoalFrame.HEIGHT, _pp.net_depth)
	var net := MeshInstance3D.new()
	net.mesh = net_mesh
	net.material_override = net_material
	net.position = Vector3(0.0, GoalFrame.HEIGHT / 2.0, -_pp.net_depth / 2.0)
	add_child(net)


## Kale çizgisi, ceza sahası (16,5 m) ve kale sahası (5,5 m).
func _build_lines() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = LINE_COLOR
	var post := GoalFrame.HALF_WIDTH
	_add_line(material, Vector3(0, 0, 0), Vector3(68.0, 0, 0.12))
	for box: Vector2 in [Vector2(post + 16.5, 16.5), Vector2(post + 5.5, 5.5)]:
		_add_line(material, Vector3(0, 0, box.y), Vector3(box.x * 2.0, 0, 0.12))
		_add_line(material, Vector3(-box.x, 0, box.y / 2.0), Vector3(0.12, 0, box.y))
		_add_line(material, Vector3(box.x, 0, box.y / 2.0), Vector3(0.12, 0, box.y))


func _add_line(material: Material, centre: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.01, size.z)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = centre + Vector3(0, 0.005, 0)
	add_child(node)
