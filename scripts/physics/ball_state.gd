class_name BallState
extends RefCounted
## Topun anlık durumu. Eksenler: kale çizgisi z = 0, kale ortası x = 0, vuruş +z tarafından -z yönüne.
## +x vurucunun sağı, +y yukarı.

var position := Vector3.ZERO
var velocity := Vector3.ZERO  ## m/s
var spin := Vector3.ZERO      ## açısal hız, rad/s
var time := 0.0               ## s
var knuckle := 0.0            ## 0–1, dönüşsüz vuruşun yalpalama şiddeti
var knuckle_phase := 0.0      ## rad, yalpalamanın başlangıç fazı


func duplicate_state() -> BallState:
	var copy := BallState.new()
	copy.position = position
	copy.velocity = velocity
	copy.spin = spin
	copy.time = time
	copy.knuckle = knuckle
	copy.knuckle_phase = knuckle_phase
	return copy


## azimuth_deg: 0 = dümdüz kaleye (-z), artı = sağa. side_rps: artı = sağa kıvrılır.
## top_rps: artı = üst falso (top dalar), eksi = alt falso (top süzülür).
static func from_kick(pos: Vector3, speed: float, elevation_deg: float, azimuth_deg: float,
		side_rps: float = 0.0, top_rps: float = 0.0) -> BallState:
	var elevation := deg_to_rad(elevation_deg)
	var azimuth := deg_to_rad(azimuth_deg)
	var forward := Vector3(sin(azimuth), 0.0, -cos(azimuth))
	var state := BallState.new()
	state.position = pos
	state.velocity = (forward * cos(elevation) + Vector3.UP * sin(elevation)) * speed
	state.spin = Vector3.UP * (-side_rps * TAU) + Vector3.UP.cross(forward) * (top_rps * TAU)
	return state
