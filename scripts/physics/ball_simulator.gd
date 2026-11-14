class_name BallSimulator
extends RefCounted
## Bir vuruşun tamamını benzetir: uçuş, sekme, yuvarlanma, direk, file ve sonuç.
## Sahneden bağımsızdır; testler ve oyun aynı sınıfı kullanır.

enum Outcome { NONE, GOAL, OUT, STOPPED }

var params: PhysicsParams
var conditions: PitchConditions
var state: BallState

var outcome := Outcome.NONE
var hit_post := false
var bounces := 0                     ## sonuçtan önceki yer sekmeleri
var grounded := false                ## top yerde yuvarlanıyor
var resting := false                 ## top durdu
var crossed_line := false
var line_crossing := Vector2.ZERO    ## merkezin kale çizgisi düzlemini geçtiği nokta (x, y)
var line_speed := 0.0                ## o andaki hız (m/s)
var line_time := 0.0                 ## o andaki süre (s)

var _segments: Array = GoalFrame.segments()
var _accumulator := 0.0


func _init(p_params: PhysicsParams = null, p_conditions: PitchConditions = null) -> void:
	params = p_params if p_params != null else PhysicsParams.new()
	conditions = p_conditions if p_conditions != null else PitchConditions.new()
	state = BallState.new()


func kick(initial: BallState) -> void:
	state = initial.duplicate_state()
	outcome = Outcome.NONE
	hit_post = false
	bounces = 0
	grounded = false
	resting = false
	crossed_line = false
	line_crossing = Vector2.ZERO
	line_speed = 0.0
	line_time = 0.0
	_accumulator = 0.0


## Sonuç belli olana kadar (ya da süre dolana kadar) benzetir.
func run(max_time: float = 30.0) -> Outcome:
	while outcome == Outcome.NONE and state.time < max_time:
		step()
	return outcome


## Kare süresi kadar ilerletir; sabit adımlara böler.
func advance(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= params.time_step:
		_accumulator -= params.time_step
		step()


## Tek bir sabit adım.
func step() -> void:
	if resting:
		state.time += params.time_step
		return
	var dt := params.time_step
	var previous := state.position
	if grounded:
		_roll(dt)
	else:
		BallFlight.integrate(state, dt, params, conditions.wind)
	if outcome == Outcome.GOAL:
		_hold_in_net(dt)
	else:
		_collide_frame()
		_check_goal_line(previous)
	_collide_ground()


func _roll(dt: float) -> void:
	var horizontal := Vector3(state.velocity.x, 0.0, state.velocity.z)
	var speed := horizontal.length()
	var resistance := params.wet_rolling_resistance if conditions.wet else params.rolling_resistance
	speed -= resistance * params.gravity * dt
	state.time += dt
	if speed <= params.rest_speed:
		state.velocity = Vector3.ZERO
		state.spin = Vector3.ZERO
		resting = true
		if outcome == Outcome.NONE:
			outcome = Outcome.STOPPED
		return
	state.velocity = horizontal.normalized() * speed
	state.position += state.velocity * dt
	state.spin = Vector3.UP.cross(state.velocity) / params.radius


func _collide_ground() -> void:
	if state.position.y > params.radius:
		return
	state.position.y = params.radius
	if grounded or state.velocity.y >= 0.0:
		return
	if -state.velocity.y < params.roll_threshold:
		state.velocity.y = 0.0
		grounded = true
		return
	var restitution := params.wet_restitution if conditions.wet else params.ground_restitution
	var friction := params.wet_friction if conditions.wet else params.ground_friction
	BallCollision.bounce(state, Vector3.UP, restitution, friction, params.radius)
	if outcome == Outcome.NONE:
		bounces += 1


func _collide_frame() -> void:
	var reach := params.radius + GoalFrame.POST_RADIUS
	for segment: Array in _segments:
		var closest := BallCollision.closest_on_segment(state.position, segment[0], segment[1])
		var offset := state.position - closest
		var distance := offset.length()
		if distance >= reach or distance < 1e-9:
			continue
		var normal := offset / distance
		state.position = closest + normal * reach
		if BallCollision.bounce(state, normal, params.post_restitution, params.post_friction, params.radius):
			hit_post = true


func _check_goal_line(previous: Vector3) -> void:
	var current := state.position
	if not crossed_line and previous.z > 0.0 and current.z <= 0.0:
		var t := previous.z / (previous.z - current.z)
		var point := previous.lerp(current, t)
		crossed_line = true
		line_crossing = Vector2(point.x, point.y)
		line_speed = state.velocity.length()
		line_time = state.time
	# Gol: topun tamamı çizgiyi geçmeli.
	var behind := -params.radius
	if previous.z > behind and current.z <= behind:
		outcome = Outcome.GOAL if GoalFrame.inside_mouth(current) else Outcome.OUT


func _hold_in_net(dt: float) -> void:
	var damping := exp(-params.net_damping * dt)
	state.velocity *= damping
	state.spin *= damping
	var r := params.radius
	var back := -params.net_depth + r
	if state.position.z < back:
		state.position.z = back
		state.velocity.z = maxf(state.velocity.z, 0.0) * 0.1
	if state.position.z > -r:
		state.position.z = -r
		state.velocity.z = minf(state.velocity.z, 0.0)
	var side := GoalFrame.HALF_WIDTH - r
	if absf(state.position.x) > side:
		state.position.x = clampf(state.position.x, -side, side)
		state.velocity.x = 0.0
	var top := GoalFrame.HEIGHT - r
	if state.position.y > top:
		state.position.y = top
		state.velocity.y = minf(state.velocity.y, 0.0)
