# Gera, para cada arma de tools/armas_novas.json: game/assets/models/weapons/wf/<m>.tscn (mundo) e <m>_fp.tscn (1ª pessoa, com Muzzle/Eject),
# a entrada em miras.json, e imprime a linha de GRIPS (3ª pessoa) e a posição de quadril. As mãos (maos_wf_<m>.glb) saem de build_fp_maos.py.
# Uso: python tools/nova_arma.py
import json, os, re
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W = os.path.join(RAIZ, "game", "assets", "models", "weapons")
cfg = json.load(open(os.path.join(RAIZ, "tools", "armas_novas.json"), encoding="utf-8"))
mir = json.load(open(os.path.join(W, "miras.json"), encoding="utf-8"))
HIP = (0.058, -0.06, -0.24)
for k, c in cfg.items():
    if k.startswith("_"):
        continue
    m = c["modelo"]
    pos = [round(HIP[i] - c["alca"][i], 4) for i in range(3)]
    open(os.path.join(W, "wf", m + "_fp.tscn"), "w", encoding="utf-8").write('''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://core/weapon_model.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/models/weapons/wf/%s.glb" id="2"]
[ext_resource type="PackedScene" path="res://assets/models/weapons/maos_wf_%s.glb" id="3"]

[node name="%s_fp" type="Node3D"]
script = ExtResource("1")

[node name="Arma" type="Node3D" parent="."]
position = Vector3(%s, %s, %s)

[node name="Modelo" parent="Arma" instance=ExtResource("2")]

[node name="MaosFP" parent="Arma" instance=ExtResource("3")]

[node name="Muzzle" type="Marker3D" parent="Arma"]
position = Vector3(%s, %s, %s)

[node name="Eject" type="Marker3D" parent="Arma"]
position = Vector3(%s, %s, %s)
''' % ((m, m, m) + tuple(pos) + tuple(c["cano"]) + tuple(c["eject"])))
    open(os.path.join(W, "wf", m + ".tscn"), "w", encoding="utf-8").write('''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://core/weapon_model.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/models/weapons/wf/%s.glb" id="2"]

[node name="%s" type="Node3D"]
script = ExtResource("1")

[node name="Model" parent="." instance=ExtResource("2")]
''' % (m, m))
    e = {"no": "Arma", "alca": c["alca"], "massa": c["massa"], "alivio": c["alivio"], "modelo": m,
         "quadril": {"pos": [0, 0, 0], "rot": [1, 3, -3], "escala": 1.0, "pivo": [0.058, -0.06, -0.24]}}
    if c.get("luneta"):
        e["luneta"] = True
    mir[k] = e
    r, l = c["cabo"], c["apoio"]
    anchor = (0.12, round(-0.14 - r[1], 3), round(-0.17 - r[2], 3))
    print('GRIP &"%s": {"anchor": Vector3(%s, %s, %s), "r": Vector3(0, %s, %s), "rf": Vector3(0, -0.55, -0.83), "rp": Vector3(-1, 0, 0), "l": Vector3(0, %s, %s), "lf": Vector3(0.3, 0.2, -0.93), "lp": Vector3(0.45, 0.89, 0)},' % (k, *anchor, r[1], r[2], l[1], l[2]))
json.dump(mir, open(os.path.join(W, "miras.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
