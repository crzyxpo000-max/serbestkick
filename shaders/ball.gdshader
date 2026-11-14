shader_type spatial;
// Top: beyaz yüzey üzerinde, ikosahedronun 12 köşesine oturan koyu paneller. Dönüş böylece görünür.

uniform vec3 base_color : source_color = vec3(0.95, 0.95, 0.93);
uniform vec3 panel_color : source_color = vec3(0.06, 0.06, 0.08);

varying vec3 direction;

const float A = 0.5257311;
const float B = 0.8506508;

void vertex() {
	direction = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(direction);
	vec3 a = abs(d);
	// 12 köşe: (0, ±A, ±B), (±A, ±B, 0), (±B, 0, ±A)
	float nearest = max(a.y * A + a.z * B, max(a.x * A + a.y * B, a.x * B + a.z * A));
	float panel = smoothstep(0.925, 0.94, nearest);
	ALBEDO = mix(base_color, panel_color, panel);
	ROUGHNESS = 0.38;
}
