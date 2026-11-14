class_name ControlParams
extends RefCounted
## Kaydırma kontrolünün ayar değerleri. Varsayılanların üzerine data/controls.json yazılır.
## Güç ve falso üst sınırları 5. aşamada krampondan gelecek.

const DATA_PATH := "res://data/controls.json"

var min_swipe_length := 0.08   ## ekran yüksekliği; daha kısa kaydırma vuruş sayılmaz
var swipe_window := 0.5        ## s; kaydırmanın yalnızca son bu kadarı değerlendirilir
var slow_swipe := 0.6          ## ekran yüksekliği/s → en düşük güç
var fast_swipe := 4.5          ## ekran yüksekliği/s → en yüksek güç
var min_speed := 20.0          ## m/s
var max_speed := 32.0          ## m/s
var max_side_spin := 8.0       ## tur/sn
var curvature_full := 0.4      ## yayın sapması / kiriş; bu eğrilik en yüksek falsoyu verir
var curvature_dead_zone := 0.04  ## bundan küçük eğrilik düz kaydırma sayılır (el titremesi)
var tangent_fraction := 0.5    ## çıkış yönü kaydırmanın ilk bu kadarından okunur

var strike_side_spin := 3.5    ## tur/sn, vuruş noktası tam kenardayken
var strike_top_spin := 6.0     ## tur/sn, vuruş noktası tam üstte/altta
var strike_elevation := 6.0    ## derece, vuruş noktası tam alttayken ek yükseliş
var strike_power_loss := 0.2   ## kenardan vuruşta güç kaybı oranı
var knuckle_radius := 0.15     ## vuruş noktası bu kadar ortadaysa vuruş dönüşsüzdür
var knuckle_max_spin := 1.0    ## tur/sn; kaydırma bundan fazla falso veriyorsa dönüşsüz olmaz

var scatter_base := 1.3        ## derece; isabeti 0 olan kramponla tam güçte nişan sapması (standart sapma)
var scatter_mishit := 1.0      ## derece; tatlı noktanın tam dışından vuruşta eklenen sapma

var aftertouch_enabled := 1.0  ## 0 = kapalı (simülasyon modu)
var aftertouch_limit := 0.2    ## dönüş en fazla bu oranda artar ya da azalır
var aftertouch_full_drag := 0.25  ## ekran yüksekliği; bu kadar sürükleme tam etki verir
var aftertouch_window := 0.5   ## uçuş mesafesinin ilk bu oranında çalışır


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


static func load_default() -> ControlParams:
	var params := ControlParams.new()
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			var unknown := params.apply(parsed)
			if not unknown.is_empty():
				push_warning("controls.json: bilinmeyen anahtarlar %s" % [unknown])
	return params
