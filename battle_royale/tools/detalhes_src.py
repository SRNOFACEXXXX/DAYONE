# -*- coding: utf-8 -*-
"""
Fonte AUTORAL dos detalhes de chão dos POIs da Ilha do Tauá -> docs/design/detalhes.json

Tudo escrito à mão, sem sorteio:
  * KITS por tipo de prédio: props em coordenadas LOCAIS do prédio (lx, ly, rot_local), escritos à mão.
    Porta = face -Y local (convenção do jogo). Frente = -Y, fundos/quintal = +Y.
  * ATRIBUIÇÃO explícita de kit a cada prédio (tabela KIT_DO_PREDIO).
  * PROPS AVULSOS em coordenadas do mundo (canoas, feira, holofotes, placas, orelhões...).
  * LINHAS DE FIAÇÃO: postes em sequência, coordenadas escritas à mão (acostamento, ~6 m do eixo).
  * CERCAS/MUROS: polilinhas escritas à mão (mundo ou locais ao prédio, p/ quintais).

Folgas (validadas; um prop/trecho de cerca que viole é DESCARTADO e contado no relatório;
poste ou portão que viole é ERRO e trava a geração):
  - prédio: 1 m da parede (props e cercas);  porta: retângulo de 2 m à frente da face -Y livre
  - via: prop/poste fora da pista de rolamento (>= meia largura + 0,5 m); cerca/muro >= max(4 m, meia largura + 0,5)
  - água: nada no mar, represa ou leito do rio.  Portão é o único que pode ficar sobre a via (é o portão dela).

Uso:  python tools/detalhes_src.py
"""
import json, math, os, sys
from collections import Counter, defaultdict
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(RAIZ, "docs", "design", "ilha_layout.json")
VEG = os.path.join(RAIZ, "docs", "design", "vegetacao.json")
HEIGHT = os.path.join(RAIZ, "game", "maps", "ilha", "height.bin")
SAIDA = os.path.join(RAIZ, "docs", "design", "detalhes.json")
PREVIEW = os.path.join(RAIZ, "raw", "detalhes_preview.png")

# meio-comprimento ao longo do X local de cada prop (para checar folga nas pontas)
MEIO = {"varal": 2.0, "canoa_praia": 2.6, "banco_praca": 1.0, "portao_ferro": 2.0, "lona_barraca": 1.5,
        "mesa_bar_cadeiras": 1.0, "placa_estrada": 1.0, "bicicleta": 0.8, "carrinho_mao": 0.6, "pilha_tijolo": 0.6}

