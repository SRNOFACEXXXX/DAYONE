class_name ArmsIK
extends SkeletonModifier3D
## Pega da arma em 3ª pessoa (roda depois da animação):
##  1. inclina o tronco (Spine1/Spine2) pela mira vertical;
##  2. posiciona a arma num quadro de mira ancorado no pescoço (a arma segue a mira e balança com o corpo);
##  3. leva as mãos por IK analítico de dois ossos até o punho e o guarda-mão, com a palma orientada.

var body: Node3D                 # BodyModel
var soldier: Node                # Soldier
var weapon: Node3D               # nó visual da arma (filho do BodyModel)
var grip := {}                   # {"pos": Vector3, "rhand": bool, "lhand": bool, "r": Vector3, "l": Vector3, ...}
var pitch := 0.0
var enabled_ik := true
var palm_flip := true
var curl_right_only := false
var knife: Node3D = null        # faca presa ao centro da palma (sem deslocamento fixo)   # faca: mão direita fechada no cabo, sem IK
var kick := 0.0
var twist := 0.0          # rad: pernas giradas para o movimento; o tronco desfaz no Spine/Spine1
var lower := 0.0          # 0..1: cano baixo correndo sem atirar (low ready)
var cheek := 0.0          # 0..1: cabeça inclinada na coronha (rifle)
var lean := Vector2.ZERO   # rad: x = lateral (curvas/strafe), y = frente/trás (arrancar/frear)
var _head_fwd_local := Vector3.BACK          # coice do tiro (0..1), decai no BodyModel

var _b := {}                     # nome -> índice
var _hand_axes := {}             # "R"/"L" -> [fingers_local, palm_local]


func setup(sk: Skeleton3D) -> void:
	for n in ["Spine", "Spine1", "Spine2", "Neck", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm",
			"LeftHand", "RightHandMiddle1", "LeftHandMiddle1", "RightShoulder", "LeftShoulder"]:
		_b[n] = sk.find_bone(n)
	var hi: int = _b.get("Head", -1)
	if hi >= 0:
		# personagem olha +Z no espaço do esqueleto
		_head_fwd_local = (sk.get_bone_global_rest(hi).basis.orthonormalized().inverse() * Vector3(0, 0, 1)).normalized()
	# eixos da mão a partir da pose de descanso (T/A-pose: palmas para baixo)
	for side in ["Right", "Left"]:
		var h: int = _b[side + "Hand"]
		var m: int = _b[side + "HandMiddle1"]
		if h < 0:
			continue
		var hb := sk.get_bone_global_rest(h)
		var fingers := Vector3(-1 if side == "Right" else 1, 0, 0)
		if m >= 0:
			fingers = (sk.get_bone_global_rest(m).origin - hb.origin).normalized()
		var inv := hb.basis.orthonormalized().inverse()
		# normal da palma = dedos x polegar (mão esquerda) ou o oposto (direita); não depende da pose de descanso
		var palm := Vector3.DOWN
		var th: int = sk.find_bone(side + "HandThumb1")
		if th >= 0:
			var t := sk.get_bone_global_rest(th).origin - hb.origin
			t = (t - fingers * t.dot(fingers)).normalized()
			palm = fingers.cross(t) if side == "Left" else -fingers.cross(t)
		_hand_axes[side[0]] = [(inv * fingers).normalized(), (inv * palm).normalized()]


