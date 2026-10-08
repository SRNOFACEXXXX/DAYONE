shader_type spatial;
// First-person weapon/arms: own FOV + depth pulled toward the camera so it never clips into walls.
// Lighting still uses the true view-space position, so sun shadows and tunnels darken the hands correctly.
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D orm_tex : filter_nearest_mipmap, hint_default_white;
uniform bool use_orm = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.62;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.45;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float viewmodel_fov = 52.0;   // vertical, degrees
uniform float depth_squeeze = 0.35;   // fraction of view distance kept (>= near plane / nearest vertex)
uniform float rim_strength = 0.10;    // leve contorno para destacar a arma no escuro

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
	// Profundidade própria numa faixa fina logo à frente da câmera: a arma sempre fica na frente do mundo e
	// nunca é cortada pelo plano próximo (sem partes transparentes/sumindo ao mirar ou no coice do tiro).
	// Mantém a ordem entre as peças da própria arma (0..2 m de distância real).
	// usa a própria projeção da câmera numa profundidade falsa de 6–10 cm (vale para z normal ou invertido)
	float d = mix(0.06, 0.10, clamp(-view_pos.z / 2.0, 0.0, 1.0));
	vec4 cz = PROJECTION_MATRIX * vec4(0.0, 0.0, -d, 1.0);
	clip.z = cz.z / cz.w * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	if (use_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = roughness;
		METALLIC = metallic;
	}
	SPECULAR = specular;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb + ALBEDO * rim * rim_strength;
}
