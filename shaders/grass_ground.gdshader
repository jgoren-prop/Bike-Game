shader_type spatial;

// === NATURAL GRASS SHADER ===
// Soft, natural grass with subtle color variation

group_uniforms colors;
uniform vec4 base_color : source_color = vec4(0.3, 0.42, 0.22, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.4, 0.52, 0.28, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.2, 0.3, 0.15, 1.0);

group_uniforms variation;
uniform float noise_scale : hint_range(0.01, 0.5) = 0.03;
uniform float color_variation : hint_range(0.0, 1.0) = 0.25;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 noise_uv = world_pos.xz * noise_scale;
	float n = noise(noise_uv);
	float n2 = noise(noise_uv * 3.0 + vec2(42.0));
	float combined_noise = (n + n2 * 0.5) / 1.5;
	
	// Create patches of lighter/darker grass
	vec3 varied_color = mix(base_color.rgb, highlight_color.rgb, combined_noise * color_variation);
	
	ALBEDO = varied_color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.05;
}
