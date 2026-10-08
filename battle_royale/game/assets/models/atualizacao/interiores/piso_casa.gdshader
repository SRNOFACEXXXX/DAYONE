shader_type spatial;
// Piso da casa do pacote: tábuas corridas com emendas desencontradas e tom por tábua; cozinha em ladrilho xadrez.
uniform vec3 madeira_a : source_color = vec3(0.55, 0.34, 0.19);
uniform vec3 madeira_b : source_color = vec3(0.72, 0.48, 0.28);
uniform vec3 ladrilho_a : source_color = vec3(0.93, 0.9, 0.82);
uniform vec3 ladrilho_b : source_color = vec3(0.3, 0.5, 0.48);
varying vec3 mp;

void vertex() {
	mp = VERTEX;
}

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 p = mp.xz;
	vec3 col;
	if (p.x < -1.25 && p.y < 3.35) {
		vec2 q = p / 0.42;
		float k = mod(floor(q.x) + floor(q.y), 2.0);
		col = mix(ladrilho_a, ladrilho_b, k);
		vec2 f = fract(q);
		if (min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y)) < 0.03) { col *= 0.75; }
	} else {
		float w = 0.17;
		float row = floor(p.y / w);
		float along = (p.x + h1(row) * 1.6) / 1.6;
		float seg = floor(along);
		float h = h1(row * 7.3 + seg * 13.7);
		col = mix(madeira_a, madeira_b, h);
		col *= 0.94 + 0.06 * sin(p.x * 23.0 + h * 9.0);
		float fy = fract(p.y / w);
		if (fy < 0.06 || fract(along) < 0.008) { col *= 0.55; }
	}
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
}
