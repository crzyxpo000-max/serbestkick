class_name Keeper
extends RefCounted
## Kaleci: tepki süresinden sonra topun geleceği yeri tahmin eder ve ellerini oraya uzatır.
## Gövdesi ayaklardan ellere uzanan bir kapsüldür. Falsoyu kısmen okur, dönüşsüz topun yalpasını okuyamaz.

var params: KeeperParams
var feet_x := 0.0
var hands := Vector2.ZERO          ## (x, y), kalecinin durduğu düzlemde
var reaction := 0.35
var target := Vector2.ZERO
var has_target := false
var holding := false

var _next_read := 0.0


func _init(p_params: KeeperParams = null) -> void:
	params = p_params if p_params != null else KeeperParams.new()
	reset(0.0)


## jitter: -1…1, tepki süresindeki oynama.
func reset(start_x: float, jitter: float = 0.0) -> void:
	feet_x = start_x
	hands = Vector2(start_x, params.ready_height)
	reaction = params.reaction_time + params.reaction_jitter * clampf(jitter, -1.0, 1.0)
	target = hands
	has_target = false
	holding = false
	_next_read = 0.0


func update(sim: BallSimulator, dt: float) -> void:
	var time := sim.state.time
	if holding or sim.hit_keeper or time < reaction or sim.outcome != BallSimulator.Outcome.NONE:
		return
	if time >= _next_read and sim.state.position.z > params.depth:
		_read(sim)
		_next_read = time + params.read_interval
	if not has_target:
		return
	var limit := GoalFrame.HALF_WIDTH - params.body_radius
	feet_x = move_toward(feet_x, clampf(target.x, -limit, limit), params.step_speed * dt)
	hands = hands.move_toward(target, params.hand_speed * dt)
	var from_feet := hands - Vector2(feet_x, 0.0)
	if from_feet.length() > params.reach:
		hands = Vector2(feet_x, 0.0) + from_feet.normalized() * params.reach
	hands.y = maxf(hands.y, params.body_radius)


## Topun kalecinin düzlemini nerede geçeceğini tahmin eder.
func _read(sim: BallSimulator) -> void:
	var guess := sim.state.duplicate_state()
	guess.spin *= params.spin_read
	guess.knuckle = 0.0
	var preview := BallSimulator.new(sim.params, sim.conditions)
	preview.kick(guess)
	preview.state.time = guess.time
	var limit := guess.time + 4.0
	while preview.state.position.z > params.depth and preview.outcome == BallSimulator.Outcome.NONE \
			and preview.state.time < limit:
		preview.step()
	var point := preview.state.position
	if absf(point.x) > params.ignore_x or point.y > params.ignore_y:
		has_target = false
		return
	has_target = true
	target = Vector2(point.x, clampf(point.y, params.body_radius, GoalFrame.HEIGHT + 0.3))


## Gövde kapsülünün ekseni: [ayak ucu, el ucu].
func body_segment() -> Array[Vector3]:
	var foot := Vector3(feet_x, params.body_radius, params.depth)
	var hand := Vector3(hands.x, hands.y, params.depth)
	var along := hand - foot
	var length := along.length()
	var body := params.body_length - params.body_radius
	if length < 1e-6:
		return [foot, foot + Vector3.UP * body]
	return [foot, foot + along / length * maxf(length, body)]


## Top kaleciye değdiyse true. Yavaş top ellerde kalır (sim.outcome = SAVED), hızlısı çelinir.
func collide(sim: BallSimulator) -> bool:
	if holding:
		return false
	var state := sim.state
	var segment := body_segment()
	var closest := BallCollision.closest_on_segment(state.position, segment[0], segment[1])
	var offset := state.position - closest
	var distance := offset.length()
	var reach_distance := sim.params.radius + params.body_radius
	if distance >= reach_distance or distance < 1e-9:
		return false
	var normal := offset / distance
	if state.velocity.dot(normal) >= 0.0:
		return false
	var along := closest.distance_to(segment[0]) / segment[0].distance_to(segment[1])
	if along >= 0.55 and state.velocity.length() <= params.catch_speed:
		holding = true
		state.velocity = Vector3.ZERO
		state.spin = Vector3.ZERO
		return true
	state.position = closest + normal * reach_distance
	BallCollision.bounce(state, normal, params.parry_restitution, params.parry_friction, sim.params.radius)
	return true
