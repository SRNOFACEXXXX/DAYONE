"""Aplica o trecho cinematic/ato2_shots.gd.txt em trailer.gd (antes do laço principal) e registra os shots do ato II."""
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
p = os.path.join(ROOT, "game", "cinematic", "trailer.gd")
s = open(p, encoding="utf-8").read()
novo = open(os.path.join(ROOT, "game", "cinematic", "ato2_shots.gd.txt"), encoding="utf-8").read()
marca = "# ======================================================================== laço principal"
if "func _p_mont1" not in s:
    s = s.replace(marca, novo + marca, 1)
reg = '''		_sh("duna", 22.0, 30.0, _p_duna, _a_duna, _c_duna),
		_sh("mont1", 30.0, 32.0, _p_mont1, _a_nada, _c_mont1),
		_sh("mont2", 32.0, 34.0, _p_mont2, _a_nada, _c_mont2),
		_sh("mont3", 34.0, 36.0, _p_mont3, _a_nada, _c_mont3),
		_sh("mont4", 36.0, 38.0, _p_mont4, _a_nada, _c_mont4),
		_sh("mont5", 38.0, 40.0, _p_mont5, _a_nada, _c_mont5),
		_sh("rua_anda", 40.0, 46.0, _p_rua, _a_rua_anda, _c_rua_anda),
		_sh("rua_close", 46.0, 48.6, _p_rua2, _a_rua_parado, _c_rua_close),
		_sh("rua_zumbi", 48.6, 51.0, _p_rua2, _a_rua_parado, _c_rua_zumbi),
		_sh("rua_olhos", 51.0, 52.6, _p_rua2, _a_rua_parado, _c_rua_olhos),
		_sh("corre_casa", 52.6, 56.0, _p_rua3, _a_corre_casa, _c_corre_casa),
		_sh("porta", 56.0, 58.2, _p_porta, _a_porta, _c_porta),
		_sh("interior", 58.2, 59.5, _p_interior, _a_interior, _c_interior),
		_sh("janela", 59.5, 60.0, _p_janela, _a_janela, _c_janela),
'''
if '"mont1"' not in s:
    s = s.replace('		_sh("duna", 22.0, 30.0, _p_duna, _a_duna, _c_duna),\n', reg, 1)
open(p, "w", encoding="utf-8").write(s)
print("ok")
