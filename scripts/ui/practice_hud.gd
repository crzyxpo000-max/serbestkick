class_name PracticeHud
extends Control
## Antrenman ekranı çizimleri: vuruş noktası seçici ve kaydırma izi. Girdiyi ana sahne işler.

const DISC_RADIUS := 0.12   ## ekran yüksekliği
const DISC_MARGIN := 0.05
const DOT_REACH := 0.85     ## vuruş noktası diskin bu kadarına kadar gidebilir

var strike := Vector2.ZERO:
	set(value):
		strike = value.limit_length(1.0)
		queue_redraw()
var swipe_points := PackedVector2Array():
	set(value):
		swipe_points = value
		queue_redraw()
var show_disc := true:
	set(value):
		show_disc = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func disc_radius() -> float:
	return size.y * DISC_RADIUS


func disc_centre() -> Vector2:
	var offset := size.y * (DISC_MARGIN + DISC_RADIUS)
	return Vector2(offset, size.y - offset)


func in_disc(point: Vector2) -> bool:
	return point.distance_to(disc_centre()) <= disc_radius() * 1.15


## Ekran noktasını vuruş noktasına çevirir (-1…1, +y üst).
func strike_from(point: Vector2) -> Vector2:
	var offset := (point - disc_centre()) / (disc_radius() * DOT_REACH)
	return Vector2(offset.x, -offset.y).limit_length(1.0)


func _draw() -> void:
	if show_disc:
		var centre := disc_centre()
		var radius := disc_radius()
		draw_circle(centre, radius, Color(1, 1, 1, 0.85))
		draw_arc(centre, radius, 0.0, TAU, 48, Color(0, 0, 0, 0.8), 3.0, true)
		draw_arc(centre, radius * 0.15, 0.0, TAU, 24, Color(0, 0, 0, 0.35), 2.0, true)
		draw_line(centre - Vector2(radius, 0), centre + Vector2(radius, 0), Color(0, 0, 0, 0.25), 1.5)
		draw_line(centre - Vector2(0, radius), centre + Vector2(0, radius), Color(0, 0, 0, 0.25), 1.5)
		var dot := centre + Vector2(strike.x, -strike.y) * radius * DOT_REACH
		draw_circle(dot, radius * 0.14, Color(0.9, 0.15, 0.15))
	if swipe_points.size() >= 2:
		draw_polyline(swipe_points, Color(1, 1, 1, 0.9), 5.0, true)
