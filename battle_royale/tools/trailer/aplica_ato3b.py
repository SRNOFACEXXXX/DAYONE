"""Aplica o arsenal (cinematic/ato3b_shots.gd.txt) em trailer.gd e troca a lista de tomadas 78–89,6 s (caça/tiro1/tiro2 -> 4 armas)."""
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
p = os.path.join(ROOT, "game", "cinematic", "trailer.gd")
s = open(p, encoding="utf-8").read()
marca = "# ======================================================================== laço principal"
novo = open(os.path.join(ROOT, "game", "cinematic", "ato3b_shots.gd.txt"), encoding="utf-8").read()
if "func armar_br" in s:
    i = s.index("# ---------------------------------------------------------------- ATO III — ARSENAL")
    j = s.index(marca)
    s = s[:i] + novo + s[j:]
else:
    s = s.replace(marca, novo + marca, 1)
for velho in ('\t\t_sh("caca", 78.0, 84.0, _p_caca, _a_caca, _c_caca),\n',
              '\t\t_sh("tiro1", 84.0, 87.0, _p_tiro1, _a_tiro1, _c_tiro1),\n',
              '\t\t_sh("tiro2", 87.0, 89.6, _p_tiro2, _a_tiro2, _c_tiro2),\n'):
    s = s.replace(velho, "")
if '"ars_ak"' not in s:
    s = s.replace('\t\t_sh("horda", 89.6, 92.0,',
                  '\t\t_sh("ars_ak", 78.0, 80.6, _p_ars_ak, _a_ars, _c_ars),\n'
                  '\t\t_sh("ars_m4", 80.6, 83.2, _p_ars_m4, _a_ars, _c_ars),\n'
                  '\t\t_sh("ars_snp", 83.2, 86.4, _p_ars_snp, _a_ars_snp, _c_ars),\n'
                  '\t\t_sh("ars_249", 86.4, 89.6, _p_ars_249, _a_ars, _c_ars),\n'
                  '\t\t_sh("horda", 89.6, 92.0,', 1)
# a horda e o resto voltam para a câmera de cinema
s = s.replace("func _p_horda() -> void:\n\tif pc.viewmodel:", "func _p_horda() -> void:\n\tfps_desliga()\n\tif pc.viewmodel:", 1) if "func _p_horda() -> void:\n\tfps_desliga()" not in s else s
# limpar(): garante que o modo FPS não vaze
if "Input.action_release(\"alt_fire\")" not in s.split("func limpar()")[1].split("func clima")[0]:
    s = s.replace("func limpar() -> void:\n", "func limpar() -> void:\n\tInput.action_release(\"alt_fire\")\n", 1)
open(p, "w", encoding="utf-8").write(s)
print("ok")
