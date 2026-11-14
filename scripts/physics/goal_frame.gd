class_name GoalFrame
extends RefCounted
## Kale ölçüleri (m). Kale çizgisi z = 0, kale ortası x = 0.

const WIDTH := 7.32          ## direklerin iç yüzleri arası
const HEIGHT := 2.44         ## üst direğin alt yüzü
const POST_RADIUS := 0.06
const HALF_WIDTH := WIDTH / 2.0
const POST_X := HALF_WIDTH + POST_RADIUS
const BAR_Y := HEIGHT + POST_RADIUS


## Direkler ve üst direk, eksen doğru parçaları olarak: [başlangıç, bitiş].
static func segments() -> Array:
	return [
		[Vector3(-POST_X, 0.0, 0.0), Vector3(-POST_X, BAR_Y, 0.0)],
		[Vector3(POST_X, 0.0, 0.0), Vector3(POST_X, BAR_Y, 0.0)],
		[Vector3(-POST_X, BAR_Y, 0.0), Vector3(POST_X, BAR_Y, 0.0)],
	]


## Top merkezi kale ağzının içinde mi (x ve y bakımından)?
static func inside_mouth(point: Vector3) -> bool:
	return absf(point.x) < HALF_WIDTH and point.y < HEIGHT
