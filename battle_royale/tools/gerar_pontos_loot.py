# Gera docs/design/pontos_loot.json (e a cópia em game/maps/ilha/) a partir dos pontos de saque INTERNOS que cada modelo de prédio
# registra ao ser gerado (tools/_loot/<modelo>.json, escritos por build_predios.py / interior.py) e do layout da ilha.
# Nada é sorteado: cada ponto foi posicionado à mão na planta do modelo (Comodo.loot / Kit.ponto); aqui só se mapeia
# id do prédio do layout -> variante do modelo (a mesma regra de ilha.gd::_modelo_predio: índice do id % nº de variantes).
# Uso: python tools/gerar_pontos_loot.py
import json, os, shutil

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..")
LAYOUT = os.path.join(RAIZ, "docs", "design", "ilha_layout.json")
PREDIOS = os.path.join(RAIZ, "game", "assets", "models", "predios")
LOOT = os.path.join(AQUI, "_loot")
SAIDA = os.path.join(RAIZ, "docs", "design", "pontos_loot.json")
COPIA = os.path.join(RAIZ, "game", "maps", "ilha", "pontos_loot.json")

layout = json.load(open(LAYOUT, encoding="utf8"))
MILITAR = {"quartel"}                                   # POIs militares: todo saque interno vira tier "alto"
VEICULOS = ("caminhao_abandonado", "trator", "carcaca_teco_teco", "carcaca_fusca", "carreta_cana")
POI_MILITAR_CENTRO = {p["id"]: p["centro"] for p in layout["pois"] if p["id"] in ("quartel", "pista_pouso")}

predios = {}
sem_modelo = []
sem_pontos = []
for poi in layout["pois"] + layout.get("marcos", []):
    for pr in poi.get("predios", []):
        tipo = pr["tipo"]
        variantes = [v for v in "abcd" if os.path.exists(os.path.join(PREDIOS, "%s_%s.glb" % (tipo, v)))]
        if not variantes:
            sem_modelo.append(pr["id"])
            continue
        idx = int(pr["id"].rsplit("_", 1)[-1])
        modelo = "%s_%s" % (tipo, variantes[idx % len(variantes)])
        arq = os.path.join(LOOT, modelo + ".json")
        if not os.path.exists(arq):
            continue
        pts = json.load(open(arq, encoding="utf8"))["loot"]
        if not pts:
            sem_pontos.append(pr["id"])
            continue
        saida = []
        for p in pts:
            q = dict(p)
            if poi.get("id") in MILITAR:
                q["tier"] = "alto"
            q["andar"] = 0 if q["y"] < 2.0 else 1
            saida.append(q)
        predios[pr["id"]] = saida

# pontos externos junto a veículos (carcaças de avião, caminhão, trator...), em coordenadas de MUNDO do design (x leste, y norte)
externos = []
coberturas = list(layout.get("cobertura_campo_aberto", []))
gp = os.path.join(RAIZ, "docs", "design", "gameplay_01.json")
if os.path.exists(gp):
    coberturas += json.load(open(gp, encoding="utf8")).get("coberturas_novas", [])
for c in coberturas:
    if c["tipo"] not in VEICULOS:
        continue
    x, y = c["pos"]
    perto_militar = any(((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 < 160 for cx, cy in POI_MILITAR_CENTRO.values())
    externos.append({"veiculo": c["tipo"], "x": x, "y": y, "desloca_m": 2.6, "tier": "alto" if perto_militar else "medio",
                     "nota": "ponto a 2,6 m do veículo, no lado de +X local do modelo (gire pelo rot_deg do veículo)", "rot_deg_veiculo": c.get("rot_deg", 0)})

doc = {
    "descricao": "Pontos INTERNOS de spawn de caixa de loot por prédio do layout (id -> lista). Coordenadas locais ao prédio, as mesmas do .glb "
                 "instanciado em ilha.gd::_modelo_predio: x/z = plano horizontal Godot (z = -y do Blender), y = altura do piso interno sobre a "
                 "origem do prédio (piso térreo ~0,12-0,25; 'andar' 1 = piso superior). rot_deg = giro em Y da frente da caixa (voltada para "
                 "dentro do cômodo). Nunca em telhado/laje externa. tier: alto = prédios militares (quartel, paiol, hangar, garagem, comando); "
                 "medio/baixo = demais. sala: quarto|cozinha|sala|galpao|container|... . Cada ponto tem 0,8 m de folga à frente.",
    "predios": predios,
    "externos_veiculos": externos,
}
with open(SAIDA, "w", encoding="utf8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
shutil.copyfile(SAIDA, COPIA)
n = sum(len(v) for v in predios.values())
print("pontos_loot.json: %d prédios, %d pontos, %d externos; sem modelo: %s; sem pontos: %s" % (len(predios), n, len(externos), sem_modelo, sem_pontos))
