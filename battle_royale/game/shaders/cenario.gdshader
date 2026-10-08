shader_type spatial;
// Cenário assado da Poeira (Compatibility): paleta (UV) x cor de vértice pintada, sol em tempo real,
// luz rebatida + oclusão assadas no Cycles (UV2: RGB = indireta empacotada, A = AO).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx, ambient_light_disabled;

uniform sampler2D paleta : source_color, filter_nearest_mipmap;
uniform sampler2D luz : filter_linear_mipmap, hint_default_white;
uniform float forca_indireta : hint_range(0.0, 3.0) = 1.0;
uniform float ao_forca : hint_range(0.0, 1.0) = 1.0;
uniform float ao_na_luz_direta : hint_range(0.0, 1.0) = 0.3;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.9;
uniform float especular : hint_range(0.0, 1.0) = 0.28;
uniform float brilho_emissivo = 3.0;
uniform bool tem_luz = true;

void fragment() {
	vec4 pal = texture(paleta, UV);
	vec3 base = pal.rgb * COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = rugosidade;
	SPECULAR = especular;
	vec3 emi = base * (1.0 - pal.a) * brilho_emissivo;
	if (tem_luz) {
		vec4 L = texture(luz, UV2);
		vec3 ind = pow(L.rgb, vec3(2.2)) * 2.0;
		AO = mix(1.0, L.a, ao_forca);
		AO_LIGHT_AFFECT = ao_na_luz_direta;
		emi += base * ind * forca_indireta;
	}
	EMISSION = emi;
}