func _process_modification_with_delta(_dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or soldier == null or not enabled_ik:
		return
	var to_sk := sk.global_transform.affine_inverse()
	var right_sk := (to_sk.basis * _aim_basis().x).normalized()
	# 0. inclinação do corpo pela aceleração (referência: 4–10° lateral, 8–12° frente)
	var isp: int = _b.get("Spine", -1)
	if isp >= 0 and lean.length() > 0.001:
		var fwd_sk := (to_sk.basis * -_aim_basis().z)
		fwd_sk.y = 0.0
		fwd_sk = fwd_sk.normalized()
		var right_flat := Vector3(right_sk.x, 0, right_sk.z).normalized()
		var gs := sk.get_bone_global_pose(isp)
		gs.basis = Basis(fwd_sk, -lean.x) * Basis(right_flat, -lean.y) * gs.basis
		sk.set_bone_global_pose(isp, gs)
	# 0b. tronco desfaz o giro das pernas (metade em cada vértebra), peito volta para a mira
	if absf(twist) > 0.001:
		for n in ["Spine", "Spine1"]:
			var it: int = _b.get(n, -1)
			if it >= 0:
				var gt := sk.get_bone_global_pose(it)
				gt.basis = Basis(Vector3.UP, twist * 0.5) * gt.basis
				sk.set_bone_global_pose(it, gt)
	# 1. tronco acompanha a mira (metade no Spine1, metade no Spine2)
	for n in ["Spine1", "Spine2"]:
		var i: int = _b.get(n, -1)
		if i >= 0:
			var g := sk.get_bone_global_pose(i)
			g.basis = Basis(right_sk, pitch * 0.3) * g.basis
			sk.set_bone_global_pose(i, g)
	# poses do pacote com escala achatada nas mãos (mão "em riscos" na faca): volta à escala de descanso
	for hs in ["LeftHand", "RightHand"]:
		var hix: int = _b.get(hs, -1)
		if hix >= 0:
			var gh := sk.get_bone_global_pose(hix)
			var want_sc := sk.get_bone_global_rest(hix).basis.get_scale()
			var sc := gh.basis.get_scale()
			if absf(sc.x / want_sc.x - 1.0) > 0.15 or absf(sc.y / want_sc.y - 1.0) > 0.15 or absf(sc.z / want_sc.z - 1.0) > 0.15:
				gh.basis = gh.basis.orthonormalized().scaled_local(want_sc)
				sk.set_bone_global_pose(hix, gh)
	if curl_right_only:
		var ih: int = _b.get("RightHand", -1)
		var ax: Array = _hand_axes.get("R", [])
		if ih >= 0 and ax.size() == 2:
			var hb := sk.get_bone_global_pose(ih).basis.orthonormalized()
			var f: Vector3 = (hb * (ax[0] as Vector3)).normalized()
			var palm: Vector3 = (hb * (ax[1] as Vector3)).normalized()
			_curl(sk, "Right", f.cross(palm).normalized())
			# mão livre relaxada (meio fechada): aberta parecia "riscos" à distância
			var il: int = _b.get("LeftHand", -1)
			var axl: Array = _hand_axes.get("L", [])
			if il >= 0 and axl.size() == 2:
				var hbl := sk.get_bone_global_pose(il).basis.orthonormalized()
				_curl(sk, "Left", (hbl * (axl[0] as Vector3)).cross(hbl * (axl[1] as Vector3)).normalized(), 0.55)
			if knife:
				# cabo no centro da palma; lâmina (−Z da faca) sai pelo lado do polegar, gume para os dedos
				var thumb := f.cross(palm).normalized()
				var g := sk.get_bone_global_pose(ih)
				var sc := g.basis.get_scale().x
				var origin_sk := g.origin + f * 0.07 * sc + palm * 0.028 * sc
				var z := -thumb
				var y := f
				var x := y.cross(z).normalized()
				var kb := Basis(x, z.cross(x).normalized(), z)
				knife.global_transform = sk.global_transform * Transform3D(kb, origin_sk)
	_aim_head(sk, to_sk)
	if weapon == null or grip.is_empty():
		return
	# 2. quadro da arma: pivô no pescoço, orientado pela mira
	var neck: int = _b.get("Neck", -1)
	if neck < 0:
		return
	var neck_w := sk.global_transform * sk.get_bone_global_pose(neck).origin
	var aim := _aim_basis()
	var off: Vector3 = grip.get("anchor", Vector3(0.08, -0.1, -0.3))
	# coice: arma recua e o cano sobe um pouco (os braços acompanham pelo IK)
	var kb := aim * Basis(Vector3.RIGHT, kick * 0.07 - lower * deg_to_rad(22.0)) * Basis(Vector3.UP, lower * deg_to_rad(12.0))
	if grip.has("wrot"):
		kb = kb * Basis.from_euler(grip.wrot)
	weapon.global_transform = Transform3D(kb, neck_w + aim * (off + Vector3(0, 0.004, 0.035) * kick + Vector3(-0.02, -0.06, 0.05) * lower))
	var wt := weapon.global_transform
	# 3. mãos
	if grip.get("rhand", true):
		var p: Vector3 = wt * grip.r
		var f: Vector3 = (wt.basis * grip.rf).normalized()
		var palm: Vector3 = (wt.basis * grip.rp).normalized()
		var pole: Vector3 = wt.basis * Vector3(0.6, -1.0, 0.5)
		_solve(sk, "Right", to_sk * (p - f * 0.07 - palm * 0.03), to_sk.basis * f, to_sk.basis * palm, to_sk.basis * pole)
	if grip.get("lhand", true):
		# "lfree": mão esquerda livre, posicionada no quadro da mira (faca), não na arma
		var free: bool = grip.has("lfree")
		var p2: Vector3 = (neck_w + aim * (grip.lfree as Vector3)) if free else wt * grip.l
		var f2: Vector3 = ((aim if free else wt.basis) * grip.lf).normalized()
		var palm2: Vector3 = ((aim if free else wt.basis) * grip.lp).normalized()
		var pole2: Vector3 = wt.basis * Vector3(-0.8, -1.0, 0.2)
		_solve(sk, "Left", to_sk * (p2 - f2 * 0.07 - palm2 * 0.03), to_sk.basis * f2, to_sk.basis * palm2, to_sk.basis * pole2)


func _aim_basis() -> Basis:
	# segue o corpo interpolado (não o yaw cru da física), para a arma não tremer em relação ao corpo
	var yaw: float = (body.global_rotation.y + twist) if body else soldier.yaw
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


## IK de dois ossos (braço, antebraço) + orientação da mão. Tudo em espaço do esqueleto.
func _solve(sk: Skeleton3D, side: String, target: Vector3, fingers: Vector3, palm: Vector3, pole: Vector3) -> void:
	var iu: int = _b.get(side + "Arm", -1)
	var ifa: int = _b.get(side + "ForeArm", -1)
	var ih: int = _b.get(side + "Hand", -1)
	if iu < 0 or ifa < 0 or ih < 0:
		return
	var gu := sk.get_bone_global_pose(iu)
	var gf := sk.get_bone_global_pose(ifa)
	var gh := sk.get_bone_global_pose(ih)
	var a := gu.origin
	var l1 := a.distance_to(gf.origin)
	var l2 := gf.origin.distance_to(gh.origin)
	var d_vec := target - a
	var d := clampf(d_vec.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := d_vec.normalized()
	var ca := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - ca * ca, 0.0))
	var perp := (pole - dir * pole.dot(dir))
	if perp.length() < 1e-4:
		perp = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	perp = perp.normalized()
	var elbow := a + dir * ca + perp * h
	# braço
	var q1 := Quaternion((gf.origin - a).normalized(), (elbow - a).normalized())
	gu.basis = Basis(q1) * gu.basis
	sk.set_bone_global_pose(iu, gu)
	# antebraço
	gf = sk.get_bone_global_pose(ifa)
	gh = sk.get_bone_global_pose(ih)
	var q2 := Quaternion((gh.origin - gf.origin).normalized(), (a + dir * d - gf.origin).normalized())
	gf.basis = Basis(q2) * gf.basis
	sk.set_bone_global_pose(ifa, gf)
	# mão: dedos e palma
	gh = sk.get_bone_global_pose(ih)
	var ax: Array = _hand_axes.get(side[0], [])
	if ax.size() == 2:
		var sc := gh.basis.get_scale()
		var lf: Vector3 = ax[0]
		var lp: Vector3 = (ax[1] - lf * lf.dot(ax[1])).normalized()
		var df := fingers.normalized()
		var dp := (palm - df * df.dot(palm)).normalized()
		var lb := Basis(lf, lp, lf.cross(lp))
		var db := Basis(df, dp, df.cross(dp))
		gh.basis = (db * lb.inverse()).scaled_local(sc)
		sk.set_bone_global_pose(ih, gh)
		_curl(sk, side, (fingers.normalized().cross(dp)).normalized(), float(grip.get("lcurl", 1.0)) if side == "Left" else 1.0)


