class_name StageBuilder
extends RefCounted
## Sahnenin görsel parçalarını kurar: gökyüzü, çim, top, kale, file, çizgiler, tribün, oyuncu figürleri.
## Oyun kuralı içermez. Performans için tribün ve figürler basit tutulur; ayrıntı topa, çime ve kaleye harcanır.

const SKY_PATH := "res://assets/sky/kloofendal_48d_partly_cloudy_puresky_1k.hdr"
const FRAME_COLOR := Color(0.95, 0.95, 0.95)
const LINE_COLOR := Color(0.88, 0.92, 0.88)
const SKIN := Color(0.55, 0.38, 0.28)
const FIGURE_HEIGHT := 1.75
const KEEPER_LENGTH := 2.1   ## kollar yukarıdayken ayaktan ele


static func apply_sky(world: WorldEnvironment) -> void:
	var texture: Texture2D = load(SKY_PATH)
	if texture == null:
		return
	var material := PanoramaSkyMaterial.new()
	material.panorama = texture
	var sky := Sky.new()
	sky.sky_material = material
	world.environment.sky = sky
	world.environment.background_energy_multiplier = 0.9
	world.environment.ambient_light_energy = 0.9


static func pitch_material() -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/pitch.gdshader")
	material.set_shader_parameter("noise", texture)
	return material


static func ball_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ball.gdshader")
	return material


static func build_goal(parent: Node3D, net_depth: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = FRAME_COLOR
	material.roughness = 0.35
	for segment: Array in GoalFrame.segments():
		var from: Vector3 = segment[0]
		var to: Vector3 = segment[1]
		var mesh := CylinderMesh.new()
		mesh.top_radius = GoalFrame.POST_RADIUS
		mesh.bottom_radius = GoalFrame.POST_RADIUS
		mesh.height = from.distance_to(to)
		var node := _mesh(parent, mesh, material, (from + to) * 0.5)
		if absf((to - from).normalized().y) < 0.5:
			node.rotation.z = PI / 2.0
	var net_material := ShaderMaterial.new()
	net_material.shader = load("res://shaders/net.gdshader")
	var net_mesh := BoxMesh.new()
	net_mesh.size = Vector3(GoalFrame.WIDTH + 2.0 * GoalFrame.POST_RADIUS, GoalFrame.HEIGHT + GoalFrame.POST_RADIUS, net_depth)
	_mesh(parent, net_mesh, net_material, Vector3(0.0, net_mesh.size.y / 2.0, -net_depth / 2.0))


## Kale çizgisi, ceza sahası (16,5 m), kale sahası (5,5 m) ve penaltı noktası.
static func build_lines(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = LINE_COLOR
	material.roughness = 0.9
	var post := GoalFrame.HALF_WIDTH
	_line(parent, material, Vector3(0, 0, 0), Vector3(68.0, 0, 0.12))
	_line(parent, material, Vector3(-34.0, 0, 26.0), Vector3(0.12, 0, 52.0))
	_line(parent, material, Vector3(34.0, 0, 26.0), Vector3(0.12, 0, 52.0))
	_line(parent, material, Vector3(0, 0, 52.0), Vector3(68.0, 0, 0.12))
	for box: Vector2 in [Vector2(post + 16.5, 16.5), Vector2(post + 5.5, 5.5)]:
		_line(parent, material, Vector3(0, 0, box.y), Vector3(box.x * 2.0, 0, 0.12))
		_line(parent, material, Vector3(-box.x, 0, box.y / 2.0), Vector3(0.12, 0, box.y))
		_line(parent, material, Vector3(box.x, 0, box.y / 2.0), Vector3(0.12, 0, box.y))
	_line(parent, material, Vector3(0, 0, 11.0), Vector3(0.24, 0, 0.24))


## Dört yanda basit tribünler ve saha kenarı panoları.
static func build_stands(parent: Node3D) -> void:
	var crowd := ShaderMaterial.new()
	crowd.shader = load("res://shaders/crowd.gdshader")
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.2, 0.21, 0.24)
	concrete.roughness = 1.0
	# [orta nokta, boyut, eğim ekseni (x ya da z), eğim açısı]
	var blocks: Array = [
		[Vector3(0, 6.0, -19.0), Vector3(100, 2.0, 22), Vector3.RIGHT, 0.5],
		[Vector3(0, 6.0, 71.0), Vector3(100, 2.0, 22), Vector3.RIGHT, -0.5],
		[Vector3(-50.0, 6.0, 26.0), Vector3(22, 2.0, 96), Vector3.BACK, -0.5],
		[Vector3(50.0, 6.0, 26.0), Vector3(22, 2.0, 96), Vector3.BACK, 0.5],
	]
	for block: Array in blocks:
		var mesh := BoxMesh.new()
		mesh.size = block[1]
		var node := _mesh(parent, mesh, crowd, block[0])
		node.rotate(block[2], block[3])
	# Tribünlerin arkasını kapatan duvarlar.
	for wall: Array in [[Vector3(0, 9, -31), Vector3(104, 18, 1)], [Vector3(0, 9, 83), Vector3(104, 18, 1)],
			[Vector3(-62, 9, 26), Vector3(1, 18, 116)], [Vector3(62, 9, 26), Vector3(1, 18, 116)]]:
		var mesh := BoxMesh.new()
		mesh.size = wall[1]
		_mesh(parent, mesh, concrete, wall[0])
	# Saha kenarı panoları: düz renk şeritler, yazı ve marka yok.
	var colors: Array[Color] = [Color(0.4, 0.07, 0.07), Color(0.06, 0.14, 0.34), Color(0.45, 0.36, 0.06), Color(0.5, 0.5, 0.5)]
	for i in 12:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[i % colors.size()]
		material.roughness = 0.6
		var mesh := BoxMesh.new()
		mesh.size = Vector3(6.0, 0.9, 0.15)
		_mesh(parent, mesh, material, Vector3(-33.0 + i * 6.0, 0.45, -5.5))


## Ayakta duran oyuncu figürü; kökü ayakların ortasındadır, +z yüzüdür.
static func build_figure(kit: Color, shorts: Color) -> Node3D:
	var root := Node3D.new()
	var kit_material := _flat(kit)
	var shorts_material := _flat(shorts)
	var skin_material := _flat(SKIN)
	for side: float in [-1.0, 1.0]:
		_limb(root, skin_material, Vector3(side * 0.1, 0.0, 0), Vector3(side * 0.1, 0.52, 0), 0.065)
		_limb(root, shorts_material, Vector3(side * 0.1, 0.5, 0), Vector3(side * 0.1, 0.9, 0), 0.09)
		# Kollar önde kavuşturulmuş.
		_limb(root, kit_material, Vector3(side * 0.24, 1.42, 0), Vector3(side * 0.2, 1.12, 0.1), 0.055)
		_limb(root, skin_material, Vector3(side * 0.2, 1.12, 0.1), Vector3(0.0, 0.95, 0.16), 0.045)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.42, 0.6, 0.22)
	_mesh(root, torso, kit_material, Vector3(0, 1.18, 0))
	var head := SphereMesh.new()
	head.radius = 0.115
	head.height = 0.23
	_mesh(root, head, skin_material, Vector3(0, FIGURE_HEIGHT - 0.115, 0))
	return root


