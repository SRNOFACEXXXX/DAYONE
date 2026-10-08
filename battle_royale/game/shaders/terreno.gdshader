shader_type spatial;
// Terreno estilizado low poly (estilo Synty/Firewatch): facetas planas + paleta pintada por material,
// com variação autoral por altura, inclinação e distância da água (dados do bake, nada de ruído).
// splat RGB: R areia, G grama, B rocha; terra batida = 1 - soma. Texturas tileáveis opcionais (Scenario).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D splat : filter_linear_mipmap;
uniform sampler2D mata : filter_linear_mipmap, hint_default_black;     // manchas de mata (sub-bosque)
uniform vec3 sub_bosque : source_color = vec3(0.17, 0.31, 0.10);   // MUNDO: verde mais vivo (refs)
uniform vec3 canavial : source_color = vec3(0.50, 0.56, 0.20);
uniform vec3 capim_seco : source_color = vec3(0.698, 0.612, 0.361);   // #B29C5C (manchas autorais do chão vivo)
uniform sampler2D trilhas : filter_linear, hint_default_black; // trilhas de pé (2048 px, lidas por pixel)
uniform vec3 trilha_cor : source_color = vec3(0.627, 0.463, 0.298);   // #A0764C
uniform sampler2D tex_areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D tex_grama : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D tex_rocha : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D tex_terra : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
// paleta (litoral brasileiro, fim de tarde seco): cada material tem cor "baixa" e "alta"
uniform vec3 areia_molhada : source_color = vec3(0.66, 0.58, 0.42);
uniform vec3 areia_seca : source_color = vec3(0.86, 0.76, 0.54);   // MUNDO: areia menos bege-acinzentada   // menos estourada ao sol (tour37)
uniform vec3 grama_baixa : source_color = vec3(0.28, 0.46, 0.18);   // MUNDO: verde vivo (refs Downloads/ref)   // muted coastal sage
uniform vec3 grama_alta : source_color = vec3(0.39, 0.52, 0.20);
uniform vec3 grama_seca : source_color = vec3(0.659, 0.604, 0.333);    // #A89A55 capim seco dos altos e faces ao sol
uniform vec3 grama_encosta : source_color = vec3(0.35, 0.45, 0.17);
uniform vec3 rocha_clara : source_color = vec3(0.47, 0.43, 0.37);
uniform vec3 rocha_escura : source_color = vec3(0.30, 0.28, 0.25);
uniform vec3 terra_cor : source_color = vec3(0.431, 0.314, 0.220);   // #6E5038: percebido ~#8A5E3F sob o sol 1.6 + rampa (crítica 02)
uniform vec3 acost_cor : source_color = vec3(0.478, 0.341, 0.231);   // #7A573B acostamento
uniform vec3 talude : source_color = vec3(0.47, 0.42, 0.26);   // #786B42 talude de terra com capim ralo
uniform vec3 sulco_cor : source_color = vec3(0.33, 0.22, 0.15);   // sulco mais escuro que a terra #6E5038 (a cor #7C4C31 do Design ficava mais clara que o leito)
uniform float escala_textura = 0.125;
uniform float facetas = 1.0;            // 1 = normal da face (low poly), 0 = suave

varying vec3 wpos;
varying vec3 wnorm;
varying flat vec3 fpos;   // posição do vértice provocante: 1 amostra de splat por triângulo (crítica 03, ajuste 1)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	fpos = wpos;
}

