# -*- coding: utf-8 -*-
"""
Chão vivo da Ilha do Tauá (CRITICA_MAPA_01 itens 2, 4 e 6; NOITE_PLANO item 22) -> docs/design/chao_vivo.json

  1. TRILHAS DE PÉ (terra batida, 1,2 m): porta de cada casa -> rua escolhida à mão (tabela TRILHAS_PORTA, com pontos de
     passagem escritos à mão para contornar a casa quando a porta dá para o lado oposto da rua) + ATALHOS entre POIs.
  2. MANCHAS DE CAPIM SECO (#B29C5C): polígonos autorais (centro + 8 raios escritos à mão, sentido anti-horário a partir do leste).
  3. CAPIM ALTO AO PÉ DE MUROS/CERCAS: padrão fixo a cada 3 m ao longo de cada cerca/muro de detalhes.json
     (3 touceiras por segmento, lados alternados, offsets escritos à mão) — linear como a cana.
  4. ARBUSTOS SOB ÁRVORES ISOLADAS: árvore sem outro tronco a 12 m recebe o gabarito fixo SOB_ARVORE.
  5. OBJETOS LEGÍVEIS a cada 12–15 m nos POIs: lista explícita OBJETOS_POI (tipos de detalhes.json).
Folgas: portas (2 m à frente), prédios (1 m p/ objetos, 0,3 m p/ trilhas), vias (objetos no acostamento), água.
Uso:  python tools/chao_vivo_src.py
"""
import json, math, os, sys
from collections import Counter, defaultdict
import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detalhes_src as D

RAIZ = D.RAIZ
SAIDA = os.path.join(RAIZ, "docs", "design", "chao_vivo.json")
DET = os.path.join(RAIZ, "docs", "design", "detalhes.json")
GAME = os.path.join(RAIZ, "docs", "design", "gameplay_01.json")
PREVIEW = os.path.join(RAIZ, "raw", "chao_vivo_preview.png")

# ===========================================================================
# 1. TRILHAS DE PÉ — predio_id: (destino, [pontos de passagem])
#    destino: ("via", id) = ponto mais próximo da via (na borda) | ("ponto", x, y)
#    ponto de passagem: ("L", lx, ly) local ao prédio | ("M", x, y) mundo
# ===========================================================================
FRENTE = {"usina_santa_cruz_08": 1.2}   # porta muito perto da ponta da casa vizinha
PRACA_CAPELA = ("ponto", -338, -384)
TRILHAS_PORTA = {
    # Vila Caiçara
    "vila_caicara_01": (("via", "V1"), [("L", -5.2, -6.5), ("L", -5.2, 4.0)]), "vila_caicara_02": (("via", "V1"), []), "vila_caicara_03": (("via", "V1"), []),
    "vila_caicara_04": (("via", "E9"), []), "vila_caicara_05": (("via", "V1"), [("L", 6.2, -8.5), ("L", 6.2, 6.0)]), "vila_caicara_06": (("via", "E9"), []),
    "vila_caicara_07": (("via", "E1"), [("L", 6.2, -10.5), ("L", 6.2, 8.0)]), "vila_caicara_08": (("via", "E1"), [("L", 6.2, -7.5), ("L", 6.2, 5.0)]), "vila_caicara_09": (("via", "E1"), [("L", 5.2, -6.5), ("L", 5.2, 4.0)]),
    "vila_caicara_10": (PRACA_CAPELA, [("L", 6.2, -8.5), ("L", 6.2, 6.0)]), "vila_caicara_11": (("via", "E1"), [("L", 5.2, -6.0), ("L", 5.2, 3.5)]), "vila_caicara_12": (PRACA_CAPELA, [("L", -5.2, -6.5), ("L", -5.2, 4.0)]),
    "vila_caicara_13": (("via", "E1"), []), "vila_caicara_14": (("via", "E1"), [("L", 5.2, -6.5), ("L", 5.2, 4.0)]), "vila_caicara_15": (PRACA_CAPELA, []),
    "vila_caicara_16": (("via", "E9"), []),
    # Morro do Cruzeiro (becos até a escadaria V2 ou às estradas de baixo)
    "morro_cruzeiro_01": (("via", "E8"), []), "morro_cruzeiro_02": (("via", "V2"), []), "morro_cruzeiro_03": (("via", "V2"), []),
    "morro_cruzeiro_04": (("via", "V2"), []), "morro_cruzeiro_05": (("via", "V2"), []), "morro_cruzeiro_06": (("via", "E10"), []),
    "morro_cruzeiro_07": (("via", "E8"), []), "morro_cruzeiro_08": (("via", "V2"), []), "morro_cruzeiro_09": (("via", "V2"), []),
    "morro_cruzeiro_10": (("via", "V2"), []), "morro_cruzeiro_11": (("via", "V2"), []), "morro_cruzeiro_12": (("via", "V2"), [("M", -288, 53)]),
    "morro_cruzeiro_13": (("via", "V2"), [("M", -277, 57), ("M", -288, 54)]), "morro_cruzeiro_14": (("via", "V2"), []), "morro_cruzeiro_15": (("via", "V2"), []),
    "morro_cruzeiro_16": (("via", "V2"), []), "morro_cruzeiro_17": (("via", "V2"), []), "morro_cruzeiro_18": (("via", "V2"), []),
    "morro_cruzeiro_19": (("via", "V2"), []), "morro_cruzeiro_20": (("via", "E8"), []), "morro_cruzeiro_21": (("via", "E8"), []),
    "morro_cruzeiro_22": (("via", "V2"), []),
    # Usina
    "usina_santa_cruz_01": (("via", "E8"), []), "usina_santa_cruz_03": (("via", "T1"), []), "usina_santa_cruz_04": (("via", "E8"), []),
    "usina_santa_cruz_06": (("via", "E7"), []), "usina_santa_cruz_07": (("via", "E8"), [("M", -346, 300), ("M", -343, 262)]), "usina_santa_cruz_08": (("via", "E8"), [("M", -356.5, 339), ("M", -357, 330), ("M", -350, 305), ("M", -346, 290), ("M", -343, 262)]),
    "usina_santa_cruz_09": (("via", "E8"), [("M", -316, 335), ("M", -306, 300), ("M", -301, 282)]),
    # Farol
    "farol_ponta_norte_01": (("via", "E6"), []), "farol_ponta_norte_02": (("via", "E7"), []), "farol_ponta_norte_03": (("via", "E6"), []),
    "farol_ponta_norte_04": (("via", "E7"), []),
    # Quartel (caminhos gastos pelo pátio até a via interna)
    "quartel_01": (("via", "E5"), [("M", 300, 318), ("M", 290, 285)]), "quartel_02": (("via", "E5"), [("M", 285, 289), ("M", 262, 289)]), "quartel_03": (("via", "E5"), []),
    "quartel_04": (("via", "E5"), []), "quartel_05": (("via", "E5"), []), "quartel_06": (("via", "E5"), [("M", 257, 238), ("M", 257, 252)]),
    # Pedreira
    "pedreira_03": (("via", "E4"), []), "pedreira_04": (("via", "E4"), []), "pedreira_05": (("via", "E4"), []), "pedreira_06": (("via", "T3"), []),
    # Pista
    "pista_pouso_01": (("via", "E4"), []), "pista_pouso_02": (("via", "E4"), []), "pista_pouso_03": (("via", "E4"), []),
    "pista_pouso_05": (("via", "E4"), []),
    # Represa
    "represa_01": (("via", "E10"), []), "represa_02": (("via", "E10"), []),
    "represa_05": (("via", "E11"), [("L", 5.2, -6.5), ("L", 5.2, 4.0), ("M", -15, 75), ("M", 25, 108)]),
    # Fazenda
    "fazenda_boa_esperanca_01": (("via", "E1"), [("L", -15.2, -11.5), ("L", -15.2, 9.0)]), "fazenda_boa_esperanca_02": (("via", "E1"), []),
    "fazenda_boa_esperanca_03": (("via", "E2"), []), "fazenda_boa_esperanca_05": (("via", "E1"), [("L", -5.2, -6.5), ("L", -5.2, 4.0)]),
    "fazenda_boa_esperanca_06": (("ponto", -127, -322), []), "fazenda_boa_esperanca_07": (("ponto", -127, -322), [("L", 5.2, -6.5), ("L", 5.2, 4.0)]),
    "fazenda_boa_esperanca_08": (("via", "E2"), []),
    # Praia (dos quiosques e do restaurante até a estrada)
    "praia_quiosques_01": (("via", "E2"), [("L", 3.9, -5.0), ("L", 3.9, 2.5)]), "praia_quiosques_02": (("via", "E2"), [("L", 3.9, -5.0), ("L", 3.9, 2.5)]), "praia_quiosques_03": (("via", "E2"), [("L", -3.9, -5.0), ("L", -3.9, 2.5), ("M", 93, -448)]),
    "praia_quiosques_04": (("via", "E3"), [("L", -3.9, -5.0), ("L", -3.9, 2.5)]), "praia_quiosques_05": (("via", "E3"), [("L", -3.9, -5.0), ("L", -3.9, 2.5)]), "praia_quiosques_06": (("via", "E2"), [("L", 5.0, -4.5), ("L", 5.0, 2.0)]),
    "praia_quiosques_07": (("via", "E2"), [("L", 7.2, -8.5), ("L", 7.2, 6.0)]),
    # Pico
    "pico_taua_02": (("via", "E11"), []),
}

