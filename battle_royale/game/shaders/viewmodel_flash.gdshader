shader_type spatial;
// Muzzle flash for the first-person weapon: additive, unshaded, same FOV/depth trick as viewmodel.gdshader.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float viewmodel_fov = 52.0;
uniform float depth_squeeze = 0.35;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	mat4 proj = PROJECTION_MATRIX;
	float f = 1.0 / tan(radians(viewmodel_fov) * 0.5);
	// preserva os sinais: no Compatibility a projeção vem com Y invertido (render target)
	float sx = sign(PROJECTION_MATRIX[0][0]);
	float sy = sign(PROJECTION_MATRIX[1][1]);
	float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
	proj[0][0] = sx * f / aspect;
	proj[1][1] = sy * f;
	vec4 clip = proj * vec4(view_pos.xyz, 1.0);
	// mesma profundidade falsa do viewmodel.gdshader: o clarão fica na ordem certa com a arma e nunca é cortado
	float d = mix(0.06, 0.10, clamp(-view_pos.z / 2.0, 0.0, 1.0));
	vec4 cz = PROJECTION_MATRIX * vec4(0.0, 0.0, -d, 1.0);
	clip.z = cz.z / cz.w * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(tex, UV) * tint;
	ALBEDO = c.rgb * 2.2;
	ALPHA = c.a;
}
