# -*- coding: utf-8 -*-
"""
Fonte AUTORAL da vegetação da Ilha do Tauá  ->  docs/design/vegetacao.json
                                              +  raw/vegetacao_preview.png (sobre o radar)

Como está desenhado (nada de random / ruído / scatter):
  1. CARIMBOS: aglomerados desenhados à mão, cada planta com offset (dx, dy), rot e escala escritos
     explicitamente (seção 1).
  2. ÂNCORAS: cada uso de carimbo tem posição x, y e giro escritos à mão, mancha por mancha (seção 2).
     Loops existem apenas para percorrer essas listas escritas à mão.
  3. BEIRA DE ESTRADA: touceiras de capim posicionadas por (via, distância ao longo da via em m, lado),
     também escritas à mão; o script só converte para x, y (offset = meia largura + 4,5 m).
  4. FOLGAS (regra fixa, determinística): uma planta é descartada se cair no mar, na represa, no leito do
     rio, a < 3 m de via, a < 4 m de prédio, dentro do muro do quartel/terreiro, ou a < 3 m de outra árvore
     (planta menor: < 1,2 m). O relatório lista quantas caíram por motivo.

Uso:  python tools/vegetacao_src.py
"""
import json, math, os, sys
from collections import Counter, defaultdict
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(RAIZ, "docs", "design", "ilha_layout.json")
HEIGHT = os.path.join(RAIZ, "game", "maps", "ilha", "height.bin")
SAIDA = os.path.join(RAIZ, "docs", "design", "vegetacao.json")
PREVIEW = os.path.join(RAIZ, "raw", "vegetacao_preview.png")
RADAR = os.path.join(RAIZ, "docs", "design", "ilha_radar.png")

A, B, C, AR, BA, CA, PE = "arvore_mata_a", "arvore_mata_b", "coqueiro", "arbusto", "bananeira", "capim_alto", "pedra_pequena"
ARVORES = {A, B, C}

# ===========================================================================
# 1. CARIMBOS (tipo, dx, dy, rot_deg, escala) — desenhados à mão
# ===========================================================================
CARIMBO = {
    # Mata densa: célula ~28 x 28 m, 9 árvores (1 a cada ~9 m) + sub-bosque
    "D1": [(A, -10, -9, 20, 1.10), (B, -1, -11, 75, 1.00), (A, 9, -8, 140, 0.95), (B, -12, 0, 210, 1.15),
           (A, 0, -1, 300, 1.25), (B, 10, 2, 35, 0.90), (A, -8, 10, 95, 1.00), (B, 2, 9, 160, 1.20),
           (A, 11, 11, 250, 1.05), (AR, -5, -4, 0, 0.90), (AR, 6, -3, 120, 1.10), (AR, -3, 5, 240, 1.00)],
    "D2": [(B, -11, -11, 40, 1.00), (A, -2, -7, 110, 1.20), (B, 8, -12, 190, 0.90), (A, 12, -3, 260, 1.00),
           (B, -9, -1, 330, 1.10), (A, 3, 3, 15, 0.95), (B, -12, 9, 85, 1.25), (A, -2, 12, 145, 1.05),
           (B, 9, 9, 225, 1.15), (AR, 5, -6, 60, 1.20), (AR, -6, 5, 180, 0.90), (PE, 13, 4, 30, 1.00)],
    # Mata média: 5 árvores por célula (~12 m entre copas), mais arbustos
    "M1": [(A, -8, -8, 10, 1.10), (B, 9, -6, 130, 1.00), (A, 0, 2, 250, 1.20), (B, -9, 9, 70, 0.90),
           (A, 10, 10, 190, 1.00), (AR, -2, -10, 0, 1.00), (AR, 5, 6, 90, 1.20), (AR, -11, 1, 200, 0.90),
           (CA, 12, -1, 0, 1.00)],
    # Capoeira: arbustos altos, uma árvore jovem, capim nas bordas
    "CP": [(AR, -9, -7, 0, 1.20), (AR, -3, -9, 45, 1.00), (AR, 5, -6, 90, 1.30), (AR, 10, -1, 135, 0.90),
           (AR, -8, 2, 180, 1.10), (AR, 1, 1, 225, 1.25), (AR, -4, 9, 270, 0.95), (AR, 7, 8, 315, 1.15),
           (A, 2, -2, 60, 0.85), (CA, -12, -2, 0, 1.00), (CA, 12, 6, 0, 1.10), (CA, 0, 12, 0, 0.90)],
    # Mata ciliar: faixa 16 x 12 m (alinhar o giro com o rio)
    "CL": [(A, -7, -3, 30, 1.00), (B, -1, 3, 100, 1.10), (A, 5, -2, 200, 0.90), (B, 8, 4, 280, 1.20),
           (AR, -4, 4, 0, 1.00), (AR, 2, -4, 90, 1.10)],
    # Bananal: touceira de 8 bananeiras (~14 m)
    "BN": [(BA, -5, -5, 0, 1.00), (BA, 0, -6, 50, 1.10), (BA, 5, -4, 100, 0.90), (BA, -6, 0, 150, 1.20),
           (BA, 1, 0, 200, 1.00), (BA, 6, 2, 250, 1.15), (BA, -3, 5, 300, 0.95), (BA, 3, 6, 350, 1.05)],
    # Quintal: 3 bananeiras, arbusto, coqueiro (junto a casas)
    "QT": [(BA, -2, -1, 0, 1.00), (BA, 1, 1, 120, 1.10), (BA, -1, 3, 240, 0.90), (AR, 3, -3, 60, 1.00),
           (C, -4, 4, 20, 1.10), (CA, 4, 3, 0, 0.90)],
    # Fila de coqueiros ao longo da praia (31 m)
    "FC": [(C, 0, 0, 10, 1.10), (C, 8, 2, 80, 0.95), (C, 15, -1, 150, 1.25), (C, 23, 3, 220, 1.00), (C, 31, 0, 300, 1.15),
           (CA, 4, -3, 0, 0.90), (CA, 19, 5, 0, 1.00)],
    # Restinga: arbusto baixo, capim, pedra — célula 28 m
    "RS": [(AR, -9, -6, 0, 0.80), (AR, 4, -9, 70, 0.90), (AR, 10, 4, 140, 0.85), (AR, -4, 7, 210, 0.95),
           (CA, -12, 3, 0, 1.00), (CA, 0, 0, 0, 1.10), (CA, 7, -3, 0, 0.90), (CA, 3, 11, 0, 1.00), (PE, -8, 11, 45, 0.90)],
    # Fila de eucaliptos (quebra-vento), 10 troncos a cada 4 m
    "EU": [(B, 0, 0, 0, 1.20), (B, 4, 0.3, 40, 1.10), (B, 8, -0.2, 80, 1.25), (B, 12, 0.4, 120, 1.15), (B, 16, 0, 160, 1.20),
           (B, 20, -0.3, 200, 1.30), (B, 24, 0.2, 240, 1.10), (B, 28, 0, 280, 1.20), (B, 32, -0.4, 320, 1.25), (B, 36, 0.1, 350, 1.15)],
    # Touceira de capim alto (campos e bordas)
    "TC": [(CA, 0, 0, 0, 1.00), (CA, 1.8, 0.6, 40, 1.20), (CA, -1.5, 1.2, 80, 0.90), (CA, 0.6, -1.7, 120, 1.10), (CA, -1.2, -1.4, 160, 0.85)],
    # Árvore isolada de pasto (marco de cobertura) com sombra de arbustos
    "AI": [(A, 0, 0, 0, 1.30), (AR, 4, -3, 30, 1.00), (CA, -4, 2, 0, 1.10), (CA, 2, 5, 0, 0.90)],
    # Pedras soltas
    "P3": [(PE, 0, 0, 0, 1.20), (PE, 2.5, 1, 70, 0.90), (PE, -1.5, 2.2, 140, 1.00)],
    # Vegetação de costão/falésia: arbustos varridos pelo vento
    "CT": [(AR, 0, 0, 0, 0.90), (AR, 4, 2, 90, 1.10), (CA, -3, 2, 0, 1.00), (PE, 2, -3, 45, 1.10)],
}

