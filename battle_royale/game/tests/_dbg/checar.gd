extends Node
## Compila scripts (com autoloads carregados) e diz quais falham. Uso: ... res://tests/_dbg/checar.tscn -- --scripts=a.gd,b.gd
func _ready() -> void:
	var lista := String(Game.test_args.get("scripts", "")).split(",", false)
	var falhas := 0
	for p in lista:
		var s = load(p)
		var ok: bool = s != null and (s as GDScript).can_instantiate()
		if not ok:
			falhas += 1
		print("CHECK %s %s" % [p, "ok" if ok else "FALHOU"])
	print("CHECK_FIM falhas=%d" % falhas)
	get_tree().quit(falhas)