# Atalhos de pé entre POIs próximos (mundo, escritos à mão)
ATALHOS = [
    {"nome": "Vila -> Praia dos Quiosques pela restinga", "pontos": [(-300, -410), (-270, -440), (-215, -462), (-150, -468), (-80, -466), (-20, -462), (20, -452)]},
    {"nome": "Morro do Cruzeiro -> Usina pela capoeira", "pontos": [(-305, 88), (-312, 128), (-318, 170), (-332, 200), (-345, 222)]},
    {"nome": "Farol -> Quartel pela costa", "pontos": [(96, 488), (140, 470), (190, 452), (240, 438), (290, 420), (345, 402), (395, 380)]},
    {"nome": "Fazenda -> Represa pelo pasto", "pontos": [(-140, -232), (-150, -205), (-140, -180), (-118, -150), (-110, -130)]},
    {"nome": "Represa -> Pico pela margem norte", "pontos": [(-60, 58), (-20, 70), (20, 112), (55, 120)]},
    {"nome": "Pedreira -> Quartel pelo contraforte", "pontos": [(300, 62), (320, 100), (345, 140), (375, 175)]},
]

# ===========================================================================
# 2. MANCHAS DE CAPIM SECO (nome, cx, cy, [8 raios a 0°,45°,...,315°])
# ===========================================================================
CAPIM_SECO = [
    # Noroeste
    ("Baixada Oeste", -450, 200, [22, 18, 26, 20, 17, 24, 19, 23]), ("Pasto do Morro Oeste", -445, 60, [18, 24, 20, 26, 22, 17, 25, 19]),
    ("Pasto Oeste norte", -465, -30, [16, 20, 25, 18, 22, 27, 19, 21]), ("Baixada Norte", -150, 420, [28, 18, 15, 20, 26, 17, 22, 30]),
    ("Pé da Serra Norte", -60, 368, [20, 24, 18, 15, 22, 26, 19, 17]), ("Praia Norte", -205, 400, [18, 15, 22, 25, 17, 20, 24, 16]),
    ("Borda da Capoeira", -290, 175, [24, 19, 17, 22, 27, 18, 20, 25]), ("Encosta do Cruzeiro", -230, 55, [17, 23, 20, 18, 25, 21, 16, 22]),
    ("Morro da Represa Oeste", -165, 40, [19, 16, 24, 21, 17, 22, 26, 18]), ("Sela da Capoeira", -380, 128, [16, 20, 18, 23, 19, 15, 21, 24]),
    # Nordeste
    ("Baixada do Farol", 20, 400, [22, 26, 18, 20, 24, 19, 27, 21]), ("Costão Nordeste", 120, 440, [18, 22, 27, 19, 23, 17, 20, 25]),
    ("Campo Norte do Quartel", 230, 418, [25, 18, 16, 22, 28, 20, 17, 23]), ("Encosta NE", 160, 300, [20, 17, 23, 26, 18, 21, 25, 19]),
    ("Topo do Pico", 70, 170, [15, 18, 14, 16, 19, 15, 17, 16]), ("Contraforte Sul", 200, 30, [23, 19, 17, 25, 21, 18, 24, 20]),
    ("Alto da Represa Leste", 110, 25, [18, 22, 26, 19, 17, 24, 20, 23]), ("Planalto Leste", 445, 160, [20, 24, 18, 22, 27, 19, 23, 17]),
    ("Topo da Falésia Leste", 455, 40, [17, 21, 25, 18, 20, 23, 19, 26]), ("Grota do Quartel", 395, 195, [19, 16, 22, 24, 18, 20, 17, 21]),
    # Sudeste
    ("Planalto da Pedreira", 440, -100, [22, 18, 25, 20, 17, 24, 21, 19]), ("Encosta Leste", 360, -125, [18, 23, 20, 26, 22, 17, 19, 24]),
    ("Leste do Morro do Sul", 290, -120, [20, 17, 24, 19, 23, 26, 18, 21]), ("Falésias Sudeste", 470, -200, [16, 19, 22, 18, 21, 17, 24, 20]),
    ("Pasto Sul", 150, -300, [26, 20, 18, 24, 28, 19, 22, 25]), ("Campo da Praia", 60, -335, [22, 25, 19, 17, 23, 27, 20, 18]),
    ("Restinga da Pista", 260, -440, [24, 18, 16, 21, 26, 19, 23, 20]), ("Sul da Pista", 380, -400, [21, 25, 18, 20, 24, 17, 22, 26]),
    ("Cabeceira 26", 440, -320, [18, 16, 20, 23, 19, 25, 21, 17]), ("Alto do Morro do Sul Oeste", 200, -250, [20, 24, 21, 17, 19, 23, 26, 18]),
    # Sudoeste
    ("Pasto Oeste sul", -450, -120, [24, 19, 17, 22, 26, 20, 18, 23]), ("Pasto da Beira-Rio", -380, -170, [18, 22, 25, 19, 17, 23, 20, 21]),
    ("Pé do Morro Sul", -300, -120, [21, 17, 23, 26, 19, 18, 24, 20]), ("Pasto da Fazenda Oeste", -250, -285, [22, 26, 19, 17, 24, 20, 23, 18]),
    ("Pasto da Fazenda Sul", -200, -365, [25, 20, 18, 23, 27, 19, 21, 24]), ("Pasto do Curral", -110, -395, [20, 17, 24, 21, 18, 25, 19, 22]),
    ("Pasto da Represa", -80, -200, [19, 23, 20, 17, 22, 26, 18, 24]), ("Pasto do Vau", -200, -225, [17, 21, 24, 19, 16, 22, 25, 20]),
    ("Restinga Sul", -150, -468, [26, 18, 15, 20, 28, 17, 16, 22]), ("Restinga do Costão", -60, -450, [20, 24, 18, 16, 22, 26, 19, 17]),
    ("Pasto da Vila", -430, -230, [17, 20, 23, 19, 16, 22, 25, 18]),
]

# ===========================================================================
# 3. Capim ao pé de muros/cercas: (posição ao longo do trecho de 3 m, lado, rot, escala)
# ===========================================================================
PE_DE_MURO = [(0.4, 1, 20, 1.05), (1.6, -1, 140, 0.90), (2.5, 1, 260, 1.15)]
AFAST_MURO = 0.55
# 4. Sob árvore isolada: (tipo, dx, dy, rot, escala) no referencial da árvore
SOB_ARVORE = [("arbusto", 2.2, 1.0, 30, 1.0), ("arbusto", -1.6, -2.0, 150, 1.15), ("capim_alto", 0.6, -2.9, 0, 1.0)]