## Kaleci figürü: kökü ayak ucunda, yerel +y ellere doğrudur; kollar yukarı uzanır (boy KEEPER_LENGTH).
static func build_keeper(kit: Color) -> Node3D:
	var root := Node3D.new()
	var kit_material := _flat(kit)
	var dark := _flat(Color(0.1, 0.1, 0.12))
	var skin_material := _flat(SKIN)
	for side: float in [-1.0, 1.0]:
		_limb(root, dark, Vector3(side * 0.1, 0.0, 0), Vector3(side * 0.1, 0.9, 0), 0.08)
		_limb(root, kit_material, Vector3(side * 0.2, 1.4, 0), Vector3(side * 0.12, KEEPER_LENGTH - 0.12, 0), 0.055)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.44, 0.62, 0.24)
	_mesh(root, torso, kit_material, Vector3(0, 1.18, 0))
	var head := SphereMesh.new()
	head.radius = 0.115
	head.height = 0.23
	_mesh(root, head, skin_material, Vector3(0, 1.63, 0))
	return root


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


static func _limb(parent: Node3D, material: Material, from: Vector3, to: Vector3, radius: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to) + 2.0 * radius
	var node := _mesh(parent, mesh, material, (from + to) * 0.5)
	node.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))


static func _line(parent: Node3D, material: Material, centre: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.01, size.z)
	_mesh(parent, mesh, material, centre + Vector3(0, 0.005, 0))


static func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node
