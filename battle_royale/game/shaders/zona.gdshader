shader_type spatial;
// Parede da zona do battle royale: cortina azul translúcida sem luz, com faixas verticais que sobem devagar
// e mais forte perto do chão. Vista por dentro e por fora (cull_disabled), não escreve profundidade.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;
uniform vec4 cor : source_color = vec4(0.25, 0.62, 1.0, 0.34);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float faixa = step(0.5, fract(UV.x * 160.0 + wpos.y * 0.01 - TIME * 0.05));
	float base = 1.0 - smoothstep(0.0, 260.0, wpos.y);
	ALBEDO = cor.rgb * (0.85 + 0.25 * faixa);
	// de longe a parede vira um véu fraco (as faixas cobriam o céu inteiro vistas de dentro da zona)
	float longe = smoothstep(80.0, 500.0, length(wpos - CAMERA_POSITION_WORLD));
	ALPHA = cor.a * (0.45 + 0.55 * base) * mix(0.8 + 0.2 * faixa, 0.35, longe);
}
