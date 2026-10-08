# Interiores dos prédios: móveis low poly modelados à mão (peças em medidas explícitas) e o "Comodo", um
# organizador que encosta cada móvel numa parede, respeita vãos de porta/janela e reserva os pontos de saque.
# Usado por build_predios.py e predios_lote2..5.py (importado depois que a classe Kit existe).
#
# Quadro local de cada móvel: origem no centro da pegada, no piso; costas do móvel para +Y, frente para -Y.
# Kit.push(x, y, z, rot) / Kit.pop() empilham transformações (rot em graus, eixo Z do Blender).
import math, json, os
from mathutils import Vector, Matrix

V = Vector
LOOT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_loot")
os.makedirs(LOOT_DIR, exist_ok=True)


# ====================================================================== peças (desenham no quadro local atual)
def sofa(k, w=2.0, cor="barra_azul"):
    d = 0.9
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, 0.14, "madeira")
    k.caixa(-w / 2 + 0.02, -d / 2 + 0.02, 0.14, w / 2 - 0.02, d / 2 - 0.02, 0.44, cor)
    k.caixa(-w / 2, d / 2 - 0.22, 0.44, w / 2, d / 2, 0.95, cor)
    for s in (-1, 1):
        k.caixa(s * (w / 2 - 0.11) - 0.11, -d / 2, 0.14, s * (w / 2 - 0.11) + 0.11, d / 2, 0.66, cor)


def poltrona(k, w=0.9, cor="janela_verde"):
    sofa(k, w, cor)


def mesa(k, w=1.4, d=0.8, h=0.75, tampo="madeira_clara", perna="madeira"):
    k.caixa(-w / 2, -d / 2, h - 0.06, w / 2, d / 2, h, tampo)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.caixa(sx * (w / 2 - 0.07) - 0.035, sy * (d / 2 - 0.07) - 0.035, 0.0, sx * (w / 2 - 0.07) + 0.035, sy * (d / 2 - 0.07) + 0.035, h - 0.06, perna)


def mesa_centro(k, w=1.0, d=0.5):
    mesa(k, w, d, 0.42, "madeira", "madeira")


def cadeira(k, cor="madeira"):
    k.caixa(-0.21, -0.21, 0.43, 0.21, 0.21, 0.47, cor)
    k.caixa(-0.21, 0.17, 0.47, 0.21, 0.21, 0.92, cor)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.caixa(sx * 0.18 - 0.02, sy * 0.18 - 0.02, 0.0, sx * 0.18 + 0.02, sy * 0.18 + 0.02, 0.43, cor)


def banco(k, w=1.2, d=0.35, h=0.46, cor="madeira_clara"):
    mesa(k, w, d, h, cor, "madeira")


def cama(k, w=1.1, l=2.0, colcha="reboco_azul"):
    """Cabeceira em +Y, pés em -Y."""
    k.caixa(-w / 2, -l / 2, 0.1, w / 2, l / 2, 0.3, "madeira")
    k.caixa(-w / 2 + 0.03, -l / 2 + 0.03, 0.3, w / 2 - 0.03, l / 2 - 0.03, 0.5, colcha)
    k.caixa(-w / 2 + 0.1, l / 2 - 0.5, 0.5, w / 2 - 0.1, l / 2 - 0.1, 0.6, "reboco_branco")        # travesseiro
    k.caixa(-w / 2, l / 2 - 0.06, 0.1, w / 2, l / 2, 1.0, "madeira")                                 # cabeceira
    for sx in (-1, 1):
        k.caixa(sx * (w / 2 - 0.04) - 0.04, -l / 2, 0.0, sx * (w / 2 - 0.04) + 0.04, -l / 2 + 0.08, 0.1, "madeira")
        k.caixa(sx * (w / 2 - 0.04) - 0.04, l / 2 - 0.08, 0.0, sx * (w / 2 - 0.04) + 0.04, l / 2, 0.1, "madeira")


def beliche(k, w=0.95, l=2.0, colcha="verde_militar"):
    for z in (0.0, 1.05):
        k.caixa(-w / 2, -l / 2, z + 0.25, w / 2, l / 2, z + 0.4, "tabua_escura")
        k.caixa(-w / 2 + 0.03, -l / 2 + 0.03, z + 0.4, w / 2 - 0.03, l / 2 - 0.03, z + 0.55, colcha)
        k.caixa(-w / 2 + 0.1, l / 2 - 0.45, z + 0.55, w / 2 - 0.1, l / 2 - 0.1, z + 0.63, "reboco_branco")
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.caixa(sx * (w / 2 - 0.03) - 0.03, sy * (l / 2 - 0.03) - 0.03, 0.0, sx * (w / 2 - 0.03) + 0.03, sy * (l / 2 - 0.03) + 0.03, 1.75, "madeira")


def guarda_roupa(k, w=1.5, d=0.6, h=2.0):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, "madeira")
    k.caixa(-w / 2 + 0.04, -d / 2 - 0.02, 0.08, -0.02, -d / 2, h - 0.08, "madeira_clara")            # portas
    k.caixa(0.02, -d / 2 - 0.02, 0.08, w / 2 - 0.04, -d / 2, h - 0.08, "madeira_clara")
    for s in (-1, 1):
        k.caixa(s * 0.07 - 0.015, -d / 2 - 0.05, 0.9, s * 0.07 + 0.015, -d / 2 - 0.02, 1.2, "ferro")


