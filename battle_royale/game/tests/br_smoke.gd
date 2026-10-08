extends Node
## Fumaça da partida BR: avião -> salto -> queda -> paraquedas -> pouso, depois pega a arma mais próxima.
## Capturas: br_aviao, br_queda, br_para, br_pouso. Uso: --out=<pasta> [--perf]

var out := ""


func _ready() -> void:
	Game.test_mode = true
	out = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var m: BRMatch = load("res://core/br_match.tscn").instantiate()
	add_child(m)
	await m.match_initialized
	var s: Soldier = m.local_player
	await _frames(120)
	var pc := s.controller as PlayerController
	assert(Audio._ambient_id == "propeller_cartoon_loop", "motor do avião deve tocar durante o salto")
	print("BR camera avião third=%s vm=%s vm_enabled=%s state=%s" % [pc._third_person, pc.viewmodel.visible, pc.viewmodel.viewmodel_enabled, m.estado.get(s, "?")])
	assert(pc._third_person and not pc.viewmodel.visible and not pc.viewmodel.viewmodel_enabled, "avião precisa iniciar em terceira pessoa sem viewmodel FP")
	while not m.pode_saltar():
		await get_tree().physics_frame
	await _frames(120)   # ~2 s já sobre a ilha
	print("BR aviao voo_t=%.1f/%.1f pos=%s estado=%s" % [m.voo_t, m.voo_dur, s.global_position, m.estado[s]])
	await _foto("aviao")
	m.saltar(s)
	assert(Audio._ambient_id == "wind_whoosh_loop", "vento ambiente deve iniciar no salto")
	s.pitch = deg_to_rad(-60.0)
	s.in_move = Vector2(0, 1)
	await _frames(4)
	if pc:
		assert(pc._third_person, "queda livre precisa forçar câmera em terceira pessoa")
		assert(pc.camera.global_position.distance_to(s.global_position) > 2.0, "câmera de queda precisa ficar atrás do jogador")
	await _frames(90)
	await _foto("queda")
	var t0 := m.clock
	var viu_para := false
	while m.estado[s] != "chao" and m.clock - t0 < 90.0:
		await get_tree().physics_frame
		if m.estado[s] == "para" and not viu_para:
			viu_para = true
			assert(Audio._ambient_id == "wind_whoosh_loop" and Audio._ambient.volume_db <= -18.0, "vento deve reduzir quando o paraquedas abre")
			s.pitch = deg_to_rad(-20.0)
			await _frames(30)
			await _foto("para")
	s.in_move = Vector2.ZERO
	print("BR pouso em %.1f s pos=%s vivo=%s hp=%d" % [m.clock - t0, s.global_position, s.alive, s.health])
	assert(Audio._ambient_id == "amb_village", "ambiente da ilha deve voltar após o pouso")
	s.pitch = 0.0
	await _frames(60)
	if pc:
		assert(not pc._third_person, "câmera deve voltar à perspectiva preferida depois do pouso")
		# A locomoção visual precisa construir e soltar a passada, mesmo quando a física
		# já começou a frear. Mede a velocidade animada, não só a velocidade do CharacterBody.
		var bm := s.body_model as BodyModel
		if bm:
			Input.action_press("move_forward")
			await _frames(6)
			var arranque_curto := bm._anim_velocity.length()
			await _frames(50)
			var velocidade_corrida := bm._anim_velocity.length()
			Input.action_release("move_forward")
			await _frames(5)
			var cauda_frenagem := bm._anim_velocity.length()
			await _foto("locomocao_freio")
			await _frames(55)
			var repouso := bm._anim_velocity.length()
			print("LOCOMOCAO arranque_0.1s=%.2f corrida=%.2f freio_0.08s=%.2f repouso=%.2f" % [arranque_curto, velocidade_corrida, cauda_frenagem, repouso])
			assert(arranque_curto > 0.1 and arranque_curto < velocidade_corrida, "a passada deve acelerar progressivamente")
			assert(cauda_frenagem > 0.2 and cauda_frenagem < velocidade_corrida, "a passada deve continuar desacelerando após soltar o movimento")
			assert(repouso < 0.05, "a animação deve concluir a frenagem e chegar ao repouso")
		var toggle := InputEventKey.new()
		toggle.pressed = true
		toggle.physical_keycode = KEY_C
		pc._unhandled_input(toggle)
		await _frames(20)
		assert(pc._third_person and pc.viewmodel.visible == false, "C deve alternar para terceira pessoa")
		await _foto("chao_3p")
		pc._unhandled_input(toggle)
		await _frames(20)
		assert(not pc._third_person and pc.viewmodel.visible, "segundo C deve retornar à primeira pessoa")
		await _foto("chao_1p")
	if Game.test_args.has("perf"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var t1 := Time.get_ticks_usec()
		var n := 0
		while Time.get_ticks_usec() - t1 < 3000000:
			await get_tree().process_frame
			n += 1
		var ms := (Time.get_ticks_usec() - t1) / 1000.0 / n
		print("PERF br_pouso %.1f ms (%.0f fps) draws=%d" % [ms, 1000.0 / ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	await _foto("pouso")
	# saque: leva o jogador até a arma mais próxima e confere se ela entra no inventário
	var alvo: Pickup = null
	for p in m.pickups_root.get_children():
		if p is Pickup and (alvo == null or p.global_position.distance_to(s.global_position) < alvo.global_position.distance_to(s.global_position)):
			alvo = p
	if alvo:
		var antes := s.inventory.size()
		s.global_position = alvo.global_position + Vector3(0, 0.2, 0)
		s.reset_physics_interpolation()
		await _frames(60)
		print("BR saque -> inventário %d -> %d" % [antes, s.inventory.size()])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("br_%s.png" % nome))
