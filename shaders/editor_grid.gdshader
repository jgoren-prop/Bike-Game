shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float grid_size : hint_range(0.5, 10.0) = 2.0;
uniform float line_thickness : hint_range(0.01, 0.2) = 0.05;
uniform vec4 line_color : source_color = vec4(0.5, 0.5, 0.6, 0.6);
uniform vec4 major_line_color : source_color = vec4(0.7, 0.7, 0.8, 0.8);
uniform int major_line_every : hint_range(2, 20) = 5;
uniform float fade_distance : hint_range(10.0, 200.0) = 80.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculate grid lines
	vec2 grid_uv = world_pos.xz / grid_size;
	vec2 grid_fract = abs(fract(grid_uv - 0.5) - 0.5);
	
	// Check if we're on a major grid line
	vec2 major_grid_uv = world_pos.xz / (grid_size * float(major_line_every));
	vec2 major_grid_fract = abs(fract(major_grid_uv - 0.5) - 0.5);
	
	// Line detection
	float line = min(grid_fract.x, grid_fract.y) / (line_thickness / grid_size);
	float major_line = min(major_grid_fract.x, major_grid_fract.y) / (line_thickness * 1.5 / (grid_size * float(major_line_every)));
	
	// Distance fade
	float dist = length(world_pos.xz);
	float fade = 1.0 - smoothstep(fade_distance * 0.5, fade_distance, dist);
	
	// Combine lines
	float is_major = step(major_line, 1.0);
	vec4 color = mix(line_color, major_line_color, is_major);
	float alpha = (1.0 - smoothstep(0.0, 1.0, min(line, major_line))) * fade;
	
	ALBEDO = color.rgb;
	ALPHA = alpha * color.a;
}