# ===========================================================================
# 5. OBJETOS LEGÍVEIS nos POIs (poi, tipo, x, y, rot) — preenchido na seção abaixo
# ===========================================================================
# Lista fixada a partir do levantamento de vazios (células de 13 m no núcleo construído de cada POI sem nenhum objeto a
# 7,5 m); cada item escrito aqui com tipo da paleta do lugar (PALETA_POI) e já conferido nas folgas. Ordem: POI, norte->sul.
OBJETOS_POI = [
    # farol_ponta_norte
    ('farol_ponta_norte', 'tambor', 70.0, 531.0, 110),
    ('farol_ponta_norte', 'barril', 31.0, 518.0, 141),
    ('farol_ponta_norte', 'caixote_peixe', 44.0, 518.0, 235),
    ('farol_ponta_norte', 'caixote_peixe', 57.0, 518.0, 16),
    ('farol_ponta_norte', 'caixote_peixe', 96.0, 518.0, 298),
    ('farol_ponta_norte', 'barril', 109.0, 518.0, 126),
    ('farol_ponta_norte', 'barril', 122.0, 518.0, 267),
    ('farol_ponta_norte', 'tambor', 18.0, 505.0, 47),
    ('farol_ponta_norte', 'caixote_peixe', 31.0, 505.0, 94),
    ('farol_ponta_norte', 'caixote_peixe', 109.0, 505.0, 79),
    ('farol_ponta_norte', 'caixote_peixe', 122.0, 505.0, 220),
    ('farol_ponta_norte', 'barril', 18.0, 492.0, 0),
    ('farol_ponta_norte', 'barril', 70.0, 492.0, 63),
    ('farol_ponta_norte', 'caixote_peixe', 83.0, 492.0, 157),
    ('farol_ponta_norte', 'tambor', 96.0, 492.0, 251),
    ('farol_ponta_norte', 'tambor', 109.0, 492.0, 32),
    ('farol_ponta_norte', 'tambor', 122.0, 492.0, 173),
    ('farol_ponta_norte', 'tambor', 57.0, 479.0, 329),
    ('farol_ponta_norte', 'barril', 96.0, 479.0, 204),
    ('farol_ponta_norte', 'barril', 109.0, 479.0, 345),
    ('farol_ponta_norte', 'tambor', 44.0, 466.0, 188),
    ('farol_ponta_norte', 'barril', 57.0, 453.0, 282),
    # fazenda_boa_esperanca
    ('fazenda_boa_esperanca', 'tambor', -149.0, -217.0, 298),
    ('fazenda_boa_esperanca', 'carrinho_mao', -136.0, -217.0, 48),
    ('fazenda_boa_esperanca', 'carrinho_mao', -123.0, -217.0, 236),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -162.0, -230.0, 329),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -136.0, -230.0, 1),
    ('fazenda_boa_esperanca', 'carrinho_mao', -71.0, -230.0, 96),
    ('fazenda_boa_esperanca', 'tambor', -136.0, -243.0, 314),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -71.0, -243.0, 49),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -58.0, -243.0, 237),
    ('fazenda_boa_esperanca', 'tambor', -45.0, -243.0, 18),
    ('fazenda_boa_esperanca', 'tambor', -162.0, -256.0, 282),
    ('fazenda_boa_esperanca', 'tambor', -110.0, -256.0, 330),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -97.0, -256.0, 205),
    ('fazenda_boa_esperanca', 'barril', -45.0, -256.0, 331),
    ('fazenda_boa_esperanca', 'tambor', -32.0, -256.0, 206),
    ('fazenda_boa_esperanca', 'barril', -149.0, -269.0, 251),
    ('fazenda_boa_esperanca', 'barril', -136.0, -269.0, 267),
    ('fazenda_boa_esperanca', 'tambor', -84.0, -269.0, 174),
    ('fazenda_boa_esperanca', 'tambor', -71.0, -269.0, 2),
    ('fazenda_boa_esperanca', 'carrinho_mao', -45.0, -269.0, 284),
    ('fazenda_boa_esperanca', 'barril', -32.0, -269.0, 159),
    ('fazenda_boa_esperanca', 'carrinho_mao', -136.0, -282.0, 220),
    ('fazenda_boa_esperanca', 'barril', -84.0, -282.0, 127),
    ('fazenda_boa_esperanca', 'barril', -71.0, -282.0, 315),
    ('fazenda_boa_esperanca', 'tambor', -58.0, -282.0, 190),
    ('fazenda_boa_esperanca', 'tambor', -175.0, -295.0, 94),
    ('fazenda_boa_esperanca', 'barril', -162.0, -295.0, 235),
    ('fazenda_boa_esperanca', 'carrinho_mao', -149.0, -295.0, 204),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -136.0, -295.0, 173),
    ('fazenda_boa_esperanca', 'carrinho_mao', -162.0, -308.0, 188),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -149.0, -308.0, 157),
    ('fazenda_boa_esperanca', 'tambor', -136.0, -308.0, 126),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -123.0, -308.0, 189),
    ('fazenda_boa_esperanca', 'barril', -110.0, -308.0, 283),
    ('fazenda_boa_esperanca', 'tambor', -97.0, -308.0, 158),
    ('fazenda_boa_esperanca', 'tambor', -149.0, -321.0, 110),
    ('fazenda_boa_esperanca', 'carrinho_mao', -84.0, -321.0, 80),
    ('fazenda_boa_esperanca', 'carrinho_mao', -71.0, -321.0, 268),
    ('fazenda_boa_esperanca', 'barril', -58.0, -321.0, 143),
    ('fazenda_boa_esperanca', 'carrinho_mao', -32.0, -321.0, 112),
    ('fazenda_boa_esperanca', 'carrinho_mao', -188.0, -334.0, 0),
    ('fazenda_boa_esperanca', 'barril', -175.0, -334.0, 47),
    ('fazenda_boa_esperanca', 'barril', -149.0, -334.0, 63),
    ('fazenda_boa_esperanca', 'barril', -136.0, -334.0, 79),
    ('fazenda_boa_esperanca', 'barril', -97.0, -334.0, 111),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -84.0, -334.0, 33),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -32.0, -334.0, 65),
    ('fazenda_boa_esperanca', 'carrinho_mao', -149.0, -347.0, 16),
    ('fazenda_boa_esperanca', 'tambor', -123.0, -347.0, 142),
    ('fazenda_boa_esperanca', 'carrinho_mao', -97.0, -347.0, 64),
    ('fazenda_boa_esperanca', 'tambor', -84.0, -347.0, 346),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -162.0, -360.0, 141),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -136.0, -360.0, 345),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -97.0, -360.0, 17),
    ('fazenda_boa_esperanca', 'barril', -84.0, -360.0, 299),
    ('fazenda_boa_esperanca', 'barril', -123.0, -373.0, 95),
    ('fazenda_boa_esperanca', 'carrinho_mao', -84.0, -373.0, 252),
    ('fazenda_boa_esperanca', 'pilha_tijolo', -71.0, -373.0, 221),
    # morro_cruzeiro
    ('morro_cruzeiro', 'bicicleta', -294.0, 123.0, 236),
    ('morro_cruzeiro', 'lixeira', -372.0, 110.0, 63),
    ('morro_cruzeiro', 'lixeira', -359.0, 110.0, 298),
    ('morro_cruzeiro', 'carrinho_mao', -346.0, 110.0, 79),
    ('morro_cruzeiro', 'tambor', -333.0, 110.0, 267),
    ('morro_cruzeiro', 'pilha_tijolo', -307.0, 110.0, 95),
    ('morro_cruzeiro', 'carrinho_mao', -294.0, 110.0, 189),
    ('morro_cruzeiro', 'pilha_tijolo', -281.0, 110.0, 330),
    ('morro_cruzeiro', 'bicicleta', -372.0, 97.0, 16),
    ('morro_cruzeiro', 'bicicleta', -359.0, 97.0, 251),
    ('morro_cruzeiro', 'pilha_tijolo', -333.0, 97.0, 220),
    ('morro_cruzeiro', 'bicicleta', -320.0, 97.0, 1),
    ('morro_cruzeiro', 'tambor', -294.0, 97.0, 142),
    ('morro_cruzeiro', 'carrinho_mao', -255.0, 97.0, 299),
    ('morro_cruzeiro', 'carrinho_mao', -359.0, 84.0, 204),
    ('morro_cruzeiro', 'lixeira', -333.0, 84.0, 173),
    ('morro_cruzeiro', 'carrinho_mao', -320.0, 84.0, 314),
    ('morro_cruzeiro', 'tambor', -255.0, 84.0, 252),
    ('morro_cruzeiro', 'carrinho_mao', -372.0, 71.0, 329),
    ('morro_cruzeiro', 'tambor', -359.0, 71.0, 157),
    ('morro_cruzeiro', 'carrinho_mao', -242.0, 71.0, 174),
    ('morro_cruzeiro', 'tambor', -372.0, 58.0, 282),
    ('morro_cruzeiro', 'pilha_tijolo', -359.0, 58.0, 110),
    ('morro_cruzeiro', 'tambor', -346.0, 58.0, 32),
    ('morro_cruzeiro', 'bicicleta', -333.0, 58.0, 126),
    ('morro_cruzeiro', 'pilha_tijolo', -255.0, 58.0, 205),
    ('morro_cruzeiro', 'tambor', -242.0, 58.0, 127),
    ('morro_cruzeiro', 'tambor', -398.0, 45.0, 47),
    ('morro_cruzeiro', 'pilha_tijolo', -372.0, 45.0, 235),
    ('morro_cruzeiro', 'lixeira', -255.0, 45.0, 158),
    ('morro_cruzeiro', 'pilha_tijolo', -242.0, 45.0, 80),
    ('morro_cruzeiro', 'lixeira', -372.0, 32.0, 188),
    ('morro_cruzeiro', 'pilha_tijolo', -346.0, 32.0, 345),
    ('morro_cruzeiro', 'lixeira', -242.0, 32.0, 33),
    ('morro_cruzeiro', 'pilha_tijolo', -398.0, 19.0, 0),
    ('morro_cruzeiro', 'carrinho_mao', -385.0, 19.0, 94),
    ('morro_cruzeiro', 'lixeira', -281.0, 19.0, 283),
    ('morro_cruzeiro', 'bicicleta', -242.0, 19.0, 346),
    ('morro_cruzeiro', 'bicicleta', -255.0, 6.0, 111),
    ('morro_cruzeiro', 'carrinho_mao', -255.0, -7.0, 64),
    ('morro_cruzeiro', 'bicicleta', -372.0, -20.0, 141),
    ('morro_cruzeiro', 'tambor', -268.0, -20.0, 17),
    # pedreira
    ('pedreira', 'pilha_tijolo', 322.0, 57.0, 95),
    ('pedreira', 'carrinho_mao', 335.0, 57.0, 283),
    ('pedreira', 'carrinho_mao', 348.0, 57.0, 205),
    ('pedreira', 'pilha_tijolo', 361.0, 57.0, 80),
    ('pedreira', 'tambor', 270.0, 44.0, 282),
    ('pedreira', 'pilha_tijolo', 283.0, 44.0, 251),
    ('pedreira', 'carrinho_mao', 296.0, 44.0, 79),
    ('pedreira', 'tambor', 309.0, 44.0, 267),
    ('pedreira', 'tambor', 322.0, 44.0, 48),
    ('pedreira', 'pilha_tijolo', 348.0, 44.0, 158),
    ('pedreira', 'tambor', 283.0, 31.0, 204),
    ('pedreira', 'carrinho_mao', 309.0, 31.0, 220),
    ('pedreira', 'carrinho_mao', 322.0, 31.0, 1),
    ('pedreira', 'pilha_tijolo', 387.0, 31.0, 2),
    ('pedreira', 'carrinho_mao', 257.0, 18.0, 94),
    ('pedreira', 'pilha_tijolo', 335.0, 18.0, 236),
    ('pedreira', 'tambor', 361.0, 18.0, 33),
    ('pedreira', 'tambor', 374.0, 18.0, 174),
    ('pedreira', 'tambor', 387.0, 18.0, 315),
    ('pedreira', 'pilha_tijolo', 257.0, 5.0, 47),
    ('pedreira', 'carrinho_mao', 270.0, 5.0, 235),
    ('pedreira', 'carrinho_mao', 283.0, 5.0, 157),
    ('pedreira', 'pilha_tijolo', 296.0, 5.0, 32),
    ('pedreira', 'tambor', 335.0, 5.0, 189),
    ('pedreira', 'carrinho_mao', 374.0, 5.0, 127),
    ('pedreira', 'carrinho_mao', 387.0, 5.0, 268),
    ('pedreira', 'tambor', 400.0, 5.0, 96),
    ('pedreira', 'tambor', 257.0, -8.0, 0),
    ('pedreira', 'pilha_tijolo', 270.0, -8.0, 188),
    ('pedreira', 'pilha_tijolo', 283.0, -8.0, 110),
    ('pedreira', 'tambor', 348.0, -8.0, 111),
    ('pedreira', 'carrinho_mao', 361.0, -8.0, 346),
    ('pedreira', 'pilha_tijolo', 387.0, -8.0, 221),
    ('pedreira', 'pilha_tijolo', 413.0, -8.0, 143),
    ('pedreira', 'tambor', 283.0, -21.0, 63),
    ('pedreira', 'tambor', 296.0, -21.0, 345),
    ('pedreira', 'carrinho_mao', 348.0, -21.0, 64),
    ('pedreira', 'carrinho_mao', 400.0, -21.0, 49),
    ('pedreira', 'tambor', 270.0, -34.0, 141),
    ('pedreira', 'carrinho_mao', 283.0, -34.0, 16),
    ('pedreira', 'pilha_tijolo', 309.0, -34.0, 173),
    ('pedreira', 'pilha_tijolo', 361.0, -34.0, 299),
    ('pedreira', 'pilha_tijolo', 283.0, -47.0, 329),
    ('pedreira', 'pilha_tijolo', 348.0, -47.0, 17),
    ('pedreira', 'tambor', 361.0, -47.0, 252),
    ('pedreira', 'carrinho_mao', 296.0, -60.0, 298),
    ('pedreira', 'tambor', 309.0, -60.0, 126),
    ('pedreira', 'tambor', 348.0, -60.0, 330),
    ('pedreira', 'pilha_tijolo', 322.0, -73.0, 314),
    ('pedreira', 'carrinho_mao', 335.0, -73.0, 142),
    # pista_pouso
    ('pista_pouso', 'carrinho_mao', 421.0, -181.0, 205),
    ('pista_pouso', 'carrinho_mao', 434.0, -181.0, 346),
    ('pista_pouso', 'tambor', 252.0, -194.0, 141),
    ('pista_pouso', 'carrinho_mao', 265.0, -194.0, 235),
    ('pista_pouso', 'tambor', 278.0, -194.0, 63),
    ('pista_pouso', 'tambor', 369.0, -194.0, 189),
    ('pista_pouso', 'tambor', 382.0, -194.0, 330),
    ('pista_pouso', 'tambor', 395.0, -194.0, 111),
    ('pista_pouso', 'tambor', 447.0, -194.0, 174),
    ('pista_pouso', 'barril', 304.0, -207.0, 251),
    ('pista_pouso', 'barril', 317.0, -207.0, 32),
    ('pista_pouso', 'tambor', 330.0, -207.0, 126),
    ('pista_pouso', 'carrinho_mao', 343.0, -207.0, 220),
    ('pista_pouso', 'carrinho_mao', 356.0, -207.0, 1),
    ('pista_pouso', 'carrinho_mao', 369.0, -207.0, 142),
    ('pista_pouso', 'carrinho_mao', 447.0, -207.0, 127),
    ('pista_pouso', 'tambor', 239.0, -220.0, 0),
    ('pista_pouso', 'carrinho_mao', 252.0, -220.0, 94),
    ('pista_pouso', 'carrinho_mao', 291.0, -220.0, 157),
    ('pista_pouso', 'tambor', 317.0, -220.0, 345),
    ('pista_pouso', 'carrinho_mao', 330.0, -220.0, 79),
    ('pista_pouso', 'barril', 356.0, -220.0, 314),
    ('pista_pouso', 'barril', 369.0, -220.0, 95),
    ('pista_pouso', 'barril', 447.0, -220.0, 80),
    ('pista_pouso', 'barril', 252.0, -233.0, 47),
    ('pista_pouso', 'tambor', 356.0, -233.0, 267),
    ('pista_pouso', 'tambor', 369.0, -233.0, 48),
    ('pista_pouso', 'carrinho_mao', 382.0, -233.0, 283),
    ('pista_pouso', 'carrinho_mao', 395.0, -233.0, 64),
    ('pista_pouso', 'barril', 434.0, -233.0, 299),
    ('pista_pouso', 'tambor', 447.0, -233.0, 33),
    ('pista_pouso', 'barril', 265.0, -246.0, 188),
    ('pista_pouso', 'carrinho_mao', 278.0, -246.0, 16),
    ('pista_pouso', 'barril', 343.0, -246.0, 173),
    ('pista_pouso', 'barril', 382.0, -246.0, 236),
    ('pista_pouso', 'tambor', 434.0, -246.0, 252),
    ('pista_pouso', 'barril', 278.0, -259.0, 329),
    ('pista_pouso', 'barril', 291.0, -259.0, 110),
    ('pista_pouso', 'tambor', 304.0, -259.0, 204),
    ('pista_pouso', 'carrinho_mao', 317.0, -259.0, 298),
    ('pista_pouso', 'barril', 395.0, -259.0, 17),
    ('pista_pouso', 'barril', 408.0, -259.0, 158),
    ('pista_pouso', 'tambor', 278.0, -272.0, 282),
    # praia_quiosques
    ('praia_quiosques', 'caixote_peixe', 48.0, -413.0, 235),
    ('praia_quiosques', 'caixote_peixe', 61.0, -413.0, 16),
    ('praia_quiosques', 'barril', 61.0, -426.0, 329),
    ('praia_quiosques', 'caixote_peixe', 35.0, -465.0, 0),
    ('praia_quiosques', 'barril', 48.0, -465.0, 141),
    ('praia_quiosques', 'lixeira', 74.0, -465.0, 110),
    ('praia_quiosques', 'caixote_peixe', 113.0, -465.0, 32),
    ('praia_quiosques', 'barril', 126.0, -465.0, 173),
    ('praia_quiosques', 'lixeira', 48.0, -478.0, 94),
    ('praia_quiosques', 'canoa_praia', 87.0, -478.0, 204),
    ('praia_quiosques', 'barril', 113.0, -478.0, 345),
    ('praia_quiosques', 'lixeira', 152.0, -478.0, 314),
    ('praia_quiosques', 'caixote_peixe', 48.0, -491.0, 47),
    ('praia_quiosques', 'barril', 87.0, -491.0, 157),
    ('praia_quiosques', 'lixeira', 113.0, -491.0, 298),
    ('praia_quiosques', 'caixote_peixe', 152.0, -491.0, 267),
    ('praia_quiosques', 'lixeira', 61.0, -504.0, 282),
    ('praia_quiosques', 'caixote_peixe', 74.0, -504.0, 63),
    ('praia_quiosques', 'caixote_peixe', 100.0, -504.0, 251),
    ('praia_quiosques', 'lixeira', 126.0, -504.0, 126),
    ('praia_quiosques', 'canoa_praia', 139.0, -504.0, 220),
    ('praia_quiosques', 'caixote_peixe', 126.0, -517.0, 79),
    # quartel
    ('quartel', 'tambor', 263.0, 365.0, 345),
    ('quartel', 'banco_praca', 276.0, 365.0, 220),
    ('quartel', 'barril', 289.0, 365.0, 95),
    ('quartel', 'banco_praca', 302.0, 365.0, 142),
    ('quartel', 'barril', 328.0, 365.0, 236),
    ('quartel', 'barril', 341.0, 365.0, 299),
    ('quartel', 'barril', 367.0, 365.0, 143),
    ('quartel', 'banco_praca', 380.0, 365.0, 331),
    ('quartel', 'barril', 237.0, 352.0, 329),
    ('quartel', 'banco_praca', 263.0, 352.0, 298),
    ('quartel', 'barril', 276.0, 352.0, 173),
    ('quartel', 'tambor', 289.0, 352.0, 48),
    ('quartel', 'tambor', 341.0, 352.0, 252),
    ('quartel', 'banco_praca', 354.0, 352.0, 268),
    ('quartel', 'tambor', 367.0, 352.0, 96),
    ('quartel', 'tambor', 237.0, 339.0, 282),
    ('quartel', 'tambor', 250.0, 339.0, 63),
    ('quartel', 'tambor', 276.0, 339.0, 126),
    ('quartel', 'banco_praca', 289.0, 339.0, 1),
    ('quartel', 'banco_praca', 341.0, 339.0, 205),
    ('quartel', 'barril', 354.0, 339.0, 221),
    ('quartel', 'banco_praca', 367.0, 339.0, 49),
    ('quartel', 'banco_praca', 237.0, 326.0, 235),
    ('quartel', 'barril', 263.0, 326.0, 251),
    ('quartel', 'banco_praca', 276.0, 326.0, 79),
    ('quartel', 'tambor', 354.0, 326.0, 174),
    ('quartel', 'barril', 367.0, 326.0, 2),
    ('quartel', 'barril', 237.0, 313.0, 188),
    ('quartel', 'barril', 341.0, 313.0, 158),
    ('quartel', 'barril', 380.0, 313.0, 284),
    ('quartel', 'tambor', 393.0, 313.0, 159),
    ('quartel', 'tambor', 237.0, 300.0, 141),
    ('quartel', 'banco_praca', 393.0, 300.0, 112),
    ('quartel', 'tambor', 341.0, 287.0, 111),
    ('quartel', 'tambor', 380.0, 287.0, 237),
    ('quartel', 'barril', 393.0, 287.0, 65),
    ('quartel', 'banco_praca', 237.0, 274.0, 94),
    ('quartel', 'tambor', 263.0, 274.0, 204),
    ('quartel', 'banco_praca', 341.0, 274.0, 64),
    ('quartel', 'banco_praca', 354.0, 274.0, 127),
    ('quartel', 'tambor', 367.0, 274.0, 315),
    ('quartel', 'banco_praca', 380.0, 274.0, 190),
    ('quartel', 'tambor', 393.0, 274.0, 18),
    ('quartel', 'barril', 237.0, 261.0, 47),
    ('quartel', 'banco_praca', 250.0, 261.0, 16),
    ('quartel', 'barril', 289.0, 261.0, 314),
    ('quartel', 'barril', 341.0, 261.0, 17),
    ('quartel', 'barril', 354.0, 261.0, 80),
    ('quartel', 'tambor', 237.0, 248.0, 0),
    ('quartel', 'banco_praca', 263.0, 248.0, 157),
    ('quartel', 'tambor', 289.0, 248.0, 267),
    ('quartel', 'tambor', 341.0, 248.0, 330),
    ('quartel', 'tambor', 354.0, 248.0, 33),
    ('quartel', 'barril', 263.0, 235.0, 110),
    ('quartel', 'barril', 276.0, 235.0, 32),
    ('quartel', 'tambor', 315.0, 235.0, 189),
    ('quartel', 'banco_praca', 341.0, 235.0, 283),
    ('quartel', 'banco_praca', 354.0, 235.0, 346),
    # represa
    ('represa', 'barril', -111.0, -57.0, 110),
    ('represa', 'lixeira', -98.0, -57.0, 298),
    ('represa', 'tambor', -163.0, -70.0, 0),
    ('represa', 'barril', -150.0, -70.0, 47),
    ('represa', 'tambor', -137.0, -83.0, 141),
    ('represa', 'barril', -124.0, -83.0, 329),
    ('represa', 'tambor', -111.0, -83.0, 63),
    ('represa', 'tambor', -124.0, -96.0, 282),
    ('represa', 'barril', -98.0, -96.0, 251),
    ('represa', 'tambor', -46.0, -96.0, 267),
    ('represa', 'lixeira', -137.0, -109.0, 94),
    ('represa', 'lixeira', -111.0, -109.0, 16),
    ('represa', 'tambor', -98.0, -109.0, 204),
    ('represa', 'lixeira', -46.0, -109.0, 220),
    ('represa', 'lixeira', -33.0, -109.0, 1),
    ('represa', 'lixeira', -124.0, -122.0, 235),
    ('represa', 'barril', -85.0, -122.0, 32),
    ('represa', 'barril', -33.0, -122.0, 314),
    ('represa', 'barril', -124.0, -135.0, 188),
    ('represa', 'tambor', -72.0, -135.0, 126),
    ('represa', 'barril', -46.0, -135.0, 173),
    ('represa', 'lixeira', -98.0, -148.0, 157),
    ('represa', 'tambor', -85.0, -148.0, 345),
    ('represa', 'lixeira', -72.0, -148.0, 79),
    # usina_santa_cruz
    ('usina_santa_cruz', 'carrinho_mao', -306.0, 383.0, 173),
    ('usina_santa_cruz', 'pilha_tijolo', -306.0, 370.0, 126),
    ('usina_santa_cruz', 'carrinho_mao', -293.0, 370.0, 1),
    ('usina_santa_cruz', 'barril', -280.0, 370.0, 283),
    ('usina_santa_cruz', 'tambor', -267.0, 370.0, 252),
    ('usina_santa_cruz', 'barril', -254.0, 370.0, 127),
    ('usina_santa_cruz', 'pilha_tijolo', -228.0, 370.0, 2),
    ('usina_santa_cruz', 'pilha_tijolo', -345.0, 357.0, 282),
    ('usina_santa_cruz', 'pilha_tijolo', -332.0, 357.0, 110),
    ('usina_santa_cruz', 'pilha_tijolo', -293.0, 357.0, 314),
    ('usina_santa_cruz', 'tambor', -280.0, 357.0, 236),
    ('usina_santa_cruz', 'carrinho_mao', -267.0, 357.0, 205),
    ('usina_santa_cruz', 'tambor', -254.0, 357.0, 80),
    ('usina_santa_cruz', 'barril', -228.0, 357.0, 315),
    ('usina_santa_cruz', 'barril', -332.0, 344.0, 63),
    ('usina_santa_cruz', 'pilha_tijolo', -319.0, 344.0, 298),
    ('usina_santa_cruz', 'carrinho_mao', -280.0, 344.0, 189),
    ('usina_santa_cruz', 'pilha_tijolo', -267.0, 344.0, 158),
    ('usina_santa_cruz', 'tambor', -215.0, 344.0, 284),
    ('usina_santa_cruz', 'tambor', -332.0, 331.0, 16),
    ('usina_santa_cruz', 'barril', -319.0, 331.0, 251),
    ('usina_santa_cruz', 'barril', -306.0, 331.0, 79),
    ('usina_santa_cruz', 'barril', -293.0, 331.0, 267),
    ('usina_santa_cruz', 'pilha_tijolo', -280.0, 331.0, 142),
    ('usina_santa_cruz', 'carrinho_mao', -215.0, 331.0, 237),
    ('usina_santa_cruz', 'pilha_tijolo', -202.0, 331.0, 18),
    ('usina_santa_cruz', 'tambor', -319.0, 318.0, 204),
    ('usina_santa_cruz', 'barril', -267.0, 318.0, 111),
    ('usina_santa_cruz', 'barril', -189.0, 318.0, 159),
    ('usina_santa_cruz', 'barril', -358.0, 305.0, 47),
    ('usina_santa_cruz', 'carrinho_mao', -332.0, 305.0, 329),
    ('usina_santa_cruz', 'carrinho_mao', -319.0, 305.0, 157),
    ('usina_santa_cruz', 'tambor', -306.0, 305.0, 32),
    ('usina_santa_cruz', 'tambor', -267.0, 305.0, 64),
    ('usina_santa_cruz', 'tambor', -228.0, 305.0, 268),
    ('usina_santa_cruz', 'tambor', -189.0, 305.0, 112),
    ('usina_santa_cruz', 'carrinho_mao', -306.0, 292.0, 345),
    ('usina_santa_cruz', 'pilha_tijolo', -215.0, 292.0, 190),
    ('usina_santa_cruz', 'carrinho_mao', -189.0, 292.0, 65),
    ('usina_santa_cruz', 'carrinho_mao', -267.0, 279.0, 17),
    ('usina_santa_cruz', 'carrinho_mao', -254.0, 279.0, 33),
    ('usina_santa_cruz', 'barril', -215.0, 279.0, 143),
    ('usina_santa_cruz', 'tambor', -358.0, 266.0, 0),
    ('usina_santa_cruz', 'tambor', -280.0, 266.0, 48),
    ('usina_santa_cruz', 'pilha_tijolo', -267.0, 266.0, 330),
    ('usina_santa_cruz', 'pilha_tijolo', -254.0, 266.0, 346),
    ('usina_santa_cruz', 'tambor', -215.0, 266.0, 96),
    ('usina_santa_cruz', 'tambor', -293.0, 253.0, 220),
    ('usina_santa_cruz', 'barril', -254.0, 253.0, 299),
    ('usina_santa_cruz', 'barril', -202.0, 253.0, 331),
    ('usina_santa_cruz', 'pilha_tijolo', -345.0, 240.0, 94),
    ('usina_santa_cruz', 'carrinho_mao', -215.0, 240.0, 49),
    ('usina_santa_cruz', 'pilha_tijolo', -241.0, 227.0, 174),
    ('usina_santa_cruz', 'carrinho_mao', -228.0, 227.0, 221),
    # vila_caicara
    ('vila_caicara', 'caixote_peixe', -396.0, -259.0, 48),
    ('vila_caicara', 'tambor', -383.0, -259.0, 189),
    ('vila_caicara', 'tambor', -370.0, -259.0, 111),
    ('vila_caicara', 'lixeira', -357.0, -259.0, 127),
    ('vila_caicara', 'caixote_peixe', -422.0, -272.0, 204),
    ('vila_caicara', 'bicicleta', -370.0, -272.0, 64),
    ('vila_caicara', 'carrinho_mao', -357.0, -272.0, 80),
    ('vila_caicara', 'tambor', -357.0, -285.0, 33),
    ('vila_caicara', 'tambor', -344.0, -285.0, 315),
    ('vila_caicara', 'lixeira', -396.0, -298.0, 1),
    ('vila_caicara', 'barril', -370.0, -298.0, 17),
    ('vila_caicara', 'bicicleta', -357.0, -298.0, 346),
    ('vila_caicara', 'caixote_peixe', -448.0, -311.0, 282),
    ('vila_caicara', 'carrinho_mao', -409.0, -311.0, 32),
    ('vila_caicara', 'carrinho_mao', -396.0, -311.0, 314),
    ('vila_caicara', 'caixote_peixe', -331.0, -311.0, 96),
    ('vila_caicara', 'barril', -305.0, -311.0, 65),
    ('vila_caicara', 'carrinho_mao', -461.0, -324.0, 188),
    ('vila_caicara', 'lixeira', -448.0, -324.0, 235),
    ('vila_caicara', 'tambor', -409.0, -324.0, 345),
    ('vila_caicara', 'tambor', -396.0, -324.0, 267),
    ('vila_caicara', 'lixeira', -331.0, -324.0, 49),
    ('vila_caicara', 'tambor', -461.0, -337.0, 141),
    ('vila_caicara', 'bicicleta', -435.0, -337.0, 16),
    ('vila_caicara', 'bicicleta', -396.0, -337.0, 220),
    ('vila_caicara', 'bicicleta', -344.0, -337.0, 268),
    ('vila_caicara', 'lixeira', -279.0, -337.0, 253),
    ('vila_caicara', 'bicicleta', -461.0, -350.0, 94),
    ('vila_caicara', 'lixeira', -422.0, -350.0, 157),
    ('vila_caicara', 'bicicleta', -409.0, -350.0, 298),
    ('vila_caicara', 'caixote_peixe', -370.0, -350.0, 330),
    ('vila_caicara', 'carrinho_mao', -279.0, -350.0, 206),
    ('vila_caicara', 'barril', -461.0, -363.0, 47),
    ('vila_caicara', 'carrinho_mao', -422.0, -363.0, 110),
    ('vila_caicara', 'lixeira', -370.0, -363.0, 283),
    ('vila_caicara', 'caixote_peixe', -305.0, -363.0, 18),
    ('vila_caicara', 'caixote_peixe', -461.0, -376.0, 0),
    ('vila_caicara', 'barril', -435.0, -376.0, 329),
    ('vila_caicara', 'tambor', -422.0, -376.0, 63),
    ('vila_caicara', 'carrinho_mao', -370.0, -376.0, 236),
    ('vila_caicara', 'barril', -357.0, -376.0, 299),
    ('vila_caicara', 'bicicleta', -292.0, -376.0, 112),
    ('vila_caicara', 'tambor', -279.0, -376.0, 159),
    ('vila_caicara', 'barril', -396.0, -389.0, 173),
    ('vila_caicara', 'bicicleta', -383.0, -389.0, 142),
    ('vila_caicara', 'caixote_peixe', -357.0, -389.0, 252),
    ('vila_caicara', 'caixote_peixe', -396.0, -402.0, 126),
    ('vila_caicara', 'lixeira', -357.0, -402.0, 205),
    ('vila_caicara', 'caixote_peixe', -344.0, -402.0, 174),
    ('vila_caicara', 'carrinho_mao', -331.0, -402.0, 2),
    ('vila_caicara', 'tambor', -318.0, -402.0, 237),
    ('vila_caicara', 'lixeira', -305.0, -402.0, 331),
    ('vila_caicara', 'barril', -409.0, -415.0, 251),
    ('vila_caicara', 'carrinho_mao', -357.0, -415.0, 158),
    ('vila_caicara', 'bicicleta', -318.0, -415.0, 190),
    ('vila_caicara', 'carrinho_mao', -305.0, -415.0, 284),
    ('vila_caicara', 'lixeira', -396.0, -428.0, 79),
    ('vila_caicara', 'barril', -383.0, -428.0, 95),
    ('vila_caicara', 'barril', -318.0, -428.0, 143),
]


