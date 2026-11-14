class_name KeeperParams
extends RefCounted
## Kaleci ve baraj ayarları. Varsayılanların üzerine data/keeper.json yazılır.

const DATA_PATH := "res://data/keeper.json"

var reaction_time := 0.45      ## s, vuruştan sonra kalecinin ilk hareketi
var reaction_jitter := 0.05    ## s, tepki süresindeki rastgele oynama
var step_speed := 1.4          ## m/s, ayakların yana kayması
var hand_speed := 3.6          ## m/s, ellerin topa uzanma hızı
var reach := 2.05               ## m, eller ayak noktasından en fazla bu kadar uzaklaşır
var body_length := 1.75        ## m
var body_radius := 0.22        ## m
var depth := 0.6               ## m, kaleci çizginin bu kadar önünde durur
var ready_height := 1.2        ## m, hazır duruşta ellerin yüksekliği
var start_offset := 0.6        ## m, kaleci barajın kapatmadığı tarafa bu kadar kayar
var spin_read := 0.35          ## kaleci falsonun bu oranını öngörür (1 = kusursuz okur)
var read_interval := 0.1       ## s, tahminini bu aralıkla yeniler
var catch_speed := 22.0        ## m/s, bundan yavaş topu elleriyle tutar; hızlısını çeler
var parry_restitution := 0.35
var parry_friction := 0.3
var ignore_x := 4.6            ## m, bundan açığa giden topa uzanmaz
var ignore_y := 3.2            ## m, bundan yükseğe giden topa uzanmaz

var wall_distance := 9.15      ## m
var wall_player_width := 0.45
var wall_player_height := 1.75
var wall_player_depth := 0.3
var wall_post_cover := 0.0     ## m, baraj yakın direk çizgisinin bu kadar dışına taşar
var wall_jump_delay := 0.1     ## s
var wall_jump_speed := 1.8     ## m/s, yaklaşık 17 cm zıplama
var wall_restitution := 0.4
var wall_friction := 0.3


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


static func load_default() -> KeeperParams:
	var params := KeeperParams.new()
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			var unknown := params.apply(parsed)
			if not unknown.is_empty():
				push_warning("keeper.json: bilinmeyen anahtarlar %s" % [unknown])
	return params
