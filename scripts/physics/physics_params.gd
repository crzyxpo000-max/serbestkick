class_name PhysicsParams
extends RefCounted
## Top fiziğinin ayar değerleri. Varsayılanlar gerçek ölçülere dayanır; data/physics.json üzerine yazar.

const DATA_PATH := "res://data/physics.json"

var gravity := 9.81            ## m/s²
var air_density := 1.225       ## kg/m³
var mass := 0.43               ## kg
var radius := 0.11             ## m
var drag_coefficient := 0.2    ## Cd, maç topu için şut hızlarında
var lift_slope := 0.8          ## Cl = lift_slope × dönüş oranı (r·ω/v)
var lift_max := 0.3            ## Cl üst sınırı
var spin_decay := 0.15         ## 1/s, dönüşün üstel sönümü
var knuckle_lift := 0.08       ## dönüşsüz topun yalpalama katsayısı (Cl karşılığı)
var knuckle_spin_limit := 9.0  ## rad/s, bu dönüşün üstünde yalpalama olmaz
var knuckle_frequency := 1.3   ## Hz
var time_step := 1.0 / 240.0   ## s, sabit benzetim adımı

var ground_restitution := 0.6
var ground_friction := 0.5
var rolling_resistance := 0.1
var wet_restitution := 0.55
var wet_friction := 0.2
var wet_rolling_resistance := 0.07
var roll_threshold := 0.3      ## m/s, bu dikey hızın altında top sekmez, yuvarlanır
var rest_speed := 0.05         ## m/s, bu hızın altında top durur

var post_restitution := 0.65
var post_friction := 0.3

var net_depth := 2.0           ## m
var net_damping := 6.0         ## 1/s, filenin topu yutma hızı


## Bilinmeyen anahtarları döndürür (boş = hepsi tanındı).
func apply(values: Dictionary) -> Array[String]:
	var unknown: Array[String] = []
	for key: String in values:
		if key.begins_with("_"):
			continue
		if get(key) == null:
			unknown.append(key)
		else:
			set(key, float(values[key]))
	return unknown


static func load_default() -> PhysicsParams:
	var params := PhysicsParams.new()
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			var unknown := params.apply(parsed)
			if not unknown.is_empty():
				push_warning("physics.json: bilinmeyen anahtarlar %s" % [unknown])
	return params