# ===========================================================================
# 2. ÂNCORAS por mancha: (x, y, carimbo, giro_deg) — escritas à mão
# ===========================================================================
def fila(y, xs_carimbos):
    """Açúcar sintático: uma fileira de âncoras na mesma cota y (x, carimbo, giro escritos à mão)."""
    return [(x, y, c, g) for (x, c, g) in xs_carimbos]

MANCHAS = {
    "Mata da Serra": {"clip": "Mata da Serra", "ancoras":
        fila(202, [(-128, "D1", 0), (-100, "D2", 90), (-72, "D1", 180), (-44, "D2", 270), (-16, "D1", 45), (12, "D2", 135), (40, "D1", 225)]) +
        fila(176, [(-170, "D2", 0), (-142, "D1", 270), (-114, "D2", 180), (-86, "D1", 90), (-58, "D2", 315), (-30, "D1", 0), (-2, "D2", 45), (26, "D1", 180), (50, "D2", 90)]) +
        fila(150, [(-186, "D1", 90), (-158, "D2", 0), (-130, "D1", 135), (-102, "D2", 270), (-74, "D1", 0), (-46, "D2", 180), (-18, "D1", 90), (10, "D2", 315)]) +
        fila(126, [(-150, "D2", 45), (-122, "D1", 225), (-94, "D2", 0), (-66, "D1", 90), (-38, "D2", 180), (-12, "D1", 270)])},
    "Mata da Serra Leste": {"clip": "Mata da Serra Leste", "ancoras":
        fila(172, [(124, "D2", 0), (152, "D1", 90), (180, "D2", 180)]) +
        fila(148, [(124, "D1", 270), (152, "D2", 45), (180, "D1", 135), (208, "D2", 0)]) +
        fila(122, [(170, "D2", 225), (198, "D1", 315), (226, "D2", 90), (252, "D1", 0)]) +
        fila(96, [(230, "D1", 180), (258, "D2", 270), (282, "D1", 45)]) +
        [(138, 160, "D2", 135), (166, 135, "D1", 315), (212, 110, "D2", 180), (240, 104, "D1", 90)]},
    "Mata do Esporão Norte": {"clip": "Mata do Esporão Norte", "ancoras":
        fila(252, [(45, "M1", 0), (72, "M1", 90), (98, "M1", 180)]) +
        fila(280, [(44, "M1", 270), (70, "M1", 45), (96, "M1", 135)]) +
        fila(308, [(44, "M1", 0), (70, "M1", 180), (95, "M1", 90)]) +
        fila(336, [(45, "M1", 315), (70, "M1", 225), (94, "M1", 0)]) +
        fila(364, [(50, "M1", 90), (75, "M1", 270)]) +
        fila(392, [(52, "M1", 180), (80, "M1", 0)])},
    "Mata do Morro do Sul": {"clip": "Mata do Morro do Sul", "ancoras":
        fila(-56, [(110, "D1", 0), (138, "D2", 90), (166, "D1", 180), (194, "D2", 270)]) +
        fila(-82, [(70, "D2", 45), (98, "D1", 135), (126, "D2", 225), (154, "D1", 315), (182, "D2", 0), (210, "D1", 90)]) +
        fila(-108, [(50, "D1", 180), (78, "D2", 270), (106, "D1", 0), (134, "D2", 90), (162, "D1", 45), (190, "D2", 180), (218, "D1", 270)]) +
        fila(-134, [(50, "D2", 0), (78, "D1", 90), (106, "D2", 180), (134, "D1", 270), (162, "D2", 315), (190, "D1", 45), (218, "D2", 135)]) +
        fila(-160, [(70, "D1", 225), (98, "D2", 0), (126, "D1", 90), (154, "D2", 180), (182, "D1", 270), (210, "D2", 45)]) +
        fila(-186, [(110, "D2", 90), (138, "D1", 0), (166, "D2", 270)])},
    "Mata da Encosta Norte": {"clip": "Mata da Encosta Norte", "ancoras":
        fila(228, [(-130, "D1", 90), (-102, "D2", 180), (-74, "D1", 270), (-46, "D2", 0), (-18, "D1", 135), (10, "D2", 225)]) +
        fila(254, [(-140, "D2", 315), (-112, "D1", 45), (-84, "D2", 90), (-56, "D1", 180), (-28, "D2", 270), (0, "D1", 0), (25, "D2", 135)]) +
        fila(280, [(-120, "M1", 0), (-92, "D1", 225), (-64, "D2", 45), (-36, "D1", 315), (-8, "D2", 180)]) +
        fila(304, [(-80, "M1", 90), (-52, "M1", 270), (-24, "M1", 0)])},
    "Mata do Flanco Sul da Serra": {"clip": "Mata do Flanco Sul da Serra", "ancoras":
        fila(100, [(-130, "D2", 0), (-102, "D1", 90), (-74, "D2", 180), (-46, "D1", 270), (-18, "D2", 45)]) +
        fila(76, [(-110, "M1", 135), (-82, "M1", 315), (-54, "M1", 225)])},
    "Mata do Contraforte Leste": {"clip": "Mata do Contraforte Leste", "ancoras":
        fila(90, [(322, "M1", 0), (350, "M1", 90), (378, "M1", 180)]) +
        fila(118, [(312, "M1", 270), (340, "D1", 45), (368, "M1", 135), (396, "M1", 225)]) +
        fila(146, [(300, "M1", 315), (328, "D2", 0), (356, "M1", 90), (384, "M1", 180)]) +
        fila(174, [(290, "M1", 45), (318, "M1", 270), (346, "M1", 0)]) +
        [(452, 112, "CP", 0), (456, 142, "CP", 90)]},
    # Franjas irregulares por fora dos recortes: quebram a borda reta das matas (capoeira + mata média)
    "Bordas de Mata": {"clip": None, "ancoras": [
        (-170, 112, "CP", 30), (-120, 106, "M1", 200), (-205, 140, "CP", 0),
        (110, 112, "M1", 0), (150, 108, "D2", 90), (205, 180, "CP", 90), (240, 160, "M1", 45), (275, 122, "CP", 0),
        (40, -190, "M1", 90), (90, -205, "CP", 180), (150, -205, "M1", 270), (200, -190, "CP", 45),
        (240, -120, "M1", 135), (235, -90, "CP", 225), (185, -40, "M1", 315), (130, -35, "CP", 0), (60, -55, "M1", 90),
        (-165, 270, "CP", 0), (-160, 300, "M1", 90), (-120, 330, "CP", 180), (-60, 330, "M1", 270), (10, 318, "CP", 45),
        (280, 200, "CP", 0), (420, 196, "CP", 90)]},
    "Capoeira do Cruzeiro": {"clip": "Capoeira do Cruzeiro", "ancoras":
        fila(118, [(-408, "CP", 0), (-380, "CP", 90)]) +
        fila(136, [(-396, "CP", 180), (-368, "CP", 270), (-340, "CP", 45), (-312, "CP", 135), (-284, "CP", 225), (-258, "CP", 315)]) +
        fila(158, [(-384, "CP", 0), (-356, "CP", 180), (-328, "CP", 90)])},
    "Mata Ciliar do Tauá": {"clip": None, "ancoras": [
        # margem noroeste do rio (offset ~12 m do eixo), giro 220° = direção da correnteza
        (-158, -117, "CL", 220), (-183, -139, "CL", 220), (-208, -161, "CL", 220), (-233, -181, "CL", 220),
        (-258, -201, "CL", 220), (-283, -226, "CL", 220), (-308, -251, "CL", 220),
        # margem sudeste
        (-142, -135, "CL", 40), (-167, -157, "CL", 40), (-192, -179, "CL", 40), (-217, -199, "CL", 40),
        (-242, -219, "CL", 40), (-267, -244, "CL", 40), (-292, -269, "CL", 40)]},
    "Mata da Cabeceira": {"clip": None, "ancoras": [
        (46, 78, "CL", 250), (22, 76, "CL", 70), (30, 40, "CL", 240), (6, 36, "CL", 60), (14, 8, "CL", 225)]},
    "Mata da Represa Norte": {"clip": "Mata da Represa Norte", "ancoras": [
        (-100, 20, "M1", 0), (-75, 42, "M1", 90), (-48, 50, "M1", 180), (-5, 50, "M1", 270), (25, 46, "M1", 0)]},
    "Bananal da Vila": {"clip": "Bananal da Vila", "ancoras": [
        (-285, -300, "BN", 0), (-265, -305, "BN", 90), (-250, -316, "BN", 180), (-282, -318, "BN", 45),
        (-262, -328, "BN", 270), (-248, -340, "BN", 135)]},
    "Quintais": {"clip": None, "ancoras": [
        # Vila Caiçara (atrás das casas)
        (-428, -318, "QT", 0), (-446, -290, "QT", 90), (-470, -262, "QT", 180), (-452, -238, "QT", 270),
        (-300, -392, "QT", 45), (-278, -414, "QT", 135), (-258, -382, "QT", 225), (-306, -294, "QT", 315),
        (-288, -364, "QT", 0), (-390, -268, "QT", 90),
        # Fazenda (casas de colono)
        (-184, -312, "QT", 180), (-176, -354, "QT", 270), (-134, -382, "QT", 45),
        # Morro do Cruzeiro (bordas)
        (-398, 36, "QT", 135), (-394, 92, "QT", 225), (-268, 104, "QT", 315),
        # Vila operária da Usina e casa do caseiro
        (-366, 318, "QT", 0), (-370, 366, "QT", 90), (-16, 56, "QT", 180)]},
    "Coqueiral da Orla": {"clip": "Coqueiral da Orla", "ancoras":
        fila(-440, [(-38, "FC", 0), (-2, "FC", 0), (34, "FC", 0), (70, "FC", 0), (106, "FC", 0), (142, "FC", 0), (178, "FC", 0)]) +
        fila(-456, [(-20, "FC", 180), (16, "FC", 180), (52, "FC", 180), (88, "FC", 180), (124, "FC", 180), (160, "FC", 180), (196, "FC", 180)])},
    "Coqueiros das Praias": {"clip": None, "ancoras": [
        (-440, -388, "FC", 335), (-398, -412, "FC", 335), (-360, -428, "FC", 335), (-324, -442, "FC", 335),   # enseada da Vila
        (-386, 352, "FC", 310), (-352, 382, "FC", 320), (-300, 408, "FC", 340),                               # praia NO (Usina)
        (-222, 432, "FC", 0), (-180, 430, "FC", 355)]},                                                      # praia norte
    "Restinga Sul": {"clip": "Restinga Sul", "ancoras":
        fila(-455, [(-200, "RS", 0), (-172, "RS", 90), (-144, "RS", 180), (-116, "RS", 270), (-88, "RS", 45), (-60, "RS", 135)]) +
        fila(-438, [(-150, "RS", 225), (-122, "RS", 315), (-94, "RS", 0), (-66, "RS", 90)])},
    "Restinga da Pista": {"clip": "Restinga da Pista", "ancoras": [
        (250, -435, "RS", 0), (278, -428, "RS", 90), (300, -420, "RS", 180), (325, -412, "RS", 270),
        (350, -400, "RS", 45), (375, -392, "RS", 135), (400, -386, "RS", 225), (425, -375, "RS", 315),
        (265, -452, "RS", 180), (292, -440, "RS", 0), (320, -430, "RS", 90)]},
    "Quebra-vento de Eucalipto": {"clip": None, "ancoras": [
        (211, -218, "EU", 12.7), (250, -209, "EU", 12.7), (289, -200, "EU", 12.7), (328, -192, "EU", 12.7),
        (367, -183, "EU", 12.7), (406, -174, "EU", 12.7)]},
    "Bordas dos Canaviais": {"clip": None, "ancoras": [
        # Norte
        (-225, 385, "TC", 0), (-195, 385, "TC", 90), (-165, 385, "TC", 180), (-146, 355, "TC", 270),
        (-150, 326, "TC", 45), (-185, 325, "TC", 135), (-218, 326, "TC", 225), (-232, 355, "TC", 315),
        # Sul
        (-235, 245, "TC", 0), (-200, 250, "TC", 90), (-168, 254, "TC", 180), (-157, 220, "TC", 270),
        (-160, 186, "TC", 45), (-200, 192, "TC", 135), (-243, 198, "TC", 225), (-238, 222, "TC", 315),
        # Oeste
        (-425, 282, "TC", 0), (-400, 295, "TC", 90), (-376, 302, "TC", 180), (-366, 270, "TC", 270),
        (-368, 238, "TC", 45), (-392, 228, "TC", 135), (-414, 222, "TC", 225), (-422, 250, "TC", 315)]},
    "Pasto da Fazenda": {"clip": None, "ancoras": [
        (-190, -205, "AI", 0), (-30, -232, "AI", 120), (-150, -392, "AI", 240), (-8, -330, "AI", 60),
        (-210, -250, "TC", 0), (-140, -215, "TC", 90), (-72, -188, "TC", 180), (-28, -268, "TC", 270),
        (-48, -372, "TC", 45), (-118, -398, "TC", 135), (-205, -332, "TC", 225), (-94, -222, "TC", 315),
        (-222, -290, "TC", 0), (-60, -395, "TC", 90)]},
    "Pasto Oeste": {"clip": None, "ancoras": [
        (-442, -118, "AI", 30), (-358, -108, "AI", 200),
        (-456, -88, "TC", 0), (-400, -122, "TC", 90), (-350, -162, "TC", 180), (-420, -205, "TC", 270),
        (-372, -78, "TC", 45), (-462, -176, "TC", 135)]},
    "Campo do Quartel": {"clip": None, "ancoras": [
        (192, 214, "AI", 90), (198, 388, "AI", 270), (428, 214, "AI", 0),
        (190, 262, "TC", 0), (214, 396, "TC", 90), (420, 226, "TC", 180), (330, 208, "TC", 270),
        (194, 350, "TC", 45), (300, 392, "TC", 135), (426, 300, "TC", 225)]},
    "Planície da Usina e Baixada Norte": {"clip": None, "ancoras": [
        (-196, 296, "AI", 45), (-120, 360, "AI", 160), (-30, 400, "AI", 300), (160, 400, "AI", 20),
        (-260, 400, "TC", 0), (-130, 410, "TC", 90), (-70, 430, "TC", 180), (40, 452, "TC", 270), (120, 460, "TC", 45),
        (-430, 180, "AI", 90), (-450, 120, "TC", 0), (-410, 200, "TC", 180)]},
    "Pátio da Pista": {"clip": None, "ancoras": [
        (220, -250, "TC", 0), (250, -265, "TC", 90), (440, -210, "TC", 180), (230, -380, "AI", 300), (180, -300, "AI", 60)]},
    "Sul (entre Fazenda e Praia)": {"clip": None, "ancoras": [
        (40, -300, "AI", 0), (140, -330, "AI", 110), (20, -370, "TC", 0), (90, -380, "TC", 90), (180, -380, "TC", 180),
        (60, -250, "M1", 45), (0, -230, "M1", 200)]},
    "Costões e Falésias": {"clip": None, "ancoras": [
        (470, 230, "CT", 0), (475, 172, "CT", 90), (478, 40, "CT", 180), (478, -20, "CT", 270), (478, -90, "CT", 0),
        (480, -160, "CT", 90), (476, -222, "CT", 180), (18, 520, "CT", 45), (118, 516, "CT", 135),
        (-280, -466, "CT", 0), (-240, -484, "CT", 90), (440, 330, "CT", 200)]},
    "Pedras": {"clip": None, "ancoras": [
        (62, 146, "P3", 0), (100, 174, "P3", 90), (400, -22, "P3", 180), (286, 62, "P3", 270), (116, -104, "P3", 45),
        (-270, -474, "P3", 0), (-150, -58, "P3", 90), (-40, -142, "P3", 180), (-424, -98, "P3", 270), (0, 444, "P3", 0),
        (150, 444, "P3", 90), (60, 430, "P3", 180), (-470, 40, "P3", 270), (-330, 110, "P3", 0), (470, -130, "P3", 45),
        (-60, -500, "P3", 0), (170, -498, "P3", 90), (-100, 440, "P3", 180)]},
}