# ===========================================================================
# 1. KITS (tipo, lx, ly, rot_local) — por tipo de prédio
# ===========================================================================
KITS = {
    # casa caiçara 6 x 8 (porta em ly = -4)
    "CC_A": {"props": [("varal", 0, 7.5, 0), ("lixeira", 2.6, -5.2, 0), ("bicicleta", -4.4, -2.5, 90), ("caixote_peixe", 4.3, -1.5, 0)],
             "cercas": [("cerca_madeira", [(-4.2, 1), (-4.2, 10), (4.2, 10), (4.2, 1)])]},
    "CC_B": {"props": [("varal", 0, 7, 10), ("tambor", 4.3, -2.5, 0), ("carrinho_mao", -2.5, 7.8, 40), ("barril", -4.3, -2, 0)],
             "cercas": [("cerca_madeira", [(-4.2, -1), (-4.2, 9.5), (4.2, 9.5)])]},
    # casa de alvenaria com laje 6 x 7
    "CL_A": {"props": [("varal", 0, 6, 0), ("pilha_tijolo", -2.4, -5.0, 0), ("lixeira", 2.4, -4.8, 0), ("carrinho_mao", 4.4, -2, 90)],
             "cercas": [("muro_baixo", [(-4.2, 0), (-4.2, 8.5), (4.2, 8.5), (4.2, 0)])]},
    "CL_B": {"props": [("tambor", 4.2, -1, 0), ("carrinho_mao", 4.4, 2, 90), ("varal", 0, 6.5, 0), ("bicicleta", -2.3, -5, 0)],
             "cercas": [("muro_baixo", [(-4.2, -1), (-4.2, 7.5)])]},
    "CL_M": {"props": [("tambor", 4.3, 1, 0), ("pilha_tijolo", -4.8, -1, 0), ("lixeira", 2.4, -4.6, 0), ("varal", 0, 5.8, 0)],
             "cercas": [("muro_baixo", [(3.9, 3.8), (3.9, 7)])]},
    # sobrado 8 x 10
    "SB": {"props": [("varal", 0, 7.5, 0), ("bicicleta", -5.3, -3, 90), ("lixeira", 3, -6, 0), ("banco_praca", -3.2, -6.5, 0)],
           "cercas": [("muro_baixo", [(-5.2, 0), (-5.2, 10), (5.2, 10), (5.2, 0)])]},
    # venda/bar 7 x 9
    "BAR": {"props": [("mesa_bar_cadeiras", -3.6, -7.5, 0), ("mesa_bar_cadeiras", 3.6, -7.5, 0), ("mesa_bar_cadeiras", 0, -9.8, 0),
                      ("barril", 4.6, -2, 0), ("barril", 4.6, -0.6, 0), ("tambor", -4.6, 1, 0), ("orelhao", -4.8, -3.8, 90),
                      ("lixeira", 5, -5, 0)], "cercas": []},
    # rancho de pesca 8 x 12 (galpão aberto de canoas)
    "RP": {"props": [("caixote_peixe", 5.5, -3, 0), ("caixote_peixe", 5.6, -1.8, 15), ("caixote_peixe", 5.5, 3, 0), ("tambor", -5.4, 2, 0),
                     ("barril", -5.4, 3.6, 0), ("canoa_praia", -4.5, -10.5, 85), ("canoa_praia", 4.5, -10.5, 95), ("varal", 0, 8.5, 0)], "cercas": []},
    # capela da vila 8 x 16 com praça e feira à frente
    "CAP": {"props": [("banco_praca", -4.5, -10.5, 0), ("banco_praca", 4.5, -10.5, 0), ("lixeira", -5.5, -9, 0), ("orelhao", 6, -8.5, 0),
                      ("placa_rua", -6.5, -11.5, 0), ("lona_barraca", -7, -17, 0), ("lona_barraca", 0, -18, 0), ("lona_barraca", 7, -17, 0),
                      ("caixote_peixe", -4, -20.5, 0), ("caixote_peixe", 4, -20.5, 0), ("carrinho_mao", 9.5, -19, 30), ("bicicleta", -9.5, -14, 90)],
            "cercas": []},
    "CAP_F": {"props": [("banco_praca", -4.5, -10.5, 0), ("banco_praca", 4.5, -10.5, 0), ("lixeira", -5.5, -9, 0)], "cercas": []},
    # quiosque 5 x 5 (frente para o mar, -Y)
    "QK": {"props": [("mesa_bar_cadeiras", -3.6, -5.5, 0), ("mesa_bar_cadeiras", 3.6, -5.5, 0), ("mesa_bar_cadeiras", 0, -8, 0),
                     ("barril", 3.6, 1.5, 0), ("lixeira", -3.6, 1.5, 0)], "cercas": []},
    "RE": {"props": [("mesa_bar_cadeiras", -3.5, -8.5, 0), ("mesa_bar_cadeiras", 3.5, -8.5, 0), ("mesa_bar_cadeiras", -3.5, -12, 0),
                     ("mesa_bar_cadeiras", 3.5, -12, 0), ("barril", 6.2, 2, 0), ("barril", 6.2, 3.4, 0), ("lixeira", -6.2, -5, 0),
                     ("caixote_peixe", 6.2, 5, 0)], "cercas": []},
    "BAN": {"props": [("lixeira", 4.2, -1, 0), ("lixeira", -4.2, -1, 0)], "cercas": []},
    # casarão 26 x 18
    "CS": {"props": [("banco_praca", -9, -11, 0), ("banco_praca", 9, -11, 0), ("carrinho_mao", 14.5, 4, 90), ("barril", -14.5, -3, 0),
                     ("barril", -14.5, -1.5, 0), ("tambor", 14.5, -2, 0), ("varal", 6, 12, 0), ("bicicleta", -14.6, 3, 90), ("lixeira", 4, -10.5, 0)],
           "cercas": [("cerca_madeira", [(-14.5, 9), (-14.5, 16), (14.5, 16), (14.5, 9)])]},
    "TU": {"props": [("carrinho_mao", 5.8, -6, 90), ("barril", 5.2, 2, 0), ("barril", 5.2, 3.5, 0), ("pilha_tijolo", -5.8, 5, 90)], "cercas": []},
    "PA": {"props": [("tambor", 5.2, 0, 0), ("tambor", 5.2, 1.5, 0), ("carrinho_mao", -5.2, 2, 90)], "cercas": []},
    # usina
    "DEST": {"props": [("barril", 11.5, -4, 0), ("barril", 11.5, -2.6, 0), ("barril", 11.5, -1.2, 0), ("barril", 11.5, 4, 0),
                       ("tambor", -11.5, 3, 0), ("tambor", -11.5, 4.5, 0), ("carrinho_mao", -11.5, -6, 90)], "cercas": []},
    "ARM": {"props": [("carrinho_mao", -9.2, -10, 90), ("pilha_tijolo", 9, 8, 90), ("tambor", -8.8, 12, 0), ("caixote_peixe", -8.8, -4, 0)], "cercas": []},
    "ESC": {"props": [("bicicleta", -6.2, -3, 90), ("lixeira", 3, -8.5, 0), ("banco_praca", -3.5, -8.8, 0)], "cercas": []},
    "VO": {"props": [("varal", 5.8, 3, 90), ("bicicleta", 4.2, -6, 90), ("tambor", -4.2, -8, 0), ("lixeira", 2.5, -13.5, 0), ("varal", -5.8, 6, 90)], "cercas": []},
    # farol
    "FAR": {"props": [("varal", 0, 8, 0), ("lixeira", 3, -6.5, 0), ("bicicleta", -5.2, -2, 90)], "cercas": []},
    "GER": {"props": [("tambor", 3.8, 0, 0), ("tambor", 3.8, 1.3, 0), ("tambor", 3.8, -1.3, 0)], "cercas": []},
    # quartel
    "GAR": {"props": [("tambor", -10, -9.8, 0), ("tambor", -8.6, -9.8, 0), ("tambor", 10, -9.8, 0), ("carrinho_mao", 13.8, 3, 90)], "cercas": []},
    "ALOJ": {"props": [("banco_praca", -4, -17, 0), ("lixeira", 4, -16.5, 0), ("bicicleta", -7.2, -10, 90)], "cercas": []},
    # pedreira / pista / represa
    "OFI": {"props": [("tambor", 11.5, -5, 0), ("tambor", 11.5, -3.6, 0), ("tambor", 11.5, 8, 0), ("carrinho_mao", -11.5, 0, 90)], "cercas": []},
    "CONT": {"props": [("carrinho_mao", 3.4, 2, 90), ("pilha_tijolo", 3.4, -3, 90)], "cercas": []},
    "HAN": {"props": [("tambor", 13.5, -3, 0), ("tambor", 13.5, -1.6, 0), ("barril", 13.5, 1.5, 0), ("carrinho_mao", -13.5, 0, 90)], "cercas": []},
    "PIL": {"props": [("bicicleta", -4.8, -2, 90), ("lixeira", 3, -6, 0), ("banco_praca", -3.4, -6.2, 0)], "cercas": []},
    "TQ": {"props": [("tambor", 4.5, -1.5, 0), ("tambor", 4.5, 0, 0), ("tambor", 4.5, 1.5, 0), ("tambor", -4.5, 0, 0)], "cercas": []},
    "CF": {"props": [("tambor", 7.5, -4, 0), ("tambor", 7.5, -2.5, 0), ("carrinho_mao", -7.5, 3, 90)], "cercas": []},
    "OPR": {"props": [("bicicleta", -4.8, -2, 90), ("lixeira", 3, -5.8, 0)], "cercas": []},
    "RAD": {"props": [("tambor", 3.8, 0, 0)], "cercas": []},
}

