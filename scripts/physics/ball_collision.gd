class_name BallCollision
extends RefCounted
## Topun sert yüzeylere çarpması. İçi boş küre: I = ⅔·m·r².

## Normali `normal` olan yüzeyden sektirir. Sürtünme hem hızı hem dönüşü değiştirir.
## Top yüzeye yaklaşmıyorsa false döner.
static func bounce(state: BallState, normal: Vector3, restitution: float, friction: float, radius: float) -> bool:
	var normal_speed := state.velocity.dot(normal)
	if normal_speed >= 0.0:
		return false
	var tangential := state.velocity - normal * normal_speed
	# Temas noktasının yüzeye göre kayma hızı
	var slip := tangential + state.spin.cross(-normal * radius)
	var normal_impulse := -(1.0 + restitution) * normal_speed
	state.velocity += normal * normal_impulse
	var slip_speed := slip.length()
	if slip_speed > 1e-9:
		# Kaymayı tam durduran itki 0,4·kayma; sürtünme bundan fazlasını veremez.
		var friction_impulse := minf(friction * normal_impulse, 0.4 * slip_speed)
		var impulse := -slip / slip_speed * friction_impulse
		state.velocity += impulse
		state.spin += (-normal).cross(impulse) * (1.5 / radius)
	return true


## `a`–`b` doğru parçası üzerinde `point` noktasına en yakın nokta.
static func closest_on_segment(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t