# Polígonos de recorte das manchas NOVAS (as demais vêm de ilha_layout.json "vegetacao")
CLIP_NOVOS = {
    "Mata da Encosta Norte": [(-150, 215), (-60, 218), (40, 216), (38, 262), (0, 300), (-40, 318), (-100, 318), (-150, 290), (-152, 250)],
    "Mata do Flanco Sul da Serra": [(-145, 112), (-90, 118), (-20, 122), (-5, 110), (-40, 86), (-70, 62), (-120, 62), (-140, 85)],
    "Mata do Contraforte Leste": [(292, 72), (400, 70), (470, 100), (470, 160), (400, 188), (290, 190), (282, 130)],
}

# Touceiras de beira de estrada: (via, distância_m ao longo da via, lado +1 esquerda / -1 direita)
BEIRA = [
    ("E1", 30, 1), ("E1", 70, -1), ("E1", 110, 1), ("E1", 150, -1), ("E1", 195, 1), ("E1", 240, -1),
    ("E2", 20, -1), ("E2", 60, 1), ("E2", 100, -1), ("E2", 150, 1), ("E2", 190, -1),
    ("E3", 25, 1), ("E3", 55, -1), ("E3", 95, 1), ("E3", 140, -1), ("E3", 175, 1),
    ("E4", 30, 1), ("E4", 90, -1), ("E4", 150, 1), ("E4", 210, -1), ("E4", 250, 1),
    ("E5", 40, -1), ("E5", 95, 1), ("E5", 150, -1), ("E5", 210, 1), ("E5", 265, -1), ("E5", 320, 1),
    ("E6", 30, 1), ("E6", 80, -1), ("E6", 130, 1), ("E6", 190, -1),
    ("E7", 30, -1), ("E7", 90, 1), ("E7", 150, -1), ("E7", 210, 1), ("E7", 270, -1), ("E7", 330, 1),
    ("E8", 35, 1), ("E8", 90, -1), ("E8", 150, 1), ("E8", 215, -1), ("E8", 280, 1), ("E8", 330, -1),
    ("E9", 30, -1), ("E9", 85, 1), ("E9", 140, -1), ("E9", 200, 1), ("E9", 255, -1),
    ("E10", 30, 1), ("E10", 80, -1), ("E10", 130, 1), ("E10", 300, -1), ("E10", 340, 1),
    ("E11", 40, -1), ("E11", 110, 1), ("E11", 170, -1),
    ("P1", 40, 1), ("P1", 100, -1), ("P1", 160, 1), ("P1", 230, -1),
]

