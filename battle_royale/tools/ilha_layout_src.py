# -*- coding: utf-8 -*-
"""
Fonte AUTORAL do layout da Ilha do Tauá.

Todos os números abaixo foram desenhados à mão (coordenadas em metros, origem no
centro do mapa, X = leste, Y = norte, Z = altura). Nada aqui é aleatório ou ruído:
o script apenas organiza os dados e grava docs/design/ilha_layout.json.

Única derivação automática: pontos de saque INTERNOS dos prédios vêm de gabaritos
fixos por tipo de prédio (offsets locais escritos à mão em GABARITO_SAQUE),
transformados pela posição/rotação do prédio — determinístico, sem sorteio.

Uso:  python tools/ilha_layout_src.py
"""
import json, math, os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "docs", "design", "ilha_layout.json")

# ---------------------------------------------------------------------------
# 1. Contorno da costa (anti-horário, começando no leste). 65 pontos.
# ---------------------------------------------------------------------------
COSTA = [
    (505, 0), (500, 60), (490, 120), (500, 180), (482, 240), (458, 292),
    (440, 340), (410, 385), (365, 415), (315, 432), (270, 448), (220, 455),
    (175, 470), (140, 500), (112, 535), (72, 556), (30, 548), (5, 520),
    (-20, 482), (-60, 457), (-110, 450), (-160, 460), (-210, 455), (-260, 442),
    (-310, 425), (-355, 400), (-395, 366), (-430, 320), (-460, 270), (-480, 215),
    (-492, 160), (-505, 100), (-520, 40), (-515, -20), (-500, -75), (-486, -125),
    (-490, -170), (-478, -215), (-486, -262), (-495, -310), (-480, -355),
    (-458, -392), (-432, -412), (-400, -428), (-365, -441), (-320, -456),
    (-272, -480), (-222, -500), (-160, -506), (-100, -511), (-40, -520),
    (20, -526), (80, -522), (140, -516), (200, -506), (255, -487), (300, -462),
    (350, -442), (400, -421), (445, -391), (480, -346), (500, -296),
    (515, -240), (515, -180), (508, -120), (505, -60),
]

# ---------------------------------------------------------------------------
# 2. Pontos de controle de altura (x, y, z, rótulo). A costa inteira é z = 0.
# ---------------------------------------------------------------------------
ALTURAS = [
    # Serra do Tauá — cumeeira principal (oeste -> leste)
    (-220, 120, 70, "sela Morro-Serra"), (-160, 160, 95, "serra"), (-100, 175, 122, "serra"),
    (-40, 170, 146, "serra"), (20, 165, 165, "serra"), (80, 160, 178, "Pico do Tauá"),
    (130, 150, 162, "serra"), (180, 125, 142, "serra"), (230, 95, 126, "serra"),
    (280, 60, 110, "serra"), (330, 42, 100, "borda norte da pedreira"),
    # Pedreira (cava em degraus)
    (330, 0, 58, "fundo da cava"), (352, -12, 58, "fundo da cava"), (305, 12, 62, "rampa"),
    (382, 22, 92, "borda"), (362, -52, 84, "borda sul"), (290, -40, 80, "borda sudoeste"),
    (300, 52, 98, "borda noroeste"), (405, -30, 68, "encosta leste"), (450, 0, 40, "topo falésia"),
    (482, 22, 32, "topo falésia"), (384, -40, 72, "platô da oficina"), (268, 22, 84, "platô do paiol"),
    # Encosta norte da serra
    (-160, 240, 58, "encosta N"), (-80, 262, 70, "encosta N"), (0, 252, 96, "encosta N"),
    (80, 240, 112, "encosta N"), (160, 222, 90, "encosta N"), (230, 200, 70, "encosta N"),
    (280, 180, 55, "encosta N"),
    # Esporão norte até o farol
    (70, 300, 88, "esporão N"), (62, 360, 72, "esporão N"), (56, 420, 60, "esporão N"),
    (68, 480, 50, "promontório"), (76, 526, 48, "base do farol"), (40, 512, 40, "promontório"),
    (112, 502, 38, "promontório"), (60, 500, 48, "platô do farol"), (92, 516, 47, "platô do farol"), (52, 528, 44, "platô do farol"), (100, 492, 46, "platô do farol"),
    # Faixa litorânea norte
    (-50, 420, 20, "baixada N"), (-150, 410, 14, "baixada N"), (-205, 420, 8, "praia N"),
    (150, 432, 26, "baixada N"), (200, 420, 22, "baixada N"), (0, 420, 30, "baixada N"),
    (-60, 380, 32, "baixada N"), (-20, 340, 55, "pé da serra"), (-100, 340, 36, "pé da serra"),
    (-150, 330, 28, "pé da serra"),
    # Planície da Usina (NO)
    (-280, 300, 14, "Usina"), (-230, 280, 17, "Usina"), (-330, 340, 12, "Usina"),
    (-250, 360, 13, "Usina"), (-350, 260, 15, "Usina"), (-200, 330, 20, "Usina"),
    (-400, 300, 6, "praia NO"), (-300, 400, 6, "praia NO"), (-420, 200, 14, "baixada O"),
    (-380, 160, 25, "baixada O"), (-460, 150, 12, "baixada O"), (-200, 240, 30, "canavial"),
    # Planalto do Quartel (NE)
    (310, 300, 22, "Quartel"), (260, 280, 26, "Quartel"), (360, 330, 20, "Quartel"),
    (330, 250, 28, "Quartel"), (270, 340, 22, "Quartel"), (400, 280, 18, "Quartel"),
    (420, 340, 10, "Quartel"), (240, 240, 27, "Quartel"), (190, 300, 45, "encosta NE"), (180, 370, 32, "encosta NE"),
    (240, 392, 20, "baixada NE"),
    # Leste (entre Quartel e Pedreira)
    (400, 180, 45, "leste"), (350, 160, 70, "leste"), (440, 120, 35, "topo falésia"),
    (470, 200, 30, "topo falésia"), (470, 60, 30, "topo falésia"), (420, 80, 50, "leste"),
    (200, 20, 100, "contraforte"), (170, 60, 118, "contraforte"),
    # Falésias do leste (topo) e sudeste
    (485, -80, 28, "topo falésia"), (486, -150, 26, "topo falésia"), (480, -212, 22, "topo falésia"),
    (440, -120, 40, "planalto leste"), (400, -150, 34, "planalto leste"),
    # Pista de pouso (SE) — plataforma plana em 12 m
    (200, -340, 12, "cabeceira 08"), (270, -322, 12, "pista"), (335, -305, 12, "pista"),
    (400, -288, 12, "pista"), (470, -270, 12, "cabeceira 26"), (300, -220, 20, "pátio"),
    (380, -200, 24, "pátio"), (250, -400, 8, "restinga"), (350, -382, 8, "restinga"),
    (432, -340, 10, "restinga"), (200, -250, 22, "encosta"),
    # Morro do Sul (entre Represa e Pista)
    (60, -60, 100, "Morro do Sul"), (110, -110, 106, "Morro do Sul (topo)"), (160, -160, 90, "Morro do Sul"),
    (200, -200, 60, "Morro do Sul"), (100, -200, 70, "Morro do Sul"), (40, -150, 70, "Morro do Sul"),
    (250, -120, 75, "Morro do Sul"), (200, -60, 96, "Morro do Sul"), (150, -20, 110, "Morro do Sul"),
    # Represa (nível d'água 48 m)
    (-40, -30, 48, "espelho d'água"), (15, -30, 56, "margem L"), (-40, 30, 60, "margem N"),
    (-95, -20, 56, "margem O"), (-40, -88, 52, "margem S"), (-100, -86, 52, "crista da barragem"),
    (-136, -116, 30, "pé da barragem"),
    # Morros ao redor da Represa
    (40, 40, 92, "morro"), (-20, 82, 112, "morro"), (-100, 60, 86, "morro"), (-150, 20, 70, "morro"),
    (-10, -122, 74, "morro"), (60, -10, 96, "morro"), (-200, 40, 62, "morro"), (-180, -60, 52, "encosta"),
    (-230, -80, 44, "encosta"),
    # Vale do Rio Tauá (jusante da barragem)
    (-150, -126, 28, "vale"), (-200, -170, 22, "vale"), (-250, -210, 16, "vale"),
    (-300, -260, 10, "vale"), (-345, -305, 6, "vale"), (-420, -386, 1, "foz"),
    # Morro do Cruzeiro
    (-320, 60, 78, "topo do Morro do Cruzeiro"), (-280, 40, 66, "Morro"), (-360, 80, 62, "Morro"),
    (-330, 0, 50, "Morro"), (-300, 110, 58, "Morro"), (-380, 20, 45, "Morro"), (-260, 90, 64, "Morro"),
    (-400, 70, 40, "Morro"), (-340, -40, 34, "pé do Morro"), (-250, 0, 50, "Morro"),
    (-440, 40, 24, "baixada O"), (-470, 60, 14, "baixada O"),
    # Costa oeste
    (-430, -60, 15, "pasto O"), (-450, -150, 10, "pasto O"), (-400, -150, 22, "pasto O"),
    (-380, -230, 12, "pasto O"), (-300, -120, 30, "pasto O"),
    # Fazenda Boa Esperança
    (-110, -290, 24, "casarão"), (-60, -260, 26, "Fazenda"), (-160, -300, 20, "Fazenda"),
    (-110, -350, 18, "Fazenda"), (-50, -330, 20, "Fazenda"), (-170, -240, 24, "Fazenda"),
    (-60, -200, 36, "Fazenda"), (-200, -360, 12, "Fazenda"), (-100, -180, 40, "encosta"),
    (-150, -200, 28, "encosta"),
    # Praia dos Quiosques e sul
    (100, -470, 3, "praia"), (40, -480, 2, "praia"), (160, -476, 3, "praia"), (0, -462, 5, "praia"),
    (100, -432, 8, "restinga"), (200, -442, 6, "restinga"), (-50, -442, 8, "restinga"),
    (50, -400, 14, "sul"), (150, -390, 16, "sul"), (0, -300, 30, "sul"), (50, -250, 46, "sul"),
    (100, -320, 22, "sul"), (-20, -380, 16, "sul"), (160, -300, 18, "sul"),
    # Vila Caiçara
    (-370, -350, 4, "Vila"), (-330, -382, 4, "Vila"), (-400, -320, 5, "Vila"), (-340, -312, 7, "Vila"),
    (-300, -360, 8, "Vila"), (-425, -362, 2, "Vila"), (-280, -420, 6, "Vila"), (-250, -330, 14, "Vila"),
    (-270, -462, 10, "costão SO"), (-220, -472, 6, "praia SO"),
]

