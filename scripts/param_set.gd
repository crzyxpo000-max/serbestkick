class_name ParamSet
extends RefCounted
## Sayısal ayar kümelerinin ortak tabanı: alanlar varsayılan değer taşır, JSON dosyası üzerine yazar.

## Sözlükteki değerleri aynı adlı alanlara yazar. Bilinmeyen anahtarları döndürür (boş = hepsi tanındı).
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


func load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var unknown := apply(parsed)
		if not unknown.is_empty():
			push_warning("%s: bilinmeyen anahtarlar %s" % [path, unknown])
