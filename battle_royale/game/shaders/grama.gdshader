shader_type spatial;
// Capim perto da câmera (maps/ilha/grama.gd): lâminas de duas faces, cor da grama do terreno escurecendo na base,
// balanço de vento só na ponta e encolhe até sumir perto do alcance (sem "pop" na borda).
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 cor_base : source_color = vec3(0.24, 0.33, 0.14);
uniform vec3 cor_ponta : source_color = vec3(0.56, 0.62, 0.30);
uniform float alcance = 38.0;
uniform float vento = 0.12;

varying float k;
varying float tom;

void vertex() {
	k = COLOR.r;   // 0 na base, 1 na ponta
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tom = 0.5 + 0.5 * sin(wpos.x * 0.045 + sin(wpos.z * 0.06) * 2.0) * sin(wpos.z * 0.037 + 1.3);   // manchas de tom (verde-oliva <-> amarelado) por zona
	float d = distance(wpos.xz, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	float some = 1.0 - smoothstep(alcance * 0.72, alcance, d);
	VERTEX.y *= some;
	float fase = TIME * 1.7 + wpos.x * 0.35 + wpos.z * 0.27;
	VERTEX.xz += vec2(sin(fase), cos(fase * 0.8)) * vento * k * k;
	NORMAL = vec3(0.0, 1.0, 0.0);   // luz de cima: capim não fica preto contra o sol
}

void fragment() {
	vec3 seca = vec3(0.62, 0.58, 0.28);
	ALBEDO = mix(mix(cor_base, cor_ponta, k), mix(cor_base * 1.1, seca, k), tom * 0.7);
	ROUGHNESS = 1.0;
}
