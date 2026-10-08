shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float aperture_radius : hint_range(0.2, 0.48) = 0.34;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float distance_from_center = length(p);
	float outside_scope = smoothstep(aperture_radius - 0.002, aperture_radius + 0.002, distance_from_center);
	COLOR = vec4(vec3(0.006, 0.009, 0.012), outside_scope * strength);
}
