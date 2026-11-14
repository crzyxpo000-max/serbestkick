extends Node3D
## Aşama 2: gri kutulu antrenman sahası. Vuruş noktasını seç, kaleye doğru kaydır, hedefi vur.

enum Phase { AIM, FLIGHT, RESULT }
enum Touch { NONE, STRIKE, SWIPE, AFTERTOUCH }

const RESULT_TIME := 2.0
const MAX_FLIGHT_TIME := 6.0
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
var _sim := BallSimulator.new(_pp)
var _aftertouch := Aftertouch.new(_cp)
var _rng := RandomNumberGenerator.new()
var _hud: PracticeHud
var _target_node: MeshInstance3D

var _phase := Phase.AIM
var _timer := 0.0
var _spot := Vector3(0.0, 0.11, 25.0)
var _target := TARGETS[0]
var _shots := 0
var _hits := 0
var _last_hit := false
var _launch_text := ""

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
	_place_target()
	_reset_shot()


func _process(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.FLIGHT:
			_fly(delta)
			if _aftertouch.is_active(_sim) and _touch == Touch.AFTERTOUCH:
				_info.text = "%s · havada falso %+d%%" % [_launch_text, roundi((_aftertouch.factor() - 1.0) * 100.0)]
			if _sim.outcome != BallSimulator.Outcome.NONE or _sim.state.time > MAX_FLIGHT_TIME:
				_finish_shot()
		Phase.RESULT:
			_fly(delta)
			if _timer >= RESULT_TIME:
				_reset_shot()
	# Sonuç belli olunca kamera yerinde kalır.
	if _phase == Phase.FLIGHT:
		var target := _camera_position(_sim.state.position)
		_camera.position = _camera.position.lerp(target, 1.0 - exp(-5.0 * delta))
		_camera.look_at(LOOK_AT)


func _unhandled_input(event: InputEvent) -> void:
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
			_reset_shot()


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
	var kick := ShotBuilder.build(swipe, _goal_plane_point(swipe.launch_point), _spot, _hud.strike, _cp, _pp)
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
	_timer = 0.0
	var parts: Array[String] = []
	_last_hit = false
	match _sim.outcome:
		BallSimulator.Outcome.GOAL:
			_last_hit = _sim.line_crossing.distance_to(_target) <= TARGET_RADIUS
			parts.append("HEDEF!" if _last_hit else "GOL")
		BallSimulator.Outcome.OUT:
			parts.append("AUT")
		_:
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
	_phase = Phase.AIM
	_timer = 0.0
	_trail_points.clear()
	_trail.clear_surfaces()
	_ball.position = _spot
	_ball.basis = Basis.IDENTITY
	_camera.position = _camera_position(_spot)
	_camera.look_at(LOOK_AT)
	_hud.show_disc = true
	_info.text = "%d m · vuruş noktasını soldan seç, kaleye doğru kaydır" % roundi(_spot.distance_to(Vector3.ZERO))
	_update_title()


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
	_title.text = "Hedef: %d / %d vuruş" % [_hits, _shots]


func _fly(delta: float) -> void:
	_sim.advance(delta)
	_ball.position = _sim.state.position
	var spin := _sim.state.spin
	var rate := spin.length()
	if rate > 0.01:
		_ball.basis = (Basis(spin / rate, rate * delta) * _ball.basis).orthonormalized()
	if _trail_points.is_empty() or _trail_points[-1].distance_to(_ball.position) > 0.05:
		_trail_points.append(_ball.position)
		_draw_trail()


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