# ---------------------------------------------------------------------------
# 3. Linhas estruturais (cumeeiras, vales, falésias)
# ---------------------------------------------------------------------------
CUMEEIRAS = [
    {"nome": "Serra do Tauá", "pontos": [(-220, 120), (-160, 160), (-100, 175), (-40, 170), (20, 165), (80, 160), (130, 150), (180, 125), (230, 95), (280, 60), (330, 42)]},
    {"nome": "Esporão do Farol", "pontos": [(80, 160), (70, 300), (62, 360), (56, 420), (68, 480), (76, 526)]},
    {"nome": "Morro do Sul", "pontos": [(40, -150), (110, -110), (150, -20), (200, 20), (280, 60)]},
    {"nome": "Esporão do Cruzeiro", "pontos": [(-220, 120), (-260, 90), (-320, 60), (-380, 20)]},
]
VALES = [
    {"nome": "Vale do Rio Tauá", "pontos": [(-40, -30), (-100, -86), (-150, -126), (-200, -170), (-250, -210), (-300, -260), (-345, -305), (-420, -386)]},
    {"nome": "Vale da Usina", "pontos": [(-200, 240), (-250, 300), (-300, 380)]},
    {"nome": "Grota do Quartel", "pontos": [(230, 200), (300, 260), (400, 330)]},
    {"nome": "Vale da Pista", "pontos": [(250, -120), (300, -220), (335, -305)]},
    {"nome": "Grota da Fazenda", "pontos": [(-60, -200), (-110, -290), (-160, -380)]},
]
FALESIAS = [
    {"nome": "Falésias do Leste", "altura_topo": [22, 40], "pontos": [(482, 240), (500, 180), (490, 120), (500, 60), (505, 0), (505, -60), (508, -120), (515, -180), (515, -240)]},
    {"nome": "Costão do Farol", "altura_topo": [38, 48], "pontos": [(5, 520), (30, 548), (72, 556), (112, 535), (140, 500)]},
    {"nome": "Costão Sudoeste", "altura_topo": [6, 12], "pontos": [(-320, -456), (-272, -480), (-222, -500)]},
]

# ---------------------------------------------------------------------------
# 4. Água
# ---------------------------------------------------------------------------
RIO = {
    "nome": "Rio Tauá",
    "nota": "nasce na encosta sul do Pico, alimenta a Represa, desce pelo vale e corta a Vila Caiçara até a foz",
    "trechos": [
        {"trecho": "cabeceira", "largura_m": 3, "pontos": [(40, 95, 118), (22, 55, 90), (5, 20, 62), (-15, -5, 48)]},
        {"trecho": "jusante", "largura_m": 10, "pontos": [(-104, -90, 34), (-136, -116, 30), (-150, -126, 28), (-200, -170, 22), (-250, -210, 16), (-300, -260, 10), (-345, -305, 6), (-385, -350, 3), (-420, -386, 1), (-445, -404, 0)]},
    ],
}
REPRESA = {
    "nome": "Represa do Tauá",
    "nivel_agua_m": 48,
    "profundidade_max_m": 6,
    "contorno": [(-100, -84), (-95, -40), (-80, 0), (-50, 25), (-15, 25), (12, 5), (18, -30), (0, -65), (-35, -90), (-70, -100)],
    "barragem": {"de": (-122, -64), "ate": (-78, -108), "altura_crista_m": 52, "largura_crista_m": 6, "altura_face_m": 22},
}

