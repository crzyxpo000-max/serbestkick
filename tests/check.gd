class_name Check
extends RefCounted
## Test yardımcıları: hata listesine okunur satır ekler.

static func in_range(errors: Array[String], label: String, value: float, low: float, high: float) -> void:
	if value < low or value > high or is_nan(value):
		errors.append("%s = %.4f, beklenen aralık [%.4f, %.4f]" % [label, value, low, high])


static func near(errors: Array[String], label: String, value: float, expected: float, tolerance: float) -> void:
	if absf(value - expected) > tolerance or is_nan(value):
		errors.append("%s = %.5f, beklenen %.5f ± %.5f" % [label, value, expected, tolerance])


static func is_true(errors: Array[String], label: String, condition: bool) -> void:
	if not condition:
		errors.append(label)


## Varsayılan değerlerle (data dosyasından bağımsız) benzetici kurar ve vuruşu sonuna kadar oynatır.
static func shoot(kick: BallState, conditions: PitchConditions = null, params: PhysicsParams = null) -> BallSimulator:
	var sim := BallSimulator.new(params, conditions)
	sim.kick(kick)
	sim.run()
	return sim


static func spot(distance: float, x: float = 0.0) -> Vector3:
	return Vector3(x, 0.11, distance)