def criado(k, w=0.45, d=0.4, h=0.5):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, "madeira")
    k.caixa(-w / 2 + 0.03, -d / 2 - 0.015, 0.06, w / 2 - 0.03, -d / 2, h - 0.06, "madeira_clara")


def fogao(k, w=0.6, d=0.6):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, 0.9, "reboco_branco")
    k.caixa(-w / 2 + 0.05, -d / 2 - 0.02, 0.08, w / 2 - 0.05, -d / 2, 0.55, "ferro")                # porta do forno
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.caixa(sx * 0.14 - 0.06, sy * 0.14 - 0.06, 0.9, sx * 0.14 + 0.06, sy * 0.14 + 0.06, 0.93, "ferro")
    k.caixa(-w / 2, d / 2 - 0.06, 0.9, w / 2, d / 2, 1.15, "reboco_branco")                          # painel


def geladeira(k, w=0.7, d=0.7, h=1.75):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, "reboco_branco")
    k.caixa(-w / 2, -d / 2 - 0.02, 1.15, w / 2, -d / 2, 1.18, "ferro")                               # divisão das portas
    k.caixa(w / 2 - 0.1, -d / 2 - 0.04, 1.25, w / 2 - 0.06, -d / 2, 1.6, "ferro")
    k.caixa(w / 2 - 0.1, -d / 2 - 0.04, 0.6, w / 2 - 0.06, -d / 2, 1.0, "ferro")


def pia(k, w=1.2, d=0.6):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, 0.85, "madeira_clara")
    k.caixa(-w / 2 - 0.02, -d / 2 - 0.02, 0.85, w / 2 + 0.02, d / 2, 0.9, "zinco")
    k.caixa(-0.3, -0.2, 0.86, 0.3, 0.2, 0.91, "ferro")                                                # cuba
    k.caixa(-0.02, d / 2 - 0.1, 0.9, 0.02, d / 2 - 0.06, 1.12, "zinco")                               # torneira
    k.caixa(-0.02, d / 2 - 0.1, 1.08, 0.02, d / 2 - 0.02, 1.12, "zinco")


def armario_baixo(k, w=1.0, d=0.55, h=0.85):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, "madeira_clara")
    k.caixa(-w / 2 - 0.02, -d / 2 - 0.02, h, w / 2 + 0.02, d / 2, h + 0.05, "madeira")
    k.caixa(-0.01, -d / 2 - 0.015, 0.06, 0.01, -d / 2, h - 0.06, "madeira")


def armario_alto(k, w=1.0, d=0.35):
    """Armário de parede (z 1.4 a 2.1): só visual, não desce ao piso."""
    k.caixa(-w / 2, -d / 2, 1.45, w / 2, d / 2, 2.1, "madeira_clara")
    k.caixa(-0.01, -d / 2 - 0.015, 1.5, 0.01, -d / 2, 2.05, "madeira")


def aparador(k, w=1.4, d=0.45, h=0.85):
    armario_baixo(k, w, d, h)


def tv_rack(k, w=1.3, d=0.45):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, 0.5, "madeira")
    k.caixa(-w / 2 + 0.03, -d / 2 - 0.015, 0.05, w / 2 - 0.03, -d / 2, 0.45, "madeira_clara")
    k.caixa(-0.45, -0.05, 0.5, 0.45, 0.05, 0.58, "ferro")
    k.caixa(-0.5, -0.04, 0.58, 0.5, 0.04, 1.08, "ferro")                                              # TV
    k.caixa(-0.46, -0.05, 0.62, 0.46, -0.04, 1.04, "vidro")


def estante(k, w=1.2, d=0.4, h=2.0, tiers=5):
    for sx in (-1, 1):
        k.caixa(sx * (w / 2 - 0.02) - 0.02, -d / 2, 0.0, sx * (w / 2 - 0.02) + 0.02, d / 2, h, "madeira")
    k.caixa(-w / 2, d / 2 - 0.015, 0.0, w / 2, d / 2, h, "madeira")
    for i in range(tiers):
        z = 0.08 + i * (h - 0.12) / (tiers - 1)
        k.caixa(-w / 2, -d / 2, z, w / 2, d / 2, z + 0.03, "madeira_clara")


