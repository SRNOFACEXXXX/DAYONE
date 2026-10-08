extends Node
## PLAYTESTER AUTOMÁTICO: joga a partida real da ilha (core/br_match.tscn) como o jogador, mede e captura.
## Uso (janela real, áudio ligado — NÃO headless):
##   godot --path game res://tests/playtest.tscn -- --etapas=spawn,andar,combate,zumbi,carro,agua,som,ambiente --semente=1 --out=raw/playtest/01
## Saída: <out>/dados.json (bruto), playtest.log, img/*.png, audio_*.wav. tools/playtest.py faz a análise e o relatório.
## Termina com PLAYTEST_COLETA_OK / PLAYTEST_COLETA_FALHOU (o veredito final PLAYTEST_OK/FALHOU vem do tools/playtest.py).
const Ctx := preload("res://tests/playtest/pt_ctx.gd")
const STAGES := {
	"spawn": preload("res://tests/playtest/pt_spawn.gd"),
	"andar": preload("res://tests/playtest/pt_andar.gd"),
	"combate": preload("res://tests/playtest/pt_combate.gd"),
	"zumbi": preload("res://tests/playtest/pt_zumbi.gd"),
	"carro": preload("res://tests/playtest/pt_carro.gd"),
	"agua": preload("res://tests/playtest/pt_agua.gd"),
	"som": preload("res://tests/playtest/pt_som.gd"),
	"ambiente": preload("res://tests/playtest/pt_ambiente.gd"),
}
const ORDEM := ["spawn", "andar", "combate", "zumbi", "carro", "agua", "som", "ambiente"]
const TIMEOUT := {"spawn": 90.0, "andar": 150.0, "combate": 220.0, "zumbi": 150.0, "carro": 100.0, "agua": 90.0, "som": 120.0, "ambiente": 110.0}
const SEM_GRAVACAO_PROPRIA := ["som", "ambiente"]

var c: Node
var out := ""
var falhas: Array = []
var etapas: Array = []


func _ready() -> void:
	Game.test_mode = true
	Game.test_args["bots"] = "0"
	var args := Game.test_args
	etapas = String(args.get("etapas", ",".join(ORDEM))).split(",", false)
	var semente := int(args.get("semente", "1"))
	seed(semente)
	out = _resolve_out(String(args.get("out", "")))
	DirAccess.make_dir_recursive_absolute(out.path_join("img"))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1024, 768))
		DisplayServer.window_set_position(Vector2i(40, 30))
	get_tree().create_timer(float(args.get("limite", "900"))).timeout.connect(func() -> void:
		print("PLAYTEST_COLETA_FALHOU limite global")
		_salvar("limite global estourado")
		get_tree().quit(2))
	c = Ctx.new()
	c.name = "PlaytestCtx"
	c.out = out
	c.semente = semente
	add_child(c)
	await _carregar()
	if c.m == null:
		falhas.append("partida não carregou")
		_salvar("")
		print("PLAYTEST_COLETA_FALHOU partida não carregou")
		get_tree().quit(1)
		return
	for nome in etapas:
		if not STAGES.has(nome):
			c.log_("etapa desconhecida: %s" % nome)
			continue
		await _rodar(nome)
	_salvar("")
	var ok := falhas.is_empty()
	print("PLAYTEST_COLETA_OK" if ok else "PLAYTEST_COLETA_FALHOU %s" % str(falhas))
	get_tree().quit(0 if ok else 1)


func _resolve_out(a: String) -> String:
	var base := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	if a == "":
		var n := 1
		while DirAccess.dir_exists_absolute(base.path_join("raw/playtest/%02d" % n)):
			n += 1
		return base.path_join("raw/playtest/%02d" % n)
	if a.is_absolute_path():
		return a
	return base.path_join(a).simplify_path()


