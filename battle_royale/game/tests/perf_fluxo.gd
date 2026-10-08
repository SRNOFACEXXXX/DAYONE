extends "res://tests/menu_fluxo.gd"
## DESEMPENHO 2: o mesmo fluxo real de tests/menu_fluxo.tscn (menu -> criador -> partida andando 60 s), com opção
## --sem_vsync=1 (desliga o vsync só durante a medição; com vsync a média nunca fica abaixo de 1 intervalo do monitor).
## Também anota, para cada quadro > 50 ms, os nós criados/apagados naquele quadro (pista de trabalho síncrono).
var _vs_feito := false
var _nos_ult := 0
var _picos: Array = []


func _process(d: float) -> void:
	if _medindo and not _vs_feito:
		_vs_feito = true
		if Game.test_args.has("sem_vsync"):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if Game.test_args.has("msaa"):   # --msaa=0|1|2 (desligado, 2x, 4x): simula a qualidade baixa/média só na medição
			get_viewport().msaa_3d = int(Game.test_args.msaa) as Viewport.MSAA
		R["janela"] = str(DisplayServer.window_get_size())
		R["msaa"] = get_viewport().msaa_3d
		R["escala3d"] = get_viewport().scaling_3d_scale
		_nos_ult = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var antes := _quadros.size()
	super(d)
	if _medindo and _quadros.size() > antes:
		var q: float = _quadros[-1]
		var nos := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if q > 50.0 and _picos.size() < 30:
			_picos.append({"i": _quadros.size() - 1, "ms": snappedf(q, 0.1), "d_nos": nos - _nos_ult, "fis": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1),
				"proc": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), "obj": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				"pos": str(Game.current_match.local_player.global_position.round()) if Game.current_match and Game.current_match.get("local_player") else ""})
		_nos_ult = nos
	elif not _medindo and _vs_feito and not R.has("picos"):
		R["picos"] = _picos
		print("PERF_FLUXO_PICOS ", JSON.stringify(_picos))
