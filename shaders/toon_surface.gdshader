shader_type spatial;

// === STYLIZED CEL SHADER ===
// Clean cel-shading with subtle rim highlights

group_uniforms color;
uniform vec4 albedo_color : source_color = vec4(0.5, 0.7, 0.4, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.25, 0.35, 0.2, 1.0);
uniform float shadow_threshold : hint_range(-0.5, 0.5) = 0.0;
uniform float shadow_softness : hint_range(0.01, 0.3) = 0.06;

group_uniforms rim;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power : hint_range(1.0, 6.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 0.5) = 0.15;

group_uniforms specular;
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.3;
uniform float specular_intensity : hint_range(0.0, 0.3) = 0.1;

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	
	// Subtle rim highlight on edges
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
	float fresnel = pow(1.0 - max(dot(normalize(world_normal), view_dir), 0.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_intensity * 0.5;
	
	ROUGHNESS = 0.85;
	SPECULAR = specular_intensity;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	
	// Clean 2-band cel shading
	float shadow_band = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, NdotL);
	
	// Lit areas use albedo, shadow areas use shadow color
	vec3 lit_color = ALBEDO * LIGHT_COLOR;
	vec3 shadow_col = shadow_color.rgb * LIGHT_COLOR * 0.5;
	
	DIFFUSE_LIGHT += mix(shadow_col, lit_color, shadow_band) * ATTENUATION;
	
	// Subtle specular spot
	if (specular_intensity > 0.01) {
		vec3 half_vec = normalize(VIEW + LIGHT);
		float NdotH = max(dot(NORMAL, half_vec), 0.0);
		float spec = smoothstep(0.92 - specular_smoothness * 0.1, 0.95, NdotH);
		SPECULAR_LIGHT += LIGHT_COLOR * spec * specular_intensity * ATTENUATION;
	}
}

