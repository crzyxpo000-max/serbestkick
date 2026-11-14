class_name Boot
extends RefCounted
## Krampon: dört özelliği doğrudan vuruş hesabına girer. Değerler data/boots.json içinde.

const DATA_PATH := "res://data/boots.json"
const STATS: Array[String] = ["power", "curl", "accuracy", "sweet_spot"]
const STAT_LABELS := {"power": "Güç", "curl": "Falso", "accuracy": "İsabet", "sweet_spot": "Tatlı nokta"}
const TYPE_LABELS := {"dengeli": "Dengeli", "guc": "Güç", "kontrol": "Kontrol", "falso": "Falso"}
## Özellik çubuklarının alt ve üst ucu.
const STAT_RANGES := {
	"power": Vector2(26.0, 35.0), "curl": Vector2(5.0, 11.0),
	"accuracy": Vector2(0.0, 1.0), "sweet_spot": Vector2(0.0, 1.0),
}

var id := ""
var name := ""
var type := ""
var power := 32.0        ## m/s, topun en yüksek çıkış hızı
var curl := 8.0          ## tur/sn, topa verilebilen en yüksek yan dönüş
var accuracy := 1.0      ## 0–1, kaydırma hatasının affedilen oranı
var sweet_spot := 0.0    ## 0–1, vuruş noktasının güç ve isabet kaybetmeden kayabileceği alan
var aftertouch := 0.2    ## havada falsonun sınırı (oran)
var wet_penalty := 0.0   ## ıslak sahada isabetten düşen miktar
var price := 0           ## kariyerde satın alma bedeli


## Kramponsuz hesap: kontrol ayarlarındaki sınırlar, hatasız vuruş.
static func neutral(cp: ControlParams) -> Boot:
	var boot := Boot.new()
	boot.id = "notr"
	boot.power = cp.max_speed
	boot.curl = cp.max_side_spin
	boot.aftertouch = cp.aftertouch_limit
	return boot


static func from_dict(values: Dictionary) -> Boot:
	var boot := Boot.new()
	for key: String in values:
		if boot.get(key) != null:
			boot.set(key, values[key])
	return boot


static func load_all() -> Array[Boot]:
	var boots: Array[Boot] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Array:
		for entry: Dictionary in parsed:
			boots.append(from_dict(entry))
	return boots


func duplicate_boot() -> Boot:
	var copy := Boot.new()
	for key: String in ["id", "name", "type", "power", "curl", "accuracy", "sweet_spot", "aftertouch", "wet_penalty", "price"]:
		copy.set(key, get(key))
	return copy


## Özelliğin 0–1 arası gösterim değeri.
func rating(stat: String) -> float:
	var limits: Vector2 = STAT_RANGES[stat]
	return clampf(inverse_lerp(limits.x, limits.y, get(stat)), 0.0, 1.0)


func type_label() -> String:
	return TYPE_LABELS.get(type, type)


## Vuruş noktası tatlı noktanın ne kadar dışında: 0 = içinde, 1 = topun kenarı.
func mishit(strike: Vector2) -> float:
	var offset := minf(strike.length(), 1.0)
	if sweet_spot >= 1.0:
		return 0.0
	return clampf((offset - sweet_spot) / (1.0 - sweet_spot), 0.0, 1.0)


func effective_accuracy(wet: bool) -> float:
	return clampf(accuracy - (wet_penalty if wet else 0.0), 0.0, 1.0)