# ---------------------------------------------------------------------------
# 5. Estradas e trilhas (tipo, largura) — polilinhas x,y
# ---------------------------------------------------------------------------
ESTRADAS = [
    {"id": "E1", "nome": "Estrada da Costa Sul", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(-367, -330), (-300, -335), (-230, -318), (-165, -270), (-105, -245)]},
    {"id": "E2", "nome": "Estrada dos Coqueiros", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(-105, -245), (-40, -280), (0, -395), (50, -420), (100, -425)]},
    {"id": "E3", "nome": "Estrada da Pista", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(100, -425), (170, -420), (230, -380), (270, -290), (285, -275)]},
    {"id": "E4", "nome": "Estrada do Leste", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(285, -275), (360, -258), (440, -238), (420, -150), (410, -80), (360, -60), (318, -38)]},
    {"id": "E5", "nome": "Estrada da Pedreira ao Quartel", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(318, -38), (400, -10), (430, 70), (410, 150), (360, 200), (300, 220), (240, 282)]},
    {"id": "E6", "nome": "Estrada do Farol", "tipo": "estrada_terra", "largura_m": 6,
     "pontos": [(240, 282), (200, 360), (150, 410), (100, 440), (70, 480)]},
    {"id": "E7", "nome": "Estrada do Norte", "tipo": "estrada_terra", "largura_m": 6,
     "pontos": [(70, 480), (20, 440), (-60, 405), (-150, 390), (-220, 360), (-235, 320)]},
    {"id": "E8", "nome": "Estrada da Usina ao Morro", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(-235, 320), (-300, 262), (-360, 210), (-400, 140), (-410, 60), (-385, 0), (-350, -35)]},
    {"id": "E9", "nome": "Estrada da Costa Oeste", "tipo": "estrada_terra", "largura_m": 7,
     "pontos": [(-350, -35), (-400, -80), (-430, -170), (-425, -240), (-398, -285), (-367, -330)]},
    {"id": "E10", "nome": "Estrada da Represa (crista)", "tipo": "estrada_terra", "largura_m": 6,
     "pontos": [(-350, -35), (-250, -30), (-180, -55), (-122, -64), (-78, -108), (-50, -150), (-70, -210), (-105, -245)]},
    {"id": "E11", "nome": "Subida do Pico", "tipo": "estrada_terra", "largura_m": 5,
     "pontos": [(-50, -150), (20, -100), (35, -40), (50, 30), (95, 70), (60, 105), (110, 125), (75, 138)]},
    {"id": "V1", "nome": "Rua da Vila (calçamento)", "tipo": "estrada_calcamento", "largura_m": 5,
     "pontos": [(-398, -285), (-425, -315), (-440, -335)]},
    {"id": "V2", "nome": "Acesso do Morro (escadaria + beco)", "tipo": "estrada_calcamento", "largura_m": 4,
     "pontos": [(-350, -35), (-309, -28), (-309, 2), (-321, 8), (-321, 30), (-318, 38), (-318, 54)]},
    {"id": "T1", "nome": "Trilha da Cumeeira", "tipo": "trilha", "largura_m": 2.5,
     "pontos": [(-235, 320), (-220, 250), (-220, 120), (-160, 160), (-100, 175), (-40, 170), (20, 165), (75, 138)]},
    {"id": "T2", "nome": "Trilha do Farol", "tipo": "trilha", "largura_m": 2.5,
     "pontos": [(75, 138), (60, 170), (70, 300), (62, 360), (56, 420), (70, 480)]},
    {"id": "T3", "nome": "Trilha da Serra Leste", "tipo": "trilha", "largura_m": 2.5,
     "pontos": [(75, 138), (130, 150), (180, 125), (230, 95), (280, 60), (318, -38)]},
    {"id": "T4", "nome": "Trilha do Vau", "tipo": "trilha", "largura_m": 2.5,
     "pontos": [(-350, -35), (-300, -120), (-232, -196), (-190, -240), (-165, -270)]},
    {"id": "T5", "nome": "Trilha do Morro do Sul", "tipo": "trilha", "largura_m": 2.5,
     "pontos": [(20, -100), (110, -110), (200, -200), (285, -275)]},
    {"id": "P1", "nome": "Pista de Pouso do Tauá (terra batida)", "tipo": "pista_pouso", "largura_m": 25,
     "pontos": [(200, -340), (470, -270)]},
]
PONTES = [
    {"nome": "Ponte da Vila", "tipo": "concreto", "pos": (-367, -330), "comprimento_m": 16, "largura_m": 7, "estrada": "E1/V1", "rot_deg": 312},
    {"nome": "Passarela dos Pescadores", "tipo": "madeira", "pos": (-400, -367), "comprimento_m": 14, "largura_m": 2, "estrada": "a pé", "rot_deg": 312},
    {"nome": "Crista da Barragem", "tipo": "barragem", "pos": (-100, -86), "comprimento_m": 62, "largura_m": 6, "estrada": "E10", "rot_deg": 315},
    {"nome": "Vau do Tauá", "tipo": "vau (pedras)", "pos": (-232, -196), "comprimento_m": 12, "largura_m": 3, "estrada": "T4", "rot_deg": 312},
]

