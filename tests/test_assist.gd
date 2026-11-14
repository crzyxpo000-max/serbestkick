extends RefCounted
## Gizli nişan yardımı.

func _assist(strength: float = 0.8) -> AimAssist:
	var cp := ControlParams.new()
	cp.assist_strength = strength
	return AimAssist.new(cp)


func _adjust(assist: AimAssist, target: Vector2, speed: float = 27.0) -> Vector2:
	return assist.adjust(target, Check.spot(25.0), speed, PhysicsParams.new())


func test_kalenin_icindeki_nisan_degismez() -> Array[String]:
	var errors: Array[String] = []
	var assist := _assist()
	for target: Vector2 in [Vector2(0, 1.2), Vector2(3.0, 2.0), Vector2(-3.2, 0.3), Vector2(1.5, 0.11)]:
		Check.is_true(errors, "%s değişmemeli" % target, _adjust(assist, target) == target)
	return errors


func test_kil_payi_disari_giden_nisan_iceri_cekilir() -> Array[String]:
	var errors: Array[String] = []
	var assist := _assist()
	var raw := Vector2(GoalFrame.HALF_WIDTH + 0.1, 1.2)
	var fixed := _adjust(assist, raw)
	Check.in_range(errors, "direğin 10 cm dışındaki nişanın kayması (m)", raw.x - fixed.x, 0.15, 0.35)
	Check.near(errors, "yükseklik değişmemeli", fixed.y, raw.y, 1e-6)
	Check.near(errors, "sol taraf ayna", _adjust(assist, Vector2(-raw.x, 1.2)).x, -fixed.x, 1e-5)
	var over := _adjust(assist, Vector2(0.0, GoalFrame.HEIGHT + 0.1))
	Check.in_range(errors, "üst direğin 10 cm üstündeki nişanın inmesi (m)", GoalFrame.HEIGHT + 0.1 - over.y, 0.1, 0.3)
	# Yardımsız aut olan vuruş yardımla gol olmalı.
	var pp := PhysicsParams.new()
	var cp := ControlParams.new()
	cp.knuckle_radius = -1.0
	var swipe := Swipe.new()
	swipe.valid = true
	swipe.speed = 2.5
	var plain := Check.shoot(ShotBuilder.build(swipe, raw, Check.spot(25.0), Vector2.ZERO, cp, pp))
	var helped := Check.shoot(ShotBuilder.build(swipe, raw, Check.spot(25.0), Vector2.ZERO, cp, pp, null, Vector2.ZERO, false, AimAssist.new(cp)))
	Check.is_true(errors, "yardımsız vuruş gol olmamalı", plain.outcome != BallSimulator.Outcome.GOAL)
	Check.is_true(errors, "yardımlı vuruş gol olmalı", helped.outcome == BallSimulator.Outcome.GOAL)
	return errors


func test_belirgin_kotu_nisan_kurtarilmaz() -> Array[String]:
	var errors: Array[String] = []
	var assist := _assist()
	for target: Vector2 in [Vector2(5.5, 1.2), Vector2(-7.0, 1.0), Vector2(0.0, 4.0)]:
		Check.is_true(errors, "%s değişmemeli" % target, _adjust(assist, target) == target)
	var wide := Vector2(GoalFrame.HALF_WIDTH + 0.7, 1.2)
	Check.is_true(errors, "70 cm dışarıdaki nişan yine dışarıda kalmalı", _adjust(assist, wide).x > GoalFrame.HALF_WIDTH)
	return errors


func test_duzeltme_surekli_ve_sirayi_bozmaz() -> Array[String]:
	var errors: Array[String] = []
	var assist := _assist()
	var previous := _adjust(assist, Vector2(2.5, 1.2)).x
	var largest := 0.0
	for i in range(1, 300):
		var x := 2.5 + i * 0.01
		var fixed := _adjust(assist, Vector2(x, 1.2)).x
		if fixed <= previous:
			errors.append("x = %.2f: düzeltilmiş nişan geri gitti" % x)
			break
		if fixed - previous > 0.03:
			errors.append("x = %.2f: düzeltmede sıçrama var (%.3f m)" % [x, fixed - previous])
			break
		largest = maxf(largest, x - fixed)
		previous = fixed
	Check.in_range(errors, "en büyük yatay düzeltme (m)", largest, 0.15, 0.3)
	return errors


func test_kapatilabilir() -> Array[String]:
	var errors: Array[String] = []
	var raw := Vector2(GoalFrame.HALF_WIDTH + 0.1, GoalFrame.HEIGHT + 0.1)
	Check.is_true(errors, "güç 0 iken nişan değişmemeli", _adjust(_assist(0.0), raw) == raw)
	var wall := Wall.new()
	wall.place(Check.spot(25.0), 3)
	var off := _assist(0.0)
	off.wall = wall
	var blocked := Vector2(wall.centres[1].x * 25.0 / (25.0 - wall.centres[1].z), 1.9)
	Check.is_true(errors, "güç 0 iken baraj yardımı da kapalı olmalı", off.adjust(blocked, Check.spot(25.0), 30.0, PhysicsParams.new()) == blocked)
	return errors


func test_baraja_takilan_vurus_biraz_yukseltilir() -> Array[String]:
	var errors: Array[String] = []
	var pp := PhysicsParams.new()
	var spot := Check.spot(25.0)
	var wall := Wall.new()
	wall.place(spot, 3)
	var assist := _assist()
	assist.wall = wall
	var x := wall.centres[1].x * spot.z / (spot.z - wall.centres[1].z)
	var speed := 26.0
	# Baraja takılan en yüksek nişanı bul.
	var blocked_y := -1.0
	var y := 2.2
	while y > 0.5:
		if assist._hits_wall(Vector2(x, y), spot, speed, pp):
			blocked_y = y
			break
		y -= 0.05
	Check.is_true(errors, "bu hızda barajın kestiği bir yükseklik olmalı", blocked_y > 0.0)
	if blocked_y > 0.0:
		var fixed := assist.adjust(Vector2(x, blocked_y), spot, speed, pp)
		Check.in_range(errors, "yükseltme (m)", fixed.y - blocked_y, 0.05, 0.4)
		Check.is_true(errors, "yükseltilmiş vuruş barajı aşmalı", not assist._hits_wall(fixed, spot, speed, pp))
		Check.is_true(errors, "yükseltme üst direği geçmemeli", fixed.y < GoalFrame.HEIGHT - pp.radius)
		var low := Vector2(x, blocked_y - 0.8)
		Check.is_true(errors, "çok alçak vuruş kurtarılmamalı", assist.adjust(low, spot, speed, pp) == low)
	var open_side := Vector2(3.0, 0.8)
	Check.is_true(errors, "barajın yanından geçen vuruş değişmemeli", assist.adjust(open_side, spot, speed, pp) == open_side)
	return errors
