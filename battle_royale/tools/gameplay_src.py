# -*- coding: utf-8 -*-
"""
Gameplay da Ilha do Tauá (CRITICA_MAPA_01 itens 9 e 10; NOITE_PLANO item 21)
  -> docs/design/gameplay_01.json  +  raw/cobertura_mapa.png (antes) e raw/cobertura_mapa_depois.png

1. Análise de cobertura: grade de 5 m sobre a terra; em cada ponto ABERTO calcula a distância até a cobertura mais
   próxima. Cobertura "agachado" (>= ~1 m): prédios, coberturas_campo_aberto (altura >= 0,8 m), muros, cerca de madeira,
   props sólidos (tambor, barril, pilha de tijolo, canoa emborcada), troncos de árvore (mata A/B, coqueiro) e as coberturas
   novas. Cobertura "em pé" (>= 1,8 m): prédios, muro alto, árvores, coberturas com altura >= 1,8 m.
   Não-aberto: dentro de prédio, água, canavial (ocultação de 2,6 m) e mata densa (>= 3 troncos a 10 m).
2. Coberturas novas: posições ESCRITAS À MÃO (COBERTURAS_NOVAS), com coerência de lugar.
3. Marcos verticais >= 18 m por POI (existentes + propostos à mão).
4. Mirante do Pico com loot.
Tudo determinístico; nenhuma posição sorteada.
Uso:  python tools/gameplay_src.py
"""
import json, math, os, sys
from collections import Counter
import numpy as np
from scipy.spatial import cKDTree
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detalhes_src as D

RAIZ = D.RAIZ
SAIDA = os.path.join(RAIZ, "docs", "design", "gameplay_01.json")
RADAR = os.path.join(RAIZ, "docs", "design", "ilha_radar.png")
DET = os.path.join(RAIZ, "docs", "design", "detalhes.json")
RAW = os.path.join(RAIZ, "raw")

ALTURA_COB = {"matacao": 2.5, "cupinzeiro": 1.2, "mureta_concreto": 1.0, "muro_pedra_seca_10m": 1.2, "tronco_caido": 0.8,
              "sacos_areia": 1.2, "fardo_feno_x3": 1.5, "tambor_x4": 1.1, "pilha_pneus": 1.2, "cocho": 1.0,
              "carcaca_fusca": 1.4, "trator": 2.5, "carreta_cana": 3.0, "trincheira": 1.0}
# comprimento aproximado (ao longo do X local) para amostrar a cobertura como segmento
COMPR_COB = {"muro_pedra_seca_10m": 10, "mureta_concreto": 3, "sacos_areia": 3, "fardo_feno_x3": 4, "tronco_caido": 5,
             "carcaca_fusca": 4, "trator": 4, "carreta_cana": 7, "trincheira": 8, "cocho": 3, "tambor_x4": 2, "pilha_pneus": 2}
PROPS_SOLIDOS = {"tambor", "barril", "pilha_tijolo", "canoa_praia", "portao_ferro"}

