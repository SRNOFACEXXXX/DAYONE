shader_type spatial;
// Água estilizada (mar e represa): cor por profundidade lida do mapa agua.png (bake), espuma em faixas
// animadas que quebram na beira, brilho do sol. Barata: 1 textura, sem leitura do depth buffer (GT 730).
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform sampler2D profundidade : filter_linear_mipmap, hint_default_black;
uniform int canal = 0;                                   // 0 = mar (R), 1 = represa (G), 2 = rio (profundidade fixa + correnteza)
uniform vec3 cor_rasa : source_color = vec3(0.30, 0.66, 0.62);
uniform vec3 cor_media : source_color = vec3(0.10, 0.42, 0.52);
uniform vec3 cor_funda : source_color = vec3(0.04, 0.20, 0.34);
uniform vec3 cor_espuma : source_color = vec3(0.92, 0.95, 0.93);
uniform float velocidade = 0.6;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz + vec2(600.0)) / 1200.0;
	float dentro = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 p = texture(profundidade, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	float d = (canal == 0 ? p.r : p.g) * 16.0;           // metros
	d = mix(16.0, d, dentro);
	if (canal == 2) {
		// rio: raso nas margens (UV.x = 0/1), 1,4 m no meio; faixas de correnteza descendo (UV.y = comprimento)
		d = 0.25 + 1.2 * sin(UV.x * 3.14159);
	}
	vec3 cor = mix(cor_rasa, cor_media, smoothstep(0.3, 3.0, d));
	cor = mix(cor, cor_funda, smoothstep(3.0, 12.0, d));
	// espuma: linha fixa na beira + 2 faixas de onda que avançam para a praia
	float beira = 1.0 - smoothstep(0.05, 0.45, d);
	float onda = sin(d * 5.0 + TIME * velocidade * 3.0) * 0.5 + 0.5;
	float faixas = smoothstep(0.82, 0.95, onda) * (1.0 - smoothstep(0.3, 1.6, d));
	float espuma = clamp(beira + faixas * 0.8, 0.0, 1.0);
	if (canal == 2) {
		// correnteza irregular: 3 ondas de frequências/velocidades diferentes, deformadas pela posição na margem
		float y = UV.y - TIME * 1.8;
		float corr = sin(y * 0.7 + sin(UV.x * 5.0 + y * 0.13) * 1.6) + 0.6 * sin(y * 1.9 + UV.x * 3.1) + 0.4 * sin(y * 3.7 - UV.x * 7.0);
		corr = smoothstep(1.1, 1.6, corr);
		espuma = clamp((1.0 - smoothstep(0.02, 0.1, min(UV.x, 1.0 - UV.x))) * 0.55 + corr * 0.22, 0.0, 1.0) * 0.25;   // crítica 04: rio menos "asfalto molhado"
	}
	ALBEDO = mix(cor, cor_espuma, espuma);
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ROUGHNESS = canal == 2 ? mix(0.35, 0.8, espuma) : mix(0.18, 0.8, espuma);   // mar: rugosidade mínima 0.18 (crítica 02)
	SPECULAR = canal == 2 ? 0.08 : 0.5;
	ALPHA = canal == 2 ? 1.0 : mix(0.78, 0.98, max(smoothstep(0.0, 4.0, d), espuma)) + f * 0.1;   // rio opaco (crítica 05)
}