def ponto_mais_proximo(pts, x, y):
    best = None
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        vx, vy = bx - ax, by - ay; L2 = vx * vx + vy * vy
        t = max(0.0, min(1.0, ((x - ax) * vx + (y - ay) * vy) / L2))
        q = (ax + t * vx, ay + t * vy); d = math.dist(q, (x, y))
        if best is None or d < best[0]: best = (d, q)
    return best[1]


def construir_trilhas(W):
    pb = {b["id"]: b for b in W.predios}
    vias = {e["id"]: e for e in W.vias}
    out = []
    for bid, (dest, wps) in TRILHAS_PORTA.items():
        b = pb[bid]; w, d, _ = b["tamanho_m"]
        pts = [D.mundo(b, 0, -d / 2 - 0.3), D.mundo(b, 0, -d / 2 - FRENTE.get(bid, 2.5))]
        for wp in wps:
            pts.append(D.mundo(b, wp[1], wp[2]) if wp[0] == "L" else (wp[1], wp[2]))
        if dest[0] == "via":
            e = vias[dest[1]]
            q = ponto_mais_proximo(e["pontos"], *pts[-1])
            L = math.dist(q, pts[-1]); hw = e["largura_m"] / 2
            if L > hw: q = (q[0] + (pts[-1][0] - q[0]) * hw / L, q[1] + (pts[-1][1] - q[1]) * hw / L)
            pts.append(q)
        else:
            pts.append((dest[1], dest[2]))
        out.append({"nome": f"porta {bid}", "origem": bid, "pontos": pts})
    for a in ATALHOS:
        out.append({"nome": a["nome"], "origem": "atalho", "pontos": list(a["pontos"])})
    return out


