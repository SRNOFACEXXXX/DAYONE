extends Node
## Intro: toca o vídeo, mede quadros enquanto o aquecimento roda e verifica que uma tecla pula para o menu.
class Vigia extends Node:
	var t := 0.0
	var feito := false
	func _process(dt: float) -> void:
		t += dt
		var cs := get_tree().current_scene
		if not feito and cs and cs.name == "MainMenu":
			feito = true
			print("INTRO_TESTE MENU_OK apos=%.2fs aquecendo=%s aquecido=%s" % [t, str(Loading.aquecendo), str(Loading.aquecido)])
			get_tree().quit()
		if t > 25.0:
			print("INTRO_TESTE FALHA: menu nao abriu")
			get_tree().quit(1)

func _ready() -> void:
	var v := Vigia.new()
	get_tree().root.add_child.call_deferred(v)
	var intro: Node = load("res://ui/intro.tscn").instantiate()
	add_child.call_deferred(intro)
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	var pl: VideoStreamPlayer = intro._player
	print("INTRO_TESTE tocando=", pl != null and pl.is_playing())
	var piores := 0.0
	var soma := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		var a := Time.get_ticks_msec()
		await get_tree().process_frame
		var d := float(Time.get_ticks_msec() - a)
		soma += d; n += 1; piores = maxf(piores, d)
	print("INTRO_TESTE quadros=%d media=%.1f ms pior=%.0f ms posicao=%.1fs aquecimento=%.2f" % [n, soma / n, piores, pl.stream_position, Loading.aquecimento_progresso()])
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_SPACE
	Input.parse_input_event(ev)