func _carregar() -> void:
	var t0 := Time.get_ticks_msec()
	var m := load("res://core/br_match.tscn").instantiate() as BRMatch
	add_child(m)
	await m.match_initialized
	var g := 0
	while (m.br_bag == null or m.local_player == null or m.local_player.controller == null) and g < 1200:
		await get_tree().process_frame
		g += 1
	if m.br_bag == null or m.local_player == null:
		return
	c.m = m
	c.s = m.local_player
	c.pc = m.local_player.controller as PlayerController
	c.ilha = m.ilha
	c.terr = m.ilha.terrain
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	c.pc._prefer_third_person = false
	c.pc._set_third_person(false)
	m.br_bag.add_item("backpack_medium")
	# Emula o fluxo real (Loading/ativar_ambiente): a horda inicial nasce em volta do JOGADOR já no spawn.
	var zd: Node = m.ilha.get_node_or_null("ZombieDirector")
	if zd:
		for z in c.zumbis():
			z.queue_free()
		await get_tree().process_frame
		zd.opening_count = 20
		zd.process_mode = Node.PROCESS_MODE_INHERIT
		zd.setup(m.ilha.terrain, m.local_player, m.ilha._zombie_settlement_centers())
	c.metricas["carga"] = {"segundos_ate_partida_pronta": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1), "zumbis_iniciais": c.zumbis().size(),
		"driver_audio": AudioServer.get_driver_name(), "renderer": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(),
		"janela": [get_window().size.x, get_window().size.y], "godot": Engine.get_version_info().string, "tem_ambiente": Audio._ambient.playing}
	for _i in 120:
		await get_tree().physics_frame
	c.log_("partida pronta em %.1f s" % c.metricas["carga"].segundos_ate_partida_pronta)


func _rodar(nome: String) -> void:
	var estado := {"fim": false}
	var limite_ms := Time.get_ticks_msec() + int((float(TIMEOUT.get(nome, 120.0)) + 20.0) * 1000.0)
	if nome not in SEM_GRAVACAO_PROPRIA:
		c.inicia_gravacao("etapa_" + nome)
	_executa(nome, estado)
	while not estado.fim and Time.get_ticks_msec() < limite_ms:
		await get_tree().process_frame
	if not estado.fim:
		falhas.append("etapa %s travou/expirou (erro de script?)" % nome)
		c.log_("ETAPA %s NÃO TERMINOU no limite" % nome)
		c.achado("ETAPA_TRAVOU", "alto", "Etapa '%s' não terminou no tempo (erro de script ou travamento do bot)" % nome, {"etapa": nome}, "", "Ferramenta")
	if c.etapa != "":
		c.termina_etapa()
	if nome not in SEM_GRAVACAO_PROPRIA:
		c.para_gravacao("etapa_" + nome)
	c.solta_entradas()
	c.s.health = 100
	if not c.s.alive:
		c.m.respawn(c.s)
		c.log_("jogador estava morto: respawn")
	await get_tree().process_frame


func _executa(nome: String, estado: Dictionary) -> void:
	await STAGES[nome].run(c)
	estado.fim = true


func _salvar(erro: String) -> void:
	if c == null:
		return
	for k in c.quadros.keys():
		if c.metricas.has(k) and c.metricas[k] is Dictionary:
			c.metricas[k]["quadros"] = c.resumo_quadros(k)
	c.metricas["performance_final"] = {"fps": Performance.get_monitor(Performance.TIME_FPS), "nos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"mem_estatica_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)}
	var d := {"versao": 1, "semente": c.semente, "etapas_pedidas": etapas, "erro": erro, "falhas_ferramenta": falhas, "metricas": c.metricas,
		"achados": c.achados, "eventos": c.eventos, "audio_eventos": c.audio_ev, "audio_externos": c.externos_ev, "bus_amostras": c.bus_amostras,
		"capturas": c.capturas, "gravacoes": c.gravacoes, "quadros_por_etapa": {}, "duracao_s": snappedf(c.tempo(), 0.1),
		"ids_som_existentes": Audio._library.keys()}
	for k in c.quadros.keys():
		var a: Array = c.quadros[k]
		var r := []
		for x in a:
			r.append(snappedf(float(x), 0.1))
		d["quadros_por_etapa"][k] = r
	var f := FileAccess.open(out.path_join("dados.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d, " "))
	f.close()
	var lf := FileAccess.open(out.path_join("playtest.log"), FileAccess.WRITE)
	lf.store_string("\n".join(c.logs))
	lf.close()
