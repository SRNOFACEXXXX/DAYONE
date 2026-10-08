class_name MxRetarget
extends RefCounted
## Animações do Mixamo (GLB leve, ossos "mixamorig_*") sobre o esqueleto do personagem (dayone_base: mesmos nomes sem prefixo, 44 ossos).
## As poses de descanso diferem (eixos dos ossos do Blender), então não dá para copiar rotações locais. Faz o mesmo que o zumbi
## (core/zombie_pose_copy.gd): copia o movimento em espaço global — delta = Pose·Descanso⁻¹ do esqueleto fonte, aplicado sobre o
## descanso global do alvo — e leva o deslocamento do quadril escalado pela razão das alturas.
## Uso: MxRetarget.tocar(body_model, "Shooting_Arrow", loop); MxRetarget.seek(body_model, t); MxRetarget.parar(body_model)

const META := "mx_ator"


class Modificador extends SkeletonModifier3D:
	var fonte: Skeleton3D
	var _alvo: PackedInt32Array = []
	var _src: PackedInt32Array = []
	var _src_rest_inv: Array[Quaternion] = []
	var _alvo_rest: Array[Quaternion] = []
	var _corr: Array[Quaternion] = []
	var _hips_alvo := -1
	var _hips_src := -1
	var _razao := 1.0
	var _pronto := false
	var _src_h0 := Vector3.ZERO

	func _montar(alvo: Skeleton3D) -> void:
		var pares: Array = []
		for i in alvo.get_bone_count():
			var nome := alvo.get_bone_name(i)
			var si := fonte.find_bone("mixamorig_" + nome)
			if si >= 0:
				pares.append([i, si])
		pares.sort_custom(func(a, b): return a[0] < b[0])
		var f_src0 := fonte.global_basis.orthonormalized().get_rotation_quaternion()
		var f_dst0 := alvo.global_basis.orthonormalized().get_rotation_quaternion()
		var k0 := f_dst0.inverse() * f_src0
		var mapa_src := {}
		for p in pares:
			mapa_src[p[0]] = p[1]
		for p in pares:
			_alvo.append(p[0])
			_src.append(p[1])
			_src_rest_inv.append(fonte.get_bone_global_rest(p[1]).basis.orthonormalized().get_rotation_quaternion().inverse())
			_alvo_rest.append(alvo.get_bone_global_rest(p[0]).basis.orthonormalized().get_rotation_quaternion())
			# correção T-pose (Mixamo) -> A-pose (corpo do jogo): gira o descanso do alvo até a direção osso->filho da fonte
			var corr := Quaternion.IDENTITY
			for filho in alvo.get_bone_children(p[0]):
				if mapa_src.has(filho):
					var d_dst: Vector3 = (alvo.get_bone_global_rest(filho).origin - alvo.get_bone_global_rest(p[0]).origin).normalized()
					var d_src: Vector3 = k0 * (fonte.get_bone_global_rest(mapa_src[filho]).origin - fonte.get_bone_global_rest(p[1]).origin).normalized()
					if d_dst.length() > 0.5 and d_src.length() > 0.5 and d_dst.dot(d_src) < 0.9998:
						corr = Quaternion(d_dst, d_src)
					break
			_corr.append(corr)
		_hips_alvo = alvo.find_bone("Hips")
		_hips_src = fonte.find_bone("mixamorig_Hips")
		var hs := (fonte.global_transform * fonte.get_bone_global_rest(_hips_src).origin - fonte.global_position).length()
		var ha := (alvo.global_transform * alvo.get_bone_global_rest(_hips_alvo).origin - alvo.global_position).length()
		_razao = ha / maxf(hs, 0.0001)
		_src_h0 = fonte.global_transform * fonte.get_bone_global_rest(_hips_src).origin
		_pronto = true

	func _process_modification() -> void:
		var alvo := get_skeleton()
		if fonte == null or alvo == null:
			return
		if not _pronto:
			_montar(alvo)
		var f_src := fonte.global_basis.orthonormalized().get_rotation_quaternion()
		var f_dst := alvo.global_basis.orthonormalized().get_rotation_quaternion()
		var k := f_dst.inverse() * f_src
		var k_inv := k.inverse()
		for n in _alvo.size():
			var ti := _alvo[n]
			var pose_src := fonte.get_bone_global_pose(_src[n])
			var motion := pose_src.basis.orthonormalized().get_rotation_quaternion() * _src_rest_inv[n]
			var pose := alvo.get_bone_global_pose(ti)
			pose.basis = Basis(k * motion * k_inv * _corr[n] * _alvo_rest[n])
			if ti == _hips_alvo:
				var atual: Vector3 = fonte.global_transform * pose_src.origin
				var delta_mundo := (atual - _src_h0) * _razao
				var rest_dst := alvo.get_bone_global_rest(ti).origin
				pose.origin = rest_dst + alvo.global_basis.inverse() * delta_mundo
			alvo.set_bone_global_pose(ti, pose)


static func tocar(bm: BodyModel, nome: String, loop := false, velocidade := 1.0) -> void:
	parar(bm)
	var cena := load("res://assets/anim_mixamo/leve/%s.glb" % nome) as PackedScene
	var raiz := cena.instantiate() as Node3D
	bm.add_child(raiz)
	raiz.global_transform = bm.global_transform
	var sk: Skeleton3D = raiz.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = raiz.find_children("*", "AnimationPlayer", true, false)[0]
	for g in raiz.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visible = false
	var mod := Modificador.new()
	mod.name = "MxCopia"
	mod.fonte = sk
	bm.skeleton.add_child(mod)
	var clip := ap.get_animation_list()[0]
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	ap.play(clip, 0.0, velocidade)
	if bm.tree:
		bm.tree.active = false
	if bm.ik:
		bm.ik.enabled_ik = false
	bm.anim_player.stop()
	bm.set_meta(META, [raiz, mod, ap])


static func seek(bm: BodyModel, t: float) -> void:
	if not bm.has_meta(META):
		return
	var ap: AnimationPlayer = bm.get_meta(META)[2]
	ap.seek(t, true)


static func duracao(bm: BodyModel) -> float:
	if not bm.has_meta(META):
		return 0.0
	var ap: AnimationPlayer = bm.get_meta(META)[2]
	return ap.get_animation(ap.current_animation).length


static func parar(bm: BodyModel) -> void:
	if bm.has_meta(META):
		var d: Array = bm.get_meta(META)
		(d[0] as Node).queue_free()
		(d[1] as Node).queue_free()
		bm.remove_meta(META)
	if bm.tree:
		bm.tree.active = true
	if bm.ik:
		bm.ik.enabled_ik = true
