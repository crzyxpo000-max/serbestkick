class_name AimAssist
extends RefCounted
## Gizli nişan yardımı: kıl payı kaçacak vuruşları kaleye doğru hafifçe çeker ve barajın tepesine
## takılacak vuruşu biraz yükseltir. Düzeltme küçük ve süreklidir (sıçrama yok), belirgin biçimde
## kötü nişanı kurtarmaz. Arayüzde gösterilmez; `assist_strength = 0` kapatır.

const POST_MARGIN := 0.12   ## m, top ile direk arasında bırakılan boşluk

var wall: Wall              ## isteğe bağlı; varsa baraj yardımı çalışır
var _cp: ControlParams


func _init(cp: ControlParams) -> void:
	_cp = cp


## target: kale düzleminde nişan (x, y). Düzeltilmiş nişanı döndürür.
func adjust(target: Vector2, ball_position: Vector3, speed: float, pp: PhysicsParams) -> Vector2:
	var strength := clampf(_cp.assist_strength, 0.0, 0.95)
	if strength <= 0.0:
		return target
	var margin := pp.radius + POST_MARGIN
	var safe_x := GoalFrame.HALF_WIDTH - margin
	var safe_y := GoalFrame.HEIGHT - margin
	var adjusted := target
	adjusted.x = signf(target.x) * _pull(absf(target.x), safe_x, _cp.assist_range_x, strength)
	adjusted.y = _pull(target.y, safe_y, _cp.assist_range_y, strength)
	if wall != null and absf(adjusted.x) <= safe_x:
		adjusted.y = _clear_wall(adjusted, ball_position, speed, safe_y, pp)
	return adjusted


## Sınırı `range` kadar aşan değeri sınıra doğru çeker. Çekiş sınırın hemen dışında en güçlüdür,
## `range` sonunda sıfıra iner; sıralamayı bozmaz (daha dışarı nişan yine daha dışarı gider).
static func _pull(value: float, limit: float, reach: float, strength: float) -> float:
	var excess := value - limit
	if excess <= 0.0 or excess >= reach or reach <= 0.0:
		return value
	return value - strength * excess * (1.0 - excess / reach)


## Falsosuz top baraja takılıyorsa nişanı en fazla `assist_wall_raise` kadar yükseltir.
func _clear_wall(target: Vector2, ball_position: Vector3, speed: float, safe_y: float, pp: PhysicsParams) -> float:
	if not _hits_wall(target, ball_position, speed, pp):
		return target.y
	var step := 0.08
	var raised := target.y
	while raised + step <= minf(target.y + _cp.assist_wall_raise, safe_y) + 1e-6:
		raised += step
		if not _hits_wall(Vector2(target.x, raised), ball_position, speed, pp):
			return raised
	return target.y


func _hits_wall(target: Vector2, ball_position: Vector3, speed: float, pp: PhysicsParams) -> bool:
	var azimuth := rad_to_deg(atan2(target.x - ball_position.x, ball_position.z))
	var elevation := ShotBuilder.solve_elevation(ball_position, speed, azimuth, maxf(target.y, pp.radius), pp)
	var state := BallState.from_kick(ball_position, speed, elevation, azimuth)
	var passed := ball_position.z - wall.params.wall_distance - 1.0
	while state.position.z > passed and state.time < 3.0:
		BallFlight.integrate(state, pp.time_step, pp, Vector3.ZERO)
		if wall.collide(state, pp.radius):
			return true
	return false
