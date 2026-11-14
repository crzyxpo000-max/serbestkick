class_name FreeKick
extends RefCounted
## Bir serbest vuruş pozisyonu.

var minute := 0
var spot := Vector3.ZERO      ## topun yeri
var wall_count := 3
var keeper_forward := false   ## kaleci öne çıkıyor mu
var taken := false
var scored := false


func distance() -> float:
	return Vector2(spot.x, spot.z).length()