# Canaviais: plantio EM NÍVEL (fileiras ao longo da curva de nível, cortando o declive — prática de
# conservação de solo). Direção medida no height.bin e escrita aqui à mão:
#   Norte: subida para -43° (16%)  -> fileiras a 47°
#   Sul:   subida para -46° (77%)  -> fileiras a 44°  (encosta forte; T1 atravessa e vira carreador natural)
#   Oeste: subida para -39° (16%)  -> fileiras a 51°
# Espaçamento 1,4 m entre fileiras, 0,9 m entre touceiras. Carreadores de 4 m (segmentos escritos à mão).
# O loop abaixo só percorre as fileiras definidas por (origem, direção, espaçamento) — plantio linear.
CANA = "cana"
CANAVIAIS = {
    "Canavial Norte": {"origem": (-190, 355), "dir_deg": 47, "carreadores": [
        ((-234, 387), (-176, 333)),   # C1 morro abaixo
        ((-201, 389), (-143, 335)),   # C2 morro abaixo
        ((-217, 321), (-163, 379))]}, # C3 cabeceira, ao longo das fileiras
    "Canavial Sul": {"origem": (-200, 220), "dir_deg": 44, "carreadores": [
        ((-218, 237), (-174, 195)),   # C1
        ((-196, 258), (-152, 216))]}, # C2
    "Canavial Oeste": {"origem": (-395, 262), "dir_deg": 51, "carreadores": [
        ((-418, 281), (-372, 243)),   # C1 morro abaixo
        ((-416, 239), (-378, 285))]}, # C2 ao longo das fileiras
}
CANA_ENTRE_FILEIRAS, CANA_NA_FILEIRA, CARREADOR_LARG = 1.4, 0.9, 4.0
CANA_ESCALAS = (1.00, 0.92, 1.08, 0.96, 1.04, 0.88, 1.12)   # ciclo fixo (sem sorteio)

