# -*- coding: utf-8 -*-
"""Monta docs/design/cenario_areas_02.json a partir dos módulos autorais cen02_*.py (cada um escreve suas áreas)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cenario_02_src as S

for mod in ("cen02_vila", "cen02_cruzeiro", "cen02_fazenda", "cen02_alamedas", "cen02_pois", "cen02_campo"):
    if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), mod + ".py")):
        importlib.import_module(mod)
S.gravar()
