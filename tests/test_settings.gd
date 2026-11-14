extends RefCounted
## Ayarlar ve ses dosyaları.

func test_ayarlar_kaydedilir() -> Array[String]:
	var errors: Array[String] = []
	var settings := Settings.new()
	Check.is_true(errors, "varsayılanlar açık olmalı", settings.sound and settings.vibration and settings.aftertouch)
	settings.toggle("aftertouch")
	settings.toggle("sound")
	var path := "user://test_settings.json"
	Check.is_true(errors, "kayıt yazılmalı", settings.save(path))
	var loaded := Settings.load_saved(path)
	Check.is_true(errors, "kapatılan ayarlar kapalı yüklenmeli", not loaded.aftertouch and not loaded.sound and loaded.vibration)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Check.is_true(errors, "kayıt yokken varsayılan dönmeli", Settings.load_saved("user://yok.json").sound)
	Check.is_true(errors, "eksik anahtar varsayılanı korumalı", Settings.from_dict({"sound": false}).vibration)
	for key in Settings.KEYS:
		Check.is_true(errors, key + " etiketi olmalı", Settings.LABELS.has(key))
	return errors


func test_ses_dosyalari_var() -> Array[String]:
	var errors: Array[String] = []
	for sound_name in Sound.NAMES:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % sound_name)
		Check.is_true(errors, sound_name + ".wav yüklenmeli", stream != null and stream.get_length() > 0.02)
	return errors


func test_simulasyon_modu_havada_falsoyu_kapatir() -> Array[String]:
	var errors: Array[String] = []
	var cp := ControlParams.new()
	cp.aftertouch_enabled = 0.0
	var sim := BallSimulator.new()
	var kick := BallState.from_kick(Check.spot(25.0), 27.0, 15.0, 0.0, 6.0)
	sim.kick(kick)
	var touch := Aftertouch.new(cp)
	touch.begin(kick)
	var before := sim.state.spin
	touch.apply(sim, Vector2(9, 0))
	Check.is_true(errors, "kapalıyken dönüş değişmemeli", sim.state.spin == before and not touch.is_active(sim))
	return errors
