extends Node
## Tour de captura da ilha: --out=<pasta>. Vistas: aérea, vila, morro, represa, quartel (olho a 1,65 m).

var views := [
	["gpt_pomar_frente", Vector2(-233, -353), Vector2(-231, -340)],
	["gpt_rota_vila", Vector2(-301, -330), Vector2(-238, -327)],
	["gpt_abrigo", Vector2(-247, -345), Vector2(-231, -340)],
	["gpt_vale", Vector2(-29, -195), Vector2(-34, -176)],
	["gpt_quartel", Vector2(188, 251), Vector2(200, 268)],
	["aerea", Vector3(-420, 380, 560), Vector3(0, 40, 0)],
	["vila", Vector2(-330, -300), Vector2(-420, -370)],
	["morro", Vector2(-250, -30), Vector2(-40, -80)],
	["represa_barragem", Vector2(-70, -120), Vector2(-60, -40)],
	["quartel", Vector2(250, 280), Vector2(330, 360)],
	["pico_vista", Vector2(62, 138), Vector2(95, 175)],
	["morro_casas", Vector2(-330, -40), Vector2(-320, 20)],
	["vila_casas", Vector2(-395, -312), Vector2(-425, -310)],
	["usina", Vector2(-330, 250), Vector2(-280, 305)],
	["farol", Vector2(40, 450), Vector2(70, 505)],
	["quartel_poi", Vector2(240, 230), Vector2(315, 300)],
	["fazenda", Vector2(-35, -228), Vector2(-110, -300)],
	["praia", Vector2(78, -490), Vector2(175, -506)],
	["pista", Vector2(260, -230), Vector2(330, -285)],
	["rio", Vector2(-190, -150), Vector2(-250, -210)],
	["canavial", Vector2(-160, 205), Vector2(-215, 235)],
	["cobertura_campo", Vector2(-88, -176), Vector2(-80, -170)],
	["cobertura_campo2", Vector2(-128, -196), Vector2(-120, -200)],
	["acampamento_quartel", Vector2(280, 311), Vector2(291, 319)],
	["acampamento_fazenda", Vector2(-140, -332), Vector2(-130, -335)],
	["acampamento_pista", Vector2(313, -261), Vector2(321, -250)],
	["quartel_identificacao", Vector2(318, 190), Vector2(318, 205)],
	["fazenda_identificacao", Vector2(-232, -316), Vector2(-236, -306)],
	["pista_identificacao", Vector2(230, -400), Vector2(222, -392)],
	# cenário por área (docs/design/cenario_areas.json)
	["cen_vila_rua", Vector2(-350, -341), Vector2(-310, -330)],
	["cen_vila_praca", Vector2(-345, -396), Vector2(-328, -385)],
	["cen_vila_bar", Vector2(-392, -302), Vector2(-416, -290)],
	["cen_morro_pe", Vector2(-310, -40), Vector2(-288, -27)],
	["cen_morro_cruzeiro", Vector2(-336, 50), Vector2(-318, 62)],
	["cen_usina", Vector2(-256, 288), Vector2(-282, 322)],
	["cen_farol", Vector2(72, 468), Vector2(48, 495)],
	["cen_quartel_portao", Vector2(350, 192), Vector2(305, 218)],
	["cen_quartel_patio", Vector2(340, 240), Vector2(365, 252)],
	["cen_pedreira", Vector2(348, -24), Vector2(318, 5)],
	["cen_pista_cabeceira", Vector2(238, -326), Vector2(212, -340)],
	["cen_pista_hangar", Vector2(268, -248), Vector2(285, -222)],
	["cen_fazenda_piquete", Vector2(-118, -347), Vector2(-86, -346)],
	["cen_fazenda_colonos", Vector2(-138, -318), Vector2(-152, -333)],
	["cen_praia", Vector2(104, -492), Vector2(88, -506)],
	["cen_praia_carros", Vector2(70, -441), Vector2(70, -427)],
	["cen_trilha", Vector2(-205, 168), Vector2(-216, 180)],
	["cen_vau", Vector2(-248, -182), Vector2(-231, -197)],
	# cenário por área, passe 02 (docs/design/cenario_areas_02.json): aéreas de 40 a 70 m e vistas a 1,65 m
	["cen2_vila_aereo", Vector3(-330, 45, 395), Vector3(-405, 3, 315)],
	["cen2_vila_aereo_leste", Vector3(-345, 45, 330), Vector3(-295, 3, 385)],
	["cen2_vila_quintais", Vector2(-398, -347), Vector2(-428, -316)],
	["cen2_vila_ruas", Vector2(-336, -332), Vector2(-318, -318)],
	["cen2_vila_ranchos", Vector2(-362, -438), Vector2(-342, -418)],
	["cen2_cruz_aereo", Vector3(-320, 75, 40), Vector3(-320, 12, -30)],
	["cen2_cruz_chao", Vector2(-309, -27), Vector2(-309, 12)],
	["cen2_praca_cruzeiro", Vector2(-322, 38), Vector2(-320, 62)],
	["cen2_fazenda_casarao", Vector2(-110, -330), Vector2(-110, -290)],
	["cen2_fazenda_colonos", Vector2(-135, -335), Vector2(-165, -335)],
	["cen2_alameda_e2", Vector2(-38, -286), Vector2(-8, -380)],
	["cen2_alameda_e4", Vector2(362, -257), Vector2(430, -240)],
	["cen2_alameda_e7", Vector2(-62, 404), Vector2(-140, 392)],
	["cen2_usina_operaria", Vector2(-318, 330), Vector2(-345, 335)],
	["cen2_quartel_rancho", Vector2(312, 230), Vector2(312, 252)],
	["cen2_pedreira_cava", Vector2(332, 30), Vector2(332, 10)],
	["cen2_pista_hangar", Vector2(284, -265), Vector2(296, -240)],
	["cen2_farol", Vector2(58, 488), Vector2(70, 516)],
	["cen2_praia", Vector2(62, -468), Vector2(100, -490)],
	["cen2_acampamento", Vector2(-180, 50), Vector2(-170, 60)],
	["cen2_ruina_curral", Vector2(-32, 360), Vector2(-42, 376)],
	["cen2_capoeira", Vector2(290, -116), Vector2(305, -130)],
	["cen2_naufragio", Vector2(350, -346), Vector2(350, -362)],
	["cen2_bosque_pinheiros", Vector2(174, 402), Vector2(196, 418)],
	["cen2_carro_e8", Vector2(-404, 78), Vector2(-399, 100)],
	["cen2_carro_e5", Vector2(419, 92), Vector2(414, 111)],
	["cen_colisao_viatura", Vector2(333, 190), Vector2(340, 197)],
	["cen_colisao_sedan_usina", Vector2(-256, 292), Vector2(-266, 299)],
]


