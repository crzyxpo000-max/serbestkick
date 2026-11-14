class_name BallFlight
extends RefCounted
## Havadaki topun hareketi: yerçekimi, hava direnci, Magnus kuvveti, dönüş kaybı, rüzgar.

## Topun ivmesi (m/s²).
static func acceleration(velocity: Vector3, spin: Vector3, p: PhysicsParams, wind: Vector3) -> Vector3:
	var accel := Vector3(0.0, -p.gravity, 0.0)
	var relative := velocity - wind
	var speed := relative.length()
	if speed < 1e-6:
		return accel
	# q = ½·ρ·A / m ; kuvvet = q·m·C·v²
	var q := 0.5 * p.air_density * PI * p.radius * p.radius / p.mass
	accel -= q * p.drag_coefficient * speed * relative
	var cross := spin.cross(relative)
	var cross_len := cross.length()
	if cross_len > 1e-9:
		var spin_ratio := p.radius * cross_len / (speed * speed)
		var lift := minf(p.lift_slope * spin_ratio, p.lift_max)
		accel += q * lift * speed * speed * (cross / cross_len)
	return accel


## Bir adım ilerletir (konum ve hız için RK4, dönüş için üstel sönüm).
static func integrate(state: BallState, dt: float, p: PhysicsParams, wind: Vector3) -> void:
	var v1 := state.velocity
	var a1 := acceleration(v1, state.spin, p, wind)
	var v2 := state.velocity + a1 * (dt * 0.5)
	var a2 := acceleration(v2, state.spin, p, wind)
	var v3 := state.velocity + a2 * (dt * 0.5)
	var a3 := acceleration(v3, state.spin, p, wind)
	var v4 := state.velocity + a3 * dt
	var a4 := acceleration(v4, state.spin, p, wind)
	state.position += (v1 + 2.0 * v2 + 2.0 * v3 + v4) * (dt / 6.0)
	state.velocity += (a1 + 2.0 * a2 + 2.0 * a3 + a4) * (dt / 6.0)
	state.spin *= exp(-p.spin_decay * dt)
	state.time += dt