# ---------------------------------------------------------------------------
# 6. Tipos de prédio (largura X, profundidade Y, altura Z em m; andares; entrável)
# ---------------------------------------------------------------------------
TIPOS = {
    "casa_caicara":        {"tam": (6, 8, 4),    "andares": 1, "entravel": True},
    "casa_laje":           {"tam": (6, 7, 3),    "andares": 1, "entravel": True, "nota": "alvenaria sem reboco, laje plana acessível por escada externa; altura = 3 m x andares"},
    "sobrado":             {"tam": (8, 10, 7),   "andares": 2, "entravel": True},
    "venda_bar":           {"tam": (7, 9, 4),    "andares": 1, "entravel": True},
    "rancho_pesca":        {"tam": (8, 12, 4),   "andares": 1, "entravel": True, "nota": "galpão aberto de canoas"},
    "capela":              {"tam": (8, 16, 9),   "andares": 1, "entravel": True},
    "caixa_dagua":         {"tam": (5, 5, 20),   "andares": 1, "entravel": False, "nota": "escada de marinheiro até o topo"},
    "cruzeiro":            {"tam": (2, 2, 8),    "andares": 0, "entravel": False},
    "casa_moenda":         {"tam": (15, 25, 10), "andares": 2, "entravel": True},
    "chamine":             {"tam": (4, 4, 40),   "andares": 0, "entravel": False},
    "armazem_acucar":      {"tam": (15, 40, 9),  "andares": 1, "entravel": True},
    "galpao":              {"tam": (20, 30, 8),  "andares": 1, "entravel": True},
    "escritorio":          {"tam": (10, 14, 7),  "andares": 2, "entravel": True},
    "vila_operaria":       {"tam": (6, 24, 4),   "andares": 1, "entravel": True, "nota": "4 casas geminadas"},
    "guarita":             {"tam": (3, 3, 8),    "andares": 2, "entravel": True},
    "tanque":              {"tam": (6, 6, 6),    "andares": 0, "entravel": False},
    "farol_torre":         {"tam": (6, 6, 22),   "andares": 5, "entravel": True, "nota": "escada helicoidal, varanda no topo"},
    "casa_faroleiro":      {"tam": (8, 10, 4),   "andares": 1, "entravel": True},
    "casa_gerador":        {"tam": (5, 6, 3),    "andares": 1, "entravel": True},
    "paiol":               {"tam": (8, 10, 3.5), "andares": 1, "entravel": True},
    "comando":             {"tam": (24, 14, 8),  "andares": 2, "entravel": True},
    "alojamento":          {"tam": (12, 30, 4),  "andares": 1, "entravel": True},
    "refeitorio":          {"tam": (20, 12, 5),  "andares": 1, "entravel": True},
    "garagem_viaturas":    {"tam": (25, 15, 6),  "andares": 1, "entravel": True},
    "heliponto":           {"tam": (20, 20, 0.3),"andares": 0, "entravel": False},
    "hangar":              {"tam": (24, 20, 8),  "andares": 1, "entravel": True},
    "torre_controle":      {"tam": (5, 5, 12),   "andares": 3, "entravel": True},
    "casa_piloto":         {"tam": (7, 9, 4),    "andares": 1, "entravel": True},
    "britador":            {"tam": (12, 15, 14), "andares": 3, "entravel": True, "nota": "estrutura metálica com passarelas"},
    "correia":             {"tam": (3, 40, 10),  "andares": 0, "entravel": False},
    "container_escritorio":{"tam": (3, 12, 3),   "andares": 1, "entravel": True},
    "casa_forca":          {"tam": (12, 18, 9),  "andares": 2, "entravel": True},
    "casa_operador":       {"tam": (7, 9, 4),    "andares": 1, "entravel": True},
    "torre_tomada":        {"tam": (5, 5, 14),   "andares": 2, "entravel": True, "nota": "tomada d'água no lago, passarela até a crista"},
    "subestacao":          {"tam": (14, 10, 6),  "andares": 0, "entravel": False},
    "casarao":             {"tam": (26, 18, 9),  "andares": 2, "entravel": True, "nota": "varanda em volta, 12 janelas por fachada"},
    "tulha":               {"tam": (8, 20, 5),   "andares": 1, "entravel": True},
    "curral":              {"tam": (20, 20, 1.5),"andares": 0, "entravel": False},
    "casa_colono":         {"tam": (6, 8, 4),    "andares": 1, "entravel": True},
    "quiosque":            {"tam": (5, 5, 3.5),  "andares": 1, "entravel": True},
    "banheiro_praia":      {"tam": (6, 4, 3),    "andares": 1, "entravel": True},
    "restaurante_praia":   {"tam": (10, 12, 7),  "andares": 2, "entravel": True},
    "posto_salvavidas":    {"tam": (3, 3, 5),    "andares": 1, "entravel": True},
    "antena":              {"tam": (4, 4, 30),   "andares": 0, "entravel": False, "nota": "treliça escalável com 2 patamares (10 m e 20 m)"},
    "casa_radio":          {"tam": (5, 6, 3),    "andares": 1, "entravel": True},
}

# Gabarito de saque interno por tipo: offsets locais (dx, dy, dz) desenhados à mão.
GABARITO_SAQUE = {
    "casa_caicara": [(-1.5, 2, 0.1), (1.5, -2, 0.1)],
    "casa_laje": [(-1.5, 1.5, 0.1), (1.5, -1.5, 0.1), (0, 0, 3.1)],  # 3.1 = sobre a laje
    "sobrado": [(-2, 3, 0.1), (2, -3, 0.1), (-2, -3, 3.6), (2, 3, 3.6)],
    "venda_bar": [(0, 3, 0.1), (-2, -2, 0.1), (2, -2, 0.1)],
    "rancho_pesca": [(-2, 4, 0.1), (2, -4, 0.1)],
    "capela": [(0, 6, 0.1), (0, -6, 0.1)],
    "casa_moenda": [(-5, 8, 0.1), (5, -8, 0.1), (-5, -8, 5.1), (5, 8, 5.1), (0, 0, 0.1)],
    "armazem_acucar": [(-5, 15, 0.1), (5, 5, 0.1), (-5, -5, 0.1), (5, -15, 0.1)],
    "galpao": [(-7, 10, 0.1), (7, -10, 0.1), (0, 0, 0.1), (7, 10, 0.1)],
    "escritorio": [(-3, 4, 0.1), (3, -4, 0.1), (-3, -4, 3.6), (3, 4, 3.6)],
    "vila_operaria": [(0, 9, 0.1), (0, 3, 0.1), (0, -3, 0.1), (0, -9, 0.1)],
    "guarita": [(0, 0, 4.1)],
    "caixa_dagua": [(0, 0, 20.1)],
    "farol_torre": [(0, 0, 0.1), (0, 0, 21.1)],
    "casa_faroleiro": [(-2, 3, 0.1), (2, -3, 0.1)],
    "casa_gerador": [(0, 0, 0.1)],
    "paiol": [(-2, 3, 0.1), (2, 0, 0.1), (-2, -3, 0.1)],
    "comando": [(-8, 3, 0.1), (8, -3, 0.1), (-8, -3, 4.1), (8, 3, 4.1), (0, 0, 4.1)],
    "alojamento": [(-3, 10, 0.1), (3, 0, 0.1), (-3, -10, 0.1)],
    "refeitorio": [(-6, 2, 0.1), (6, -2, 0.1)],
    "garagem_viaturas": [(-8, 3, 0.1), (0, -3, 0.1), (8, 3, 0.1)],
    "hangar": [(-8, 5, 0.1), (8, -5, 0.1), (0, 0, 0.1)],
    "torre_controle": [(0, 0, 0.1), (0, 0, 9.1)],
    "casa_piloto": [(-2, 2, 0.1), (2, -2, 0.1)],
    "britador": [(0, 0, 7.1), (-3, 4, 0.1)],
    "container_escritorio": [(0, 3, 0.1)],
    "casa_forca": [(-3, 6, 0.1), (3, -6, 0.1), (-3, -6, 4.6), (3, 6, 4.6)],
    "casa_operador": [(-2, 2, 0.1), (2, -2, 0.1)],
    "torre_tomada": [(0, 0, 7.1)],
    "casarao": [(-8, 5, 0.1), (8, -5, 0.1), (-8, -5, 4.6), (8, 5, 4.6), (0, 0, 0.1), (0, 0, 4.6)],
    "tulha": [(0, 6, 0.1), (0, -6, 0.1)],
    "casa_colono": [(0, 2, 0.1)],
    "quiosque": [(0, 0, 0.1)],
    "banheiro_praia": [(0, 0, 0.1)],
    "restaurante_praia": [(-3, 3, 0.1), (3, -3, 0.1), (0, 0, 3.6)],
    "posto_salvavidas": [(0, 0, 2.1)],
    "casa_radio": [(0, 0, 0.1)],
}

