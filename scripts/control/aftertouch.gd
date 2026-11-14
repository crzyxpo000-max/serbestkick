class_name Aftertouch
extends RefCounted
## Havada falso (sınırlı): uçuşun ilk bölümünde topun mevcut dönüşünü en fazla ±%20 değiştirir.
## Yönünü tersine çeviremez; dönüşsüz topa etki etmez.

var _cp: ControlParams
var _factor := 1.0
var _start_distance := 0.0


func _init(cp: ControlParams) -> void:
	_cp = cp


func begin(kick: BallState) -> void:
	_factor = 1.0
	_start_distance = kick.position.z


func factor() -> float:
	return _factor


func is_active(sim: BallSimulator) -> bool:
	if _cp.aftertouch_enabled <= 0.0 or sim.outcome != BallSimulator.Outcome.NONE:
		return false
	if sim.bounces > 0 or sim.hit_post or sim.grounded:
		return false
	return sim.state.position.z > _start_distance * (1.0 - _cp.aftertouch_window)


## drag: parmağın dokunduğu yerden beri yer değiştirmesi, ekran yüksekliği biriminde (+x sağ, +y aşağı).
## Falsonun yönüne sürüklemek dönüşü artırır, tersine sürüklemek azaltır.
func apply(sim: BallSimulator, drag: Vector2) -> void:
	if not is_active(sim):
		return
	var spin := sim.state.spin
	var forward := Vector3(sim.state.velocity.x, 0.0, sim.state.velocity.z)
	if spin.length() < 1e-3 or forward.length() < 1e-3:
		return
	forward = forward.normalized()
	# Ekranda: sağa kıvrılan top +x, dalan top +y yönünde hareket eder.
	var curve_dir := Vector2(-spin.y, spin.dot(Vector3.UP.cross(forward)))
	if curve_dir.length() < 1e-3:
		return
	var amount := clampf(drag.dot(curve_dir.normalized()) / _cp.aftertouch_full_drag, -1.0, 1.0)
	var target := 1.0 + _cp.aftertouch_limit * amount
	sim.state.spin *= target / _factor
	_factor = target
