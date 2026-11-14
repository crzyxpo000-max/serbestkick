shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
// File: kutunun arka, üst ve yan yüzlerinde ince örgü. Ön ve alt yüz çizilmez.

uniform float cell = 0.12;
uniform vec3 thread_color : source_color = vec3(0.95, 0.95, 0.95);

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	if (local_normal.z > 0.5 || local_normal.y < -0.5) {
		discard;
	}
	vec3 in_plane = 1.0 - abs(local_normal);
	vec3 edge = abs(fract(local_position / cell) - 0.5) * 2.0;
	float line = max(edge.x * in_plane.x, max(edge.y * in_plane.y, edge.z * in_plane.z));
	ALBEDO = thread_color;
	ALPHA = mix(0.05, 0.85, smoothstep(0.86, 0.94, line));
}
