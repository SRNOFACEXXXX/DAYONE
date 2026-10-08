# Reposiciona a pose de quadril das armas wf: pega (mão direita) num ponto da câmera + rotação em volta da pega.
# Uso: python tools/pose_quadril.py  (edite HIP abaixo)
import json, re, os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "weapons")
CABO = {"ak47": (0, 0.05, 0.15), "m4": (0, -0.092, 0.144), "mosin": (0, 0.013, 0.228), "m1911": (0, -0.07, 0.076), "revolver": (0, 0.0, 0.121)}
# Pose "ombreada baixa" (docs/ref/mosin_lowpoly.png): a ALÇA fica neste ponto da câmera; rotação (pitch, yaw, roll) em volta dela.
HIP = {"ak47": ((0.06, -0.06, -0.18), (0, 10, -8)), "m4": ((0.06, -0.06, -0.18), (0, 10, -8)),
       "mosin": ((0.10, -0.12, -0.34), (0, 10, -8)),
       "m1911": ((0.06, -0.075, -0.40), (1, 3, -2)), "revolver": ((0.06, -0.075, -0.40), (1, 3, -2))}
p = os.path.join(R, "miras.json")
mir = json.load(open(p, encoding="utf-8"))
for gid, e in mir.items():
    if gid.startswith("_"):
        continue
    m = e["modelo"]
    if m not in HIP:
        continue   # armas extras (tools/armas_novas.json) já têm a pose gerada por nova_arma.py
    g, rot = HIP[m]; c = e["alca"]
    pos = [round(g[i] - c[i], 4) for i in range(3)]
    f = os.path.join(R, "wf", m + "_fp.tscn")
    t = open(f, encoding="utf-8").read()
    t = re.sub(r'(\[node name="Arma" type="Node3D" parent="\."\]\n)position = Vector3\([^)]*\)', r'\1position = Vector3(%s, %s, %s)' % tuple(pos), t)
    open(f, "w", encoding="utf-8").write(t)
    e["quadril"] = {"pos": [0, 0, 0], "rot": list(rot), "escala": 1.0, "pivo": list(g)}
json.dump(mir, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("pose ok")