KIT_DO_PREDIO = {
    # Vila Caiçara
    "vila_caicara_01": "CC_A", "vila_caicara_02": "CC_B", "vila_caicara_03": "BAR", "vila_caicara_04": "CL_A",
    "vila_caicara_05": "RP", "vila_caicara_06": "CC_A", "vila_caicara_07": "CAP", "vila_caicara_08": "SB",
    "vila_caicara_09": "CC_B", "vila_caicara_10": "RP", "vila_caicara_11": "CL_A", "vila_caicara_12": "CC_A",
    "vila_caicara_13": "SB", "vila_caicara_14": "CC_B", "vila_caicara_15": "CC_A", "vila_caicara_16": "CL_B",
    # Morro do Cruzeiro (alternância autoral de kits; ruas estreitas -> kits compactos)
    "morro_cruzeiro_01": "CL_M", "morro_cruzeiro_02": "CL_B", "morro_cruzeiro_03": "CL_M", "morro_cruzeiro_04": "CL_B",
    "morro_cruzeiro_05": "CL_M", "morro_cruzeiro_06": "CL_B", "morro_cruzeiro_07": "CL_M", "morro_cruzeiro_08": "CL_B",
    "morro_cruzeiro_09": "CL_M", "morro_cruzeiro_10": "CL_M", "morro_cruzeiro_11": "CL_B", "morro_cruzeiro_12": "CL_M",
    "morro_cruzeiro_13": "CL_B", "morro_cruzeiro_14": "CL_M", "morro_cruzeiro_15": "CL_B", "morro_cruzeiro_16": "CL_M",
    "morro_cruzeiro_17": "CL_B", "morro_cruzeiro_18": "CL_M", "morro_cruzeiro_19": "CL_B", "morro_cruzeiro_20": "CL_M",
    "morro_cruzeiro_21": "CL_B", "morro_cruzeiro_22": "BAR",
    # Usina
    "usina_santa_cruz_03": "ARM", "usina_santa_cruz_04": "DEST", "usina_santa_cruz_06": "ESC",
    "usina_santa_cruz_07": "VO", "usina_santa_cruz_08": "VO", "usina_santa_cruz_09": "VO",
    # Farol
    "farol_ponta_norte_02": "FAR", "farol_ponta_norte_03": "GER", "farol_ponta_norte_04": "PA",
    # Quartel
    "quartel_02": "ALOJ", "quartel_03": "ALOJ", "quartel_05": "GAR", "quartel_06": "PA",
    # Pedreira
    "pedreira_03": "CONT", "pedreira_04": "CONT", "pedreira_05": "OFI", "pedreira_06": "PA",
    # Pista
    "pista_pouso_01": "HAN", "pista_pouso_03": "PIL", "pista_pouso_04": "TQ", "pista_pouso_05": "OFI",
    # Represa
    "represa_01": "CF", "represa_02": "OPR", "represa_05": "CC_A",
    # Fazenda
    "fazenda_boa_esperanca_01": "CS", "fazenda_boa_esperanca_02": "CAP_F", "fazenda_boa_esperanca_03": "TU",
    "fazenda_boa_esperanca_05": "CC_A", "fazenda_boa_esperanca_06": "CC_B", "fazenda_boa_esperanca_07": "CC_A",
    "fazenda_boa_esperanca_08": "PA",
    # Praia
    "praia_quiosques_01": "QK", "praia_quiosques_02": "QK", "praia_quiosques_03": "QK", "praia_quiosques_04": "QK",
    "praia_quiosques_05": "QK", "praia_quiosques_06": "BAN", "praia_quiosques_07": "RE",
    # Pico
    "pico_taua_02": "RAD",
}

