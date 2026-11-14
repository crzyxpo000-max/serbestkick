extends SceneTree
## Başsız test koşucusu:
##   godot --headless --path . --script res://tests/run_tests.gd
## tests/ içindeki her test_*.gd dosyasında "test_" ile başlayan yöntemleri çalıştırır.
## Test yöntemi hata listesi (Array[String]) döndürür; boş liste = geçti.

func _init() -> void:
	var failed := 0
	var total := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files())
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			print("HATA  %s yüklenemedi" % file)
			failed += 1
			total += 1
			continue
		var suite: Object = script.new()
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var errors: Array = suite.call(name)
			if errors.is_empty():
				print("GEÇTİ %s.%s" % [file, name])
			else:
				failed += 1
				print("KALDI %s.%s" % [file, name])
				for e: String in errors:
					print("        " + e)
	print("%d test, %d başarısız" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
