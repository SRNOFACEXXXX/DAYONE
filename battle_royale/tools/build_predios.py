# Prédios da Ilha do Tauá, modelados à mão com um kit de peças em medidas explícitas (nada aleatório).
# Cada tipo/variante -> game/assets/models/predios/<tipo>_<v>.glb. Origem no centro do piso, frente para -Y (porta).
# Uso: blender -b --factory-startup -P tools/build_predios.py [-- tipo1 tipo2 ...]
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interior

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "models", "predios")
os.makedirs(OUT, exist_ok=True)
V = Vector
COR = {
    "tijolo": (0.66, 0.36, 0.22), "tijolo_escuro": (0.52, 0.27, 0.17), "argamassa": (0.62, 0.55, 0.45),
    "concreto": (0.62, 0.61, 0.58), "concreto_escuro": (0.45, 0.44, 0.42), "reboco_branco": (0.90, 0.88, 0.82),
    "reboco_rosa": (0.86, 0.64, 0.58), "reboco_azul": (0.42, 0.62, 0.62), "reboco_amarelo": (0.92, 0.80, 0.50),
    "reboco_verde": (0.62, 0.78, 0.62), "barra_azul": (0.20, 0.40, 0.62), "barra_verde": (0.18, 0.46, 0.32),
    "telha": (0.66, 0.30, 0.18), "telha_escura": (0.52, 0.23, 0.14), "madeira": (0.42, 0.30, 0.19), "madeira_clara": (0.62, 0.48, 0.32),
    "janela_azul": (0.18, 0.38, 0.62), "janela_verde": (0.16, 0.45, 0.30), "vidro": (0.165, 0.227, 0.267), "reflexo": (0.50, 0.60, 0.66), "piso": (0.58, 0.50, 0.42),
    "ferro": (0.22, 0.22, 0.22), "caixa_agua": (0.20, 0.36, 0.58), "sape": (0.62, 0.52, 0.30),
    "barra_suja": (0.42, 0.37, 0.31), "zinco": (0.60, 0.62, 0.62), "zinco_ferrugem": (0.52, 0.40, 0.30), "reboco_ocre": (0.80, 0.62, 0.38), "verde_militar": (0.33, 0.37, 0.24),
    "placa": (0.85, 0.20, 0.15), "tabua": (0.50, 0.38, 0.25), "tabua_escura": (0.36, 0.27, 0.18), "porta_aco": (0.45, 0.47, 0.48),
}


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(n):
    m = bpy.data.materials.get(n)
    if m:
        return m
    m = bpy.data.materials.new(n)
    m.use_nodes = True
    bs = next(x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (*[lin(c) for c in COR[n]], 1)
    bs.inputs["Roughness"].default_value = 0.35 if n == "vidro" else 0.9
    return m


class Kit:
    def __init__(self, nome):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.nome, self.bm, self.mats = nome, bmesh.new(), []
        self.xf, self._pilha = Matrix.Identity(4), []        # transformação corrente (móveis girados/deslocados)
        self.loot, self.vazios, self.entradas, self.lances = [], [], [], []     # pontos de saque internos / Empties (escadas verticais) / portas de entrada (testes)
        self.moveis = []                                     # móveis do pacote do usuário (interior.mobilia_pacote -> game/maps/ilha/moveis.json)

    def push(self, x, y, z, rot=0.0):
        self._pilha.append(self.xf)
        self.xf = self.xf @ Matrix.Translation(V((x, y, z))) @ Matrix.Rotation(math.radians(rot), 4, "Z")

    def pop(self):
        self.xf = self._pilha.pop()

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def caixa(self, x0, y0, z0, x1, y1, z1, m):
        """Caixa alinhada aos eixos por cantos (metros)."""
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        c = V(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        s = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
        M = self.xf @ Matrix.Translation(c) @ Matrix.Diagonal((*s, 1))
        mi = self._mi(m)
        mp = {v: self.bm.verts.new(M @ v.co) for v in t.verts}
        for f in t.faces:
            self.bm.faces.new([mp[v] for v in f.verts]).material_index = mi
        t.free()

    def poli(self, pts, m):
        vs = [self.bm.verts.new(self.xf @ V(p)) for p in pts]
        self.bm.faces.new(vs).material_index = self._mi(m)

    def prisma(self, base, altura_vec, m):
        """Extrusão de um polígono (lista de pontos 3D) ao longo de altura_vec: tampa, fundo e lados."""
        b = [self.xf @ V(p) for p in base]
        t = [p + self.xf.to_3x3() @ V(altura_vec) for p in b]
        mi = self._mi(m)
        vb = [self.bm.verts.new(p) for p in b]
        vt = [self.bm.verts.new(p) for p in t]
        self.bm.faces.new(list(reversed(vb))).material_index = mi
        self.bm.faces.new(vt).material_index = mi
        n = len(b)
        for i in range(n):
            self.bm.faces.new((vb[i], vb[(i + 1) % n], vt[(i + 1) % n], vt[i])).material_index = mi

    # ------------------------------------------------------------------ peças de arquitetura
    def parede(self, eixo, a0, a1, fixo, z0, z1, esp, m, vaos=(), lado=1):
        """Parede ao longo de 'x' ou 'y' de a0 a a1, na coordenada 'fixo' do outro eixo, com vãos
        (lista de (centro, largura, z_base, z_topo)). esp cresce para dentro (lado=+1 ou -1)."""
        def bloco(u0, u1, w0, w1):
            if u1 - u0 < 0.01 or w1 - w0 < 0.01:
                return
            f0, f1 = sorted((fixo, fixo + esp * lado))
            if eixo == "x":
                self.caixa(u0, f0, w0, u1, f1, w1, m)
            else:
                self.caixa(f0, u0, w0, f1, u1, w1, m)
        # barra suja na face externa (respingo de terra até 1,1 m) — crítica 01, item 20
        if lado in (1, -1) and z0 < 0.6 and m not in ("ferro", "vidro", "barra_suja"):
            fe = fixo - lado * 0.012
            zt = min(z0 + 1.1, z1)
            ff0, ff1 = sorted((fe, fe + lado * 0.012))
            u = a0
            for c, larg, zb, _zt in sorted(vaos, key=lambda v: v[0]):
                u0, u1 = c - larg / 2, c + larg / 2
                if zb <= z0 + 0.05:                  # porta: interrompe a barra
                    if u0 - u > 0.01:
                        (self.caixa(u, ff0, z0, u0, ff1, zt, "barra_suja") if eixo == "x" else self.caixa(ff0, u, z0, ff1, u0, zt, "barra_suja"))
                    u = u1
            if a1 - u > 0.01:
                (self.caixa(u, ff0, z0, a1, ff1, zt, "barra_suja") if eixo == "x" else self.caixa(ff0, u, z0, ff1, a1, zt, "barra_suja"))
        cortes = sorted(vaos, key=lambda v: v[0])
        u = a0
        for c, larg, zb, zt in cortes:
            u0, u1 = c - larg / 2, c + larg / 2
            bloco(u, u0, z0, z1)
            bloco(u0, u1, z0, zb)       # peitoril
            bloco(u0, u1, zt, z1)       # verga
            u = u1
        bloco(u, a1, z0, z1)

    def janela(self, eixo, c, fixo, zb, zt, larg, cor, lado=-1, venezianas=True):
        """Caixilho + vidro no vão; venezianas abertas presas à parede (fachada externa em 'lado')."""
        f = fixo + 0.02 * lado
        # reflexo pintado: faixa diagonal clara no vidro, pelo lado de fora (crítica 02, ajuste 7)
        if larg > 0.6 and zt - zb > 0.6:
            e = f + 0.045 * lado
            a, b = c - larg / 2 + 0.12, c + larg / 2 - 0.42
            q = [(a, zb + 0.15), (a + 0.24, zb + 0.15), (b + 0.24, zt - 0.15), (b, zt - 0.15)]
            if eixo == "x":
                self.prisma([(u, e, z) for u, z in q], (0, 0.01 * lado, 0), "reflexo")
            else:
                self.prisma([(e, u, z) for u, z in q], (0.01 * lado, 0, 0), "reflexo")
        if eixo == "x":
            self.caixa(c - larg / 2, f - 0.04, zb, c + larg / 2, f + 0.04, zt, "vidro")
            for s in (-1, 1):
                self.caixa(c + s * larg / 2 - 0.05, f - 0.06, zb, c + s * larg / 2 + 0.05, f + 0.06, zt, cor)
            self.caixa(c - larg / 2 - 0.08, f - 0.12 * -lado, zb - 0.08, c + larg / 2 + 0.08, f + 0.02, zb, "concreto")
            if venezianas:
                for s in (-1, 1):
                    x0 = c + s * (larg / 2 + 0.02)
                    self.caixa(min(x0, x0 + s * larg / 2), f + 0.03 * lado, zb, max(x0, x0 + s * larg / 2), f + 0.07 * lado, zt, cor)
        else:
            self.caixa(f - 0.04, c - larg / 2, zb, f + 0.04, c + larg / 2, zt, "vidro")
            for s in (-1, 1):
                self.caixa(f - 0.06, c + s * larg / 2 - 0.05, zb, f + 0.06, c + s * larg / 2 + 0.05, zt, cor)
            if venezianas:
                for s in (-1, 1):
                    y0 = c + s * (larg / 2 + 0.02)
                    self.caixa(f + 0.03 * lado, min(y0, y0 + s * larg / 2), zb, f + 0.07 * lado, max(y0, y0 + s * larg / 2), zt, cor)

    def porta_aberta(self, eixo, c, fixo, larg, alt, cor, lado=-1):
        """Folha de porta aberta a 90° encostada por dentro (vão livre para entrar)."""
        if eixo == "x":
            x = c - larg / 2 + 0.03
            self.caixa(x - 0.04, fixo - lado * 0.05, 0.02, x + 0.0, fixo - lado * (0.05 + larg), alt, cor)

    def folha(self, eixo, c, fixo, larg, alt, cor, lado, z0=0.12, espessura=0.15, dir=1):
        """Folha de porta aberta a 180° rente à face EXTERNA da parede (lado = sentido em que a parede cresce para dentro).
        O vão livre fica desimpedido: a folha encosta ao lado dele, sem invadir a passagem."""
        if eixo == "x":
            self.entrada(c, fixo - lado * 1.3, 0, lado)
        else:
            self.entrada(fixo - lado * 1.3, c, lado, 0)
        f0 = fixo - lado * 0.01
        f1 = fixo - lado * 0.05
        a, b = sorted((c + dir * (larg / 2 + 0.02), c + dir * (larg / 2 + 0.02 + larg * 0.85)))
        g0, g1 = sorted((f0, f1))
        if eixo == "x":
            self.caixa(a, g0, z0, b, g1, z0 + alt - 0.05, cor)
        else:
            self.caixa(g0, a, z0, g1, b, z0 + alt - 0.05, cor)

    def escada_mao(self, id, x, y, z_base, z_plat, dx, dy, sai=0.9, folga=0.42, larg=0.5, passo=0.3, cor="ferro", saida=None):
        """Escada de mão vertical (90°) jogável: trilhos + degraus e dois Empties ESCADA_<id>_base / _topo lidos pelo jogo
        (core/escada_vertical.gd). (x, y) = eixo dos degraus na face da estrutura; (dx, dy) = vetor unitário que sai da estrutura
        para o lado de onde se sobe; z_plat = piso da plataforma de chegada, que fica atrás da escada ('sai' m para dentro)."""
        px, py = -dy, dx
        top = z_plat + 0.95
        for s_ in (-1, 1):
            cx, cy = x + px * s_ * larg / 2, y + py * s_ * larg / 2
            self.caixa(cx - 0.025, cy - 0.025, z_base + 0.05, cx + 0.025, cy + 0.025, top, cor)
        n = int((top - z_base - 0.35) / passo)
        for i in range(n):
            z = z_base + 0.3 + i * passo
            ax, ay = x + px * (-larg / 2), y + py * (-larg / 2)
            bx, by = x + px * (larg / 2), y + py * (larg / 2)
            self.caixa(min(ax, bx) - 0.015, min(ay, by) - 0.015, z, max(ax, bx) + 0.015, max(ay, by) + 0.015, z + 0.035, cor)
        self.vazios.append(("ESCADA_%s_base" % id, V((x + dx * folga, y + dy * folga, z_base))))
        self.vazios.append(("ESCADA_%s_face" % id, V((x, y, z_base))))
        sx, sy = saida if saida else (x - dx * sai, y - dy * sai)
        self.vazios.append(("ESCADA_%s_topo" % id, V((sx, sy, z_plat))))

    def entrada(self, x, y, dx, dy):
        """Registra uma porta de entrada: (x, y) = ponto 1,3 m fora do vão; (dx, dy) = sentido para dentro (Blender). Só para os testes."""
        self.entradas.append({"x": round(x, 2), "y": round(y, 2), "dx": dx, "dy": dy})

    def lance_teste(self, x, y, dx, dy, z_topo, tx, ty):
        """Registra um lance de escada para os testes: o Soldier parte de (x, y) andando no sentido (dx, dy) e deve chegar a z_topo;
        (tx, ty) = ponto de piso logo depois do último degrau (semente da busca de alcance no andar de cima)."""
        self.lances.append({"x": round(x, 2), "y": round(y, 2), "dx": dx, "dy": dy, "z": round(z_topo, 2), "tx": round(tx, 2), "ty": round(ty, 2)})

    def ponto(self, x, y, z, rot_godot, tier, sala):
        """Ponto de saque interno avulso (x, y Blender no plano; z = altura do piso). Coordenadas Godot: z = -y."""
        self.loot.append({"x": round(x, 2), "y": round(z, 2), "z": round(-y, 2), "rot_deg": rot_godot, "tier": tier, "sala": sala})

    def lance(self, rect, sentido, n, z_base, z_topo, m="concreto", macico=False, espessura=0.3):
        """Lance de escada reto e caminhável. rect=(x0,y0,x1,y1) do lance; sentido '+x','-x','+y','-y' = para onde SOBE.
        n degraus com altura (z_topo-z_base)/n (<= 0,3 m). macico=True preenche até o piso."""
        x0, y0, x1, y1 = rect
        h = (z_topo - z_base) / n
        for i in range(n):
            zt = z_base + (i + 1) * h
            zb = z_base if macico else zt - espessura
            if sentido == "+y":
                a, b = y0 + i * (y1 - y0) / n, y0 + (i + 1) * (y1 - y0) / n
                self.caixa(x0, a, zb, x1, b, zt, m)
            elif sentido == "-y":
                a, b = y1 - (i + 1) * (y1 - y0) / n, y1 - i * (y1 - y0) / n
                self.caixa(x0, a, zb, x1, b, zt, m)
            elif sentido == "+x":
                a, b = x0 + i * (x1 - x0) / n, x0 + (i + 1) * (x1 - x0) / n
                self.caixa(a, y0, zb, b, y1, zt, m)
            else:
                a, b = x1 - (i + 1) * (x1 - x0) / n, x1 - i * (x1 - x0) / n
                self.caixa(a, y0, zb, b, y1, zt, m)

    def telhado_duas_aguas(self, x0, x1, y0, y1, z, altura, beiral, m, m2, cumeeira_x=True):
        """Telhado de duas águas com espessura e beiral. cumeeira ao longo de X (caimento para ±Y) ou Y."""
        e = 0.12
        if cumeeira_x:
            ym = (y0 + y1) / 2
            for ya, yb in ((y0 - beiral, ym), (y1 + beiral, ym)):
                za = z - beiral * altura / ((y1 - y0) / 2)
                self.prisma([(x0 - beiral, ya, za), (x1 + beiral, ya, za), (x1 + beiral, yb, z + altura), (x0 - beiral, yb, z + altura)], (0, 0, e), m)
            # oitões (triângulos de parede)
            for x in (x0, x1):
                self.prisma([(x, y0, z), (x, y1, z), (x, ym, z + altura)], (0.15 if x == x0 else -0.15, 0, 0), m2)
            self.caixa(x0 - beiral, ym - 0.12, z + altura - 0.02, x1 + beiral, ym + 0.12, z + altura + e + 0.1, "telha_escura")
        else:
            xm = (x0 + x1) / 2
            for xa, xb in ((x0 - beiral, xm), (x1 + beiral, xm)):
                za = z - beiral * altura / ((x1 - x0) / 2)
                self.prisma([(xa, y0 - beiral, za), (xa, y1 + beiral, za), (xb, y1 + beiral, z + altura), (xb, y0 - beiral, z + altura)], (0, 0, e), m)
            for y in (y0, y1):
                self.prisma([(x0, y, z), (x1, y, z), (xm, y, z + altura)], (0, 0.15 if y == y0 else -0.15, 0), m2)
            self.caixa(xm - 0.12, y0 - beiral, z + altura - 0.02, xm + 0.12, y1 + beiral, z + altura + e + 0.1, "telha_escura")

    def fim(self):
        me = bpy.data.meshes.new(self.nome)
        self.bm.normal_update()
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(self.nome, me)
        bpy.context.scene.collection.objects.link(ob)
        for nome_v, pos_v in self.vazios:
            e = bpy.data.objects.new(nome_v, None)
            e.location = pos_v
            e.empty_display_type = "PLAIN_AXES"
            bpy.context.scene.collection.objects.link(e)
        interior.salvar_loot(self.nome, self.loot, self.entradas, self.lances)
        interior.salvar_moveis(self.nome, self.moveis)
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, self.nome + ".glb"), use_selection=True, export_format="GLB",
                                  export_yup=True, export_apply=True)
        print("PREDIO", self.nome, len(me.polygons), "faces", len(self.moveis), "moveis")


