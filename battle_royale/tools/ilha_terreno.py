# -*- coding: utf-8 -*-
"""Funções compartilhadas: carregar ilha_layout.json, ponto-em-polígono e
altura do terreno (thin-plate spline sobre os pontos autorais + costa z=0)."""
import json, os
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(RAIZ, "docs", "design", "ilha_layout.json")
Z_MAX = 185.0


def carregar(path=JSON_PATH):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dentro(poly, x, y):
    """Ponto(s) dentro do polígono (ray casting, vetorizado)."""
    x = np.asarray(x, float); y = np.asarray(y, float)
    res = np.zeros(np.broadcast(x, y).shape, bool)
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % n]
        cond = (y1 > y) != (y2 > y)
        with np.errstate(divide="ignore", invalid="ignore"):
            xi = (x2 - x1) * (y - y1) / (y2 - y1) + x1
        res ^= cond & (x < xi)
    return res


def amostrar_costa(costa, passo=20.0):
    pts = []
    n = len(costa)
    for i in range(n):
        (x1, y1), (x2, y2) = costa[i], costa[(i + 1) % n]
        L = float(np.hypot(x2 - x1, y2 - y1))
        k = max(1, int(L // passo))
        for j in range(k):
            t = j / k
            pts.append((x1 + (x2 - x1) * t, y1 + (y2 - y1) * t))
    return pts


class Terreno:
    def __init__(self, dados):
        from scipy.interpolate import RBFInterpolator
        self.costa = dados["costa"]
        hp = dados["terreno"]["pontos_altura"]
        xy = [(p["x"], p["y"]) for p in hp]
        z = [p["z"] for p in hp]
        for (x, y) in amostrar_costa(self.costa):
            xy.append((x, y)); z.append(0.0)
        self.rbf = RBFInterpolator(np.array(xy, float), np.array(z, float), kernel="thin_plate_spline", smoothing=0.0)
        rep = dados["agua"]["represa"]
        self.represa = rep["contorno"]; self.nivel = rep["nivel_agua_m"]

    def altura(self, x, y, bloco=40000):
        x = np.asarray(x, float); y = np.asarray(y, float)
        shp = np.broadcast(x, y).shape
        X = np.broadcast_to(x, shp).ravel(); Y = np.broadcast_to(y, shp).ravel()
        out = np.empty(X.size)
        for i in range(0, X.size, bloco):
            out[i:i + bloco] = self.rbf(np.column_stack([X[i:i + bloco], Y[i:i + bloco]]))
        out = np.clip(out, 0.0, Z_MAX).reshape(shp)
        terra = dentro(self.costa, x, y)
        out = np.where(terra, np.maximum(out, 0.3), -8.0)
        return out
