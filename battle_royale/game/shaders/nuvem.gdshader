shader_type spatial;
// Nuvem estilizada: sem luz/sombra (lê como volume macio, não como rocha), gradiente vertical base fria -> topo creme,
// borda levemente mais clara pelo ângulo de visão. Recebe a névoa normalmente.
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;   // névoa deixava as nuvens cinzentas (crítica 04)
uniform vec3 base : source_color = vec3(0.655, 0.702, 0.788);   // #A7B3C9 (crítica 02)
uniform vec3 topo : source_color = vec3(1.0, 0.953, 0.878);   // #FFF3E0
uniform vec3 sol_dir = vec3(0.47, 0.37, 0.80);   // direção para o sol (mundo), definida em ilha.gd
uniform vec3 borda_sol : source_color = vec3(1.0, 0.86, 0.70);
varying float h;
void vertex() {
	h = clamp((VERTEX.z + 6.0) / 30.0, 0.0, 1.0);   // modelo exportado Z-up -> Y-up: altura local no eixo do glTF
	h = clamp((VERTEX.y + 6.0) / 30.0, 0.0, 1.0);
}
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 c = mix(base, topo, smoothstep(0.0, 0.7, h));
	c = mix(c, borda_sol, f * 0.35);
	// volume toon por faceta (crítica 05, ajuste 4): 3 tons duros pela face em relação ao sol, sem custo de luz real
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	fn *= sign(dot(fn, VIEW));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	float l = dot(wn, normalize(sol_dir));
	c *= l > 0.3 ? 1.04 : (l > -0.15 ? 0.95 : 0.88);
	ALBEDO = c;
}
