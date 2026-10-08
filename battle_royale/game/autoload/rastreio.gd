extends Node
## Rastreio de recursos em memória (ferramenta de depuração).
## O jogo roda direto da pasta do projeto (res:// = game/), mas os assets (GLB, PNG, WAV...) são lidos já "descomprimidos"
## do cache de importação em game/.godot/imported/ (.ctex, .scn, .mesh, .sample...) e ficam vivos na RAM/VRAM
## enquanto alguém os referencia. Este autoload varre a árvore de cenas e lista cada recurso carregado:
##   caminho de origem (res://...), arquivo importado no disco, tipo, tamanho estimado e quem o usa (nó).
## Uso: F9 em jogo = grava o relatório; ou no código: Rastreio.rastrear() -> Array de Dictionary; Rastreio.gravar() -> caminho do relatório.
## Saída: user://rastreio/rastreio_<hora>.txt e .json  (user:// = %APPDATA%\Godot\app_userdata\<projeto>\rastreio\)

signal rastreado(total: int)

var ultimo: Array = []
var _hist: Array = []     # [tempo, memória estática, textura, buffer]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F9:
		var caminho := gravar()
		print("RASTREIO gravado em: ", ProjectSettings.globalize_path(caminho))


## Resumo da memória do processo (bytes).
func memoria() -> Dictionary:
	return {
		"estatica": OS.get_static_memory_usage(),
		"estatica_pico": OS.get_static_memory_peak_usage(),
		"textura_vram": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_vram": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"video_total": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"nos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"recursos": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


## Caminho do arquivo importado (descomprimido) no disco para um res://, lido do .import.
func arquivo_importado(res_path: String) -> String:
	if not res_path.begins_with("res://"):
		return ""
	var imp := res_path + ".import"
	if not FileAccess.file_exists(imp):
		return ""
	var cfg := ConfigFile.new()
	if cfg.load(imp) != OK:
		return ""
	var p := String(cfg.get_value("remap", "path", ""))
	if p == "":
		p = String(cfg.get_value("remap", "path.s3tc", ""))
	return p


func _tamanho(r: Resource) -> int:
	if r is Texture2D:
		var t := r as Texture2D
		return int(t.get_width() * t.get_height() * 4 * 1.33)
	if r is Mesh:
		var m := r as Mesh
		var b := 0
		for i in m.get_surface_count():
			var a := m.surface_get_arrays(i)
			if a.size() > Mesh.ARRAY_VERTEX and a[Mesh.ARRAY_VERTEX] != null:
				b += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 32
			if a.size() > Mesh.ARRAY_INDEX and a[Mesh.ARRAY_INDEX] != null:
				b += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 4
		return b
	if r is AudioStreamWAV:
		return (r as AudioStreamWAV).data.size()
	if r is AudioStream:
		return int((r as AudioStream).get_length() * 44100 * 4)
	return 0


func _coletar(r: Resource, dono: Node, mapa: Dictionary) -> void:
	if r == null:
		return
	var caminho := r.resource_path
	if caminho == "" or caminho.contains("::"):
		# sub-recurso embutido numa cena: contabiliza na cena-pai
		var base := caminho.get_slice("::", 0)
		if base == "":
			return
		caminho = base
	var e: Dictionary = mapa.get(caminho, {})
	if e.is_empty():
		e = {"origem": caminho, "tipo": r.get_class(), "bytes": 0, "usos": 0, "nos": [], "importado": arquivo_importado(caminho)}
		mapa[caminho] = e
	e.bytes += _tamanho(r)
	e.usos += 1
	if e.nos.size() < 3:
		e.nos.append(String(dono.get_path()))


func _varrer(n: Node, mapa: Dictionary) -> void:
	var sc: Script = n.get_script()
	if sc and sc.resource_path != "":
		_coletar(sc, n, mapa)
	if n.scene_file_path != "":
		var e: Dictionary = mapa.get(n.scene_file_path, {})
		if e.is_empty():
			mapa[n.scene_file_path] = {"origem": n.scene_file_path, "tipo": "PackedScene", "bytes": 0, "usos": 1, "nos": [String(n.get_path())], "importado": arquivo_importado(n.scene_file_path)}
		else:
			e.usos += 1
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		_coletar(mi.mesh, n, mapa)
		for i in mi.get_surface_override_material_count():
			_coletar(mi.get_active_material(i), n, mapa)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
		_coletar((n as MultiMeshInstance3D).multimesh.mesh, n, mapa)
	elif n is Sprite3D or n is Sprite2D:
		_coletar(n.get("texture"), n, mapa)
	elif n is TextureRect:
		_coletar((n as TextureRect).texture, n, mapa)
	elif n is AudioStreamPlayer or n is AudioStreamPlayer3D:
		_coletar(n.get("stream"), n, mapa)
	elif n is AnimationPlayer:
		for lib in (n as AnimationPlayer).get_animation_library_list():
			_coletar((n as AnimationPlayer).get_animation_library(lib), n, mapa)
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_override:
		_coletar((n as GeometryInstance3D).material_override, n, mapa)
	for c in n.get_children():
		_varrer(c, mapa)


## Varre a árvore e devolve a lista de recursos de arquivo carregados (maiores primeiro).
func rastrear() -> Array:
	var mapa := {}
	_varrer(get_tree().root, mapa)
	# texturas dos materiais (albedo etc.)
	for k in mapa.keys().duplicate():
		var r := load(k) if (mapa[k].tipo.ends_with("Material") and ResourceLoader.exists(k)) else null
		if r is BaseMaterial3D:
			for prop in ["albedo_texture", "normal_texture", "roughness_texture", "emission_texture"]:
				_coletar(r.get(prop), get_tree().root, mapa)
	ultimo = mapa.values()
	ultimo.sort_custom(func(a, b): return int(a.bytes) > int(b.bytes))
	_hist.append([Time.get_ticks_msec() / 1000.0, memoria()])
	rastreado.emit(ultimo.size())
	return ultimo


func _mb(b: float) -> String:
	return "%.1f MB" % (b / 1048576.0)


## Grava o relatório (texto + JSON) em user://rastreio/ e devolve o caminho do .txt.
func gravar() -> String:
	var lista := rastrear()
	DirAccess.make_dir_recursive_absolute("user://rastreio")
	var carimbo := Time.get_datetime_string_from_system().replace(":", "-")
	var txt := "user://rastreio/rastreio_%s.txt" % carimbo
	var mem := memoria()
	var f := FileAccess.open(txt, FileAccess.WRITE)
	if f == null:   # pasta sem permissão / disco cheio: não derruba o jogo (F9 só registra o erro)
		push_error("Rastreio: não foi possível gravar %s (erro %d)" % [txt, FileAccess.get_open_error()])
		return ""
	f.store_line("RASTREIO DE RECURSOS EM MEMÓRIA — %s" % carimbo)
	f.store_line("RAM estática: %s (pico %s) | VRAM texturas: %s | buffers: %s | nós: %d | recursos: %d" % [
		_mb(mem.estatica), _mb(mem.estatica_pico), _mb(mem.textura_vram), _mb(mem.buffer_vram), mem.nos, mem.recursos])
	f.store_line("Cache importado (descomprimido) no disco: %s" % ProjectSettings.globalize_path("res://.godot/imported"))
	f.store_line("")
	f.store_line("%-12s %-14s %-6s  ORIGEM  ->  ARQUIVO IMPORTADO  [nós]" % ["TAMANHO", "TIPO", "USOS"])
	for e in lista:
		f.store_line("%-12s %-14s %-6d  %s  ->  %s  %s" % [_mb(e.bytes), e.tipo, e.usos, e.origem, e.importado, str(e.nos)])
	f.close()
	var j := FileAccess.open("user://rastreio/rastreio_%s.json" % carimbo, FileAccess.WRITE)
	if j == null:
		push_error("Rastreio: não foi possível gravar o .json do relatório")
		return txt
	j.store_string(JSON.stringify({"memoria": mem, "recursos": lista}, "  "))
	j.close()
	return txt