# ===========================================================================
# COBERTURAS NOVAS (x, y, tipo, rot_deg) — escritas à mão, por zona
# ===========================================================================
COBERTURAS_NOVAS = [
    # --- Baixada oeste / Pasto Oeste / encosta oeste do Morro (matacões na costa, cupinzeiros e fenos no pasto)
    (-400, 345, "matacao", 20), (-432, 296, "fardo_feno_x3", 30), (-455, 262, "matacao", 0), (-440, 250, "cupinzeiro", 0),
    (-475, 215, "matacao", 45), (-440, 205, "tronco_caido", 60), (-400, 205, "cupinzeiro", 0), (-320, 212, "cupinzeiro", 0),
    (-300, 215, "matacao", 0), (-260, 215, "tronco_caido", 90),
    (-470, 175, "matacao", 0), (-432, 172, "cupinzeiro", 0), (-390, 185, "fardo_feno_x3", 60), (-340, 180, "matacao", 0),
    (-300, 180, "tronco_caido", 30), (-250, 178, "matacao", 0), (-205, 185, "cupinzeiro", 0),
    (-490, 140, "matacao", 0), (-455, 130, "cupinzeiro", 0), (-425, 150, "tronco_caido", 20), (-280, 160, "matacao", 0), (-235, 140, "matacao", 0),
    (-495, 100, "matacao", 0), (-460, 95, "cupinzeiro", 0), (-430, 110, "tronco_caido", 20), (-318, 108, "matacao", 0),
    (-200, 95, "matacao", 0), (-225, 90, "tronco_caido", 45),
    (-505, 55, "matacao", 0), (-470, 60, "matacao", 30), (-440, 50, "cupinzeiro", 0), (-200, 60, "matacao", 0), (-160, 70, "tronco_caido", 120),
    (-505, 15, "matacao", 0), (-470, 20, "cupinzeiro", 0), (-435, 25, "matacao", 0), (-230, 30, "matacao", 0), (-190, 20, "matacao", 0),
    (-150, 35, "tronco_caido", 0),
    (-500, -25, "matacao", 0), (-465, -20, "cupinzeiro", 0), (-420, -15, "fardo_feno_x3", 20), (-270, -10, "matacao", 0),
    (-230, -5, "tronco_caido", 90), (-190, -15, "matacao", 0), (-150, -20, "matacao", 0), (-110, -25, "matacao", 0),
    (-490, -65, "matacao", 0), (-455, -55, "cupinzeiro", 0), (-340, -65, "matacao", 0), (-300, -60, "tronco_caido", 0),
    (-260, -55, "matacao", 0), (-220, -60, "cupinzeiro", 0), (-185, -80, "matacao", 0),
    (-490, -105, "matacao", 0), (-455, -100, "fardo_feno_x3", 80), (-385, -110, "cupinzeiro", 0), (-330, -100, "matacao", 0),
    (-290, -95, "fardo_feno_x3", 40), (-250, -100, "matacao", 0), (-210, -100, "tronco_caido", 45),
    (-470, -145, "matacao", 0), (-440, -140, "cupinzeiro", 0), (-350, -140, "fardo_feno_x3", 0), (-310, -150, "cupinzeiro", 0),
    (-270, -135, "matacao", 0), (-230, -140, "matacao", 0),
    (-470, -185, "matacao", 0), (-400, -185, "cupinzeiro", 0), (-320, -180, "matacao", 0), (-280, -175, "tronco_caido", 45),
    (-470, -225, "matacao", 0), (-400, -225, "fardo_feno_x3", 90), (-360, -230, "cupinzeiro", 0), (-330, -215, "matacao", 0),
    (-215, -240, "cupinzeiro", 0), (-110, -220, "fardo_feno_x3", 0), (-470, -245, "matacao", 0),
    (-470, -290, "matacao", 0), (-478, -330, "tronco_caido", 20), (-475, -310, "matacao", 0), (-470, -345, "tronco_caido", 70),
    # --- Vila Caiçara (beira do rio e ponte)
    (-385, -330, "mureta_concreto", 50), (-360, -345, "mureta_concreto", 50), (-378, -375, "tambor_x4", 0), (-400, -352, "tambor_x4", 0),
    # --- Fazenda e pastos do sul
    (-240, -300, "fardo_feno_x3", 30), (-260, -345, "cupinzeiro", 0), (-230, -370, "fardo_feno_x3", 60), (-215, -330, "cupinzeiro", 0),
    (-120, -360, "fardo_feno_x3", 0), (-105, -385, "cocho", 0), (-250, -250, "cupinzeiro", 0), (-230, -230, "matacao", 0),
    (-20, -262, "fardo_feno_x3", 70), (-44, -312, "cocho", 80), (-170, -245, "fardo_feno_x3", 0), (-155, -285, "cocho", 20),
    (-120, -235, "cupinzeiro", 0),
    # --- Praias e restinga do sudoeste
    (-250, -420, "matacao", 0), (-215, -445, "tronco_caido", 0), (-260, -470, "matacao", 0), (-175, -470, "tronco_caido", 15),
    (-130, -440, "matacao", 0), (-95, -475, "tronco_caido", 0), (-60, -450, "matacao", 0), (-45, -495, "matacao", 0),
    (-140, -495, "matacao", 0), (-210, -490, "matacao", 0), (-170, -420, "cupinzeiro", 0), (-100, -410, "fardo_feno_x3", 0),
    (-60, -420, "cupinzeiro", 0), (-20, -440, "matacao", 0), (25, -512, "tronco_caido", 0),
    # --- Sul (entre Fazenda, Praia e Pista)
    (-20, -380, "cupinzeiro", 0), (30, -370, "fardo_feno_x3", 20), (70, -395, "matacao", 0), (110, -390, "cupinzeiro", 0),
    (150, -395, "tronco_caido", 0), (190, -380, "matacao", 0), (240, -405, "matacao", 0), (280, -420, "tronco_caido", 20),
    (320, -400, "matacao", 0), (360, -420, "tronco_caido", 30), (400, -395, "matacao", 0), (440, -370, "matacao", 0),
    (330, -440, "matacao", 0), (270, -460, "tronco_caido", 0), (230, -470, "matacao", 0), (300, -450, "tronco_caido", 20),
    (118, -452, "tronco_caido", 0),
    (60, -340, "cupinzeiro", 0), (100, -360, "fardo_feno_x3", 0), (20, -330, "matacao", 0), (140, -360, "tronco_caido", 0),
    (175, -355, "pilha_pneus", 0), (100, -285, "cupinzeiro", 0), (140, -270, "matacao", 0), (180, -280, "tronco_caido", 0),
    (20, -275, "cupinzeiro", 0), (120, -235, "matacao", 0), (160, -255, "matacao", 0), (200, -250, "matacao", 0), (240, -270, "tronco_caido", 0),
    # --- Pista de pouso (ao longo da pista, fora da faixa de 25 m)
    (270, -370, "tambor_x4", 15), (330, -355, "pilha_pneus", 0), (390, -340, "tambor_x4", 15), (450, -320, "matacao", 0),
    (256, -344, "tambor_x4", 15), (301.3, -332.3, "pilha_pneus", 0), (359.4, -317.2, "tambor_x4", 15), (417.5, -302.2, "pilha_pneus", 0),
    (461, -291, "tambor_x4", 15), (224.5, -315.1, "tambor_x4", 15), (321.3, -290, "pilha_pneus", 0), (389.1, -272.4, "tambor_x4", 15),
    (447.2, -257.3, "pilha_pneus", 0), (330, -240, "tambor_x4", 15),
    # --- Planalto leste e topo das falésias (matacões)
    (470, 205, "matacao", 0), (430, 195, "matacao", 0), (390, 205, "matacao", 0), (485, 160, "matacao", 0), (445, 165, "matacao", 0),
    (470, 125, "matacao", 0), (440, 130, "tronco_caido", 0), (480, 85, "matacao", 0), (450, 70, "matacao", 0),
    (485, 40, "matacao", 0), (450, 30, "matacao", 0), (490, 0, "matacao", 0), (450, -5, "matacao", 0), (420, 5, "tronco_caido", 60),
    (485, -40, "matacao", 0), (450, -45, "matacao", 0), (410, -40, "matacao", 0),
    (490, -85, "matacao", 0), (455, -80, "matacao", 0), (380, -95, "matacao", 0), (290, -85, "matacao", 0), (330, -100, "tronco_caido", 20),
    (490, -125, "matacao", 0), (455, -120, "matacao", 0), (380, -130, "matacao", 0), (340, -120, "matacao", 0), (300, -130, "tronco_caido", 45),
    (490, -165, "matacao", 0), (455, -160, "matacao", 0), (390, -165, "matacao", 0), (350, -170, "tronco_caido", 13), (300, -160, "matacao", 0),
    (260, -165, "matacao", 0), (490, -205, "matacao", 0), (460, -200, "matacao", 0), (495, -245, "matacao", 0), (470, -225, "tronco_caido", 0),
    (395, 185, "matacao", 0),
    # --- Morro do Sul, represa e contraforte (encostas: matacões e troncos)
    (-20, -90, "matacao", 0), (0, -130, "matacao", 0), (-30, -175, "matacao", 0), (-10, -215, "tronco_caido", 0), (-110, -165, "matacao", 0),
    (20, -60, "matacao", 0), (25, -35, "matacao", 0), (240, -40, "matacao", 0), (250, -80, "matacao", 0), (270, -20, "matacao", 0),
    (60, 20, "matacao", 0), (100, 40, "matacao", 0), (140, 10, "matacao", 0), (180, 40, "tronco_caido", 20), (220, 20, "matacao", 0),
    (260, 40, "matacao", 0), (80, -10, "matacao", 0), (120, -15, "tronco_caido", 100), (200, -20, "matacao", 0), (240, 60, "matacao", 0),
    (160, 80, "matacao", 0), (300, 30, "matacao", 0), (60, 60, "matacao", 0), (80, 100, "matacao", 0), (15, 110, "matacao", 0),
    # --- Baixada norte e encosta norte
    (-160, 440, "tronco_caido", 0), (-100, 435, "matacao", 0), (-40, 440, "matacao", 0), (100, 470, "matacao", 0), (140, 460, "matacao", 0),
    (190, 445, "matacao", 0), (230, 430, "tronco_caido", 0), (280, 432, "matacao", 0), (330, 410, "matacao", 0), (0, 480, "matacao", 0),
    (-230, 400, "matacao", 0), (-190, 410, "fardo_feno_x3", 20), (0, 395, "matacao", 0), (30, 410, "tronco_caido", 90), (100, 395, "matacao", 0),
    (140, 380, "matacao", 0), (170, 350, "tronco_caido", 45), (-60, 360, "matacao", 0), (-20, 370, "matacao", 0), (-100, 370, "matacao", 0),
    (-150, 360, "fardo_feno_x3", 30), (150, 330, "matacao", 0), (-20, 330, "matacao", 0), (20, 350, "tronco_caido", 0),
    (160, 300, "matacao", 0), (130, 260, "matacao", 0), (180, 240, "matacao", 0), (120, 215, "matacao", 0), (90, 215, "matacao", 0),
    # --- Quartel (sacos de areia, trincheira, mureta)
    (250, 410, "sacos_areia", 0), (300, 400, "sacos_areia", 0), (350, 395, "sacos_areia", 20), (312, 300, "sacos_areia", 0),
    (362, 345, "sacos_areia", 90), (257, 336, "sacos_areia", 0), (272, 262, "mureta_concreto", 0), (192, 278, "sacos_areia", 90),
    (258, 192, "trincheira", 0),
    # --- Usina
    (-272, 272, "carreta_cana", 40), (-366, 258, "trator", 80),
]