def estante_carga(k, w=1.6, d=0.6, h=2.2, tiers=4):
    """Prateleira de depósito (ferro + tábua) com caixotes nos andares de baixo."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.caixa(sx * (w / 2 - 0.03) - 0.03, sy * (d / 2 - 0.03) - 0.03, 0.0, sx * (w / 2 - 0.03) + 0.03, sy * (d / 2 - 0.03) + 0.03, h, "ferro")
    for i in range(tiers):
        z = 0.15 + i * (h - 0.3) / (tiers - 1)
        k.caixa(-w / 2, -d / 2, z, w / 2, d / 2, z + 0.04, "tabua")
        if i < tiers - 1 and i % 2 == 0:
            k.caixa(-w / 2 + 0.1, -d / 2 + 0.08, z + 0.04, -w / 2 + 0.5, d / 2 - 0.08, z + 0.42, "tabua_escura")
            k.caixa(0.05, -d / 2 + 0.08, z + 0.04, 0.6, d / 2 - 0.08, z + 0.34, "verde_militar")


def caixote(k, s=0.6, cor="tabua"):
    k.caixa(-s / 2, -s / 2, 0.0, s / 2, s / 2, s, cor)
    for z in (0.05, s - 0.1):
        k.caixa(-s / 2 - 0.01, -s / 2 - 0.01, z, s / 2 + 0.01, s / 2 + 0.01, z + 0.05, "tabua_escura")


def caixotes(k, n=2):
    caixote(k, 0.7, "tabua")
    k.push(0.75, 0.05, 0, 14)
    caixote(k, 0.55, "tabua_escura")
    k.pop()
    if n > 2:
        k.push(0.05, 0.0, 0.7, -10)
        caixote(k, 0.5, "tabua")
        k.pop()


def pallet(k, w=1.2, d=0.8, carga=True):
    for x in (-w / 2 + 0.06, 0.0, w / 2 - 0.06):
        k.caixa(x - 0.06, -d / 2, 0.0, x + 0.06, d / 2, 0.1, "madeira")
    for i in range(5):
        y = -d / 2 + 0.08 + i * (d - 0.16) / 4
        k.caixa(-w / 2, y - 0.05, 0.1, w / 2, y + 0.05, 0.14, "tabua")
    if carga:
        k.caixa(-w / 2 + 0.05, -d / 2 + 0.05, 0.14, -0.02, d / 2 - 0.05, 0.74, "verde_militar")
        k.caixa(0.02, -d / 2 + 0.05, 0.14, w / 2 - 0.05, d / 2 - 0.05, 0.54, "tabua_escura")


def tambor(k, r=0.3, h=0.9, cor="verde_militar", lados=8):
    k.prisma([(r * math.cos(a), r * math.sin(a), 0.0) for a in [i * math.tau / lados for i in range(lados)]], (0, 0, h), cor)


def tambores(k):
    for (x, y, c) in ((-0.35, 0.0, "verde_militar"), (0.35, 0.05, "placa"), (0.0, 0.6, "zinco_ferrugem")):
        k.push(x, y, 0, 0)
        tambor(k, 0.29, 0.9, c)
        k.pop()


def bancada(k, w=2.0, d=0.7, h=0.92):
    mesa(k, w, d, h, "tabua", "ferro")
    k.caixa(-w / 2 + 0.05, d / 2 - 0.05, h, w / 2 - 0.05, d / 2, h + 0.5, "madeira")                  # painel de ferramentas


def mesa_escritorio(k, w=1.5, d=0.75):
    mesa(k, w, d, 0.76, "madeira", "ferro")
    k.caixa(-w / 2 + 0.05, -d / 2 + 0.05, 0.1, -w / 2 + 0.45, d / 2 - 0.05, 0.7, "madeira_clara")     # gavetas
    k.caixa(0.2, d / 2 - 0.3, 0.76, 0.6, d / 2 - 0.1, 1.0, "ferro")                                   # monitor


def arquivo(k, w=0.5, d=0.6, h=1.3):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, "zinco")
    for z in (0.15, 0.55, 0.95):
        k.caixa(-w / 2 + 0.03, -d / 2 - 0.015, z, w / 2 - 0.03, -d / 2, z + 0.32, "ferro")


def balcao(k, w=2.4, d=0.6, h=1.05, cor="madeira"):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, h, cor)
    k.caixa(-w / 2 - 0.05, -d / 2 - 0.05, h, w / 2 + 0.05, d / 2 + 0.05, h + 0.06, "madeira_clara")


def vaso(k):
    k.caixa(-0.2, -0.3, 0.0, 0.2, 0.25, 0.4, "reboco_branco")
    k.caixa(-0.2, 0.15, 0.4, 0.2, 0.3, 0.9, "reboco_branco")


def lavatorio(k):
    k.caixa(-0.3, -0.2, 0.0, 0.3, 0.2, 0.85, "reboco_branco")
    k.caixa(-0.3, -0.2, 0.85, 0.3, 0.2, 0.9, "zinco")


def tapete(k, w=2.0, d=1.4, cor="barra_azul"):
    k.caixa(-w / 2, -d / 2, 0.0, w / 2, d / 2, 0.012, cor)


def mesa_longa(k, w=3.0, d=0.8):
    mesa(k, w, d, 0.76, "tabua", "madeira")


def banco_longo(k, w=3.0):
    banco(k, w, 0.3, 0.46, "tabua_escura")


def mesa_bar(k, w=0.9, d=0.9):
    mesa(k, w, d, 0.76, "madeira_clara", "ferro")


def fardos(k):
    caixote(k, 0.6, "sape")
    k.push(0.65, 0, 0, 0)
    caixote(k, 0.6, "sape")
    k.pop()
    k.push(0.3, 0, 0.6, 8)
    caixote(k, 0.55, "sape")
    k.pop()


def pneus(k):
    for z in (0.0, 0.25):
        k.prisma([(0.3 * math.cos(a), 0.3 * math.sin(a), 0.0) for a in [i * math.tau / 8 for i in range(8)]], (0, 0, 0.25), "ferro") if False else None
        k.caixa(-0.3, -0.3, z, 0.3, 0.3, z + 0.24, "ferro")


# nome -> (largura padrão, profundidade padrão, altura, função). w/d podem ser sobrescritos: enc("sofa", "S", w=1.6)
PECAS = {
    "sofa": (2.0, 0.9, 0.95, sofa), "poltrona": (0.9, 0.9, 0.95, poltrona), "mesa": (1.4, 0.8, 0.75, mesa), "mesa_centro": (1.0, 0.5, 0.42, mesa_centro),
    "cadeira": (0.44, 0.44, 0.92, cadeira), "banco": (1.2, 0.35, 0.46, banco), "cama": (1.1, 2.0, 0.95, cama), "beliche": (0.95, 2.0, 1.75, beliche),
    "guarda_roupa": (1.5, 0.6, 2.0, guarda_roupa), "criado": (0.45, 0.4, 0.5, criado), "fogao": (0.6, 0.6, 0.95, fogao),
    "geladeira": (0.7, 0.7, 1.75, geladeira), "pia": (1.2, 0.6, 0.95, pia), "armario_baixo": (1.0, 0.55, 0.9, armario_baixo),
    "armario_alto": (1.0, 0.35, 0.0, armario_alto), "aparador": (1.4, 0.45, 0.85, aparador), "tv_rack": (1.3, 0.45, 0.95, tv_rack),
    "estante": (1.2, 0.4, 2.0, estante), "estante_carga": (1.6, 0.6, 2.2, estante_carga), "caixotes": (1.4, 0.8, 0.7, caixotes),
    "caixote": (0.6, 0.6, 0.6, caixote), "pallet": (1.2, 0.8, 0.75, pallet), "tambores": (1.0, 1.0, 0.9, tambores),
    "bancada": (2.0, 0.7, 1.4, bancada), "mesa_escritorio": (1.5, 0.75, 1.0, mesa_escritorio), "arquivo": (0.5, 0.6, 1.3, arquivo),
    "balcao": (2.4, 0.6, 1.1, balcao), "vaso": (0.4, 0.6, 0.9, vaso), "lavatorio": (0.6, 0.4, 0.9, lavatorio), "tapete": (2.0, 1.4, 0.012, tapete),
    "mesa_longa": (3.0, 0.8, 0.76, mesa_longa), "banco_longo": (3.0, 0.3, 0.46, banco_longo), "mesa_bar": (0.9, 0.9, 0.76, mesa_bar),
    "fardos": (1.3, 0.7, 1.1, fardos),
}
# peças sem colisão relevante/que ficam no ar: não entram na checagem de pegada
SEM_PEGADA = {"armario_alto", "tapete"}


# ====================================================================== mobília do pacote do usuário (tools/importar_moveis.py)
# As peças com equivalente NÃO são desenhadas na malha do prédio: a colocação (modelo, posição/giro local no prédio, escala) vai
# para game/maps/ilha/moveis.json e o jogo instancia o .glb (game/assets/models/moveis) com colisão de caixa (core/moveis.gd).
# tipo -> candidatos, altura-alvo fixa (None = altura real do modelo), altura máxima, modular (divide a largura em módulos de ~0,8 m)
MOVEIS = {
    "sofa": (["sofa_a", "sofa_b", "sofa_c", "sofa_d"], None, 1.0, False),
    "poltrona": (["poltrona_a", "poltrona_b", "poltrona_c", "poltrona_d"], None, 1.0, False),
    "cama": (["cama_a", "cama_b", "cama_c", "cama_d"], None, 1.25, False),
    "guarda_roupa": (["guarda_roupa_a", "guarda_roupa_b"], None, 2.1, False),
    "criado": (["comoda_c", "comoda_f"], 0.55, 0.6, False),
    "fogao": (["fogao_a"], None, 1.1, False),
    "geladeira": (["geladeira_a"], 1.75, 1.8, False),
    "pia": (["pia_a"], None, 1.2, True),
    "armario_baixo": (["armario_baixo_a", "armario_baixo_b"], None, 0.9, True),
    "armario_alto": (["armario_alto_a"], None, 0.7, True),
    "estante": (["estante_a", "estante_b", "estante_c", "estante_d", "cristaleira_a"], None, 2.1, False),
    "aparador": (["estante_baixa", "comoda_d", "comoda_e", "comoda_b"], 0.85, 0.9, False),
    "tv_rack": (["comoda_a", "comoda_b", "comoda_d"], 0.9, 0.95, False),
    "mesa": (["mesa_a", "mesa_c", "mesa_d", "mesa_b"], 0.75, 0.8, False),
    "mesa_centro": (["mesa_e", "mesa_a"], 0.42, 0.45, False),
    "mesa_bar": (["mesa_d", "mesa_c"], 0.76, 0.8, False),
    "mesa_longa": (["mesa_b", "mesa_e"], 0.76, 0.8, False),
    "cadeira": (["cadeira_a", "cadeira_b", "cadeira_c"], None, 1.1, False),
}
MODULO_Z = {"armario_alto": 1.4}       # altura da base acima do piso
_RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
_MANIF = os.path.join(_RAIZ, "game", "assets", "models", "moveis", "moveis.json")
MOVEIS_JSON = os.path.join(_RAIZ, "game", "maps", "ilha", "moveis.json")
DIM = json.load(open(_MANIF, encoding="utf8")) if os.path.exists(_MANIF) else {}
USAR_PACOTE = bool(DIM) and os.environ.get("MOVEIS_A_MAO") != "1"      # MOVEIS_A_MAO=1 volta aos móveis desenhados


def _escala(tipo, m, w, d, h_pedida):
    """Escala (x = largura, y = altura, z = profundidade) que cabe na pegada w x d; distorção limitada a 35 % entre eixos."""
    W, D, H = DIM[m]["dim"]
    _, h_alvo, h_max, _ = MOVEIS[tipo]
    sx, sz = w / W, d / D
    if h_pedida or h_alvo:
        sy = (h_pedida or h_alvo) / H
        base = min(sx, sz)
        sx, sz = min(sx, base * 1.35), min(sz, base * 1.35)
    else:
        sy = min(1.0, h_max / H)
        base = min(sx, sz, sy)
        sx, sy, sz = min(sx, base * 1.35), min(sy, base * 1.35), min(sz, base * 1.35)
    sy = min(sy, h_max / H)
    return sx, sy, sz


def _distorcao(tipo, m, w, d, h_pedida):
    sx, sy, sz = _escala(tipo, m, w, d, h_pedida)
    W, D, _ = DIM[m]["dim"]
    ocupa = (sx * W * sz * D) / max(w * d, 1e-6)           # quanto da pegada o modelo preenche
    return max(sx, sz, sy) / min(sx, sz, sy) + (1.0 - ocupa) * 1.5


def _escolher(k, tipo, w, d, h):
    """Modelo com menor distorção; entre os quase empatados alterna por prédio e por ordem da peça (fixo, nada sorteado)."""
    cands = [m for m in MOVEIS[tipo][0] if m in DIM]
    notas = sorted((_distorcao(tipo, m, w, d, h), m) for m in cands)
    bons = [m for n, m in notas if n <= notas[0][0] * 1.05 + 0.01]
    cont = k.__dict__.setdefault("_cont_moveis", {})
    i = cont.get(tipo, 0)
    cont[tipo] = i + 1
    return bons[(sum(map(ord, k.nome)) + i) % len(bons)]


def _registrar(k, m, ox, oz, esc):
    """Grava um móvel no quadro corrente do Kit (+ deslocamento local ox ao longo da largura, oz de altura) em coordenadas Godot."""
    M = k.xf @ Matrix.Translation(V((ox, 0.0, oz)))
    p = M.translation
    rot = math.degrees(math.atan2(M[1][0], M[0][0]))
    k.moveis.append({"m": m, "pos": [round(p.x, 3), round(p.z, 3), round(-p.y, 3)], "rot_y": round(rot, 2),
                     "esc": [round(esc[0], 4), round(esc[1], 4), round(esc[2], 4)]})


def mobilia_pacote(k, tipo, w, d, h=None):
    """Registra o móvel do pacote no lugar da peça desenhada (o quadro local já está empilhado no Kit)."""
    if not hasattr(k, "moveis"):
        k.moveis = []
    cands, h_alvo, h_max, modular = MOVEIS[tipo]
    z0 = MODULO_Z.get(tipo, 0.0)
    if modular:
        W0 = DIM[cands[0]]["dim"][0]
        n = max(1, int(w / W0 + 1e-6))
        resto = w - n * W0
        larguras = [W0] * n + [resto] if resto >= 0.25 else [w / n] * n
        x = -w / 2
        for i, seg in enumerate(larguras):
            if tipo == "pia":
                m = "pia_a" if i == 0 else ("armario_baixo_b" if i % 2 else "armario_baixo_a")
            else:
                m = cands[i % len(cands)]
            Wm, Dm, Hm = DIM[m]["dim"]
            sy = min(1.0, h_max / Hm)
            if m.startswith("armario_baixo") and tipo == "pia":
                sy = 0.9 / Hm                           # bancada ao lado da pia (a cuba tem ~0,9 m)
            _registrar(k, m, x + seg / 2, z0, (seg / Wm, sy, d / Dm))
            x += seg
        return
    m = _escolher(k, tipo, w, d, h)
    esc = _escala(tipo, m, w, d, h)
    _registrar(k, m, 0.0, z0, esc)
    if tipo == "criado":                                # abajur sobre o criado-mudo
        _registrar(k, "abajur", 0.0, DIM[m]["dim"][2] * esc[1], (0.6, 0.6, 0.6))


def salvar_moveis(nome, lista):
    """Atualiza game/maps/ilha/moveis.json (chave = nome do modelo do prédio). Lista vazia remove a chave."""
    dados = {}
    if os.path.exists(MOVEIS_JSON):
        with open(MOVEIS_JSON, encoding="utf8") as f:
            dados = json.load(f)
    if lista:
        dados[nome] = lista
    else:
        dados.pop(nome, None)
    with open(MOVEIS_JSON, "w", encoding="utf8") as f:
        json.dump(dict(sorted(dados.items())), f, ensure_ascii=False, separators=(",", ":"))


# ====================================================================== Comodo: organizador de móveis
PAREDES = {"N": (0, 0), "S": (0, 0), "E": (0, 0), "W": (0, 0)}
ROT_PAREDE = {"N": 0.0, "S": 180.0, "E": -90.0, "W": 90.0}          # costas do móvel para a parede
ROT_GODOT = {"N": 0.0, "S": 180.0, "E": 270.0, "W": 90.0}           # frente da caixa de saque voltada para dentro do cômodo


def _inter(a, b, folga=0.0):
    return a[0] < b[2] - folga and a[2] > b[0] + folga and a[1] < b[3] - folga and a[3] > b[1] + folga


class Comodo:
    """r = (x0, y0, x1, y1) área livre do cômodo; z = altura do piso; portas = [(cx, cy)] sobre o contorno (vão >= 1,1 m);
    janelas = [(cx, cy, larg)] sobre o contorno (móveis altos não tampam)."""

    def __init__(self, k, nome, r, z, portas=(), janelas=(), tipo=None):
        self.k, self.nome, self.r, self.z = k, nome, tuple(r), z
        self.tipo = tipo or nome
        self.ocupado = []          # retângulos ocupados por móveis / pontos de saque
        self.zonas = []            # vãos de porta: nunca recebem móvel nem saque
        self.jan = []              # vãos de janela: só liberam móveis baixos
        x0, y0, x1, y1 = self.r
        for pt in portas:
            cx, cy = pt[0], pt[1]
            m = max(0.6, pt[2] / 2) if len(pt) > 2 else 0.6      # (cx, cy[, largura do vão])
            if abs(cy - y0) < 0.35:
                self.zonas.append((cx - m, y0 - 0.3, cx + m, y0 + 1.0))
            elif abs(cy - y1) < 0.35:
                self.zonas.append((cx - m, y1 - 1.0, cx + m, y1 + 0.3))
            elif abs(cx - x0) < 0.35:
                self.zonas.append((x0 - 0.3, cy - m, x0 + 1.0, cy + m))
            else:
                self.zonas.append((x1 - 1.0, cy - m, x1 + 0.3, cy + m))
        for (cx, cy, lg) in janelas:
            m = lg / 2 + 0.05
            if abs(cy - y0) < 0.4:
                self.jan.append((cx - m, y0 - 0.3, cx + m, y0 + 0.6))
            elif abs(cy - y1) < 0.4:
                self.jan.append((cx - m, y1 - 0.6, cx + m, y1 + 0.3))
            elif abs(cx - x0) < 0.4:
                self.jan.append((x0 - 0.3, cy - m, x0 + 0.6, cy + m))
            else:
                self.jan.append((x1 - 0.6, cy - m, x1 + 0.3, cy + m))

    def _ok(self, ret, alto, folga=0.02):
        x0, y0, x1, y1 = self.r
        if ret[0] < x0 - 0.001 or ret[1] < y0 - 0.001 or ret[2] > x1 + 0.001 or ret[3] > y1 + 0.001:
            return False
        for o in self.ocupado + self.zonas:
            if _inter(ret, o, folga):
                return False
        if alto:
            for o in self.jan:
                if _inter(ret, o, 0.0):
                    return False
        return True

    def _ret(self, parede, frac, w, d):
        x0, y0, x1, y1 = self.r
        if parede in "NS":
            cx = x0 + w / 2 + frac * max(x1 - x0 - w, 0.0)
            cy = y1 - d / 2 if parede == "N" else y0 + d / 2
            return cx, cy, (cx - w / 2, cy - d / 2, cx + w / 2, cy + d / 2)
        cy = y0 + w / 2 + frac * max(y1 - y0 - w, 0.0)
        cx = x1 - d / 2 if parede == "E" else x0 + d / 2
        return cx, cy, (cx - d / 2, cy - w / 2, cx + d / 2, cy + w / 2)

    def enc(self, nome, parede, frac=0.5, w=None, d=None, alt=None, **kw):
        """Encosta o móvel na parede N/S/E/W. Se o ponto pedido estiver ocupado tenta outras posições ao longo da parede."""
        pw, pd, ph, fn = PECAS[nome]
        w = pw if w is None else w
        d = pd if d is None else d
        alto = ph > 0.95
        for f in [frac, 0.5, 0.15, 0.85, 0.3, 0.7, 0.0, 1.0]:
            cx, cy, ret = self._ret(parede, f, w, d)
            if nome in SEM_PEGADA:                      # móvel de parede (não ocupa piso): só respeita portas e janelas
                if not any(_inter(ret, o, 0.02) for o in self.zonas + self.jan):
                    self._por(nome, fn, cx, cy, ROT_PARede(parede), ret, w, d, kw, alt, reservar=False)
                    return (cx, cy)
                continue
            if self._ok(ret, alto):
                self._por(nome, fn, cx, cy, ROT_PARede(parede), ret, w, d, kw, alt)
                return (cx, cy)
        print("AVISO: sem lugar para", nome, "em", self.nome, parede)
        return None

    def livre(self, nome, cx, cy, rot=0.0, w=None, d=None, alt=None, **kw):
        """Móvel solto em (cx, cy) (centro), girado rot graus (0 = costas para +Y)."""
        pw, pd, ph, fn = PECAS[nome]
        w = pw if w is None else w
        d = pd if d is None else d
        rr = math.radians(rot)
        ex = abs(math.cos(rr)) * w / 2 + abs(math.sin(rr)) * d / 2
        ey = abs(math.sin(rr)) * w / 2 + abs(math.cos(rr)) * d / 2
        ret = (cx - ex, cy - ey, cx + ex, cy + ey)
        if nome in SEM_PEGADA:
            self._por(nome, fn, cx, cy, rot, ret, w, d, kw, alt, reservar=False)
            return (cx, cy)
        if self._ok(ret, ph > 0.95):
            self._por(nome, fn, cx, cy, rot, ret, w, d, kw, alt)
            return (cx, cy)
        print("AVISO: sem lugar (livre) para", nome, "em", self.nome, (round(cx, 2), round(cy, 2)))
        return None

    def _por(self, nome, fn, cx, cy, rot, ret, w, d, kw, alt, reservar=True):
        k = self.k
        k.push(cx, cy, self.z if alt is None else alt, rot)
        args = dict(kw)
        sig = fn.__code__.co_varnames[:fn.__code__.co_argcount]
        if "w" in sig and nome not in ("caixotes", "fardos"):
            args["w"] = w
        if "d" in sig:
            args["d"] = d
        if USAR_PACOTE and nome in MOVEIS:
            mobilia_pacote(k, nome, w, d, kw.get("h"))
        else:
            fn(k, **args)
        k.pop()
        if reservar:
            self.ocupado.append(ret)

    def _frente_loot(self, parede, ret):
        """Faixa de 0,8 m à frente da caixa (lado aberto): tem que ficar livre para o jogador chegar."""
        if parede == "N":
            return (ret[0], ret[1] - 0.8, ret[2], ret[1])
        if parede == "S":
            return (ret[0], ret[3], ret[2], ret[3] + 0.8)
        if parede == "E":
            return (ret[0] - 0.8, ret[1], ret[0], ret[3])
        return (ret[2], ret[1], ret[2] + 0.8, ret[3])

    def loot(self, parede, frac=0.5, tier="medio", sala=None):
        """Reserva uma pegada de 0,8 x 0,6 m encostada na parede (mais 0,8 m livres à frente) e registra o ponto de saque
        (coordenadas Godot locais: x, z = -y, y = piso, rot_deg com a frente da caixa voltada para dentro do cômodo)."""
        for par in [parede] + [q for q in "NSEW" if q != parede]:          # outra parede do mesmo cômodo se a pedida estiver cheia
            for f in [frac, 0.5, 0.2, 0.8, 0.35, 0.65, 0.0, 1.0, 0.1, 0.9]:
                cx, cy, ret = self._ret(par, f, 0.8, 0.6)
                fr = self._frente_loot(par, ret)
                if self._ok(ret, False, 0.05) and not any(_inter(fr, o, 0.02) for o in self.ocupado) and not any(_inter(ret, o, 0.0) for o in self.zonas):
                    self.ocupado.append(ret)
                    self.ocupado.append(fr)
                    self.k.loot.append({"x": round(cx, 2), "y": round(self.z, 2), "z": round(-cy, 2), "rot_deg": ROT_GODOT[par], "tier": tier, "sala": sala or self.tipo})
                    return (cx, cy)
        print("AVISO: sem lugar para saque em", self.nome, parede)
        return None

    def loot_livre(self, cx, cy, rot_godot=0.0, tier="medio", sala=None):
        """Saque solto no piso (galpões): pegada 0,9 x 0,9 m com 0,4 m de folga ao redor."""
        ret = (cx - 0.45, cy - 0.45, cx + 0.45, cy + 0.45)
        ex = (ret[0] - 0.4, ret[1] - 0.4, ret[2] + 0.4, ret[3] + 0.4)
        if self._ok(ret, False, 0.05) and not any(_inter(ex, o, 0.0) for o in self.ocupado):
            self.ocupado.append(ex)
            self.k.loot.append({"x": round(cx, 2), "y": round(self.z, 2), "z": round(-cy, 2), "rot_deg": rot_godot, "tier": tier, "sala": sala or self.tipo})
            return (cx, cy)
        print("AVISO: sem lugar (livre) para saque em", self.nome, (round(cx, 2), round(cy, 2)))
        return None


def ROT_PARede(p):
    return ROT_PAREDE[p]


# ====================================================================== composições de cômodo (mobília por tipo)
_DIR = {"S": (0, 1), "N": (0, -1), "E": (-1, 0), "W": (1, 0)}     # de cada parede para dentro do cômodo


def _frente(c, p, parede, prof, dist):
    """Ponto a 'dist' da frente de uma peça de profundidade 'prof' encostada na parede."""
    dx, dy = _DIR[parede]
    return (p[0] + dx * (prof / 2 + dist), p[1] + dy * (prof / 2 + dist))


def mob_sala(c, sofa="S", tv="N", largura=2.0):
    p = c.enc("sofa", sofa, 0.8, w=largura)
    tv_p = c.enc("tv_rack", tv, 0.5, w=1.2)
    lado = "E" if sofa in "NS" else "N"
    c.enc("estante", lado, 0.3, w=1.0)
    c.enc("aparador", "W" if sofa in "NS" else "S", 0.75, w=1.0)
    if p:
        q = _frente(c, p, sofa, 0.9, 0.75)
        c.livre("tapete", q[0], q[1], 0 if sofa in "NS" else 90, w=2.2, d=1.4)
        c.livre("mesa_centro", q[0], q[1], 0 if sofa in "NS" else 90, w=1.0, d=0.5)
    c.enc("poltrona", "E" if sofa in "NS" else "N", 0.9, w=0.85)


def mob_cozinha(c, geladeira="E", mesa=True):
    c.enc("pia", "N", 0.0, w=1.1)
    c.enc("fogao", "N", 0.5)
    c.enc("geladeira", geladeira, 1.0)
    c.enc("armario_alto", "N", 0.0, w=1.1)
    c.enc("armario_baixo", "W", 0.6, w=0.9)
    if mesa:
        x0, y0, x1, y1 = c.r
        mx, my = x0 + 0.5 * (x1 - x0), y0 + 0.5 * (y1 - y0)
        if c.livre("mesa", mx, my, 0, w=0.8, d=0.7):
            c.livre("cadeira", mx, my + 0.6, 0)
            c.livre("cadeira", mx, my - 0.6, 180)


def mob_quarto(c, cama="N", largura=1.1, roupeiro="W"):
    c.enc("cama", cama, 0.9, w=largura)
    c.enc("guarda_roupa", roupeiro, 0.5, w=1.3)
    c.enc("criado", cama, 0.25)
    c.enc("tapete", cama, 0.5, w=1.6, d=1.0, cor="reboco_rosa") if False else None


def mob_escritorio(c, mesas=3, parede="N"):
    for i in range(mesas):
        p = c.enc("mesa_escritorio", parede, (i + 0.5) / max(mesas, 1), w=1.4, d=0.7)
        if p:
            dx, dy = _DIR[parede]
            c.livre("cadeira", p[0] + dx * 0.75, p[1] + dy * 0.75, {"N": 180, "S": 0, "E": 90, "W": 270}[parede])
    c.enc("arquivo", "E", 0.9)
    c.enc("arquivo", "E", 0.6)
    c.enc("estante", "W", 0.5, w=1.2)


def mob_reuniao(c):
    x0, y0, x1, y1 = c.r
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    if c.livre("mesa_longa", mx, my, 0, w=min(3.2, x1 - x0 - 1.6), d=0.9):
        for i in (-1, 0, 1):
            c.livre("cadeira", mx + i * 0.9, my + 0.7, 0)
            c.livre("cadeira", mx + i * 0.9, my - 0.7, 180)
    c.enc("estante", "N", 0.5, w=1.4)
    c.enc("arquivo", "W", 0.8)


def mob_salao(c, fx=(0.25, 0.75), fy=(0.3, 0.7)):
    x0, y0, x1, y1 = c.r
    for a in fx:
        for b in fy:
            mx, my = x0 + a * (x1 - x0), y0 + b * (y1 - y0)
            if c.livre("mesa_bar", mx, my, 0):
                c.livre("cadeira", mx, my + 0.65, 0)
                c.livre("cadeira", mx, my - 0.65, 180)
                c.livre("cadeira", mx + 0.65, my, 90)
                c.livre("cadeira", mx - 0.65, my, 270)


def mob_dormitorio(c, n=3):
    for f in [(i + 0.5) / n for i in range(n)]:
        c.enc("beliche", "W", f, w=0.95)
        c.enc("beliche", "E", f, w=0.95)
    c.enc("guarda_roupa", "N", 0.5, w=1.6)


def mob_hall(c):
    c.enc("aparador", "W", 0.5, w=1.0)
    c.enc("banco", "N", 0.5, w=1.0)


def mob_deposito(c, pallets=4, prateleiras=3):
    for f in [(i + 0.5) / prateleiras for i in range(prateleiras)]:
        c.enc("estante_carga", "W", f, w=1.6)
        c.enc("estante_carga", "E", f, w=1.6)
    x0, y0, x1, y1 = c.r
    for i in range(pallets):
        c.livre("pallet", x0 + (0.3 + 0.4 * (i % 2)) * (x1 - x0), y0 + (0.25 + 0.5 * (i // 2)) * (y1 - y0), 0 if i % 2 == 0 else 90)


def salvar_loot(nome, pontos, entradas=(), lances=()):
    with open(os.path.join(LOOT_DIR, nome + ".json"), "w", encoding="utf8") as f:
        json.dump({"loot": pontos, "entradas": list(entradas), "lances": list(lances)}, f, ensure_ascii=False, indent=1)