# ===========================================================================
# 3. Montagem + folgas
# ===========================================================================
def dentro(poly, x, y):
    ins = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            ins = not ins
    return ins


def dist_seg(px, py, a, b):
    ax, ay = a[0], a[1]; bx, by = b[0], b[1]
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy
    t = 0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
    return math.hypot(px - ax - t * vx, py - ay - t * vy)


def dist_poli(px, py, pts):
    return min(dist_seg(px, py, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def dist_obb(px, py, b):
    w, d, _ = b["tamanho_m"]; x, y = b["pos"]; r = math.radians(b["rot_deg"])
    lx = (px - x) * math.cos(r) + (py - y) * math.sin(r)
    ly = -(px - x) * math.sin(r) + (py - y) * math.cos(r)
    dx = max(abs(lx) - w / 2, 0); dy = max(abs(ly) - d / 2, 0)
    return math.hypot(dx, dy)


class Altura:
    def __init__(self, path):
        self.h = np.fromfile(path, dtype="<f4").reshape(601, 601)

    def __call__(self, x, y):
        c = (x + 600) / 2.0; r = (600 - y) / 2.0
        c0 = int(max(0, min(599, math.floor(c)))); r0 = int(max(0, min(599, math.floor(r))))
        fc, fr = c - c0, r - r0
        h = self.h
        return float(h[r0, c0] * (1 - fc) * (1 - fr) + h[r0, c0 + 1] * fc * (1 - fr) + h[r0 + 1, c0] * (1 - fc) * fr + h[r0 + 1, c0 + 1] * fc * fr)


def ponto_na_via(pts, s, lado, off):
    acc = 0.0
    for i in range(len(pts) - 1):
        (x1, y1), (x2, y2) = pts[i], pts[i + 1]
        L = math.hypot(x2 - x1, y2 - y1)
        if acc + L >= s or i == len(pts) - 2:
            t = min(1.0, (s - acc) / L)
            ux, uy = (x2 - x1) / L, (y2 - y1) / L
            return x1 + ux * L * t - uy * off * lado, y1 + uy * L * t + ux * off * lado, math.degrees(math.atan2(uy, ux))
        acc += L


def main():
    lay = json.load(open(LAYOUT, encoding="utf-8"))
    alt = Altura(HEIGHT)
    costa = lay["costa"]
    represa = lay["agua"]["represa"]["contorno"]
    rio = [([p[:2] for p in t["pontos"]], t["largura_m"] / 2) for t in lay["agua"]["rio"]["trechos"]]
    vias = {e["id"]: e for e in lay["estradas"]}
    predios = [b for p in lay["pois"] + lay["marcos"] for b in p["predios"]]
    areas_livres = [p["muro"] for p in lay["pois"] if "muro" in p] + [p["terreiro"] for p in lay["pois"] if "terreiro" in p]
    pontes = []
    for b in lay["pontes"]:
        r = math.radians(b["rot_deg"]); hl = b["comprimento_m"] / 2
        pontes.append(((b["pos"][0] - hl * math.cos(r), b["pos"][1] - hl * math.sin(r)),
                       (b["pos"][0] + hl * math.cos(r), b["pos"][1] + hl * math.sin(r)), b["largura_m"] / 2))
    clips = {m["nome"]: m["poligono"] for m in lay["vegetacao"]}
    clips.update(CLIP_NOVOS)

    # candidatos na ordem de autoria
    cand = []
    for nome, m in MANCHAS.items():
        clip = clips.get(m["clip"]) if m["clip"] else None
        for (ax, ay, carimbo, giro) in m["ancoras"]:
            r = math.radians(giro)
            for (tipo, dx, dy, rot, esc) in CARIMBO[carimbo]:
                x = ax + dx * math.cos(r) - dy * math.sin(r)
                y = ay + dx * math.sin(r) + dy * math.cos(r)
                cand.append((nome, tipo, x, y, (rot + giro) % 360, esc, clip))
    for (vid, s, lado) in BEIRA:
        e = vias[vid]
        x, y, ang = ponto_na_via(e["pontos"], s, lado, e["largura_m"] / 2 + 4.5)
        for (tipo, dx, dy, rot, esc) in CARIMBO["TC"]:
            cand.append(("Beira de estrada", tipo, x + dx, y + dy, (rot + ang) % 360, esc, None))

    aceitas, motivo = [], Counter()
    grade = defaultdict(list)  # hash espacial 10 m para checar espaçamento

    def perto(x, y, raio, so_arvores):
        gx, gy = int(math.floor(x / 10)), int(math.floor(y / 10))
        for i in (-1, 0, 1):
            for j in (-1, 0, 1):
                for (ox, oy, ot) in grade[(gx + i, gy + j)]:
                    if so_arvores and ot not in ARVORES: continue
                    if math.hypot(ox - x, oy - y) < raio: return True
        return False

    def folga(x, y):
        """Motivo de descarte pelas folgas fixas, ou None se o ponto é válido."""
        if not dentro(costa, x, y): return "mar"
        if alt(x, y) < 0.6: return "mar"
        if dentro(represa, x, y) or dist_poli(x, y, represa + [represa[0]]) < 2.0: return "represa"
        if any(dist_poli(x, y, pts) < hw + 1.5 for pts, hw in rio): return "leito do rio"
        if any(dist_poli(x, y, e["pontos"]) < e["largura_m"] / 2 + 3.0 for e in lay["estradas"]): return "via (folga 3 m)"
        if any(dist_seg(x, y, a, b) < hw + 3.0 for a, b, hw in pontes): return "ponte/barragem"
        if any(dist_obb(x, y, b) < 4.0 for b in predios if abs(b["pos"][0] - x) < 60 and abs(b["pos"][1] - y) < 60):
            return "prédio (folga 4 m)"
        if any(dentro(p, x, y) for p in areas_livres): return "pátio/terreiro"
        return None

    for (nome, tipo, x, y, rot, esc, clip) in cand:
        if clip is not None and not dentro(clip, x, y): motivo["fora da mancha (recorte)"] += 1; continue
        m = folga(x, y)
        if m: motivo[m] += 1; continue
        z = alt(x, y)
        if tipo in ARVORES:
            if perto(x, y, 3.0, True): motivo["espaçamento entre árvores"] += 1; continue
        elif perto(x, y, 1.2, False): motivo["espaçamento"] += 1; continue
        grade[(int(math.floor(x / 10)), int(math.floor(y / 10)))].append((x, y, tipo))
        aceitas.append({"tipo": tipo, "x": round(x, 2), "y": round(y, 2), "z": round(z, 2), "rot_deg": round(rot, 1),
                        "escala": esc, "mancha": nome})

    # --------- canaviais: fileiras em nível (depois das demais plantas; não entram no hash de espaçamento)
    motivo_cana, cana_info = Counter(), {}
    for nome, cv in CANAVIAIS.items():
        poly = clips[nome]
        ox, oy = cv["origem"]; r = math.radians(cv["dir_deg"])
        ux, uy = math.cos(r), math.sin(r)          # ao longo da fileira
        nx, ny = -uy, ux                           # entre fileiras
        R = max(math.hypot(px - ox, py - oy) for px, py in poly) + 2
        nfil = int(R / CANA_ENTRE_FILEIRAS); npl = int(R / CANA_NA_FILEIRA)
        n_ok, fileiras = 0, set()
        for k in range(-nfil, nfil + 1):
            for j in range(-npl, npl + 1):
                x = ox + nx * k * CANA_ENTRE_FILEIRAS + ux * j * CANA_NA_FILEIRA
                y = oy + ny * k * CANA_ENTRE_FILEIRAS + uy * j * CANA_NA_FILEIRA
                if not dentro(poly, x, y): continue
                if any(dist_seg(x, y, a, b) < CARREADOR_LARG / 2 for a, b in cv["carreadores"]):
                    motivo_cana["carreador"] += 1; continue
                m = folga(x, y)
                if m: motivo_cana[m] += 1; continue
                if perto(x, y, 1.0, False): motivo_cana["encosta em outra planta"] += 1; continue
                aceitas.append({"tipo": CANA, "x": round(x, 2), "y": round(y, 2), "z": round(alt(x, y), 2),
                                "rot_deg": float((cv["dir_deg"] + 90 * ((j + k) % 4)) % 360),
                                "escala": CANA_ESCALAS[(j + 3 * k) % len(CANA_ESCALAS)], "mancha": nome})
                n_ok += 1; fileiras.add(k)
        cana_info[nome] = {"direcao_fileiras_deg": cv["dir_deg"], "fileiras": len(fileiras), "touceiras": n_ok,
                           "carreadores": [[list(a), list(b)] for a, b in cv["carreadores"]]}
    motivo.update({"cana: " + k: v for k, v in motivo_cana.items()})

    # --------- relatório
    por_tipo = Counter(a["tipo"] for a in aceitas)
    por_mancha = defaultdict(Counter)
    for a in aceitas: por_mancha[a["mancha"]][a["tipo"]] += 1
    dens = {}
    for nome in ("Mata da Serra", "Mata da Serra Leste", "Mata do Morro do Sul", "Mata da Encosta Norte", "Mata do Esporão Norte"):
        poly = clips[MANCHAS[nome]["clip"]]
        n = len(poly)
        area = abs(sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))) / 2
        arv = sum(v for t, v in por_mancha[nome].items() if t in ARVORES)
        dens[nome] = {"area_m2": round(area), "arvores": arv, "espacamento_medio_m": round(math.sqrt(area / max(arv, 1)), 1)}

    # validação final independente (todas as regras de novo sobre o resultado)
    viol = 0
    for a in aceitas:
        x, y = a["x"], a["y"]
        assert 0.8 <= a["escala"] <= 1.3
        if any(dist_poli(x, y, e["pontos"]) < e["largura_m"] / 2 + 3.0 - 0.02 for e in lay["estradas"]): viol += 1
        if any(dist_obb(x, y, b) < 4.0 - 0.02 for b in predios): viol += 1
        if any(dist_poli(x, y, pts) < hw + 1.5 - 0.02 for pts, hw in rio): viol += 1
        if dentro(represa, x, y) or alt(x, y) < 0.6: viol += 1

    doc = {
        "versao": 1,
        "fonte": "tools/vegetacao_src.py (carimbos e âncoras autorais; sem sorteio)",
        "sistema": "metros; origem no centro; x leste, y norte; z amostrado de game/maps/ilha/height.bin (bilinear)",
        "tipos": {A: "copa larga 14–18 m", B: "copa alta estreita 16–20 m", C: "coqueiro", AR: "arbusto 1,5–2,5 m",
                  BA: "bananeira 3–4 m", CA: "touceira de capim alto 1 m", PE: "pedra pequena", CANA: "touceira de cana 2,6 m, ~0,6 m de diâmetro"},
        "folgas": {"via_m": 3.0, "predio_m": 4.0, "leito_rio_m": 1.5, "represa_m": 2.0, "entre_arvores_m": 3.0},
        "total": len(aceitas),
        "contagem_por_tipo": dict(por_tipo),
        "contagem_por_mancha": {k: dict(v) for k, v in por_mancha.items()},
        "densidade_matas": dens,
        "descartes_por_folga": dict(motivo),
        "violacoes_na_validacao_final": viol,
        "canaviais": {"plantio": "em nível (fileiras ao longo da curva de nível)", "entre_fileiras_m": CANA_ENTRE_FILEIRAS, "na_fileira_m": CANA_NA_FILEIRA, "carreador_m": CARREADOR_LARG, "talhoes": cana_info},
        "instancias": aceitas,
    }
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=0)

    # --------- prévia sobre o radar
    from PIL import Image, ImageDraw
    im = Image.open(RADAR).convert("RGBA")
    S = 1024 / 1200.0
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    COR = {A: ((20, 70, 30, 235), 2.6), B: ((10, 110, 60, 235), 2.2), C: ((250, 210, 60, 255), 2.2), AR: ((120, 170, 60, 230), 1.4),
           BA: ((200, 240, 80, 255), 1.6), CA: ((230, 200, 120, 220), 1.0), PE: ((200, 200, 200, 255), 1.2),
           CANA: ((150, 190, 40, 255), 0.45)}
    for a in aceitas:
        cor, r = COR[a["tipo"]]
        px, py = (a["x"] + 600) * S, (600 - a["y"]) * S
        d.ellipse([px - r, py - r, px + r, py + r], fill=cor)
    im = Image.alpha_composite(im, ov)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 12, 250, 166], fill=(15, 25, 35, 210))
    try:
        from PIL import ImageFont
        f = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 12)
    except OSError:
        f = None
    for i, (t, (cor, r)) in enumerate(COR.items()):
        d.ellipse([22, 24 + i * 17, 32, 34 + i * 17], fill=cor)
        d.text((40, 22 + i * 17), f"{t}: {por_tipo.get(t, 0)}", fill=(255, 255, 255), font=f)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    im.convert("RGB").save(PREVIEW)

    print(f"{len(aceitas)} instâncias -> {SAIDA}")
    print("por tipo:", dict(por_tipo))
    for k, v in por_mancha.items(): print(f"  {k:<36} {sum(v.values()):>4}  {dict(v)}")
    print("densidade:", json.dumps(dens, ensure_ascii=False))
    print("descartes:", dict(motivo))
    print("violações na validação final:", viol)
    return 0 if viol == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