# ===========================================================================
# 2. PROPS AVULSOS (poi, tipo, x, y, rot) — mundo
# ===========================================================================
AVULSOS = [
    # Vila: canoas na areia da enseada (dos dois lados da foz), caixotes, placas
    ("vila_caicara", "canoa_praia", -455, -368, 110), ("vila_caicara", "canoa_praia", -449, -377, 115),
    ("vila_caicara", "canoa_praia", -418, -397, 135), ("vila_caicara", "canoa_praia", -360, -432, 155),
    ("vila_caicara", "canoa_praia", -350, -437, 150), ("vila_caicara", "canoa_praia", -332, -441, 160),
    ("vila_caicara", "canoa_praia", -318, -448, 155), ("vila_caicara", "caixote_peixe", -356, -438, 20),
    ("vila_caicara", "caixote_peixe", -340, -444, 0), ("vila_caicara", "tambor", -325, -446, 0),
    ("vila_caicara", "placa_estrada", -434, -214, 90), ("vila_caicara", "placa_estrada", -240, -312, 190),
    ("vila_caicara", "placa_rua", -380, -298, 30),
    ("vila_caicara", "lixeira", -384, -322, 0), ("vila_caicara", "lixeira", -350, -323, 0),
    ("vila_caicara", "orelhao", -307, -325, 0), ("vila_caicara", "bicicleta", -304, -325, 90),
    # Morro: praça do cruzeiro, pé da escadaria
    ("morro_cruzeiro", "banco_praca", -312, 60, 90), ("morro_cruzeiro", "banco_praca", -326, 67, 0),
    ("morro_cruzeiro", "lixeira", -324, 52, 0), ("morro_cruzeiro", "orelhao", -337, -24, 0),
    ("morro_cruzeiro", "lixeira", -334, -26, 0), ("morro_cruzeiro", "placa_rua", -314, -22, 0),
    ("morro_cruzeiro", "pilha_tijolo", -303, -24, 0), ("morro_cruzeiro", "carrinho_mao", -300, -22, 30),
    ("morro_cruzeiro", "placa_estrada", -364, -32, 45),
    # Usina: holofotes nos portões, pilha de tijolos da chaminé, placas
    ("usina_santa_cruz", "holofote", -222, 322, 200), ("usina_santa_cruz", "holofote", -336, 247, 20),
    ("usina_santa_cruz", "pilha_tijolo", -259, 336, 0), ("usina_santa_cruz", "pilha_tijolo", -258, 324, 90),
    ("usina_santa_cruz", "placa_estrada", -160, 395, 200), ("usina_santa_cruz", "placa_estrada", -345, 232, 20),
    ("usina_santa_cruz", "tambor", -205, 312, 0), ("usina_santa_cruz", "tambor", -205, 298, 0),
    # Farol
    ("farol_ponta_norte", "placa_estrada", 84, 470, 300), ("farol_ponta_norte", "banco_praca", 62, 530, 10),
    ("farol_ponta_norte", "lixeira", 88, 526, 0),
    # Quartel: holofotes nos cantos e portões, placa
    ("quartel", "holofote", 227, 227, 45), ("quartel", "holofote", 405, 227, 135), ("quartel", "holofote", 405, 371, 225),
    ("quartel", "holofote", 227, 371, 315), ("quartel", "holofote", 316, 371, 270), ("quartel", "holofote", 405, 300, 180),
    ("quartel", "holofote", 312, 227, 90), ("quartel", "holofote", 330, 228, 90), ("quartel", "holofote", 212, 320, 0),
    ("quartel", "placa_estrada", 318, 205, 0), ("quartel", "tambor", 404, 242, 0), ("quartel", "tambor", 404, 244, 0),
    ("quartel", "banco_praca", 300, 318, 0), ("quartel", "banco_praca", 324, 318, 0),
    # Pedreira
    ("pedreira", "placa_estrada", 340, -60, 160), ("pedreira", "carrinho_mao", 330, -8, 30), ("pedreira", "tambor", 352, 2, 0),
    ("pedreira", "pilha_tijolo", 322, 12, 30),
    # Pista: biruta ao sul da pista, placa
    ("pista_pouso", "biruta", 330, -331, 0), ("pista_pouso", "placa_estrada", 222, -392, 35),
    ("pista_pouso", "tambor", 386, -212, 0), ("pista_pouso", "tambor", 388, -212, 0),
    # Represa
    ("represa", "placa_estrada", -135, -55, 350), ("represa", "lixeira", -66, -113, 0), ("represa", "holofote", -132, -70, 315),
    ("represa", "holofote", -70, -100, 135),
    # Fazenda: terreiro de café, porteiras, placa
    ("fazenda_boa_esperanca", "carrinho_mao", -115, -318, 0), ("fazenda_boa_esperanca", "carrinho_mao", -95, -326, 60),
    ("fazenda_boa_esperanca", "placa_estrada", -236, -306, 15), ("fazenda_boa_esperanca", "tambor", -52, -366, 0),
    ("fazenda_boa_esperanca", "barril", -74, -366, 0),
    # Praia: canoas na areia, orelhão, placa, lixeiras da orla
    ("praia_quiosques", "canoa_praia", 10, -500, 5), ("praia_quiosques", "canoa_praia", 47, -503, 355),
    ("praia_quiosques", "canoa_praia", 82, -505, 10), ("praia_quiosques", "canoa_praia", 118, -505, 0),
    ("praia_quiosques", "canoa_praia", 188, -498, 15), ("praia_quiosques", "canoa_praia", 206, -494, 20),
    ("praia_quiosques", "orelhao", 108, -440, 0), ("praia_quiosques", "placa_estrada", 100, -415, 180),
    ("praia_quiosques", "lixeira", 15, -470, 0), ("praia_quiosques", "lixeira", 85, -470, 0), ("praia_quiosques", "lixeira", 155, -470, 0),
    ("praia_quiosques", "caixote_peixe", 196, -490, 10), ("praia_quiosques", "bicicleta", 120, -440, 90),
]