def validar_trilha(W, t):
    pts = t["pontos"]; ori = t["origem"]
    for i in range(len(pts) - 1):
        for q in D.amostrar_seg(pts[i], pts[i + 1], 0.5) if hasattr(D, "amostrar_seg") else []:
            pass
    amostras = []
    for i in range(len(pts) - 1):
        (x1, y1), (x2, y2) = pts[i], pts[i + 1]
        n = max(1, int(math.dist(pts[i], pts[i + 1]) / 0.5))
        amostras += [(x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n) for k in range(n + 1)]
    for (x, y) in amostras:
        if W.agua(x, y): return f"água em ({x:.0f},{y:.0f})"
        for b in W.predios:
            if abs(b["pos"][0] - x) > 40 or abs(b["pos"][1] - y) > 40: continue
            if b["id"] == ori:
                if D.dist_obb(b, x, y) < 0.05: return f"atravessa o próprio prédio em ({x:.0f},{y:.0f})"
                continue
            if D.dist_obb(b, x, y) < 0.3: return f"atravessa {b['id']} em ({x:.0f},{y:.0f})"
    return None


PALETA_POI = {
    "vila_caicara": ["caixote_peixe", "barril", "bicicleta", "tambor", "carrinho_mao", "lixeira"],
    "morro_cruzeiro": ["pilha_tijolo", "tambor", "carrinho_mao", "bicicleta", "lixeira"],
    "usina_santa_cruz": ["tambor", "barril", "pilha_tijolo", "carrinho_mao"],
    "quartel": ["tambor", "barril", "banco_praca"],
    "fazenda_boa_esperanca": ["carrinho_mao", "barril", "tambor", "pilha_tijolo"],
    "praia_quiosques": ["canoa_praia", "caixote_peixe", "lixeira", "barril"],
    "pista_pouso": ["tambor", "barril", "carrinho_mao"],
    "pedreira": ["tambor", "pilha_tijolo", "carrinho_mao"],
    "represa": ["tambor", "barril", "lixeira"],
    "farol_ponta_norte": ["barril", "tambor", "caixote_peixe"],
}
MEIO_OBJ = {"canoa_praia": 2.6, "banco_praca": 1.0, "bicicleta": 0.8, "carrinho_mao": 0.6, "pilha_tijolo": 0.6}


