class_name MatchParams
extends ParamSet
## Maç akışı ayarları. Varsayılanların üzerine data/match.json yazılır.

const DATA_PATH := "res://data/match.json"

var our_xg := 1.1               ## bizim takımın (oyuncu hariç) maç başına beklenen golü
var their_xg := 1.3
var free_kicks_none := 0.1      ## maçta hiç serbest vuruş çıkmama olasılığı
var free_kicks_two := 0.35      ## iki serbest vuruş çıkma olasılığı (kalanı bir)
var first_minute := 12.0        ## serbest vuruş bundan önce çıkmaz
var min_gap := 8.0              ## iki serbest vuruş arası en az dakika
var distance_min := 18.0        ## m
var distance_max := 33.0
var angle_max := 28.0           ## derece, kale ortasına göre
var forward_keeper_chance := 0.3
var forward_depth := 2.0        ## m, öne çıkan kalecinin çizgiden uzaklığı
var windy_chance := 0.25
var rain_chance := 0.15
var wind_min := 4.0             ## m/s, rüzgarlı havada
var wind_max := 9.0
var rain_wind_max := 4.0
var derby_chance := 0.2
var final_chance := 0.1
var filler_count := 6.0         ## maç başına ara spiker yazısı

var seconds_per_minute := 0.28  ## hızlı akışta bir maç dakikası kaç saniye sürer
var event_pause := 1.8          ## s, bir olaydan sonra bekleme

var pressure_league := 0.1
var pressure_derby := 0.3
var pressure_final := 0.45
var pressure_late_75 := 0.15
var pressure_late_85 := 0.3
var pressure_level := 0.15      ## skor eşitken
var pressure_behind_one := 0.25
var pressure_behind_more := 0.1
var pressure_scatter := 0.8     ## tam baskıda nişan sapması bu oranda büyür
var pressure_sway := 0.35       ## derece, tam baskıda nişanın titremesi


static func load_default() -> MatchParams:
	var params := MatchParams.new()
	params.load_file(DATA_PATH)
	return params