# ====================================================================== casa de laje (6 x 7 x 3 m), 3 variantes
def casa_laje(v, parede, laje_extra, janela_cor, cobertura_caixa):
    k = Kit("casa_laje_%s" % v)
    W, D, H, e = 6.0, 7.0, 2.8, 0.15
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    zp = 0.12
    k.caixa(x0 - 0.1, y0 - 0.1, -0.3, x1 + 0.1, y1 + 0.1, 0.1, "concreto_escuro")          # radier/calçada
    k.caixa(x0 + e, y0 + e, 0.1, x1 - e, y1 - e, zp, "piso")                                 # piso interno
    XD = 0.1                                                                                 # divisória quarto | cozinha
    # frente (-Y): porta (vão 1,1 x 2,15) à esquerda, janela à direita
    k.parede("x", x0, x1, y0, 0.1, H, e, parede, vaos=[(-1.4, 1.1, 0.1, 2.25), (1.2, 1.2, 1.0, 2.1)], lado=1)
    k.janela("x", 1.2, y0, 1.0, 2.1, 1.2, janela_cor, lado=-1, venezianas=False)
    k.folha("x", -1.4, y0, 1.1, 2.15, "madeira", 1, z0=0.1, dir=-1)
    # fundos: janela do quarto (esq.) e da cozinha (dir.)
    k.parede("x", x0, x1, y1, 0.1, H, e, parede, vaos=[(-1.5, 0.9, 1.0, 2.0), (1.4, 1.0, 1.0, 2.0)], lado=-1)
    k.janela("x", -1.5, y1, 1.0, 2.0, 0.9, janela_cor, lado=1, venezianas=False)
    k.janela("x", 1.4, y1, 1.0, 2.0, 1.0, janela_cor, lado=1, venezianas=False)
    # laterais
    k.parede("y", y0 + e, y1 - e, x0, 0.1, H, e, parede, vaos=[(-1.2, 1.2, 1.0, 2.1)], lado=1)
    k.janela("y", -1.2, x0, 1.0, 2.1, 1.2, janela_cor, lado=-1, venezianas=False)
    k.parede("y", y0 + e, y1 - e, x1, 0.1, H, e, parede, vaos=[], lado=-1)
    # divisórias: sala na frente; quarto (esq.) e cozinha (dir.) nos fundos; portas de 1,1 m alinhadas
    YD = 0.7
    k.parede("x", x0 + e, x1 - e, YD, zp, H, 0.1, parede, vaos=[(-1.4, 1.1, zp, zp + 2.1), (1.5, 1.1, zp, zp + 2.1)])
    k.parede("y", YD + 0.1, y1 - e, XD, zp, H, 0.1, parede)
    # laje (acessível) + platibanda baixa + ferros de espera para o 2º andar (a "casa que nunca termina")
    k.caixa(x0 - 0.2, y0 - 0.2, H, x1 + 0.2, y1 + 0.2, H + 0.14, "concreto")
    if laje_extra:
        k.parede("x", x0 - 0.2, x1 + 0.2, y0 - 0.2, H + 0.14, H + 1.0, 0.12, parede, lado=1)
        k.parede("y", y0, y1 + 0.2, x1 + 0.2, H + 0.14, H + 1.0, 0.12, parede, lado=-1)
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        for d in (-0.05, 0.05):
            k.caixa(x + d - 0.01, y - 0.01, H + 0.14, x + d + 0.01, y + 0.01, H + 0.9, "ferro")
    if cobertura_caixa:
        k.caixa(x0 + 0.6, y1 - 1.6, H + 0.14, x0 + 1.6, y1 - 0.6, H + 1.1, "caixa_agua")
    # escada externa de concreto até a laje (lateral direita, sobe de trás para a frente): 14 degraus de 0,2 m, 1,2 m de largura
    # livre (fora do beiral da laje, que avança 0,2 m) com guarda-corpo só na borda externa
    n = 14
    xe0, xe1 = x1 + 0.25, x1 + 1.45
    for i in range(n):
        z = 0.1 + (i + 1) * (H + 0.04) / n
        yy = y1 - 0.3 - i * 0.28
        k.caixa(xe0, yy - 0.28, z - 0.2, xe1, yy, z, "concreto")
    for i in range(0, n + 1, 3):
        z = 0.1 + i * (H + 0.04) / n
        yy = y1 - 0.3 - i * 0.28
        k.caixa(xe1 - 0.06, yy - 0.03, z, xe1, yy + 0.03, z + 0.95, "ferro")
    zt, zb = 0.1 + (H + 0.04) + 0.95, 0.1 + 0.95
    yt, yb = y1 - 0.3 - n * 0.28, y1 - 0.3
    k.prisma([(xe1 - 0.06, yb, zb), (xe1 - 0.06, yt, zt), (xe1 - 0.06, yt, zt + 0.05), (xe1 - 0.06, yb, zb + 0.05)], (0.06, 0, 0), "ferro")
    k.caixa(x1 + 0.1, yt - 0.5, H, xe0, yt + 0.0, H + 0.14, "concreto")                  # patamar de chegada na laje
    k.lance_teste(x1 + 0.85, y1 + 0.6, 0, -1, H + 0.14, x1 - 0.5, 0.0)        # escada externa -> laje (sem saque no telhado)
    # ---- interior mobiliado
    C = interior.Comodo
    sala = C(k, "sala", (x0 + e, y0 + e, x1 - e, YD), zp, portas=[(-1.4, y0 + e), (-1.4, YD), (1.5, YD)], janelas=[(1.2, y0 + e, 1.2), (x0 + e, -1.2, 1.2)])
    quarto = C(k, "quarto", (x0 + e, YD + 0.1, XD, y1 - e), zp, portas=[(-1.4, YD + 0.1)], janelas=[(-1.5, y1 - e, 0.9)])
    coz = C(k, "cozinha", (XD + 0.1, YD + 0.1, x1 - e, y1 - e), zp, portas=[(1.5, YD + 0.1)], janelas=[(1.4, y1 - e, 1.0)])
    sala.enc("sofa", "S", 1.0, w=1.9)
    sala.enc("tv_rack", "N", 0.5, w=1.2)
    sala.enc("estante", "E", 0.5, w=1.0)
    sala.enc("aparador", "W", 0.75, w=1.1)
    sala.livre("tapete", 1.0, -1.7, 0, w=2.2, d=1.4)
    sala.livre("mesa_centro", 1.0, -1.9, 0, w=1.0, d=0.5)
    sala.loot("W", 0.0, "baixo")
    quarto.enc("cama", "W", 1.0, w=1.1)
    quarto.enc("guarda_roupa", "E", 1.0, w=1.4)
    quarto.enc("criado", "N", 0.0)
    quarto.loot("W", 0.0, "baixo")
    coz.enc("pia", "N", 0.0, w=1.1)
    coz.enc("fogao", "N", 0.5)
    coz.enc("geladeira", "E", 1.0)
    coz.enc("armario_alto", "N", 0.0, w=1.1)
    coz.loot("E", 0.0, "medio")
    k.fim()


