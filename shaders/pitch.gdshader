shader_type spatial;
// Çim: biçme şeritleri ve gürültüyle kırılmış yeşil. Islak sahada koyulaşır ve parlar.

uniform vec3 dark_green : source_color = vec3(0.07, 0.22, 0.06);
uniform vec3 light_green : source_color = vec3(0.11, 0.3, 0.08);
uniform float stripe_width = 5.5;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = step(0.5, fract(world_position.z / (stripe_width * 2.0)));
	vec3 color = mix(dark_green, light_green, band);
	float fine = texture(noise, world_position.xz * 0.45).r;
	float broad = texture(noise, world_position.xz * 0.035).r;
	color *= 0.78 + 0.34 * fine;
	color *= 0.88 + 0.24 * broad;
	ALBEDO = color * (1.0 - 0.25 * wetness);
	ROUGHNESS = mix(0.95, 0.45, wetness);
}