# ---------------------------------------------------------------------------
# 7. POIs e prédios (x, y, rot_deg, tipo, andares_opcional, tier_override)
#    rot_deg: rotação em torno de Z, anti-horária, 0 = largura alinhada ao eixo X.
# ---------------------------------------------------------------------------
def P(x, y, rot, tipo, andares=None, tier=None, nome=None):
    return {"x": x, "y": y, "rot": rot, "tipo": tipo, "andares": andares, "tier": tier, "nome": nome}

POIS = [
    {"id": "vila_caicara", "nome": "Vila Caiçara", "tema": "vila de pescadores com rio cortando a vila, ranchos de canoa, capela na praia",
     "referencia": "Trindade (Paraty-RJ); Saco do Mamanguá; vila de Itaúnas-ES",
     "centro": (-370, -350), "raio": 95, "tier": "medio", "altura_m": [1, 14],
     "predios": [
        P(-420, -330, 35, "casa_caicara"), P(-435, -300, 30, "casa_caicara"), P(-415, -285, 30, "venda_bar", nome="Bar do Tião"),
        P(-378, -282, 35, "casa_laje", 2), P(-445, -350, 40, "rancho_pesca"), P(-458, -272, 20, "casa_caicara"),
        P(-345, -372, 35, "capela", nome="Capela de São Pedro"), P(-325, -352, 35, "sobrado"), P(-312, -382, 30, "casa_caicara"),
        P(-342, -420, 40, "rancho_pesca"), P(-298, -352, 30, "casa_laje", 1), P(-288, -404, 25, "casa_caicara"),
        P(-318, -306, 35, "sobrado", nome="Pousada"), P(-268, -370, 20, "casa_caicara"), P(-378, -408, 40, "casa_caicara"),
        P(-440, -250, 25, "casa_laje", 2),
     ],
     "saque_externo": [(-395, -385, 1), (-430, -375, 1), (-360, -440, 1), (-300, -330, 7)]},
    {"id": "morro_cruzeiro", "nome": "Morro do Cruzeiro", "tema": "comunidade em encosta: casas de alvenaria com laje, becos e escadarias, cruzeiro no topo",
     "referencia": "Morro da Providência e Rocinha (Rio de Janeiro-RJ)",
     "centro": (-320, 45), "raio": 85, "tier": "medio", "altura_m": [40, 80],
     "predios": [
        P(-362, -8, 10, "casa_laje", 2), P(-342, -14, 5, "casa_laje", 1), P(-320, -12, 0, "casa_laje", 2), P(-298, -5, 350, "casa_laje", 3),
        P(-278, 6, 340, "casa_laje", 2), P(-260, 24, 330, "casa_laje", 1),
        P(-372, 16, 15, "casa_laje", 2), P(-352, 14, 10, "casa_laje", 3), P(-332, 16, 5, "casa_laje", 2), P(-310, 20, 355, "casa_laje", 1),
        P(-290, 30, 345, "casa_laje", 2), P(-274, 48, 330, "casa_laje", 3), P(-266, 72, 310, "casa_laje", 2),
        P(-356, 42, 15, "casa_laje", 1), P(-336, 40, 10, "casa_laje", 2), P(-300, 44, 350, "casa_laje", 2), P(-286, 66, 330, "casa_laje", 1),
        P(-282, 92, 300, "casa_laje", 2), P(-346, 86, 30, "casa_laje", 1), P(-386, 50, 20, "casa_laje", 2), P(-380, 80, 30, "casa_laje", 1),
        P(-305, 80, 340, "venda_bar", nome="Bar da Laje"),
        P(-320, 62, 0, "cruzeiro", nome="Cruzeiro"), P(-340, 68, 0, "caixa_dagua"),
     ],
     "saque_externo": [(-330, 30, 55), (-295, 12, 50), (-320, 50, 70)]},
    {"id": "usina_santa_cruz", "nome": "Usina Santa Cruz", "tema": "engenho/usina de açúcar desativada com chaminé de tijolo, armazém, vila operária e canaviais",
     "referencia": "Engenho Central de Piracicaba-SP; Usina Trapiche (Sirinhaém-PE); Museu da Cana (Pontal-SP)",
     "centro": (-280, 305), "raio": 95, "tier": "alto", "altura_m": [12, 20],
     "predios": [
        P(-290, 310, 20, "casa_moenda", nome="Casa da Moenda"), P(-266, 330, 0, "chamine", nome="Chaminé (40 m)"),
        P(-238, 286, 20, "armazem_acucar", nome="Armazém de Açúcar"), P(-322, 278, 20, "galpao", nome="Destilaria"),
        P(-302, 348, 0, "caixa_dagua"), P(-248, 342, 20, "escritorio", nome="Escritório da Usina"),
        P(-345, 328, 20, "vila_operaria"), P(-357, 352, 20, "vila_operaria"), P(-325, 372, 20, "vila_operaria"),
        P(-222, 252, 20, "guarita", nome="Balança"), P(-212, 305, 0, "tanque"),
     ],
     "saque_externo": [(-270, 300, 14), (-300, 295, 14), (-260, 270, 15)]},
    {"id": "farol_ponta_norte", "nome": "Farol da Ponta Norte", "tema": "farol listrado sobre o costão, casa do faroleiro",
     "referencia": "Farol de Santa Marta (Laguna-SC); Farol de Abrolhos (BA)",
     "centro": (70, 505), "raio": 55, "tier": "medio", "altura_m": [44, 56],
     "predios": [
        P(74, 512, 0, "farol_torre", nome="Farol"), P(48, 500, 10, "casa_faroleiro"), P(96, 506, 10, "casa_gerador"),
        P(34, 480, 10, "paiol", nome="Depósito"),
     ],
     "saque_externo": [(66, 522, 46), (85, 490, 48)]},
    {"id": "quartel", "nome": "Quartel do 7º BIL", "tema": "batalhão de infantaria leve: pátio de formatura, alojamentos, paiol, muro com guaritas",
     "referencia": "Quartel do Exército em Bela Vista; quartel do Bacacheri (Curitiba-PR)",
     "centro": (315, 300), "raio": 100, "tier": "alto", "altura_m": [18, 28],
     "predios": [
        P(312, 345, 0, "comando", nome="Comando"), P(265, 300, 90, "alojamento", nome="Alojamento A"),
        P(360, 300, 90, "alojamento", nome="Alojamento B"), P(312, 255, 0, "refeitorio"),
        P(380, 250, 0, "garagem_viaturas"), P(250, 245, 0, "paiol", tier="alto", nome="Paiol"),
        P(228, 285, 0, "guarita", nome="Portão"), P(402, 365, 0, "guarita"), P(236, 228, 0, "guarita"),
        P(392, 335, 0, "heliponto"), P(252, 360, 0, "caixa_dagua"),
     ],
     "muro": [(222, 222), (410, 222), (410, 376), (222, 376)],
     "saque_externo": [(312, 300, 22), (330, 290, 22), (395, 335, 20)]},
    {"id": "pedreira", "nome": "Pedreira São Jorge", "tema": "cava de granito em degraus, britador, correia transportadora",
     "referencia": "Pedreira do Morro Santana (Porto Alegre-RS); pedreiras de Santo Antônio da Patrulha-RS",
     "centro": (335, 5), "raio": 80, "tier": "medio", "altura_m": [58, 100],
     "predios": [
        P(368, 42, 30, "britador"), P(348, 22, 30, "correia"), P(300, -46, 15, "container_escritorio"),
        P(318, -52, 15, "container_escritorio"), P(384, -40, 15, "galpao", nome="Oficina de Máquinas"),
        P(272, 20, 0, "paiol", tier="alto", nome="Paiol de Explosivos"),
     ],
     "saque_externo": [(330, 0, 58), (352, -12, 58), (300, 12, 62)]},
    {"id": "pista_pouso", "nome": "Pista do Tauá", "tema": "pista de pouso de terra com hangar, biruta e torre de madeira",
     "referencia": "Aeródromo do Aeroclube de Birigui-SP; pistas de terra do interior",
     "centro": (330, -285), "raio": 150, "tier": "medio", "altura_m": [10, 24],
     "predios": [
        P(300, -237, 15, "hangar"), P(345, -228, 15, "torre_controle"), P(268, -225, 15, "casa_piloto"),
        P(382, -221, 15, "tanque"), P(412, -215, 15, "galpao", nome="Depósito de Carga"),
     ],
     "saque_externo": [(360, -300, 12), (240, -330, 12), (440, -278, 12)]},
    {"id": "represa", "nome": "Represa do Tauá", "tema": "barragem de concreto com crista transitável, casa de força e tomada d'água",
     "referencia": "Represa Usina de Atibaia-SP; vertedouro da Barragem de Santa Maria (Brasília-DF)",
     "centro": (-85, -70), "raio": 80, "tier": "alto", "altura_m": [30, 60],
     "predios": [
        P(-100, -128, 45, "casa_forca", nome="Casa de Força"), P(-58, -122, 45, "casa_operador"),
        P(-150, -92, 45, "subestacao"), P(-88, -78, 0, "torre_tomada", nome="Tomada d'Água"),
        P(-30, 42, 20, "casa_caicara", nome="Casa do Caseiro"),
     ],
     "saque_externo": [(-100, -86, 52), (-122, -64, 52), (-78, -108, 52)]},
    {"id": "fazenda_boa_esperanca", "nome": "Fazenda Boa Esperança", "tema": "casarão colonial com varanda, capela, tulha, terreiro e curral",
     "referencia": "Fazenda Jambeiro (Casa Branca-SP); Fazenda Ponte Alta (Barra do Piraí-RJ); casarão de Mangaraí-ES",
     "centro": (-110, -295), "raio": 90, "tier": "medio", "altura_m": [16, 28],
     "predios": [
        P(-110, -285, 0, "casarao", nome="Casarão"), P(-150, -235, 0, "capela"), P(-68, -302, 90, "tulha"),
        P(-60, -342, 0, "curral"), P(-172, -320, 10, "casa_colono"), P(-162, -346, 10, "casa_colono"),
        P(-146, -372, 10, "casa_colono"), P(-60, -258, 0, "paiol"),
     ],
     "terreiro": [(-125, -310), (-85, -310), (-85, -335), (-125, -335)],
     "saque_externo": [(-105, -322, 20), (-130, -270, 24)]},
    {"id": "praia_quiosques", "nome": "Praia dos Quiosques", "tema": "orla com quiosques de sapê, restaurante de dois andares, posto salva-vidas",
     "referencia": "Praia de Tambaú (João Pessoa-PB); Canoa Quebrada (Aracati-CE)",
     "centro": (100, -465), "raio": 75, "tier": "baixo", "altura_m": [2, 10],
     "predios": [
        P(30, -482, 0, "quiosque"), P(65, -484, 0, "quiosque"), P(100, -484, 0, "quiosque"), P(135, -484, 0, "quiosque"),
        P(170, -482, 0, "quiosque"), P(100, -446, 0, "banheiro_praia"), P(58, -442, 0, "restaurante_praia", nome="Restaurante Maré Alta"),
        P(150, -500, 0, "posto_salvavidas"),
     ],
     "saque_externo": [(15, -445, 6), (120, -500, 2), (180, -455, 5)]},
]