void fragment() {
	// cor por face (estilo low poly): o splat é lido no centro da célula de 4 m e as transições ficam duras
	// cor por triângulo: amostra no vértice provocante (flat) -> cada face tem uma cor só, sem "escada" de células
	// longe (LODs de 4–8 m) a amostra por face vira serrote nas estradas: lá a leitura é por pixel
	float dist_cam = length(wpos - CAMERA_POSITION_WORLD);
	vec2 uv_cel = ((dist_cam < 140.0 ? fpos.xz : wpos.xz) + vec2(600.0)) / 1200.0;
	vec3 s3 = texture(splat, uv_cel).rgb;
	vec4 w = vec4(s3, clamp(1.0 - s3.r - s3.g - s3.b, 0.0, 1.0));
	w = smoothstep(vec4(0.4), vec4(0.6), w) + w * 0.08;       // dominante vence; resto quase some
	// terra lida por pixel com limiar duro: borda de estrada curva e nítida (a amostra por face fazia dente de serra — crítica 04, ajuste 1)
	vec3 sp = texture(splat, (wpos.xz + vec2(600.0)) / 1200.0).rgb;
	float terra_px = clamp(1.0 - sp.r - sp.g - sp.b, 0.0, 1.0);
	float e_terra = step(0.5, terra_px);
	float acostamento = step(0.32, terra_px) - e_terra;          // faixa ~0,8 m de terra pisada na borda
	w.a = 0.0;
	w.g += 0.001;
	w /= max(w.r + w.g + w.b, 0.001);
	w = mix(w, vec4(0.0, 0.0, 0.0, 1.0), e_terra);
	// normal da face (derivadas de tela) -> facetas nítidas como nos modelos low poly do jogo
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	fn *= sign(dot(fn, VIEW));      // no Compatibility o framebuffer é invertido: garante a face voltada para a câmera
	vec3 fwn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	float inclina = 1.0 - clamp(fwn.y, 0.0, 1.0);          // 0 plano .. 1 vertical
	vec2 tuv = wpos.xz * escala_textura;
	// areia em faixas duras (crítica 04, ajuste 6): molhada até 0,8 m, linha de maré (detritos) 0,8–1,0 m, seca acima
	vec3 a = wpos.y < 0.8 ? areia_molhada : (wpos.y < 1.0 ? areia_molhada * 0.82 : areia_seca);
	a *= texture(tex_areia, tuv).rgb;
	// 3 tons de grama por faixa de altura (quantizada por célula: cada faceta escolhe um tom)
	float alt_cel = floor(clamp(fpos.y / 48.0, 0.0, 1.0) * 6.0) / 6.0;
	vec3 g = mix(grama_baixa, grama_alta, smoothstep(0.08, 0.3, alt_cel));
	g = mix(g, grama_seca, smoothstep(0.5, 0.8, alt_cel) * 0.6);
	g = mix(g, grama_encosta, smoothstep(0.15, 0.45, inclina));
	vec3 mk = smoothstep(vec3(0.25), vec3(0.78), texture(mata, uv_cel).rgb);
	g = mix(g, sub_bosque, mk.r * 0.85);
	g = mix(g, canavial, mk.g * 0.9);
	g = mix(g, capim_seco, mk.b * 0.45) * texture(tex_grama, tuv).rgb;
	vec3 r = mix(rocha_clara, rocha_escura, smoothstep(0.35, 0.9, inclina)) * texture(tex_rocha, tuv * 0.5).rgb;
	// cortes de platô/estrada em cota baixa são talude de terra e capim, não rocha (paredão cinza da pista — crítica 05)
	r = mix(talude, r, smoothstep(30.0, 45.0, wpos.y));
	vec3 t = terra_cor * texture(tex_terra, tuv).rgb;
	w = mix(w, vec4(0.0, 0.0, 1.0, 0.0), step(0.36, inclina));   // > ~50°: rocha (paredões de terra/grama liam falsos — crítica 05)
	vec3 cor = a * w.r + g * w.g + r * w.b + t * w.a;
	cor = mix(cor, acost_cor, acostamento * (1.0 - w.b));
	// tom por orientação da face (±6%): faces voltadas ao sol esquentam, as opostas esfriam — dá leitura de faceta
	float orient = dot(normalize(fwn.xz + vec2(0.0001)), normalize(vec2(0.57, -0.82)));
	cor *= 1.0 + 0.06 * orient * (1.0 - fwn.y);
	float tr = step(0.5, texture(trilhas, UV).r) * step(0.5, w.g + w.r);   // borda dura, só sobre grama/areia   // trilha só sobre grama/areia
	cor = mix(cor, trilha_cor, tr * 0.9);
	float sulco = smoothstep(0.1, 0.35, texture(trilhas, UV).g) * e_terra;   // sulcos de roda só dentro da terra da estrada
	cor = mix(cor, sulco_cor, sulco * 0.35);   // trilho de pneu sutil (máscara de 0,59 m/texel não segura um sulco fino nítido)
	ALBEDO = cor;
	EMISSION = cor * 0.07;   // luz rebatida barata: sombras sem virar cinza-chumbo (crítica 05, ajuste 2)
	NORMAL = mix(NORMAL, fn, facetas);
	ROUGHNESS = 0.95;
}
