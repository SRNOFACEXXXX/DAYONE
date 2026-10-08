shader_type spatial;
// Paredes internas da casa do pacote (core/casa_pacote.gd): cor por cômodo (pelo lado da parede: posição + normal no quadro
// da casa), lambri na metade de baixo com frisos verticais, faixa clara a 0,95 m, rodapé de madeira e "AO" falso perto do piso/teto.
uniform vec3 c_coz : source_color = vec3(0.78, 0.9, 0.8);
uniform vec3 c_sala : source_color = vec3(0.93, 0.84, 0.66);
uniform vec3 c_qne : source_color = vec3(0.66, 0.78, 0.9);
uniform vec3 c_qse : source_color = vec3(0.95, 0.74, 0.7);
uniform vec3 c_ban : source_color = vec3(0.75, 0.9, 0.92);
uniform vec3 c_hall : source_color = vec3(0.92, 0.88, 0.78);
uniform vec3 c_lambri : source_color = vec3(0.36, 0.55, 0.5);
uniform float lambri_mix = 0.55;
uniform vec3 c_faixa : source_color = vec3(0.97, 0.95, 0.89);
uniform vec3 c_rodape : source_color = vec3(0.33, 0.21, 0.13);
uniform float piso = 0.083;
varying vec3 mp;
varying vec3 mn;

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
}

vec3 comodo(vec2 p) {
	if (p.x < -1.25) {
		return p.y > 3.35 ? c_hall : c_coz;
	}
	if (p.y < -2.15) { return c_qne; }
	if (p.y < 0.6) { return c_sala; }
	return p.x < 1.0 ? c_ban : c_qse;
}

void fragment() {
	vec2 n2 = mn.xz;
	float nl = length(n2);
	n2 = nl > 0.01 ? n2 / nl : vec2(0.0);
	vec3 c = comodo(mp.xz + n2 * 0.3);
	float y = mp.y - piso;
	vec3 col = c;
	if (y < 0.95) {
		col = mix(c * 0.8, c_lambri, lambri_mix);
		float t = dot(mp.xz, vec2(-n2.y, n2.x));
		if (fract(t / 0.14) < 0.07) { col *= 0.82; }
	}
	if (y > 0.93 && y < 1.0) { col = c_faixa; }
	if (y < 0.13) { col = c_rodape; }
	else if (y < 0.15) { col = c_faixa * 0.92; }
	float ao = mix(0.78, 1.0, smoothstep(0.0, 0.7, y)) * mix(1.0, 0.82, smoothstep(2.1, 2.54, y));
	ALBEDO = col * ao;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
