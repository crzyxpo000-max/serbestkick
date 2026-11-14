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
var boot: Boot:
	set(value):
		boot = value
		queue_redraw()
var pressure := 0.0:   ## 0–1; kalp atışı gibi atan kırmızı çerçeve
	set(value):
		pressure = value
		set_process(value > 0.05)
		queue_redraw()
var show_disc := true:
	set(value):
		show_disc = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


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
	if pressure > 0.05:
		var beats_per_second := (70.0 + 60.0 * pressure) / 60.0
		var beat := pow(maxf(sin(Time.get_ticks_msec() / 1000.0 * TAU * beats_per_second), 0.0), 6.0)
		var width := size.y * 0.05
		var color := Color(0.85, 0.05, 0.05, pressure * (0.15 + 0.45 * beat))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-width / 2.0), color, false, width)
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
		if boot != null:
			_draw_boot()
	if swipe_points.size() >= 2:
		draw_polyline(swipe_points, Color(1, 1, 1, 0.9), 5.0, true)


## Seçili kramponun özellikleri (sağ altta).
func _draw_boot() -> void:
	var font := get_theme_default_font()
	var width := size.y * 0.3
	var line := size.y * 0.042
	var origin := Vector2(size.x - width - size.y * DISC_MARGIN, size.y - line * 6.6 - size.y * DISC_MARGIN)
	draw_rect(Rect2(origin - Vector2(12, 8), Vector2(width + 24, line * 6.6 + 16)), Color(0, 0, 0, 0.45))
	draw_string(font, origin + Vector2(0, line), "%s · %s" % [boot.name, boot.type_label()],
			HORIZONTAL_ALIGNMENT_LEFT, width, int(line * 0.8))
	for i in Boot.STATS.size():
		var stat := Boot.STATS[i]
		var y := origin.y + line * (1.6 + i * 1.25)
		draw_string(font, Vector2(origin.x, y + line * 0.75), Boot.STAT_LABELS[stat],
				HORIZONTAL_ALIGNMENT_LEFT, width * 0.45, int(line * 0.62), Color(1, 1, 1, 0.85))
		var bar := Rect2(origin.x + width * 0.47, y + line * 0.2, width * 0.53, line * 0.55)
		draw_rect(bar, Color(1, 1, 1, 0.2))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * boot.rating(stat), bar.size.y)), Color(1.0, 0.8, 0.25))