# Lote 2 — buracos restantes apontados pela análise (centro de cada zona > 25 m); cada posição foi fixada aqui
# como coordenada explícita, com tipo pela regra do lugar (quartel: sacos de areia; pista: tambores/pneus; areia: tronco;
# encosta > 40 m: matacão; pasto: cupinzeiro/feno) e passou pelas mesmas folgas do lote 1. Ordenado de norte para sul.
COBERTURAS_LOTE2 = [
    (2, 508, "tronco_caido", 0), (133, 490, "cupinzeiro", 37), (78, 482, "matacao", 74), (168, 470, "tronco_caido", 111), (-30, 468, "tronco_caido", 148),
    (-128, 448, "tronco_caido", 5), (80, 448, "matacao", 42), (259, 445, "sacos_areia", 79), (52, 444, "matacao", 116), (-260, 435, "tronco_caido", 153),
    (122, 434, "matacao", 10), (-63, 432, "fardo_feno_x3", 47), (38, 432, "matacao", 84), (309, 431, "sacos_areia", 121), (-276, 425, "tronco_caido", 158),
    (118, 416, "matacao", 15), (156, 414, "fardo_feno_x3", 0), (208, 412, "sacos_areia", 89), (-141, 404, "matacao", 126), (380, 402, "sacos_areia", 163),
    (-69, 398, "cupinzeiro", 20), (-179, 392, "fardo_feno_x3", 57), (-135, 386, "fardo_feno_x3", 0), (-208, 385, "matacao", 131), (166, 384, "fardo_feno_x3", 168),
    (122, 353, "matacao", 25), (-98, 342, "fardo_feno_x3", 62), (438, 338, "sacos_areia", 99), (-417, 308, "tronco_caido", 136), (447, 308, "sacos_areia", 173),
    (131, 299, "matacao", 30), (-422, 272, "matacao", 67), (160, 265, "sacos_areia", 104), (451, 262, "sacos_areia", 141), (-464, 245, "tronco_caido", 178),
    (468, 233, "matacao", 35), (-416, 232, "cupinzeiro", 72), (-376, 220, "fardo_feno_x3", 109), (-360, 220, "cupinzeiro", 146), (150, 220, "matacao", 3),
    (-376, 204, "matacao", 40), (-230, 198, "fardo_feno_x3", 77), (492, 190, "tronco_caido", 114), (-226, 162, "matacao", 151), (418, 159, "matacao", 8),
    (-410, 123, "fardo_feno_x3", 45), (50, 128, "matacao", 82), (-224, 118, "matacao", 119), (-422, 77, "cupinzeiro", 156), (422, 76, "matacao", 13),
    (207, 67, "matacao", 50), (104, 64, "matacao", 87), (494, 62, "tronco_caido", 124), (-232, 60, "matacao", 161), (293, 57, "matacao", 18),
    (408, 48, "matacao", 55), (132, 46, "matacao", 92), (-178, 45, "matacao", 129), (-122, 38, "matacao", 166), (-406, 17, "matacao", 23),
    (104, 12, "matacao", 60), (392, 11, "matacao", 97), (-152, 6, "matacao", 134), (184, 6, "matacao", 171), (-448, 2, "fardo_feno_x3", 28),
    (48, -6, "matacao", 65), (296, -6, "matacao", 102), (237, -7, "matacao", 139), (-392, -8, "matacao", 176), (166, -10, "matacao", 33),
    (-88, -12, "matacao", 70), (321, -18, "matacao", 107), (-384, -32, "matacao", 144), (-366, -32, "fardo_feno_x3", 1), (-227, -32, "matacao", 38),
    (96, -36, "matacao", 75), (342, -39, "matacao", 112), (-478, -42, "fardo_feno_x3", 149), (-325, -42, "matacao", 6), (-429, -44, "matacao", 43),
    (-136, -44, "matacao", 80), (-186, -46, "matacao", 117), (-98, -48, "matacao", 154), (269, -54, "matacao", 11), (228, -62, "matacao", 48),
    (502, -62, "tronco_caido", 85), (350, -68, "matacao", 122), (-378, -70, "cupinzeiro", 159), (-432, -74, "cupinzeiro", 16), (424, -86, "matacao", 53),
    (-394, -88, "cupinzeiro", 90), (13, -94, "matacao", 127), (278, -112, "matacao", 164), (-25, -118, "matacao", 21), (424, -118, "matacao", 58),
    (-308, -122, "fardo_feno_x3", 95), (-410, -136, "fardo_feno_x3", 132), (272, -140, "matacao", 169), (355, -142, "matacao", 26), (328, -147, "matacao", 63),
    (412, -148, "matacao", 100), (-416, -154, "cupinzeiro", 137), (-255, -158, "fardo_feno_x3", 174), (-368, -162, "matacao", 31), (2, -163, "matacao", 68),
    (-342, -168, "matacao", 105), (-46, -168, "matacao", 142), (2, -177, "matacao", 179), (238, -180, "matacao", 36), (512, -185, "tronco_caido", 73),
    (-54, -192, "matacao", 110), (-305, -202, "cupinzeiro", 147), (-76, -204, "fardo_feno_x3", 4), (-419, -218, "matacao", 41), (512, -220, "tronco_caido", 78),
    (185, -228, "tambor_x4", 115), (-89, -241, "matacao", 152), (235, -242, "pilha_pneus", 9), (-382, -248, "matacao", 46), (356, -250, "pilha_pneus", 83),
    (100, -254, "matacao", 120), (418, -265, "tambor_x4", 157), (-346, -266, "fardo_feno_x3", 14), (268, -266, "pilha_pneus", 0), (348, -268, "tambor_x4", 88),
    (-235, -272, "cupinzeiro", 125), (502, -272, "tronco_caido", 162), (210, -284, "tambor_x4", 19), (286, -285, "tambor_x4", 56), (488, -294, "pilha_pneus", 93),
    (-274, -298, "fardo_feno_x3", 130), (-3, -298, "fardo_feno_x3", 167), (254, -302, "tambor_x4", 24), (132, -304, "cupinzeiro", 61), (-202, -306, "matacao", 98),
    (-358, -308, "fardo_feno_x3", 135), (389, -309, "pilha_pneus", 172), (-276, -312, "cupinzeiro", 29), (104, -320, "matacao", 66), (-132, -330, "fardo_feno_x3", 103),
    (-111, -322, "cupinzeiro", 140), (190, -327, "pilha_pneus", 177), (468, -330, "tambor_x4", 34), (438, -342, "pilha_pneus", 108),
    (371, -348, "tambor_x4", 145), (409, -348, "pilha_pneus", 2), (235, -350, "pilha_pneus", 39), (-200, -358, "cupinzeiro", 76), (465, -358, "tambor_x4", 113),
    (1, -361, "cupinzeiro", 150), (210, -364, "pilha_pneus", 7), (65, -368, "fardo_feno_x3", 44), (298, -376, "tambor_x4", 81), (371, -376, "tambor_x4", 118),
    (238, -384, "tambor_x4", 155), (345, -388, "matacao", 12), (-58, -394, "cupinzeiro", 49), (268, -398, "matacao", 86), (429, -398, "tronco_caido", 123),
    (28, -399, "cupinzeiro", 160), (-12, -405, "cupinzeiro", 17), (-217, -409, "fardo_feno_x3", 54), (-129, -411, "cupinzeiro", 91), (197, -411, "fardo_feno_x3", 0),
    (122, -412, "cupinzeiro", 165), (389, -421, "tronco_caido", 22), (308, -422, "tronco_caido", 59), (245, -437, "tronco_caido", 96), (-93, -441, "cupinzeiro", 133),
    (-262, -450, "fardo_feno_x3", 170), (-186, -444, "matacao", 27), (-158, -445, "matacao", 64), (-135, -476, "matacao", 101), (-232, -472, "cupinzeiro", 138),
    (252, -485, "tronco_caido", 175), (-82, -498, "tronco_caido", 32), (-176, -500, "tronco_caido", 69), (-102, -506, "tronco_caido", 106), (-18, -507, "tronco_caido", 143),
]
COBERTURAS_LOTE2 += [(182, 418, "matacao", 0), (486, -256, "tambor_x4", 40), (270, -345, "pilha_pneus", 0)]   # ajuste final à mão
N_LOTE1 = len(COBERTURAS_NOVAS)
COBERTURAS_NOVAS = COBERTURAS_NOVAS + COBERTURAS_LOTE2