## Fecha os dedos em volta do punho/guarda-mão (dobra nas duas falanges; polegar menos).
const CURL := {"Index": [0.95, 0.9], "Middle": [1.0, 0.95], "Ring": [1.05, 1.0], "Pinky": [1.1, 1.0], "Thumb": [0.25, 0.35]}


func _curl(sk: Skeleton3D, side: String, axis: Vector3, amount := 1.0) -> void:
	for f in CURL:
		for j in 2:
			var i := sk.find_bone("%sHand%s%d" % [side, f, j + 1])
			if i < 0:
				continue
			var g := sk.get_bone_global_pose(i)
			g.basis = Basis(axis, CURL[f][j] * amount) * g.basis
			sk.set_bone_global_pose(i, g)


## Cabeça olha para onde a mira aponta (80 %), corrigindo o que a pose/animação deixar torto.
func _aim_head(sk: Skeleton3D, to_sk: Transform3D) -> void:
	var hi: int = _b.get("Head", -1)
	if hi < 0:
		return
	var g := sk.get_bone_global_pose(hi)
	var cur := (g.basis.orthonormalized() * _head_fwd_local).normalized()
	var want := (to_sk.basis * -_aim_basis().z).normalized()
	var q := Quaternion(cur, want)
	q = Quaternion.IDENTITY.slerp(q, 0.8)
	g.basis = Basis(q) * g.basis
	if cheek > 0.001:
		# bochecha na coronha: cabeça tomba ~10° para a direita e desce ~5°
		var fwd := want
		var rgt := (to_sk.basis * _aim_basis().x).normalized()
		g.basis = Basis(fwd, deg_to_rad(10.0) * cheek) * Basis(rgt, -deg_to_rad(5.0) * cheek) * g.basis
	sk.set_bone_global_pose(hi, g)