func _ready() -> void:
	var out: String = Game.test_args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1024, 768))
	var scene: Node3D = load("res://maps/ilha/ilha.tscn").instantiate()
	add_child(scene)
	await scene.map_ready
	await get_tree().process_frame
	var ex: Node3D = scene.get_node("Explorador")
	ex.set_physics_process(false)
	var cam: Camera3D = ex.cam
	var t: IlhaTerrain = scene.terrain
	var only: String = Game.test_args.get("only", "")
	for v in views:
		if only != "" and not String(v[0]) in only.split(","):
			continue
		if v[1] is Vector3:
			cam.global_position = v[1]
			cam.look_at(v[2])
		else:
			var a: Vector2 = v[1]
			var b: Vector2 = v[2]
			cam.global_position = Vector3(a.x, t.height_world(a.x, -a.y) + 1.65, -a.y)
			cam.look_at(Vector3(b.x, t.height_world(b.x, -b.y) + 3.0, -b.y))
		for i in 30:
			await get_tree().process_frame
		if Game.test_args.has("perf"):
			# média de 3 s após o aquecimento, sem vsync: tempo de quadro real da cena
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			var t0 := Time.get_ticks_usec()
			var n := 0
			while Time.get_ticks_usec() - t0 < 3000000:
				await get_tree().process_frame
				n += 1
			var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
			print("PERF %s %.1f ms (%.0f fps) draws=%d prims=%d" % [v[0], ms, 1000.0 / ms,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		if Game.test_args.has("probe"):
			# --probe=x;y : diz qual colisor está sob o pixel (depuração de objetos estranhos no quadro)
			var px: PackedStringArray = String(Game.test_args.probe).split(";")
			var sp := Vector2(float(px[0]), float(px[1]))
			var o := cam.project_ray_origin(sp)
			var q := PhysicsRayQueryParameters3D.create(o, o + cam.project_ray_normal(sp) * 2000.0)
			var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
			print("PROBE %s -> %s at %s" % [v[0], (hit.collider as Node).get_path() if hit else "nada", hit.get("position", "")])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("ilha_%s.png" % v[0]))
		print("VIEW %s fps=%d" % [v[0], Engine.get_frames_per_second()])
	get_tree().quit()