# ===========================================================================
# MARCOS VERTICAIS propostos (poi, tipo, x, y, rot, altura)
# ===========================================================================
MARCOS_NOVOS = [
    # (poi, tipo, x, y, rot_deg, altura_m, justificativa)
    ("vila_caicara", "caixa_dagua", -296, -318, 35, 20, "capela tem 9 m; caixa d'água branca e vermelha na entrada leste, visível da enseada e da ponte"),
    ("pedreira", "antena_celular", 305, 45, 0, 25, "britador tem 14 m; repetidora na borda noroeste da cava, silhueta contra o céu vista do Pico"),
    ("pista_pouso", "torre_vigia_madeira", 262, -190, 15, 18, "torre de controle tem 12 m; torre de vigia de madeira atrás do quebra-vento, marca a cabeceira 08"),
    ("represa", "antena_celular", -160, -120, 45, 25, "tomada d'água tem 14 m; repetidora junto à subestação, lê a jusante da barragem"),
    ("fazenda_boa_esperanca", "cata_vento", -40, -240, 0, 18, "casarão tem 9 m; cata-vento de fazenda ao lado do paiol, no alto do pasto"),
    ("praia_quiosques", "caixa_dagua", 140, -445, 0, 20, "quiosques têm 3,5 m; caixa d'água do coqueiral, vista do mar e da Pista"),
]