# ===========================================================================
# 3. LINHAS DE FIAÇÃO (postes em sequência) — mundo
# ===========================================================================
LINHAS = [
    {"nome": "Vila - rede principal (E9 -> ponte -> E1)", "tipo_poste": "poste_madeira", "poi": "vila_caicara", "postes": [
        (-424, -172), (-420, -205), (-419, -238), (-405, -262), (-386, -294), (-366, -316), (-352, -340),
        (-322, -326), (-290, -326), (-258, -318), (-228, -310)]},
    {"nome": "Vila - rua da praia (V1)", "tipo_poste": "poste_madeira", "poi": "vila_caicara", "postes": [
        (-386, -294), (-418, -296), (-437, -318), (-452, -338)]},
    {"nome": "Vila - capela e ranchos", "tipo_poste": "poste_madeira", "poi": "vila_caicara", "postes": [
        (-352, -340), (-362, -362), (-372, -392)]},
    {"nome": "Vila - lado leste", "tipo_poste": "poste_madeira", "poi": "vila_caicara", "postes": [
        (-290, -326), (-282, -360), (-278, -390)]},
    {"nome": "Vila -> Fazenda (E1)", "tipo_poste": "poste_madeira", "poi": "fazenda_boa_esperanca", "postes": [
        (-228, -310), (-209.5, -295.4), (-185.4, -277.6), (-148.8, -256.8), (-125.8, -247.2), (-112, -236)]},
    {"nome": "Fazenda - ramal do casarão", "tipo_poste": "poste_madeira", "poi": "fazenda_boa_esperanca", "postes": [
        (-125.8, -247.2), (-126, -268)]},
    {"nome": "Usina -> Morro (E8)", "tipo_poste": "poste_concreto", "poi": "usina_santa_cruz", "postes": [
        (-250.2, 314.5), (-272.6, 294.5), (-295, 274.5), (-322.8, 250.1), (-352.9, 223.9), (-375.1, 195.6),
        (-395, 160.9), (-408.5, 120.9), (-396, 96), (-398, 64), (-392, 30), (-376, -2), (-352, -14), (-330, -22)]},
    {"nome": "Morro - escadaria (V2)", "tipo_poste": "poste_concreto", "poi": "morro_cruzeiro", "postes": [
        (-330, -22), (-304, -12), (-315, 14), (-326, 44), (-312, 62)]},
    {"nome": "Morro - fileira de baixo (E10)", "tipo_poste": "poste_concreto", "poi": "morro_cruzeiro", "postes": [
        (-330, -22), (-300, -40), (-270, -38), (-240, -42)]},
    {"nome": "Morro - ramal leste", "tipo_poste": "poste_concreto", "poi": "morro_cruzeiro", "postes": [
        (-304, -12), (-282, -8), (-266, 6), (-252, 34)]},
    {"nome": "Represa -> Morro (E10)", "tipo_poste": "poste_concreto", "poi": "represa", "postes": [
        (-162, -78), (-165, -50), (-200, -42), (-240, -22), (-280, -24), (-300, -40)]},
    {"nome": "Quartel - rede interna", "tipo_poste": "poste_concreto", "poi": "quartel", "postes": [
        (306, 232), (326, 250), (330, 272), (333, 297), (335, 322), (290, 322), (255, 322)]},
    {"nome": "Pista - pátio (E4)", "tipo_poste": "poste_madeira", "poi": "pista_pouso", "postes": [
        (288.6, -268), (327.6, -259.2), (368.2, -249.8), (407, -240.1)]},
    {"nome": "Farol - ramal (E6)", "tipo_poste": "poste_madeira", "poi": "farol_ponta_norte", "postes": [
        (98.8, 451.6), (80.8, 475.6), (104, 498)]},
    {"nome": "Pedreira - ramal (E5)", "tipo_poste": "poste_madeira", "poi": "pedreira", "postes": [
        (345, -35), (372, -10)]},
    {"nome": "Praia - orla (E2/E3)", "tipo_poste": "poste_madeira", "poi": "praia_quiosques", "postes": [
        (36, -404), (75, -414), (110, -416)]},
    {"nome": "Praia - ramal do restaurante", "tipo_poste": "poste_madeira", "poi": "praia_quiosques", "postes": [
        (75, -414), (66, -432)]},
]

# ===========================================================================
# 4. CERCAS E MUROS — mundo (polilinhas); gaps de estrada escritos à mão
# ===========================================================================
CERCAS = [
    # Quartel: muro alto do layout, aberto nos portões sul (E5) e oeste (E6)
    {"poi": "quartel", "tipo": "muro_alto", "pontos": [(303.7, 222), (410, 222), (410, 376), (222, 376), (222, 326)]},
    {"poi": "quartel", "tipo": "muro_alto", "pontos": [(222, 308.4), (222, 222), (292.5, 222)]},
    # Usina: muro alto em volta do complexo; portões na E7 (NE), E8 (SO) e na trilha T1 (SE)
    {"poi": "usina_santa_cruz", "tipo": "muro_alto", "pontos": [(-228.1, 326.5), (-210, 318), (-200, 300), (-205, 262), (-215.5, 251.1)]},
    {"poi": "usina_santa_cruz", "tipo": "muro_alto", "pontos": [(-224, 242.2), (-236, 246), (-290, 244), (-327.4, 232.6)]},
    {"poi": "usina_santa_cruz", "tipo": "muro_alto", "pontos": [(-333, 239), (-364, 296), (-378, 330), (-384, 365), (-360, 385), (-300, 392), (-250, 378), (-238, 360), (-236, 340), (-235.9, 329.5)]},
    # Farol: cerca de madeira na borda do costão
    {"poi": "farol_ponta_norte", "tipo": "cerca_madeira", "pontos": [(20, 522), (45, 538), (80, 542), (108, 528)]},
    # Pedreira: cerca de arame de segurança na borda norte/leste da cava
    {"poi": "pedreira", "tipo": "cerca_arame", "pontos": [(296, 70), (330, 70), (372, 64), (398, 40), (410, 0)]},
    # Pista: cerca de arame no perímetro sul/cabeceiras (aberta na E3)
    {"poi": "pista_pouso", "tipo": "cerca_arame", "pontos": [(240, -290), (200, -296), (185, -320), (190, -352), (207.5, -369), (233.2, -362.4)]},
    {"poi": "pista_pouso", "tipo": "cerca_arame", "pontos": [(243.8, -359.6), (477.5, -299), (488, -270), (470, -250)]},
    # Fazenda: pastos cercados de arame, manga do curral em madeira
    {"poi": "fazenda_boa_esperanca", "tipo": "cerca_arame", "pontos": [(-215, -255), (-190, -300), (-200, -345), (-190, -392)]},
    {"poi": "fazenda_boa_esperanca", "tipo": "cerca_arame", "pontos": [(-200, -215), (-150, -200), (-100, -190), (-80, -200), (-100, -228)]},
    {"poi": "fazenda_boa_esperanca", "tipo": "cerca_arame", "pontos": [(-50, -300), (-40, -360), (-50, -390), (-110, -402), (-160, -400)]},
    {"poi": "fazenda_boa_esperanca", "tipo": "cerca_madeira", "pontos": [(-64, -353), (-64, -363)]},
    {"poi": "fazenda_boa_esperanca", "tipo": "cerca_madeira", "pontos": [(-56, -353), (-56, -363)]},
    # Pasto Oeste (lado oeste da E9)
    {"poi": "vila_caicara", "tipo": "cerca_arame", "pontos": [(-406, -78), (-436, -168), (-431, -240)]},
]

