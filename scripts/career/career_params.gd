class_name CareerParams
extends ParamSet
## Kariyer ayarları. Varsayılanların üzerine data/career.json yazılır.

const DATA_PATH := "res://data/career.json"

var start_trust := 50.0
var trust_goal := 10.0         ## gol atınca hoca güveni artışı
var trust_clutch := 6.0        ## yüksek baskı altında atılan gol için ek artış
var trust_miss := 6.0          ## kaçan vuruşta düşüş
var clutch_pressure := 0.6     ## bu baskının üstü "kritik an" sayılır

var bonus_appearance := 50.0   ## vuruş kullandığın maç için prim
var bonus_goal := 150.0
var bonus_win := 100.0
var tier_bonus_step := 0.6     ## her üst ligde primler bu oranda artar

var fame_goal := 3.0
var fame_champion := 15.0
var fame_top_two := 8.0
var offer_fame := 25.0         ## üst ligden teklif için gereken ün (lig başına)

var skill_cost := 300.0        ## ilk seviye; her seviyede bu kadar artar
var skill_max := 5.0
var skill_power := 0.4         ## m/s, seviye başına
var skill_curl := 0.4          ## tur/sn
var skill_accuracy := 0.05
var skill_composure := 0.12    ## seviye başına baskı etkisindeki azalma

var strength_spread := 0.2     ## takım güçleri 1 ± bu aralıkta


static func load_default() -> CareerParams:
	var params := CareerParams.new()
	params.load_file(DATA_PATH)
	return params
