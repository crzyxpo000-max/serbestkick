class_name Swipe
extends RefCounted
## Tek bir kaydırma hareketinin ölçümü. Ekran koordinatları: +x sağ, +y aşağı (piksel).

const MIN_DURATION := 1.0 / 60.0

var valid := false
var speed := 0.0               ## ekran yüksekliği / s
var curvature := 0.0           ## yay sapması / kiriş; artı = yay hareket yönünün sağına bombeli
var start := Vector2.ZERO
var end := Vector2.ZERO
var launch_point := Vector2.ZERO  ## parmak ilk yönünde dümdüz gitseydi varacağı nokta


static func analyze(points: PackedVector2Array, times: PackedFloat64Array, screen_height: float,
		cp: ControlParams) -> Swipe:
	var swipe := Swipe.new()
	var count := mini(points.size(), times.size())
	if count < 2 or screen_height <= 0.0:
		return swipe
	# Parmak bekleyip sonra fırlattıysa yalnızca son bölümü al.
	var first := 0
	var last_time := times[count - 1]
	while first < count - 2 and last_time - times[first] > cp.swipe_window:
		first += 1
	swipe.start = points[first]
	swipe.end = points[count - 1]
	var chord := swipe.end - swipe.start
	var chord_length := chord.length()
	# Olaylar kare başına toplu gelir; çok hızlı bir fiske tek kareye sığabilir.
	var duration := maxf(last_time - times[first], MIN_DURATION)
	if chord_length < cp.min_swipe_length * screen_height:
		return swipe
	var path_length := 0.0
	for i in range(first + 1, count):
		path_length += points[i].distance_to(points[i - 1])
	swipe.speed = path_length / screen_height / duration

	var direction := chord / chord_length
	var right := Vector2(-direction.y, direction.x)
	var deviation := 0.0
	for i in range(first + 1, count - 1):
		var offset := (points[i] - swipe.start).dot(right)
		if absf(offset) > absf(deviation):
			deviation = offset
	swipe.curvature = deviation / chord_length

	# Çıkış yönü: yolun ilk bölümünün doğrultusu.
	var tangent := direction
	var walked := 0.0
	for i in range(first + 1, count):
		walked += points[i].distance_to(points[i - 1])
		if walked >= path_length * cp.tangent_fraction:
			var early := points[i] - swipe.start
			if early.length() > 1e-6:
				tangent = early.normalized()
			break
	swipe.launch_point = swipe.start + tangent * chord_length
	swipe.valid = true
	return swipe