# ====================================================================== casa caiçara (6 x 8 x 4 m), 2 variantes
def casa_caicara(v, reboco, barra, janela_cor):
    k = Kit("casa_caicara_%s" % v)
    W, D, H, e = 6.0, 8.0, 2.7, 0.15
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    zp = 0.14
    k.caixa(x0 - 0.1, y0 - 1.6, -0.3, x1 + 0.1, y1 + 0.1, 0.12, "concreto_escuro")          # piso + varandinha
    k.caixa(x0 + e, y0 + e, 0.12, x1 - e, y1 - e, zp, "piso")
    k.parede("x", x0, x1, y0, 0.12, H, e, reboco, vaos=[(0.0, 1.1, 0.12, 2.25), (-1.9, 1.0, 1.0, 2.0), (1.9, 1.0, 1.0, 2.0)], lado=1)
    k.caixa(x0, y0 - 0.02, 0.12, -0.55, y0 + 0.02, 0.9, barra)                               # barra pintada (com o vão da porta livre)
    k.caixa(0.55, y0 - 0.02, 0.12, x1, y0 + 0.02, 0.9, barra)
    for c in (-1.9, 1.9):
        k.janela("x", c, y0, 1.0, 2.0, 1.0, janela_cor, lado=-1)
    k.folha("x", 0.0, y0, 1.1, 2.15, janela_cor, 1, z0=0.12, dir=1)
    k.parede("x", x0, x1, y1, 0.12, H, e, reboco, vaos=[(2.0, 1.1, 0.12, 2.25), (-1.5, 1.0, 1.0, 2.0)], lado=-1)
    k.janela("x", -1.5, y1, 1.0, 2.0, 1.0, janela_cor, lado=1)
    k.parede("y", y0 + e, y1 - e, x0, 0.12, H, e, reboco, vaos=[(-1.0, 1.0, 1.0, 2.0), (2.0, 1.0, 1.0, 2.0)], lado=1)
    for c in (-1.0, 2.0):
        k.janela("y", c, x0, 1.0, 2.0, 1.0, janela_cor, lado=-1)
    k.parede("y", y0 + e, y1 - e, x1, 0.12, H, e, reboco, vaos=[(-1.4, 1.0, 1.0, 2.0)], lado=-1)
    k.janela("y", -1.4, x1, 1.0, 2.0, 1.0, janela_cor, lado=1)
    YD, XD = 0.8, 0.0
    k.parede("x", x0 + e, x1 - e, YD, zp, H, 0.1, reboco, vaos=[(-1.4, 1.1, zp, zp + 2.1), (1.4, 1.1, zp, zp + 2.1)])
    k.parede("y", YD + 0.1, y1 - e, XD, zp, H, 0.1, reboco)
    # varanda: dois esteios de madeira e o beiral do telhado cobrindo
    for x in (x0 + 0.3, x1 - 0.3):
        k.caixa(x - 0.08, y0 - 1.45, 0.12, x + 0.08, y0 - 1.3, H, "madeira")
    k.telhado_duas_aguas(x0, x1, y0 - 1.4, y1, H, 1.6, 0.45, "telha", reboco, cumeeira_x=False)
    k.caixa(x0 + e, y0 + e, H - 0.1, x1 - e, y1 - e, H, "reboco_branco")                   # forro
    C = interior.Comodo
    sala = C(k, "sala", (x0 + e, y0 + e, x1 - e, YD), zp, portas=[(0.0, y0 + e), (-1.4, YD), (1.4, YD)], janelas=[(-1.9, y0 + e, 1.0), (1.9, y0 + e, 1.0), (x0 + e, -1.0, 1.0), (x1 - e, -1.4, 1.0)])
    quarto = C(k, "quarto", (x0 + e, YD + 0.1, XD, y1 - e), zp, portas=[(-1.4, YD + 0.1)], janelas=[(-1.5, y1 - e, 1.0), (x0 + e, 2.0, 1.0)])
    coz = C(k, "cozinha", (XD + 0.1, YD + 0.1, x1 - e, y1 - e), zp, portas=[(1.4, YD + 0.1), (2.0, y1 - e)])
    sala.enc("sofa", "S", 0.15, w=1.9)
    sala.enc("tv_rack", "N", 0.5, w=1.1)
    sala.enc("estante", "E", 0.3, w=1.0)
    sala.enc("aparador", "W", 0.8, w=1.0)
    sala.livre("tapete", -1.6, -1.5, 0, w=2.2, d=1.5, cor="reboco_rosa")
    sala.livre("mesa_centro", -1.6, -1.6, 0, w=1.0, d=0.5)
    sala.loot("W", 0.05, "baixo")
    quarto.enc("cama", "W", 1.0, w=1.3)
    quarto.enc("guarda_roupa", "E", 1.0, w=1.2)
    quarto.enc("criado", "N", 0.9)
    quarto.loot("S", 0.05, "baixo")
    coz.enc("pia", "N", 0.0, w=1.1)
    coz.enc("fogao", "W", 0.6)
    coz.enc("geladeira", "E", 0.3)
    coz.enc("armario_alto", "N", 0.0, w=1.1)
    coz.livre("mesa", 0.75, 2.4, 0, w=0.8, d=0.7)
    coz.loot("E", 0.85, "medio")
    k.fim()


ALVO = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def quer(t):
    return not ALVO or t in ALVO


if quer("casa_laje"):
    casa_laje("a", "tijolo", True, "janela_azul", True)        # tijolo à vista, platibanda, caixa d'água
    casa_laje("b", "reboco_rosa", False, "janela_verde", True) # rebocada e pintada
    casa_laje("c", "tijolo_escuro", False, "ferro", False)     # tijolo escuro, grade de ferro
if quer("casa_caicara"):
    casa_caicara("a", "reboco_branco", "barra_azul", "janela_azul")
    casa_caicara("b", "reboco_amarelo", "barra_verde", "janela_verde")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import predios_lote2
predios_lote2.construir(Kit, quer)
import predios_lote3
predios_lote3.construir(Kit, quer)
import predios_lote4
predios_lote4.construir(Kit, quer)
print("PREDIOS_DONE")