MARCOS = [
    {"id": "pico_taua", "nome": "Pico do Tauá", "tema": "cume com antena de rádio (marco de orientação; saque baixo)",
     "centro": (82, 158), "raio": 30, "tier": "baixo", "altura_m": [170, 178],
     "predios": [P(80, 160, 0, "antena", nome="Antena"), P(92, 150, 20, "casa_radio")],
     "saque_externo": [(75, 165, 178)]},
]

# ---------------------------------------------------------------------------
# 8. Vegetação — manchas autorais (polígonos)
# ---------------------------------------------------------------------------
VEGETACAO = [
    {"nome": "Mata da Serra", "tipo": "mata_atlantica_densa", "cobertura": "bloqueia visão, árvores 15–20 m, sub-bosque",
     "poligono": [(-200, 150), (-140, 200), (-60, 215), (20, 212), (60, 200), (58, 176), (30, 140), (-20, 125), (-90, 120), (-160, 115)]},
    {"nome": "Mata da Serra Leste", "tipo": "mata_atlantica_densa", "cobertura": "bloqueia visão",
     "poligono": [(108, 188), (170, 180), (240, 140), (290, 95), (285, 70), (240, 80), (180, 100), (120, 130)]},
    {"nome": "Mata do Esporão Norte", "tipo": "mata_atlantica_media", "cobertura": "árvores esparsas 10–15 m",
     "poligono": [(30, 240), (110, 240), (100, 330), (90, 410), (40, 410), (35, 320)]},
    {"nome": "Mata do Morro do Sul", "tipo": "mata_atlantica_densa", "cobertura": "bloqueia visão",
     "poligono": [(30, -120), (80, -70), (160, -40), (220, -80), (230, -150), (180, -200), (100, -190), (50, -170)]},
    {"nome": "Capoeira do Cruzeiro", "tipo": "capoeira", "cobertura": "arbustos 2–4 m, esconde agachado",
     "poligono": [(-420, 100), (-360, 120), (-290, 130), (-240, 110), (-250, 150), (-330, 170), (-410, 150)]},
    {"nome": "Mata Ciliar do Tauá", "tipo": "mata_ciliar", "cobertura": "faixa de 20 m ao longo do rio",
     "poligono": [(-140, -105), (-200, -155), (-255, -195), (-300, -245), (-320, -270), (-290, -275), (-245, -225), (-195, -185), (-140, -135)]},
    {"nome": "Mata da Represa Norte", "tipo": "mata_atlantica_media", "cobertura": "árvores esparsas",
     "poligono": [(-120, 10), (-60, 60), (20, 60), (50, 20), (20, 40), (-60, 35), (-100, 0)]},
    {"nome": "Canavial Norte", "tipo": "canavial", "cobertura": "cana 2,5 m: oculta de pé, não para tiros",
     "poligono": [(-230, 380), (-160, 380), (-150, 330), (-220, 330)]},
    {"nome": "Canavial Sul", "tipo": "canavial", "cobertura": "cana 2,5 m",
     "poligono": [(-230, 240), (-170, 250), (-160, 190), (-240, 200)]},
    {"nome": "Canavial Oeste", "tipo": "canavial", "cobertura": "cana 2,5 m",
     "poligono": [(-420, 280), (-380, 300), (-370, 240), (-410, 225)]},
    {"nome": "Bananal da Vila", "tipo": "bananal", "cobertura": "folhagem 4 m, visão curta",
     "poligono": [(-300, -290), (-250, -300), (-240, -350), (-270, -345), (-295, -320)]},
    {"nome": "Manguezal da Foz", "tipo": "manguezal", "cobertura": "raízes, água rasa, lento",
     "poligono": [(-450, -392), (-430, -388), (-418, -400), (-432, -406)]},
    {"nome": "Coqueiral da Orla", "tipo": "coqueiral", "cobertura": "troncos finos, visão aberta",
     "poligono": [(-40, -460), (220, -468), (215, -440), (-40, -430)]},
    {"nome": "Restinga Sul", "tipo": "restinga", "cobertura": "arbusto baixo 0,5–1,5 m",
     "poligono": [(-220, -480), (-40, -455), (-40, -425), (-200, -440)]},
    {"nome": "Restinga da Pista", "tipo": "restinga", "cobertura": "arbusto baixo",
     "poligono": [(230, -470), (420, -400), (440, -360), (240, -410)]},
    {"nome": "Quebra-vento de Eucalipto", "tipo": "eucalipto_linha", "cobertura": "fila de troncos a cada 4 m",
     "poligono": [(210, -222), (440, -170), (442, -162), (212, -214)]},
    {"nome": "Pasto da Fazenda", "tipo": "pasto_aberto", "cobertura": "ABERTO — usar cobertura pontual",
     "poligono": [(-230, -240), (-40, -180), (0, -260), (-20, -380), (-200, -400)]},
    {"nome": "Pasto Oeste", "tipo": "pasto_aberto", "cobertura": "ABERTO",
     "poligono": [(-470, -60), (-360, -60), (-330, -200), (-460, -220)]},
    {"nome": "Campo do Quartel", "tipo": "pasto_aberto", "cobertura": "ABERTO, capim roçado",
     "poligono": [(180, 200), (430, 200), (430, 330), (400, 385), (180, 400)]},
]

