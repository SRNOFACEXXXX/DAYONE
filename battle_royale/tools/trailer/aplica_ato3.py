"""Aplica cinematic/ato3_shots.gd.txt (atos III e IV) em trailer.gd e registra as tomadas."""
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
p = os.path.join(ROOT, "game", "cinematic", "trailer.gd")
s = open(p, encoding="utf-8").read()
novo = open(os.path.join(ROOT, "game", "cinematic", "ato3_shots.gd.txt"), encoding="utf-8").read()
marca = "# ======================================================================== laço principal"
if "func _p_loot1" in s:
    i = s.index("func _fps_cam")
    j = s.index(marca)
    s = s[:i] + novo + s[j:]
else:
    s = s.replace(marca, novo + marca, 1)
reg = '''		_sh("loot1", 60.0, 62.8, _p_loot1, _a_loot1, _c_loot1),
		_sh("loot2", 62.8, 65.4, _p_loot2, _a_loot2, _c_loot2),
		_sh("loot3", 65.4, 68.0, _p_loot3, _a_loot3, _c_loot3),
		_sh("base", 68.0, 78.0, _p_base, _a_base, _c_base),
		_sh("caca", 78.0, 84.0, _p_caca, _a_caca, _c_caca),
		_sh("tiro1", 84.0, 87.0, _p_tiro1, _a_tiro1, _c_tiro1),
		_sh("tiro2", 87.0, 89.6, _p_tiro2, _a_tiro2, _c_tiro2),
		_sh("horda", 89.6, 92.0, _p_horda, _a_horda, _c_horda),
		_sh("carro", 92.0, 96.4, _p_carro, _a_carro, _c_carro),
		_sh("tiro3", 96.4, 100.0, _p_tiro1, _a_tiro1, _c_tiro3),
		_sh("cruz", 100.0, 110.0, _p_cruz, _a_cruz, _c_cruz),
'''
marca_reg = '		_sh("dbg_fumaca", 200.0, 210.0, _p_dbgf, _a_nada, _c_dbgf),\n'
if '"loot1"' not in s:
    s = s.replace(marca_reg, reg + marca_reg, 1)
if "func _c_tiro3" not in s:
    s = s.replace("# ======================================================================== laço principal", '''func _c_tiro3(tl: float) -> void:
	var u := _suave(tl / 3.0)
	var sp := s.global_position
	cam_a(sp + Vector3(-5.5 + 2.0 * u, 0.4, -1.4), sp + Vector3(0, 1.5, 0), 40.0, 0.012)


# ======================================================================== laço principal''', 1)
open(p, "w", encoding="utf-8").write(s)
print("ok")
