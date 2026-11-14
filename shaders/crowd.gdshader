shader_type spatial;
// Tribün: uzaktan bakıldığında kalabalık gibi görünen renkli benekler. Basit tutulur (performans).

uniform vec3 seat_color : source_color = vec3(0.05, 0.055, 0.075);
uniform float density = 0.7;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(vec2(world_position.x + world_position.z, world_position.y * 1.6) / 0.55);
	float pick = hash(cell);
	float present = step(1.0 - density, hash(cell + 17.0));
	vec3 shirt = vec3(hash(cell + 3.0), hash(cell + 5.0), hash(cell + 9.0));
	shirt = mix(vec3(dot(shirt, vec3(0.33))), shirt, 0.3) * (0.18 + 0.22 * pick);
	ALBEDO = mix(seat_color, shirt, present);
	ROUGHNESS = 1.0;
}