class Ocupacao:
    """Tudo que já é 'objeto legível' no chão: props, postes, coberturas, cercas, prédios, troncos."""
    def __init__(self, W, det, game):
        pts = [(p["x"], p["y"]) for p in det["props"]]
        pts += [tuple(q) for L in det["linhas_fiacao"] for q in L["postes"]]
        pts += [tuple(c["pos"]) for c in W.lay["cobertura_campo_aberto"]] + [tuple(c["pos"]) for c in game["coberturas_novas"]]
        for c in det["cercas"]:
            for i in range(len(c["pontos"]) - 1):
                (x1, y1), (x2, y2) = c["pontos"][i], c["pontos"][i + 1]
                n = max(1, int(math.dist(c["pontos"][i], c["pontos"][i + 1]) / 2))
                pts += [(x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n) for k in range(n + 1)]
        for b in W.predios:
            w, d, _ = b["tamanho_m"]
            cs = [D.mundo(b, sx * w / 2, sy * d / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            for i in range(4):
                (x1, y1), (x2, y2) = cs[i], cs[(i + 1) % 4]
                n = max(1, int(math.dist(cs[i], cs[(i + 1) % 4]) / 2))
                pts += [(x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n) for k in range(n + 1)]
        veg = json.load(open(D.VEG, encoding="utf-8"))["instancias"]
        self.veg = veg
        pts += [(v["x"], v["y"]) for v in veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro", "bananeira")]
        self.tree = cKDTree(np.array(pts))
        self.cercas = [c["pontos"] for c in det["cercas"]]
        self.troncos = cKDTree(np.array([(v["x"], v["y"]) for v in veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro", "bananeira")]))


def folga_objeto(W, O, x, y, rot, tipo):
    h = MEIO_OBJ.get(tipo, 0.0); r = math.radians(rot)
    for (px, py) in [(x, y)] + ([(x + s * h * math.cos(r), y + s * h * math.sin(r)) for s in (-1, 1)] if h else []):
        m = W.motivo_ponto(px, py, None, prop=True)
        if m: return m
        if any(abs(c[0][0] - px) < 400 and D.dist_poli(px, py, c) < 0.8 for c in O.cercas): return "cerca"
        if O.troncos.query((px, py))[0] < 0.9: return "tronco"
    return None


def vazios_poi(W, O, passo=13.0, raio_livre=7.5):
    """Células de 13 m dentro de cada POI sem nenhum objeto a 7,5 m (só terra, fora de via)."""
    out = []
    for p in W.lay["pois"]:
        cx, cy = p["centro"]; R = p["raio_m"]
        n = int(R // passo)
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                x, y = cx + i * passo, cy + j * passo
                if math.dist((x, y), (cx, cy)) > R: continue
                # só o núcleo construído: a até 30 m de um prédio do próprio POI (campo aberto já tem as coberturas)
                if min(D.dist_obb(bb, x, y) for bb in p["predios"]) > 30: continue
                if p["id"] == "quartel" and 285 <= x <= 340 and 272 <= y <= 328: continue   # pátio de formatura fica livre
                if W.agua(x, y): continue
                if any(D.dist_poli(x, y, e["pontos"]) < e["largura_m"] / 2 + 1.0 for e in W.vias): continue
                if any(D.dist_obb(b, x, y) == 0 for b in W.predios if abs(b["pos"][0] - x) < 30 and abs(b["pos"][1] - y) < 30): continue
                if any(D.dentro(m["muro"], x, y) for m in W.lay["pois"] if "muro" in m) and p["id"] != "quartel": continue
                if O.tree.query((x, y))[0] > raio_livre: out.append((p["id"], x, y))
    return out


def rascunho(W, O):
    vz = vazios_poi(W, O)
    cont = Counter(); linhas = []
    for (poi, x, y) in vz:
        pal = PALETA_POI[poi]
        for (dx, dy) in ((0, 0), (2, 0), (-2, 0), (0, 2), (0, -2), (3, 3), (-3, -3), (3, -3), (-3, 3), (5, 0), (-5, 0), (0, 5), (0, -5)):
            t = pal[cont[poi] % len(pal)]
            if poi == "praia_quiosques" and t == "canoa_praia" and W.z(x + dx, y + dy) > 3.0: t = "caixote_peixe"
            rot = (cont[poi] * 47) % 360
            if not folga_objeto(W, O, x + dx, y + dy, rot, t):
                linhas.append((poi, t, round(x + dx, 1), round(y + dy, 1), rot)); cont[poi] += 1; break
    print(f"# {len(vz)} células vazias, {len(linhas)} objetos")
    for l in linhas: print(f"    {l},")


def folga_planta(W, O, x, y, predio=1.0, via=1.0):
    if W.agua(x, y): return "água"
    for e in W.vias:
        if D.dist_poli(x, y, e["pontos"]) < e["largura_m"] / 2 + via: return "via"
    for b in W.predios:
        if abs(b["pos"][0] - x) > 40 or abs(b["pos"][1] - y) > 40: continue
        if D.dist_obb(b, x, y) < predio: return "prédio"
        if D.na_porta(b, x, y): return "porta"
    return None


def gerar(W, det, game, O, trilhas):
    desc = Counter()
    # --- 2. manchas de capim seco
    manchas = []
    for (nome, cx, cy, raios) in CAPIM_SECO:
        pol = [(round(cx + r * math.cos(math.radians(45 * k)), 1), round(cy + r * math.sin(math.radians(45 * k)), 1)) for k, r in enumerate(raios)]
        if not D.dentro(W.lay["costa"], cx, cy) or W.agua(cx, cy):
            raise SystemExit(f"mancha {nome}: centro fora da terra")
        dentro_terra = sum(1 for q in pol if D.dentro(W.lay["costa"], *q))
        manchas.append({"nome": nome, "cor": "#B29C5C", "poligono": [list(q) for q in pol],
                        "area_m2": round(0.5 * abs(sum(pol[k][0] * pol[(k + 1) % 8][1] - pol[(k + 1) % 8][0] * pol[k][1] for k in range(8)))),
                        "vertices_na_terra": dentro_terra})
    # --- 3. capim ao pé de muros e cercas
    capim_muro = []
    for c in det["cercas"]:
        pts = c["pontos"]
        for i in range(len(pts) - 1):
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            L = math.dist(pts[i], pts[i + 1]); ux, uy = (x2 - x1) / L, (y2 - y1) / L; nx, ny = -uy, ux
            k = 0.0
            while k < L - 0.1:
                for (a, lado, rot, esc) in PE_DE_MURO:
                    if k + a > L: continue
                    x = x1 + ux * (k + a) + nx * AFAST_MURO * lado; y = y1 + uy * (k + a) + ny * AFAST_MURO * lado
                    m = folga_planta(W, O, x, y, predio=0.5, via=1.0)
                    if m: desc["capim de muro: " + m] += 1; continue
                    capim_muro.append({"tipo": "capim_alto", "x": round(x, 2), "y": round(y, 2), "z": round(W.z(x, y), 2),
                                       "rot_deg": rot, "escala": esc, "mancha": f"pé de {c['tipo']} ({c['poi']})"})
                k += 3.0
    # --- 4. arbustos sob árvores isoladas
    arv = [v for v in O.veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro")]
    tr = cKDTree(np.array([(v["x"], v["y"]) for v in arv]))
    sob, n_iso = [], 0
    for v in arv:
        if len(tr.query_ball_point((v["x"], v["y"]), 12.0)) > 1: continue
        n_iso += 1
        r = math.radians(v["rot_deg"])
        for (t, dx, dy, rot, esc) in SOB_ARVORE:
            x = v["x"] + dx * math.cos(r) - dy * math.sin(r); y = v["y"] + dx * math.sin(r) + dy * math.cos(r)
            m = folga_planta(W, O, x, y, predio=4.0, via=3.0)
            if m: desc["sob árvore: " + m] += 1; continue
            sob.append({"tipo": t, "x": round(x, 2), "y": round(y, 2), "z": round(W.z(x, y), 2), "rot_deg": (v["rot_deg"] + rot) % 360,
                        "escala": esc, "mancha": "sob árvore isolada"})
    # --- 5. objetos legíveis (lista explícita) — valida e trava se algum violar
    erros, objs = [], []
    for (poi, t, x, y, rot) in OBJETOS_POI:
        m = folga_objeto(W, O, x, y, rot, t)
        if m: erros.append(f"objeto {t} ({x},{y}): {m}")
        objs.append({"tipo": t, "x": x, "y": y, "rot_deg": rot, "poi": poi})
    for o in objs:
        for t in trilhas:
            if D.dist_poli(o["x"], o["y"], t["pontos"]) < 1.2: erros.append(f"objeto {o['tipo']} ({o['x']},{o['y']}) sobre a trilha {t['nome']}")
    for cb in game["coberturas_novas"]:
        for t in trilhas:
            if D.dist_poli(cb["pos"][0], cb["pos"][1], t["pontos"]) < 2.0: erros.append(f"cobertura {cb['tipo']} {cb['pos']} sobre a trilha {t['nome']}")
    if erros:
        print("ERROS:"); [print("  ", e) for e in erros]; return 1
    # --- saída
    trilhas_out = [{"nome": t["nome"], "largura_m": 1.2, "cor": "#A0764C", "opacidade": 0.4,
                    "pontos": [[round(q[0], 2), round(q[1], 2)] for q in t["pontos"]],
                    "comprimento_m": round(sum(math.dist(t["pontos"][i], t["pontos"][i + 1]) for i in range(len(t["pontos"]) - 1)), 1)}
                   for t in trilhas]
    veg_novas = capim_muro + sob
    doc = {
        "versao": 1, "fonte": "tools/chao_vivo_src.py (trilhas, manchas, padrões e objetos escritos à mão; sem sorteio)",
        "trilhas_pe": trilhas_out,
        "manchas_capim_seco": manchas,
        "vegetacao_extra": {"nota": "instâncias a ACRESCENTAR ao vegetacao.json (mesmo formato)", "instancias": veg_novas},
        "objetos_poi": objs,
        "resumo": {
            "trilhas_porta": sum(1 for t in trilhas if t["origem"] != "atalho"), "atalhos": sum(1 for t in trilhas if t["origem"] == "atalho"),
            "trilhas_m": round(sum(t["comprimento_m"] for t in trilhas_out)),
            "manchas_capim_seco": len(manchas), "manchas_area_m2": sum(m["area_m2"] for m in manchas),
            "capim_pe_de_muro": len(capim_muro), "arvores_isoladas": n_iso, "plantas_sob_arvore": dict(Counter(v["tipo"] for v in sob)),
            "objetos_por_poi": dict(Counter(o["poi"] for o in objs)), "objetos_por_tipo": dict(Counter(o["tipo"] for o in objs)),
            "descartes_por_folga": dict(desc),
        },
    }
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    preview(W, det, game, doc)
    print(json.dumps(doc["resumo"], ensure_ascii=False, indent=1))
    return 0


def preview(W, det, game, doc):
    from PIL import Image, ImageDraw
    im = Image.open(os.path.join(RAIZ, "docs", "design", "ilha_radar.png")).convert("RGBA")
    S = 1024 / 1200.0; P = lambda x, y: ((x + 600) * S, (600 - y) * S)
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for m in doc["manchas_capim_seco"]:
        d.polygon([P(*q) for q in m["poligono"]], fill=(178, 156, 92, 150))
    for t in doc["trilhas_pe"]:
        d.line([P(*q) for q in t["pontos"]], fill=(160, 118, 76, 255), width=2)
    for c in game["coberturas_novas"]:
        x, y = P(*c["pos"]); d.rectangle([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(255, 80, 40, 255))
    for o in doc["objetos_poi"]:
        x, y = P(o["x"], o["y"]); d.ellipse([x - 1.3, y - 1.3, x + 1.3, y + 1.3], fill=(40, 120, 255, 255))
    for v in doc["vegetacao_extra"]["instancias"]:
        x, y = P(v["x"], v["y"]); d.point((x, y), fill=(210, 230, 90, 255))
    im = Image.alpha_composite(im, ov)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 12, 300, 92], fill=(15, 25, 35, 220))
    for k, (c, t) in enumerate([((178, 156, 92), "capim seco"), ((160, 118, 76), "trilhas de pé"), ((255, 80, 40), "coberturas novas (gameplay_01)"), ((40, 120, 255), "objetos legíveis nos POIs")]):
        d.rectangle([20, 20 + k * 17, 32, 30 + k * 17], fill=c); d.text((40, 18 + k * 17), t, fill=(255, 255, 255))
    im.convert("RGB").save(PREVIEW)


def main():
    W = D.Mundo()
    det = json.load(open(DET, encoding="utf-8"))
    erros = []
    trilhas = construir_trilhas(W)
    for t in trilhas:
        m = validar_trilha(W, t)
        if m: erros.append(f"trilha {t['nome']}: {m}")
    if erros:
        print(f"{len(erros)} ERROS"); [print("  ", e) for e in erros]
        return 1
    print("trilhas ok", len(trilhas))
    game = json.load(open(GAME, encoding="utf-8"))
    O = Ocupacao(W, det, game)
    if "--rascunho" in sys.argv:
        rascunho(W, O); return 0
    return gerar(W, det, game, O, trilhas)


if __name__ == "__main__":
    sys.exit(main())