# Portões: (poi, x, y, rot) — sobre as vias, nas aberturas dos muros (2 folhas de 4 m)
PORTOES = [
    ("quartel", 296.1, 222, 0), ("quartel", 300.1, 222, 0),                     # portão sul (E5)
    ("quartel", 222, 315.2, 90), ("quartel", 222, 319.2, 90),                   # portão oeste (E6)
    ("usina_santa_cruz", -230.1, 327.3, 339.4), ("usina_santa_cruz", -233.9, 328.7, 339.4),   # NE (E7)
    ("usina_santa_cruz", -328.9, 234.3, 311), ("usina_santa_cruz", -331.5, 237.3, 311),   # SO (E8)
    ("usina_santa_cruz", -222, 244.3, 46), ("usina_santa_cruz", -218, 248.6, 46),        # SE (trilha T1)
]

# ===========================================================================
# 5. Montagem e validação
# ===========================================================================
PORTA_LARGA = {"galpao", "hangar", "garagem_viaturas", "armazem_acucar", "casa_moenda", "rancho_pesca"}


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


def local(b, px, py):
    r = math.radians(b["rot_deg"]); x, y = b["pos"]
    return ((px - x) * math.cos(r) + (py - y) * math.sin(r), -(px - x) * math.sin(r) + (py - y) * math.cos(r))


def mundo(b, lx, ly):
    r = math.radians(b["rot_deg"]); x, y = b["pos"]
    return (x + lx * math.cos(r) - ly * math.sin(r), y + lx * math.sin(r) + ly * math.cos(r))


def dist_obb(b, px, py):
    lx, ly = local(b, px, py); w, d, _ = b["tamanho_m"]
    return math.hypot(max(abs(lx) - w / 2, 0), max(abs(ly) - d / 2, 0))


def na_porta(b, px, py):
    if not b.get("entravel"): return False
    lx, ly = local(b, px, py); w, d, _ = b["tamanho_m"]
    meia = 2.5 if b["tipo"] in PORTA_LARGA else 0.8
    return abs(lx) <= meia + 0.5 and -d / 2 - 2.0 <= ly <= -d / 2 + 0.01


class Mundo:
    def __init__(self):
        self.lay = json.load(open(LAYOUT, encoding="utf-8"))
        self.h = np.fromfile(HEIGHT, dtype="<f4").reshape(601, 601)
        self.predios = [dict(b, poi=p["id"]) for p in self.lay["pois"] + self.lay["marcos"] for b in p["predios"]]
        self.vias = self.lay["estradas"]
        self.rep = self.lay["agua"]["represa"]["contorno"]
        self.rio = [([q[:2] for q in t["pontos"]], t["largura_m"] / 2) for t in self.lay["agua"]["rio"]["trechos"]]
        veg = json.load(open(VEG, encoding="utf-8"))["instancias"]
        self.troncos = [(v["x"], v["y"]) for v in veg if v["tipo"] in ("arvore_mata_a", "arvore_mata_b", "coqueiro", "bananeira")]

    def z(self, x, y):
        c = int(round((x + 600) / 2)); r = int(round((600 - y) / 2))
        return float(self.h[min(600, max(0, r)), min(600, max(0, c))])

    def agua(self, x, y):
        if self.z(x, y) < 0.2 or not dentro(self.lay["costa"], x, y): return "mar"
        if dentro(self.rep, x, y): return "represa"
        if any(dist_poli(x, y, pts) < hw + 0.5 for pts, hw in self.rio): return "rio"
        return None

    def motivo_ponto(self, x, y, folga_via, prop=True):
        m = self.agua(x, y)
        if m: return m
        for e in self.vias:
            lim = e["largura_m"] / 2 + 0.5 if prop else max(4.0, e["largura_m"] / 2 + 0.5)
            if folga_via is not None: lim = folga_via(e)
            if dist_poli(x, y, e["pontos"]) < lim - 1e-6: return "via"
        for b in self.predios:
            if abs(b["pos"][0] - x) > 40 or abs(b["pos"][1] - y) > 40: continue
            if dist_obb(b, x, y) < 1.0 - 1e-6: return "prédio (1 m)"
            if na_porta(b, x, y): return "porta"
        return None


