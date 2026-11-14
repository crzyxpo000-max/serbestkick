class_name ShotBuilder
extends RefCounted
## Kaydırma + vuruş noktası → topun çıkış durumu.
## Parmağın hızı gücü, yönü nişanı, yayın eğriliği falsoyu belirler.

const MAX_ELEVATION := 35.0
const TARGET_LIMIT_X := 15.0
const TARGET_LIMIT_Y := 6.0


## target: kaydırmanın çıkış noktasının kale düzlemindeki (z = 0) karşılığı (x, y), metre.
## strike: topun üzerindeki vuruş noktası, -1…1 (+x sağ, +y üst).
## boot: krampon (yoksa kontrol ayarlarındaki sınırlar, hatasız). noise: (yön, yükseliş) için birim rastgele
## sapma; kramponun isabeti ve tatlı noktası bunun ne kadarının vuruşa yansıyacağını belirler.
static func build(swipe: Swipe, target: Vector2, ball_position: Vector3, strike: Vector2,
		cp: ControlParams, pp: PhysicsParams, boot: Boot = null, noise: Vector2 = Vector2.ZERO,
		wet: bool = false) -> BallState:
	if boot == null:
		boot = Boot.neutral(cp)
	var hit := strike.limit_length(1.0)
	var mishit := boot.mishit(hit)
	var power := clampf(inverse_lerp(cp.slow_swipe, cp.fast_swipe, swipe.speed), 0.0, 1.0)
	var top_speed := maxf(boot.power, cp.min_speed)
	var speed := lerpf(cp.min_speed, top_speed, power) * (1.0 - cp.strike_power_loss * mishit * mishit)

	var aim_x := clampf(target.x, -TARGET_LIMIT_X, TARGET_LIMIT_X)
	var aim_y := clampf(target.y, pp.radius, TARGET_LIMIT_Y)
	var azimuth := rad_to_deg(atan2(aim_x - ball_position.x, ball_position.z))
	var elevation := solve_elevation(ball_position, speed, azimuth, aim_y, pp)
	var scatter := scatter_degrees(boot, cp, power, mishit, wet)
	azimuth += noise.x * scatter
	elevation += noise.y * scatter * 0.6
	elevation = clampf(elevation - hit.y * cp.strike_elevation, 0.0, MAX_ELEVATION + cp.strike_elevation)

	# Sağa bombeli yay: top sağa çıkar, sola kıvrılır. Topun sağına vurmak da sola kıvırır.
	var bend := maxf(absf(swipe.curvature) - cp.curvature_dead_zone, 0.0)
	var curve := signf(swipe.curvature) * clampf(bend / (cp.curvature_full - cp.curvature_dead_zone), 0.0, 1.0)
	var spin_scale := boot.curl / cp.max_side_spin
	var swipe_spin := -curve * boot.curl
	var side_spin := clampf(swipe_spin - hit.x * cp.strike_side_spin * spin_scale, -boot.curl, boot.curl)
	var top_spin := hit.y * cp.strike_top_spin * spin_scale

	var knuckle := hit.length() <= cp.knuckle_radius and absf(swipe_spin) <= cp.knuckle_max_spin
	if knuckle:
		side_spin = 0.0
		top_spin = 0.0
	var state := BallState.from_kick(ball_position, speed, elevation, azimuth, side_spin, top_spin)
	if knuckle:
		state.knuckle = 1.0
		state.knuckle_phase = fposmod(speed * 7.13 + aim_x * 3.7 + aim_y * 5.3, TAU)
	return state


## Nişan sapmasının standart sapması (derece): sert vuruşta ve tatlı noktanın dışında büyür,
## kramponun isabeti küçültür.
static func scatter_degrees(boot: Boot, cp: ControlParams, power: float, mishit: float, wet: bool) -> float:
	var forgiven := boot.effective_accuracy(wet)
	return cp.scatter_base * (1.0 - forgiven) * (0.4 + 0.6 * power) + cp.scatter_mishit * (1.0 - forgiven) * mishit


## Falsosuz topun kale düzlemini `target_y` yüksekliğinde geçmesi için gereken yükseliş açısı (derece).
## Top o hızla yetişemiyorsa en uzağa giden açıya yakın bir değer döner.
static func solve_elevation(ball_position: Vector3, speed: float, azimuth_deg: float, target_y: float,
		pp: PhysicsParams) -> float:
	var low := 0.0
	var high := MAX_ELEVATION
	if _height_at_line(ball_position, speed, high, azimuth_deg, pp) < target_y:
		return high
	for i in 18:
		var middle := (low + high) * 0.5
		if _height_at_line(ball_position, speed, middle, azimuth_deg, pp) < target_y:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## Topun kale düzlemindeki yüksekliği; yere daha önce düşerse eksi (kalan mesafe kadar).
static func _height_at_line(ball_position: Vector3, speed: float, elevation_deg: float, azimuth_deg: float,
		pp: PhysicsParams) -> float:
	var state := BallState.from_kick(ball_position, speed, elevation_deg, azimuth_deg)
	var previous := state.position
	while state.time < 10.0:
		previous = state.position
		BallFlight.integrate(state, pp.time_step, pp, Vector3.ZERO)
		if state.position.z <= 0.0:
			var t := previous.z / (previous.z - state.position.z)
			return lerpf(previous.y, state.position.y, t)
		if state.position.y < pp.radius and state.velocity.y < 0.0:
			return -state.position.z
	return -state.position.z
