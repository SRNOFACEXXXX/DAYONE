extends Node
## Perf: chuva com CHUVA_PARTICULAS (220; antes 380). Uso: godot --path battle_royale/game res://tests/perf_clima_chuva.tscn


func _ready() -> void:
	var ilha := Node3D.new()
	add_child(ilha)
	Clima._ilha = ilha
	Clima._montar_chuva()
	assert(Clima._chuva_fx != null, "partículas de chuva criadas")
	assert(Clima.CHUVA_PARTICULAS == 220, "meta de 220 partículas")
	assert(Clima._chuva_fx.amount == Clima.CHUVA_PARTICULAS, "amount deve ser CHUVA_PARTICULAS")
	print("PERF_CLIMA_CHUVA_OK amount=", Clima._chuva_fx.amount)
	get_tree().quit()