def main():
    W = Mundo()
    pb = {b["id"]: b for b in W.predios}
    props, cercas_in, descartes = [], [], Counter()
    avisos_veg = 0

    def add_prop(poi, tipo, x, y, rot, origem):
        props.append({"poi": poi, "tipo": tipo, "x": round(x, 2), "y": round(y, 2), "rot_deg": round(rot % 360, 1), "origem": origem})

    # kits
    for bid, kit in KIT_DO_PREDIO.items():
        b = pb[bid]
        for (tipo, lx, ly, rl) in KITS[kit]["props"]:
            x, y = mundo(b, lx, ly)
            add_prop(b["poi"], tipo, x, y, b["rot_deg"] + rl, f"{bid}:{kit}")
        for (tipo, pts) in KITS[kit]["cercas"]:
            cercas_in.append({"poi": b["poi"], "tipo": tipo, "pontos": [mundo(b, *q) for q in pts], "origem": f"{bid}:{kit}"})
    for (poi, tipo, x, y, rot) in AVULSOS:
        add_prop(poi, tipo, x, y, rot, "avulso")
    for c in CERCAS:
        cercas_in.append(dict(c, origem="avulso"))

    # --- validação de props (descarta e conta)
    props_ok = []
    for p in props:
        r = math.radians(p["rot_deg"]); h = MEIO.get(p["tipo"], 0.0)
        amostras = [(p["x"], p["y"])] + ([(p["x"] + s * h * math.cos(r), p["y"] + s * h * math.sin(r)) for s in (-1, 1)] if h else [])
        m = None
        for (x, y) in amostras:
            m = W.motivo_ponto(x, y, None, prop=True)
            if m: break
        if m: descartes[f"prop {p['tipo']}: {m}"] += 1; continue
        if any(math.hypot(tx - p["x"], ty - p["y"]) < 1.0 for tx, ty in W.troncos): avisos_veg += 1
        props_ok.append(p)

    # --- portões (sobre a via, mas não em prédio/água/porta)
    erros = []
    portoes = []
    for (poi, x, y, rot) in PORTOES:
        m = W.agua(x, y) or next((("prédio" if dist_obb(b, x, y) < 1.0 else "porta") for b in W.predios
                                   if dist_obb(b, x, y) < 1.0 or na_porta(b, x, y)), None)
        if m: erros.append(f"portão {x},{y}: {m}")
        portoes.append({"poi": poi, "tipo": "portao_ferro", "x": x, "y": y, "rot_deg": rot, "origem": "portão"})

    # --- linhas de fiação (erro se poste violar)
    for L in LINHAS:
        for (x, y) in L["postes"]:
            m = W.motivo_ponto(x, y, lambda e: e["largura_m"] / 2 + 1.0, prop=True)
            if m: erros.append(f"poste {L['nome']} ({x},{y}): {m}")
        vaos = [math.dist(L["postes"][i], L["postes"][i + 1]) for i in range(len(L["postes"]) - 1)]
        if max(vaos) > 45: erros.append(f"linha {L['nome']}: vão de {max(vaos):.0f} m (> 45 m)")

    # --- cercas: amostra a cada 0,5 m; trechos inválidos viram aberturas (contadas)
    cercas_ok = []
    for c in cercas_in:
        pts = c["pontos"]
        amostras = []
        for i in range(len(pts) - 1):
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            L = math.hypot(x2 - x1, y2 - y1); n = max(1, int(math.ceil(L / 0.5)))
            for k in range(n + (1 if i == len(pts) - 2 else 0)):
                t = k / n
                amostras.append((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t))
        ok = [W.motivo_ponto(x, y, None, prop=False) for (x, y) in amostras]
        run = []
        for (q, m) in zip(amostras, ok):
            if m is None:
                run.append(q)
            else:
                descartes[f"cerca {c['tipo']}: {m} (m)"] += 0.5
                if len(run) >= 7: cercas_ok.append((c, run))   # >= 3 m
                run = []
        if len(run) >= 7: cercas_ok.append((c, run))
    cercas_out = []
    for (c, run) in cercas_ok:
        # simplifica mantendo vértices originais (colineares removidos)
        simp = [run[0]]
        for i in range(1, len(run) - 1):
            ax, ay = simp[-1]; bx, by = run[i]; cx, cy = run[i + 1]
            if abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) > 1e-3: simp.append(run[i])
        simp.append(run[-1])
        comp = sum(math.dist(simp[i], simp[i + 1]) for i in range(len(simp) - 1))
        cercas_out.append({"poi": c["poi"], "tipo": c["tipo"], "pontos": [[round(x, 2), round(y, 2)] for x, y in simp],
                           "comprimento_m": round(comp, 1), "segmentos_3m": int(math.ceil(comp / 3.0)), "origem": c["origem"]})

    if erros:
        print("ERROS:"); [print("  ", e) for e in erros]
        return 1

    todos_props = props_ok + portoes
    por_tipo = Counter(p["tipo"] for p in todos_props)
    por_poi = defaultdict(Counter)
    for p in todos_props: por_poi[p["poi"]][p["tipo"]] += 1
    postes_poi = Counter()
    for L in LINHAS: postes_poi[L["poi"]] += len(L["postes"])
    postes_tipo = Counter()
    for L in LINHAS: postes_tipo[L["tipo_poste"]] += len(L["postes"])
    seg_tipo = Counter(); seg_poi = Counter()
    for c in cercas_out:
        seg_tipo[c["tipo"]] += c["segmentos_3m"]; seg_poi[c["poi"]] += c["segmentos_3m"]

    doc = {
        "versao": 1, "fonte": "tools/detalhes_src.py (kits por prédio + avulsos + linhas + cercas, tudo autoral)",
        "convencoes": {"coords": "metros; x leste, y norte; rot_deg em Z anti-horária", "porta": "face -Y local do prédio",
                       "postes": "só aparecem em linhas_fiacao (não repetidos em props)",
                       "cercas": "polilinhas; dividir em segmentos de 3 m (muro_baixo/muro_alto também 3 m)"},
        "tipos_extra": {"biruta": "não estava na lista de tipos — pedida no briefing da Pista; 1 instância"},
        "props": [{k: p[k] for k in ("tipo", "x", "y", "rot_deg", "poi")} for p in todos_props],
        "linhas_fiacao": [{"nome": L["nome"], "poi": L["poi"], "tipo_poste": L["tipo_poste"], "postes": [list(q) for q in L["postes"]]} for L in LINHAS],
        "cercas": [{k: c[k] for k in ("tipo", "pontos", "poi", "comprimento_m", "segmentos_3m")} for c in cercas_out],
        "resumo": {"props_por_tipo": dict(por_tipo), "postes_por_tipo": dict(postes_tipo), "segmentos_cerca_por_tipo": dict(seg_tipo),
                   "por_poi": {k: {"props": sum(v.values()), "postes": postes_poi.get(k, 0), "segmentos_cerca": seg_poi.get(k, 0), "tipos": dict(v)} for k, v in por_poi.items()},
                   "descartes": {k: v for k, v in descartes.items()}, "props_encostando_em_tronco_de_vegetacao": avisos_veg},
    }
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)

    # --- prévias recortadas por POI (sobre desenho simples)
    try:
        preview(W, doc)
    except Exception as ex:  # prévia é opcional
        print("prévia falhou:", ex)

    print(f"props {len(todos_props)} | postes {sum(postes_tipo.values())} em {len(LINHAS)} linhas | cercas {len(cercas_out)} polilinhas, {sum(seg_tipo.values())} segmentos de 3 m")
    print("props por tipo:", dict(sorted(por_tipo.items(), key=lambda kv: -kv[1])))
    print("postes:", dict(postes_tipo), "| segmentos:", dict(seg_tipo))
    for k in sorted(por_poi, key=lambda k: -sum(por_poi[k].values())):
        print(f"  {k:<24} props {sum(por_poi[k].values()):>4}  postes {postes_poi.get(k,0):>3}  seg.cerca {seg_poi.get(k,0):>4}")
    print("descartes:", dict(descartes))
    print("avisos (prop a < 1 m de tronco):", avisos_veg)
    return 0