# Mirante do Pico: plataforma de madeira 6 x 6 m a 3 m do chão, guarda-corpo (mureta) e escada na face -Y local.
# Acessos: estrada E11 (Subida do Pico, serpentina) e trilhas T1/T2/T3 (íngremes). Loot alto nos 4 cantos da plataforma.
MIRANTE = {"pos": (88, 168), "rot_deg": 0, "tamanho_m": (6, 6), "altura_piso_m": 3.0, "escada": "face -Y local, 1,2 m de largura, 5 m de projeção",
           "loot_local": [(-1.8, -1.8), (1.8, -1.8), (-1.8, 1.8), (1.8, 1.8)], "tier": "alto"}


def amostrar_seg(a, b, passo=1.0):
    L = math.dist(a, b); n = max(1, int(math.ceil(L / passo)))
    return [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]


def pontos_cobertura(W, novas, det):
    agach, pe = [], []
    for b in W.predios:
        if b["tipo"] in ("heliponto",): continue
        w, d, h = b["tamanho_m"]
        cs = [D.mundo(b, sx * w / 2, sy * d / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for i in range(4):
            pts = amostrar_seg(cs[i], cs[(i + 1) % 4])
            agach += pts
            if h >= 1.8 and b["tipo"] != "curral": pe += pts
    cobs = [(c["pos"][0], c["pos"][1], c["tipo"], c.get("rot_deg", 0), c["altura_m"]) for c in W.lay["cobertura_campo_aberto"]]
    cobs += [(x, y, t, r, ALTURA_COB[t]) for (x, y, t, r) in novas]
    for (x, y, t, r, h) in cobs:
        if h < 0.8: continue
        L = COMPR_COB.get(t, 0); rr = math.radians(r)
        pts = amostrar_seg((x - L / 2 * math.cos(rr), y - L / 2 * math.sin(rr)), (x + L / 2 * math.cos(rr), y + L / 2 * math.sin(rr))) if L else [(x, y)]
        agach += pts
        if h >= 1.8: pe += pts
    for c in det["cercas"]:
        if c["tipo"] == "cerca_arame": continue
        for i in range(len(c["pontos"]) - 1):
            pts = amostrar_seg(c["pontos"][i], c["pontos"][i + 1])
            agach += pts
            if c["tipo"] == "muro_alto": pe += pts
    for p in det["props"]:
        if p["tipo"] in PROPS_SOLIDOS: agach.append((p["x"], p["y"]))
    veg = json.load(open(D.VEG, encoding="utf-8"))["instancias"]
    for v in veg:
        if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro"):
            agach.append((v["x"], v["y"])); pe.append((v["x"], v["y"]))
    return np.array(agach), np.array(pe), veg


def analisar(W, novas, det, passo=5.0):
    xs = np.arange(-600 + passo / 2, 600, passo)
    X, Y = np.meshgrid(xs, xs[::-1])
    Z = np.zeros_like(X)
    for i in range(X.shape[0]):
        for j in range(X.shape[1]):
            Z[i, j] = W.z(X[i, j], Y[i, j])
    costa = W.lay["costa"]
    terra = np.zeros_like(X, bool)
    for i in range(X.shape[0]):
        for j in range(X.shape[1]):
            if Z[i, j] > 0.3 and D.dentro(costa, X[i, j], Y[i, j]) and not D.dentro(W.rep, X[i, j], Y[i, j]):
                terra[i, j] = True
    agach, pe, veg = pontos_cobertura(W, novas, det)
    troncos = np.array([(v["x"], v["y"]) for v in veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b")])
    canas = [m["poligono"] for m in W.lay["vegetacao"] if m["tipo"] == "canavial"]
    P = np.column_stack([X.ravel(), Y.ravel()])
    dens = cKDTree(troncos).query_ball_point(P, 10.0, return_length=True).reshape(X.shape)
    aberto = terra & (dens < 3)
    for i in range(X.shape[0]):
        for j in range(X.shape[1]):
            if not aberto[i, j]: continue
            x, y = X[i, j], Y[i, j]
            if any(D.dentro(c, x, y) for c in canas) or any(D.dist_poli(x, y, pts) < hw for pts, hw in W.rio) or \
               any(D.dist_obb(b, x, y) == 0 for b in W.predios if abs(b["pos"][0] - x) < 30 and abs(b["pos"][1] - y) < 30):
                aberto[i, j] = False
    da = cKDTree(agach).query(P)[0].reshape(X.shape)
    dp = cKDTree(pe).query(P)[0].reshape(X.shape)
    ruim = aberto & (da > 25)
    rot, n = ndimage.label(ruim)
    zonas = []
    for k in range(1, n + 1):
        m = rot == k
        cx, cy = float(X[m].mean()), float(Y[m].mean())
        poi = min(W.lay["pois"] + W.lay["marcos"], key=lambda p: math.dist(p["centro"], (cx, cy)))
        zonas.append({"id": f"Z{k:02d}", "centro": [round(cx), round(cy)], "area_m2": int(m.sum() * passo * passo),
                      "dist_max_m": round(float(da[m].max()), 1), "xmin": float(X[m].min()), "xmax": float(X[m].max()),
                      "ymin": float(Y[m].min()), "ymax": float(Y[m].max()), "poi_mais_proximo": poi["id"]})
    zonas.sort(key=lambda z: -z["area_m2"])
    st = {"pontos_abertos": int(aberto.sum()), "pct_ate_25m_agachado": round(100 * float((aberto & (da <= 25)).sum()) / aberto.sum(), 1),
          "pct_ate_40m_em_pe": round(100 * float((aberto & (dp <= 40)).sum()) / aberto.sum(), 1),
          "dist_max_agachado_m": round(float(da[aberto].max()), 1), "dist_max_em_pe_m": round(float(dp[aberto].max()), 1),
          "pontos_em_pe_acima_40m": int((aberto & (dp > 40)).sum())}
    return dict(X=X, Y=Y, aberto=aberto, da=da, dp=dp, zonas=zonas, stats=st)


def heatmap(res, caminho, titulo):
    from PIL import Image, ImageDraw
    im = Image.open(RADAR).convert("RGBA")
    S = 1024 / 1200.0
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    X, Y, ab, da = res["X"], res["Y"], res["aberto"], res["da"]
    for i in range(X.shape[0]):
        for j in range(X.shape[1]):
            if not ab[i, j]: continue
            v = da[i, j]
            cor = (40, 170, 60, 110) if v <= 10 else (230, 210, 40, 130) if v <= 25 else (240, 120, 20, 170) if v <= 40 else (220, 20, 20, 200)
            x0, y0 = (X[i, j] - 2.5 + 600) * S, (600 - Y[i, j] - 2.5) * S
            d.rectangle([x0, y0, x0 + 5 * S, y0 + 5 * S], fill=cor)
    im = Image.alpha_composite(im, ov); d = ImageDraw.Draw(im)
    for z in res["zonas"]:
        x, y = (z["centro"][0] + 600) * S, (600 - z["centro"][1]) * S
        d.text((x + 4, y - 6), z["id"], fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
    d.rectangle([12, 12, 330, 100], fill=(15, 25, 35, 220))
    d.text((20, 18), titulo, fill=(255, 255, 255))
    for k, (c, t) in enumerate([((40, 170, 60), "<= 10 m"), ((230, 210, 40), "10–25 m"), ((240, 120, 20), "25–40 m"), ((220, 20, 20), "> 40 m")]):
        d.rectangle([20, 38 + k * 15, 32, 48 + k * 15], fill=c); d.text((38, 36 + k * 15), f"cobertura mais próxima {t}", fill=(255, 255, 255))
    os.makedirs(RAW, exist_ok=True)
    im.convert("RGB").save(caminho)


class Folgas:
    """Checagem de folgas para objetos novos (coberturas, marcos, mirante)."""
    def __init__(self, W, det):
        self.W = W
        self.cercas = [c["pontos"] for c in det["cercas"]]
        self.postes = [tuple(p) for L in det["linhas_fiacao"] for p in L["postes"]]
        veg = json.load(open(D.VEG, encoding="utf-8"))["instancias"]
        self.troncos = cKDTree(np.array([(v["x"], v["y"]) for v in veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro", "bananeira")]))
        self.cob_exist = [tuple(c["pos"]) for c in W.lay["cobertura_campo_aberto"]]

    def checar(self, x, y, rot=0, compr=0, raio=1.0, folga_predio=1.5, folga_via=1.5):
        W = self.W; r = math.radians(rot)
        amostras = [(x, y)] + ([(x + s * compr / 2 * math.cos(r), y + s * compr / 2 * math.sin(r)) for s in (-1, -0.5, 0.5, 1)] if compr else [])
        for (px, py) in amostras:
            m = W.agua(px, py)
            if m: return m
            for e in W.vias:
                if D.dist_poli(px, py, e["pontos"]) < e["largura_m"] / 2 + folga_via + raio: return f"via {e['id']}"
            for b in W.predios:
                if abs(b["pos"][0] - px) > 50 or abs(b["pos"][1] - py) > 50: continue
                if D.dist_obb(b, px, py) < folga_predio + raio: return f"prédio {b['id']}"
                if D.na_porta(b, px, py): return f"porta {b['id']}"
            for c in self.cercas:
                if abs(c[0][0] - px) < 400 and D.dist_poli(px, py, c) < 1.0 + raio: return "cerca/muro"
            if self.troncos.query((px, py))[0] < 1.0 + raio: return "tronco de árvore"
            if any(math.dist(p, (px, py)) < 1.0 + raio for p in self.postes): return "poste"
        if any(math.dist(p, (x, y)) < 3.0 for p in self.cob_exist): return "cobertura existente"
        return None


def main():
    W = D.Mundo()
    det = json.load(open(DET, encoding="utf-8"))
    F = Folgas(W, det)
    erros = []
    vistos = []
    for (x, y, t, r) in COBERTURAS_NOVAS:
        m = F.checar(x, y, r, COMPR_COB.get(t, 0), raio=1.2 if t in ("matacao", "trator", "carreta_cana") else 0.8)
        if m: erros.append(f"cobertura ({x},{y}) {t}: {m}")
        if any(math.dist(v, (x, y)) < 6 for v in vistos): erros.append(f"cobertura ({x},{y}) {t}: duplicada (< 6 m de outra nova)")
        vistos.append((x, y))
    if erros:
        print(f"{len(erros)} ERROS de folga:"); [print("  ", e) for e in erros]
    antes = analisar(W, [], det)
    print("ANTES:", antes["stats"], "zonas >25 m:", len(antes["zonas"]))
    for z in antes["zonas"]:
        print(f"  {z['id']} c={z['centro']} área={z['area_m2']} m² dmax={z['dist_max_m']} x[{z['xmin']},{z['xmax']}] y[{z['ymin']},{z['ymax']}] ~{z['poi_mais_proximo']}")
    heatmap(antes, os.path.join(RAW, "cobertura_mapa.png"), "Cobertura (agachado) — ANTES")
    depois = analisar(W, COBERTURAS_NOVAS, det)
    print("DEPOIS:", depois["stats"], "zonas >25 m:", len(depois["zonas"]))
    for z in depois["zonas"]:
        print(f"  {z['id']} c={z['centro']} área={z['area_m2']} m² dmax={z['dist_max_m']} x[{z['xmin']},{z['xmax']}] y[{z['ymin']},{z['ymax']}] ~{z['poi_mais_proximo']}")
    heatmap(depois, os.path.join(RAW, "cobertura_mapa_depois.png"), "Cobertura (agachado) — DEPOIS")
    if "--rapido" in sys.argv:
        return 1 if erros else 0
    return gravar(W, det, F, antes, depois, erros)


def gravar(W, det, F, antes, depois, erros):
    # --- marcos: existentes (>= 18 m) por POI + propostos
    marcos = {}
    for p in W.lay["pois"] + W.lay["marcos"]:
        ex = [{"id": b["id"], "tipo": b["tipo"], "altura_m": b["tamanho_m"][2], "pos": b["pos"]} for b in p["predios"] if b["tamanho_m"][2] >= 18]
        marcos[p["id"]] = {"existentes": ex, "propostos": []}
    RAIO_MARCO = {"caixa_dagua": 3.0, "antena_celular": 2.0, "torre_vigia_madeira": 2.5, "cata_vento": 2.0, "torre_igreja": 3.0}
    for (poi, t, x, y, rot, h, just) in MARCOS_NOVOS:
        m = F.checar(x, y, rot, 0, raio=RAIO_MARCO[t], folga_predio=2.0)
        if m: erros.append(f"marco {t} ({x},{y}): {m}")
        marcos[poi]["propostos"].append({"tipo": t, "pos": [x, y], "z_chao": round(W.z(x, y), 1), "rot_deg": rot, "altura_m": h, "motivo": just})
    sem = [k for k, v in marcos.items() if not v["existentes"] and not v["propostos"]]
    if sem: erros.append(f"POIs sem marco >= 18 m: {sem}")
    # --- mirante
    mx, my = MIRANTE["pos"]
    m = F.checar(mx, my, 0, 0, raio=4.3, folga_predio=2.0)
    esc = D.mundo({"pos": [mx, my], "rot_deg": MIRANTE["rot_deg"]}, 0, -5.5)
    m2 = F.checar(esc[0], esc[1], 0, 0, raio=1.0)
    if m or m2: erros.append(f"mirante: {m or m2}")
    zc = W.z(mx, my)
    loot = []
    for i, (lx, ly) in enumerate(MIRANTE["loot_local"]):
        x, y = D.mundo({"pos": [mx, my], "rot_deg": MIRANTE["rot_deg"]}, lx, ly)
        loot.append({"id": f"MIR{i+1}", "pos": [round(x, 2), round(y, 2)], "z_abs_m": round(zc + MIRANTE["altura_piso_m"] + 0.1, 2), "tier": MIRANTE["tier"]})
    if erros:
        print("ERROS:"); [print("  ", e) for e in erros]
        return 1
    cobs = [{"pos": [x, y], "tipo": t, "rot_deg": r, "altura_m": ALTURA_COB[t], "lote": 1 if i < N_LOTE1 else 2}
            for i, (x, y, t, r) in enumerate(COBERTURAS_NOVAS)]
    doc = {
        "versao": 1, "fonte": "tools/gameplay_src.py (coberturas, marcos e mirante escritos à mão; análise determinística)",
        "regra": {"agachado_m": 25, "em_pe_m": 40, "grade_m": 5,
                  "aberto": "terra fora de prédio, água, canavial (ocultação) e mata densa (>= 3 troncos a 10 m)",
                  "cobre_agachado": "prédios, coberturas (>= 0,8 m), muros, cerca de madeira, tambor/barril/tijolos/canoa/portão, troncos",
                  "cobre_em_pe": "prédios, muro alto, árvores, coberturas >= 1,8 m (matacão, trator, carreta)"},
        "analise_antes": {"stats": antes["stats"], "zonas_acima_25m": antes["zonas"]},
        "analise_depois": {"stats": depois["stats"], "zonas_acima_25m": depois["zonas"]},
        "coberturas_novas": cobs,
        "contagem_coberturas_por_tipo": dict(Counter(c["tipo"] for c in cobs)),
        "marcos_verticais": marcos,
        "mirante_pico": {"pos": [mx, my], "z_chao_m": round(zc, 1), "rot_deg": MIRANTE["rot_deg"], "tamanho_m": list(MIRANTE["tamanho_m"]),
                         "altura_piso_m": MIRANTE["altura_piso_m"], "escada": MIRANTE["escada"], "guarda_corpo": "mureta de madeira 1,0 m nos 3 lados sem escada",
                         "acessos": ["E11 Subida do Pico (estrada)", "T1 Trilha da Cumeeira", "T2 Trilha do Farol", "T3 Trilha da Serra Leste"],
                         "loot": loot},
    }
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print(f"gravado {SAIDA}: {len(cobs)} coberturas novas, {len(MARCOS_NOVOS)} marcos propostos, mirante com {len(loot)} loots")
    return 0


if __name__ == "__main__":
    sys.exit(main())
