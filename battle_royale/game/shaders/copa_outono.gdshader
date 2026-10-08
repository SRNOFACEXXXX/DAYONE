shader_type spatial;
// Copa de outono para as árvores do pacote (paleta 'tex_paleta_natureza'): só os texels VERDES da paleta viram a cor
// de outono (laranja/amarelo/vermelho da ref MOSIN_LOWPOLY); tronco/galhos ficam como estão. Usado em instâncias
// escolhidas à mão em maps/ilha/cenario_atualizacao.json (campo "copa").
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D paleta : source_color, filter_nearest_mipmap;
uniform vec3 outono : source_color = vec3(0.93, 0.52, 0.12);

void fragment() {
	vec3 c = texture(paleta, UV).rgb;
	float verde = smoothstep(0.015, 0.08, c.g - max(c.r, c.b));
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c, outono * clamp(0.6 + l * 1.4, 0.6, 1.25), verde);
	ROUGHNESS = 0.95;
}
