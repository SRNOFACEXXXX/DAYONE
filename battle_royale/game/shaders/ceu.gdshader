shader_type sky;
// Céu estilizado com ciclo dia/noite (core/clima.gd comanda os uniforms): gradiente zênite -> horizonte,
// halo e disco do sol, lua, estrelas à noite; abaixo do horizonte a cor do mar (sem a faixa cinza do céu procedural).
uniform vec3 zenite : source_color = vec3(0.247, 0.435, 0.69);   // #3F6FB0 (crítica 04)
uniform vec3 meio : source_color = vec3(0.45, 0.64, 0.86);
uniform vec3 horizonte : source_color = vec3(0.90, 0.80, 0.70);   // pêssego de fim de tarde (crítica 01, item 19)
uniform vec3 mar_longe : source_color = vec3(0.63, 0.69, 0.74);   // casado com o mar enevoado a 6 km (crítica 02, faixa escura)
uniform vec3 sol_cor : source_color = vec3(1.0, 0.86, 0.62);
uniform float sol_tamanho = 0.9995;
uniform vec3 sol_dir = vec3(0.47, 0.37, 0.80);     // direção PARA o sol (mundo)
uniform vec3 lua_dir = vec3(-0.47, -0.37, -0.80);  // direção PARA a lua
uniform float sol_vis : hint_range(0.0, 1.0) = 1.0;
uniform float lua_vis : hint_range(0.0, 1.0) = 0.0;
uniform float estrelas : hint_range(0.0, 1.0) = 0.0;
uniform float raio : hint_range(0.0, 1.0) = 0.0;     // clarão de relâmpago

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizonte, meio, smoothstep(0.0, 0.18, y));
	c = mix(c, zenite, smoothstep(0.18, 0.75, y));
	c = mix(c, mar_longe, smoothstep(0.0, -0.02, y));          // abaixo do horizonte: mar distante
	float up = smoothstep(-0.01, 0.02, y);
	float s = dot(EYEDIR, normalize(sol_dir));
	c += sol_cor * pow(max(s, 0.0), 24.0) * 0.35 * sol_vis;      // halo largo
	c += sol_cor * pow(max(s, 0.0), 400.0) * 0.8 * sol_vis;      // brilho
	c = mix(c, vec3(1.0, 0.95, 0.85) * 3.0, smoothstep(sol_tamanho, sol_tamanho + 0.0002, s) * sol_vis * up);   // disco
	if (estrelas > 0.01 && y > 0.0) {
		vec3 p = EYEDIR * 90.0;
		vec3 cell = floor(p);
		float h = hash13(cell);
		float d = length(fract(p) - 0.5);
		float st = step(0.985, h) * smoothstep(0.32, 0.08, d) * (0.5 + 0.5 * hash13(cell + 7.0));
		c += vec3(0.85, 0.9, 1.0) * st * estrelas * smoothstep(0.02, 0.2, y) * 1.4;
	}
	float m = dot(EYEDIR, normalize(lua_dir));
	c += vec3(0.55, 0.65, 0.9) * pow(max(m, 0.0), 40.0) * 0.12 * lua_vis;
	c = mix(c, vec3(0.92, 0.95, 1.0) * 1.6, smoothstep(0.9993, 0.9996, m) * lua_vis * up);   // disco da lua
	c += vec3(0.7, 0.75, 1.0) * raio * 0.9;
	COLOR = c;
}
