# -*- coding: utf-8 -*-
"""Alamedas ao lado das estradas (referência docs/ref/mosin_lowpoly.png): árvores em fila, alternadas entre os dois lados,
a 5,5 m do eixo (estradas de 7 m) ou 5,0 m (6 m). Cada trecho foi escolhido por ser campo aberto (sem mata, sem barranco)."""
from cenario_02_src import *

ROT = (0, 70, 140, 210, 280, 35, 105, 175, 245, 315)
ESC = (1.0, 0.9, 1.1, 0.95, 1.05)


def lado(a, b, passo, off, sentido, tipos, ini, fim=None):
    ao_longo(a, b, passo, off, sentido, tipos, ini=ini, fim=fim, rot_extra=ROT, esc=ESC)


def alameda(a, b, tipos, passo=15.0, off=5.5, ini=0.0, fim=None, lados=(1, -1)):
    """duas fileiras em quincôncio: a segunda começa meio passo adiante."""
    for k, sd in enumerate(lados):
        lado(a, b, passo, off, sd, tipos if k == 0 else tipos[::-1], ini + (passo / 2 if k else 0), fim)


def montar():
    area("Alamedas das estradas",
         "As estradas de terra ganham fileiras de árvores nos trechos de campo aberto, em quincôncio, como na referência de FPS "
         "low poly: sombra e linha de fuga para quem corre de carro ou a pé, e cobertura lateral de tronco.")
    E = lambda *pts: pts
    # E2 Coqueiros: reta sul da fazenda (campo aberto) rumo ao litoral
    alameda((-40, -280), (0, -395), ["carvalho", "arvore_d", "betula", "arvore_b"], passo=16, ini=30, fim=110)
    # E3 Pista: da praia ao entroncamento
    alameda((100, -425), (170, -420), ["arvore_b", "betula", "arvore_d"], passo=16, ini=8, fim=64)
    # E4 Leste: duas retas longas
    alameda((360, -258), (440, -238), ["betula", "arvore_d", "carvalho"], passo=16, ini=10, fim=76)
    alameda((440, -238), (420, -150), ["arvore_d", "betula", "arvore_b"], passo=16, ini=8, fim=84)
    # E5 Quartel-Pedreira: subida suave
    alameda((430, 70), (410, 150), ["pinheiro_medio", "carvalho", "pinheiro_medio", "betula"], passo=16, ini=8, fim=76)
    # E7 Norte: eixo do planalto
    alameda((-60, 405), (-150, 390), ["pinheiro_medio", "betula", "pinheiro_medio", "arvore_b"], passo=16, off=5.0, ini=8, fim=84)
    # E8: costa oeste
    alameda((-300, 262), (-360, 210), ["pinheiro_medio", "carvalho", "arvore_d"], passo=16, ini=8, fim=76)
    # E9: costa oeste sul (reta)
    alameda((-430, -170), (-425, -240), ["betula", "arvore_b", "arvore_d"], passo=16, ini=6, fim=64)
    # E1: entrada da Vila
    alameda((-300, -335), (-230, -318), ["arvore_d", "betula", "carvalho"], passo=16, ini=8, fim=26)
    alameda((-300, -335), (-230, -318), ["carvalho", "betula", "arvore_d"], passo=16, ini=50, fim=70)   # depois da casa do pacote (-265,-330)
    # E6: Farol
    alameda((200, 360), (150, 410), ["pinheiro_medio", "betula", "pinheiro_medio", "arvore_b"], passo=16, off=5.0, ini=6, fim=64)
    # --- segunda leva: mais trechos abertos, passo de 18 m
    alameda((-105, -245), (-40, -280), ["arvore_d", "carvalho", "betula"], passo=22, ini=12, fim=40)
    alameda((170, -420), (230, -380), ["betula", "arvore_b", "arvore_d"], passo=22, ini=6, fim=66)
    alameda((410, -80), (360, -60), ["arvore_d", "carvalho"], passo=22, ini=6, fim=50)
    alameda((400, -10), (430, 70), ["pinheiro_medio", "betula", "carvalho"], passo=22, ini=6, fim=80)
    alameda((-150, 390), (-220, 360), ["pinheiro_medio", "arvore_b", "pinheiro_medio", "betula"], passo=22, off=5.0, ini=6, fim=72)
    alameda((20, 440), (-60, 405), ["betula", "pinheiro_medio", "arvore_b"], passo=22, off=5.0, ini=6, fim=80)
    alameda((-400, -80), (-430, -170), ["carvalho", "betula", "arvore_b"], passo=22, ini=8, fim=90, lados=(1,))
    alameda((-230, -318), (-165, -270), ["carvalho", "arvore_d", "betula"], passo=22, ini=8, fim=76)


montar()