def preview(W, doc):
    from PIL import Image, ImageDraw
    alvo = [("vila_caicara", (-470, -230, -220, -460)), ("morro_cruzeiro", (-420, 110, -230, -60)),
            ("usina_santa_cruz", (-400, 405, -190, 225)), ("quartel", (200, 400, 430, 190)),
            ("fazenda_boa_esperanca", (-230, -180, -20, -410)), ("praia_quiosques", (0, -390, 230, -525))]
    tiles = []
    for nome, (x0, y0, x1, y1) in alvo:
        S = 3.0
        im = Image.new("RGB", (int((x1 - x0) * S), int((y0 - y1) * S)), (214, 206, 170)); d = ImageDraw.Draw(im)
        P = lambda x, y: ((x - x0) * S, (y0 - y) * S)
        for e in W.vias:
            d.line([P(*q) for q in e["pontos"]], fill=(190, 150, 100), width=max(2, int(e["largura_m"] * S)))
        for pts, hw in W.rio:
            d.line([P(*q) for q in pts], fill=(80, 140, 200), width=int(2 * hw * S))
        for b in W.predios:
            w, dd, _ = b["tamanho_m"]
            cs = [P(*mundo(b, sx * w / 2, sy * dd / 2)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            d.polygon(cs, fill=(90, 84, 80), outline=(20, 20, 20))
            if b.get("entravel"):
                meia = 2.5 if b["tipo"] in PORTA_LARGA else 0.8
                a = P(*mundo(b, -meia, -dd / 2)); c = P(*mundo(b, meia, -dd / 2))
                d.line([a, c], fill=(255, 60, 60), width=3)
        COR = {"muro_alto": (60, 60, 60), "muro_baixo": (140, 110, 100), "cerca_madeira": (130, 80, 40), "cerca_arame": (240, 240, 240)}
        for c in doc["cercas"]:
            d.line([P(*q) for q in c["pontos"]], fill=COR[c["tipo"]], width=3 if "muro" in c["tipo"] else 2)
        for L in doc["linhas_fiacao"]:
            d.line([P(*q) for q in L["postes"]], fill=(30, 30, 30), width=1)
            for q in L["postes"]:
                x, y = P(*q); d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=(250, 200, 0), outline=(0, 0, 0))
        for p in doc["props"]:
            x, y = P(p["x"], p["y"])
            cor = (0, 120, 255) if p["tipo"] in ("canoa_praia", "mesa_bar_cadeiras", "banco_praca") else (220, 0, 180) if p["tipo"] in ("holofote", "portao_ferro", "orelhao") else (0, 150, 60)
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=cor)
        d.text((6, 6), nome, fill=(0, 0, 0))
        tiles.append(im)
    Wd = sum(t.width for t in tiles[:3]); H = max(t.height for t in tiles[:3]) + max(t.height for t in tiles[3:])
    out = Image.new("RGB", (max(Wd, sum(t.width for t in tiles[3:])), H), (255, 255, 255))
    x = 0
    for t in tiles[:3]: out.paste(t, (x, 0)); x += t.width
    x = 0; y = max(t.height for t in tiles[:3])
    for t in tiles[3:]: out.paste(t, (x, y)); x += t.width
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    out.save(PREVIEW)


if __name__ == "__main__":
    sys.exit(main())
