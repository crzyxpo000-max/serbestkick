class_name Wall
extends RefCounted
## Baraj: toptan 9,15 m uzakta, yakın direği kapatan, vuruşla birlikte zıplayan oyuncular.

var params: KeeperParams
var centres: Array[Vector3] = []   ## her oyuncunun yerdeki orta noktası
var axis := Vector3.RIGHT          ## baraj boyunca yatay yön
var facing := Vector3.BACK         ## barajdan topa bakan yatay yön
var near_post_sign := -1.0         ## barajın kapattığı direk: -1 sol, +1 sağ


func _init(p_params: KeeperParams = null) -> void:
	params = p_params if p_params != null else KeeperParams.new()


## Mesafeye göre barajdaki oyuncu sayısı.
static func default_count(spot: Vector3) -> int:
	var distance := Vector2(spot.x, spot.z).length()
	if distance < 22.0:
		return 5
	if distance < 28.0:
		return 4
	if distance < 33.0:
		return 3
	return 2


func place(spot: Vector3, count: int) -> void:
	centres.clear()
	var ball := Vector3(spot.x, 0.0, spot.z)
	var to_goal := (-ball).normalized()
	facing = -to_goal
	axis = Vector3(-to_goal.z, 0.0, to_goal.x)
	near_post_sign = signf(spot.x) if absf(spot.x) > 0.5 else -1.0
	var post := Vector3(near_post_sign * GoalFrame.HALF_WIDTH, 0.0, 0.0)
	var to_post := post - ball
	# Top–yakın direk çizgisinin baraj düzlemini kestiği nokta.
	var edge := ball + to_post * (params.wall_distance / to_post.dot(to_goal))
	var middle := ball + to_goal * params.wall_distance
	var inward := signf((middle - edge).dot(axis))
	if inward == 0.0:
		inward = 1.0
	var first := edge - axis * (inward * params.wall_post_cover)
	for i in count:
		centres.append(first + axis * (inward * params.wall_player_width * (i + 0.5)))


## Oyuncuların ayaklarının yerden yüksekliği (m).
func jump_offset(time: float) -> float:
	var t := time - params.wall_jump_delay
	if t <= 0.0:
		return 0.0
	return maxf(params.wall_jump_speed * t - 0.5 * 9.81 * t * t, 0.0)


## Top barajdaki bir oyuncuya çarptıysa sektirir ve true döner.
func collide(state: BallState, radius: float) -> bool:
	var half := Vector3(params.wall_player_width, params.wall_player_height, params.wall_player_depth) * 0.5
	var lift := jump_offset(state.time)
	var hit := false
	for centre in centres:
		var rel := state.position - centre
		var local := Vector3(rel.dot(axis), rel.y - lift - half.y, rel.dot(facing))
		var closest := local.clamp(-half, half)
		var offset := local - closest
		var distance := offset.length()
		if distance >= radius:
			continue
		var local_normal := Vector3.ZERO
		if distance > 1e-6:
			local_normal = offset / distance
		else:
			local_normal = Vector3(0, 0, 1)
		var normal := axis * local_normal.x + Vector3.UP * local_normal.y + facing * local_normal.z
		state.position += normal * (radius - distance)
		if BallCollision.bounce(state, normal, params.wall_restitution, params.wall_friction, radius):
			hit = true
	return hit
