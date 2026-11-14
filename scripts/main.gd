extends Node3D
## Aşama 1 gösterimi: hazır vuruşları sırayla oynatır. Ekrana dokununca sıradaki vuruşa geçer.

enum Phase { READY, FLIGHT, RESULT }

const READY_TIME := 1.2
const RESULT_TIME := 2.5
const MAX_FLIGHT_TIME := 5.0
const CAMERA_OFFSET := Vector3(0.0, 1.3, 4.0)
const FRAME_COLOR := Color(0.95, 0.95, 0.95)
const LINE_COLOR := Color(0.9, 0.95, 0.9)

@onready var _ball: MeshInstance3D = $Ball
@onready var _camera: Camera3D = $Camera
@onready var _title: Label = $UI/Title
@onready var _info: Label = $UI/Info

var _params := PhysicsParams.load_default()
var _sim: BallSimulator
var _shots: Array[DemoShot] = []
var _index := -1
var _phase := Phase.READY
var _timer := 0.0
var _trail := ImmediateMesh.new()
var _trail_points := PackedVector3Array()
var _trail_material := StandardMaterial3D.new()


func _ready() -> void:
	_build_goal()
	_build_lines()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.albedo_color = Color(1.0, 0.85, 0.2)
	var trail_node := MeshInstance3D.new()
	trail_node.name = "Trail"
	trail_node.mesh = _trail
	add_child(trail_node)
	_shots = DemoShot.load_all()
	_next_shot()


func _process(delta: float) -> void:
	if _sim == null:
		return
	_timer += delta
	match _phase:
		Phase.READY:
			if _timer >= READY_TIME:
				_phase = Phase.FLIGHT
				_timer = 0.0
		Phase.FLIGHT:
			_fly(delta)
			if _sim.outcome != BallSimulator.Outcome.NONE or _sim.state.time > MAX_FLIGHT_TIME:
				_phase = Phase.RESULT
				_timer = 0.0
				_info.text = _result_text()
		Phase.RESULT:
			_fly(delta)
			if _timer >= RESULT_TIME:
				_next_shot()
	_follow_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_next_shot()


func _next_shot() -> void:
	if _shots.is_empty():
		_title.text = "Vuruş verisi bulunamadı"
		return
	_index = (_index + 1) % _shots.size()
	var shot := _shots[_index]
	_sim = BallSimulator.new(_params, shot.conditions)
	_sim.kick(shot.kick)
	_phase = Phase.READY
	_timer = 0.0
	_trail_points.clear()
	_trail.clear_surfaces()
	_ball.position = _sim.state.position
	_ball.basis = Basis.IDENTITY
	_camera.position = _camera_target()
	_aim_camera()
	_title.text = "%d/%d · %s" % [_index + 1, _shots.size(), shot.name]
	_info.text = "%d m · çıkış %d km/sa · dokun: sıradaki vuruş" % [
		roundi(shot.kick.position.z), roundi(shot.launch_speed * 3.6)]


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


func _camera_target() -> Vector3:
	var target := _sim.state.position + CAMERA_OFFSET
	target.y = maxf(target.y, 1.2)
	target.z = maxf(target.z, 9.0)
	return target


func _follow_camera(delta: float) -> void:
	_camera.position = _camera.position.lerp(_camera_target(), 1.0 - exp(-5.0 * delta))
	_aim_camera()


func _aim_camera() -> void:
	_camera.look_at(Vector3(_sim.state.position.x * 0.5, 1.2, 0.0))


func _result_text() -> String:
	var parts: Array[String] = []
	match _sim.outcome:
		BallSimulator.Outcome.GOAL:
			parts.append("GOL")
		BallSimulator.Outcome.OUT:
			parts.append("AUT")
		_:
			parts.append("KAÇTI")
	if _sim.hit_post:
		parts.append("direk")
	if _sim.crossed_line:
		parts.append("çizgide %d km/sa" % roundi(_sim.line_speed * 3.6))
		parts.append(("%.2f sn" % _sim.line_time).replace(".", ","))
	if _sim.bounces > 0:
		parts.append("%d sekme" % _sim.bounces)
	return " · ".join(parts)


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
	net_mesh.size = Vector3(GoalFrame.WIDTH, GoalFrame.HEIGHT, _params.net_depth)
	var net := MeshInstance3D.new()
	net.mesh = net_mesh
	net.material_override = net_material
	net.position = Vector3(0.0, GoalFrame.HEIGHT / 2.0, -_params.net_depth / 2.0)
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