# ---------------------------------------------------------------------------
# 9. Cobertura em campo aberto (autoral)
# ---------------------------------------------------------------------------
COBERTURA = [
    # Pasto da Fazenda (entre Represa e Fazenda) — cupinzeiros, matacões, cocho
    (-150, -180, "matacao", 2.5), (-120, -200, "cupinzeiro", 1.2), (-80, -170, "matacao", 3.0), (-60, -230, "cocho", 1.0),
    (-180, -220, "cupinzeiro", 1.2), (-40, -290, "matacao", 2.0), (-200, -270, "muro_pedra_seca_10m", 1.2),
    (-30, -350, "cupinzeiro", 1.2), (-190, -390, "tronco_caido", 0.8),
    # Pasto Oeste (Morro <-> Vila)
    (-420, -100, "matacao", 2.5), (-380, -140, "cupinzeiro", 1.2), (-440, -190, "carcaca_fusca", 1.4),
    (-360, -190, "fardo_feno_x3", 1.5), (-400, -60, "muro_pedra_seca_10m", 1.2),
    # Pista de pouso (runway totalmente aberta — só isso e o eucalipto)
    (240, -300, "tambor_x4", 1.1), (300, -315, "carcaca_teco_teco", 2.2), (360, -300, "carcaca_teco_teco", 2.2),
    (420, -300, "tambor_x4", 1.1), (330, -330, "biruta_base_concreto", 1.0), (450, -250, "pilha_pneus", 1.2),
    # Campo do Quartel (fora do muro)
    (200, 250, "sacos_areia", 1.2), (200, 330, "trincheira", 1.0), (430, 250, "sacos_areia", 1.2),
    (300, 200, "caminhao_abandonado", 3.0), (180, 300, "matacao", 2.5),
    # Planície da Usina / canaviais
    (-200, 290, "carreta_cana", 3.0), (-380, 330, "carreta_cana", 3.0), (-160, 360, "trator", 2.5),
    # Crista da barragem e margens (travessia crítica)
    (-118, -66, "mureta_concreto", 1.0), (-100, -86, "mureta_concreto", 1.0), (-82, -104, "mureta_concreto", 1.0),
    (-160, -60, "matacao", 2.5), (-40, -140, "matacao", 2.5),
    # Cume do Pico
    (60, 150, "matacao", 2.0), (100, 170, "matacao", 2.0), (70, 175, "matacao", 1.5),
    # Baixada Norte
    (-100, 420, "barco_encalhado", 2.0), (0, 440, "matacao", 2.5), (150, 440, "matacao", 2.0),
    # Sul
    (0, -250, "matacao", 2.5), (60, -300, "cupinzeiro", 1.2), (160, -340, "tronco_caido", 0.8),
]

# ---------------------------------------------------------------------------
# 10. Zona (gás) e avião
# ---------------------------------------------------------------------------
ZONA = {
    "nota": "centro de cada fase sorteado APENAS entre candidatos autorais dentro do círculo anterior; dano em HP/s",
    "fases": [
        {"fase": 0, "raio_m": 640, "espera_s": 0,   "fechamento_s": 0,  "dano_hp_s": 0,  "descricao": "ilha inteira; voo + saque"},
        {"fase": 1, "raio_m": 400, "espera_s": 120, "fechamento_s": 60, "dano_hp_s": 1},
        {"fase": 2, "raio_m": 260, "espera_s": 90,  "fechamento_s": 50, "dano_hp_s": 2},
        {"fase": 3, "raio_m": 160, "espera_s": 75,  "fechamento_s": 40, "dano_hp_s": 4},
        {"fase": 4, "raio_m": 90,  "espera_s": 60,  "fechamento_s": 30, "dano_hp_s": 6},
        {"fase": 5, "raio_m": 45,  "espera_s": 45,  "fechamento_s": 25, "dano_hp_s": 8},
        {"fase": 6, "raio_m": 15,  "espera_s": 30,  "fechamento_s": 25, "dano_hp_s": 10},
        {"fase": 7, "raio_m": 0,   "espera_s": 30,  "fechamento_s": 30, "dano_hp_s": 15},
    ],
    "tempo_voo_s": 60,
    "finais_candidatos": [
        {"nome": "Terreiro da Fazenda", "pos": (-105, -305)}, {"nome": "Beco do Morro", "pos": (-315, 20)},
        {"nome": "Pátio da Usina", "pos": (-275, 300)}, {"nome": "Pátio do Quartel", "pos": (312, 300)},
        {"nome": "Cava da Pedreira", "pos": (335, 0)}, {"nome": "Hangar da Pista", "pos": (305, -262)},
        {"nome": "Casa de Força", "pos": (-140, -125)}, {"nome": "Capela da Vila", "pos": (-345, -360)},
        {"nome": "Margem Norte da Represa", "pos": (-40, 45)}, {"nome": "Mata do Morro do Sul", "pos": (120, -120)},
        {"nome": "Pé da Serra Norte", "pos": (-100, 330)}, {"nome": "Baixada do Farol", "pos": (60, 430)},
        {"nome": "Pasto Oeste (matacões)", "pos": (-410, -110)}, {"nome": "Restaurante da Praia", "pos": (60, -445)},
    ],
}
AVIAO = {
    "altitude_m": 300, "velocidade_m_s": 45, "salto_liberado_apos_s": 3, "salto_forcado_no_fim": True,
    "nota": "uma das 4 rotas autorais por partida (sorteio entre 4, sentido pode inverter = 8 variações)",
    "rotas": [
        {"id": "R1", "nome": "Sudoeste -> Nordeste", "de": (-760, -640), "ate": (760, 700)},
        {"id": "R2", "nome": "Oeste -> Leste (norte)", "de": (-800, 200), "ate": (800, 60)},
        {"id": "R3", "nome": "Sul -> Norte", "de": (-60, -800), "ate": (160, 800)},
        {"id": "R4", "nome": "Noroeste -> Sudeste", "de": (-720, 700), "ate": (760, -620)},
    ],
}

# ---------------------------------------------------------------------------
# Montagem do JSON
# ---------------------------------------------------------------------------
TIER_POR_TIPO = {"paiol": "alto", "comando": "alto", "casa_forca": "alto", "britador": "medio"}

def montar_poi(p, idx_saque):
    predios, saque = [], []
    for i, b in enumerate(p["predios"]):
        t = TIPOS[b["tipo"]]
        w, d, h = t["tam"]
        andares = b["andares"] or t["andares"]
        if b["tipo"] == "casa_laje":
            h = 3 * andares
        pid = f'{p["id"]}_{i+1:02d}'
        predios.append({"id": pid, "tipo": b["tipo"], "nome": b["nome"], "pos": [b["x"], b["y"]], "rot_deg": b["rot"],
                        "tamanho_m": [w, d, h], "andares": andares, "entravel": t["entravel"]})
        tier = b["tier"] or TIER_POR_TIPO.get(b["tipo"]) or p["tier"]
        r = math.radians(b["rot"])
        for (dx, dy, dz) in GABARITO_SAQUE.get(b["tipo"], []):
            # andares extras de casa_laje: laje sobe junto
            if b["tipo"] == "casa_laje" and dz > 3:
                dz = 3 * andares + 0.1
            x = b["x"] + dx * math.cos(r) - dy * math.sin(r)
            y = b["y"] + dx * math.sin(r) + dy * math.cos(r)
            idx_saque[0] += 1
            saque.append({"id": f"L{idx_saque[0]:04d}", "pos": [round(x, 1), round(y, 1)], "dz_sobre_piso_m": dz,
                          "tier": tier, "origem": pid})
    for (x, y, z) in p.get("saque_externo", []):
        idx_saque[0] += 1
        saque.append({"id": f"L{idx_saque[0]:04d}", "pos": [x, y], "z_abs_m": z, "tier": p["tier"], "origem": "externo"})
    out = {k: p[k] for k in ("id", "nome", "tema", "centro", "raio", "tier", "altura_m") if k in p}
    out["referencia"] = p.get("referencia", "")
    out["raio_m"] = out.pop("raio")
    out["centro"] = list(out["centro"])
    out["n_predios"] = len(predios)
    out["predios"] = predios
    for k in ("muro", "terreiro"):
        if k in p:
            out[k] = [list(v) for v in p[k]]
    out["saque"] = saque
    return out

def main():
    idx = [0]
    pois = [montar_poi(p, idx) for p in POIS]
    marcos = [montar_poi(p, idx) for p in MARCOS]
    doc = {
        "nome": "Ilha do Tauá",
        "versao": 1,
        "unidades": "metros",
        "sistema": {"origem": "centro do mapa", "x": "leste", "y": "norte", "z": "altura acima do nível do mar",
                    "rot_deg": "rotação em Z, anti-horária a partir do eixo X"},
        "limites_mapa": {"xmin": -600, "xmax": 600, "ymin": -600, "ymax": 600},
        "costa": [list(p) for p in COSTA],
        "terreno": {
            "interpolacao": "thin-plate spline (scipy RBFInterpolator, smoothing=0) sobre pontos_altura + costa amostrada a cada 20 m com z=0; resultado limitado a [0, 185]; fora da costa = mar (-8 m a 60 m da costa)",
            "pontos_altura": [{"x": x, "y": y, "z": z, "rotulo": r} for (x, y, z, r) in ALTURAS],
            "cumeeiras": [{"nome": c["nome"], "pontos": [list(p) for p in c["pontos"]]} for c in CUMEEIRAS],
            "vales": [{"nome": c["nome"], "pontos": [list(p) for p in c["pontos"]]} for c in VALES],
            "falesias": [{"nome": c["nome"], "altura_topo_m": c["altura_topo"], "pontos": [list(p) for p in c["pontos"]]} for c in FALESIAS],
        },
        "agua": {
            "rio": {"nome": RIO["nome"], "nota": RIO["nota"],
                    "trechos": [{"trecho": t["trecho"], "largura_m": t["largura_m"], "pontos": [list(p) for p in t["pontos"]]} for t in RIO["trechos"]]},
            "represa": {**{k: v for k, v in REPRESA.items() if k not in ("contorno", "barragem")},
                        "contorno": [list(p) for p in REPRESA["contorno"]],
                        "barragem": {**REPRESA["barragem"], "de": list(REPRESA["barragem"]["de"]), "ate": list(REPRESA["barragem"]["ate"])}},
        },
        "estradas": [{**{k: v for k, v in e.items() if k != "pontos"}, "pontos": [list(p) for p in e["pontos"]]} for e in ESTRADAS],
        "pontes": [{**b, "pos": list(b["pos"])} for b in PONTES],
        "tipos_predio": {k: {**v, "tam": list(v["tam"])} for k, v in TIPOS.items()},
        "pois": pois,
        "marcos": marcos,
        "vegetacao": [{**{k: v for k, v in m.items() if k != "poligono"}, "poligono": [list(p) for p in m["poligono"]]} for m in VEGETACAO],
        "cobertura_campo_aberto": [{"pos": [x, y], "tipo": t, "altura_m": h} for (x, y, t, h) in COBERTURA],
        "zona": {**ZONA, "finais_candidatos": [{"nome": f["nome"], "pos": list(f["pos"])} for f in ZONA["finais_candidatos"]]},
        "aviao": {**AVIAO, "rotas": [{**r, "de": list(r["de"]), "ate": list(r["ate"])} for r in AVIAO["rotas"]]},
    }
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    n_saque = sum(len(p["saque"]) for p in pois + marcos)
    n_pred = sum(p["n_predios"] for p in pois + marcos)
    print(f"gravado {SAIDA}: {len(COSTA)} pts costa, {len(ALTURAS)} pts altura, {len(pois)} POIs, {n_pred} prédios, {n_saque} pontos de saque")

if __name__ == "__main__":
    main()
