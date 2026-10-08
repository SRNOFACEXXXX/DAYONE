"""Aplica uma revisão autoral de cotas; não distribui objetos nem gera relevo aleatório.

Tabela por índice dos 180 pontos existentes. Idempotente: a versão anterior fica
preservada em raw/relevo_original e cada nova execução aplica as mesmas cotas.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKUP = ROOT / 'raw/relevo_original'
BACKUP.mkdir(parents=True, exist_ok=True)
for relative in ['docs/design/ilha_layout.json', 'game/maps/ilha/ilha_layout.json',
                 'game/maps/ilha/height.bin', 'game/maps/ilha/meta.json',
                 'game/maps/ilha/splat.png', 'game/maps/ilha/mata.png',
                 'game/maps/ilha/agua.png', 'game/maps/ilha/height16.png']:
    source = ROOT / relative
    target = BACKUP / relative
    if source.exists() and not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

# Serra: um único cume de 48 m e selas baixas; pedreira: depressão local.
COTAS = [
    19,24,30,37,43,48,43,36,30,27,26,16,16,18,25,23,22,26,20,14,12,21,23,
    # Encosta norte / farol / baixada: corredores suaves entre bosques.
    14,18,23,28,24,20,17,21,18,16,14,14,12,12,14,14,13,14,
    8,7,5,9,8,10,11,15,12,10,
    # Usina e canaviais: baixada agrícola de 7 a 11 m.
    9,10,8,8,9,11,5,5,8,11,7,12,
    # Quartel: platô amplo; aproximação pelo leste em colinas baixas.
    12,13,12,13,12,11,8,14,16,12,10,17,21,13,12,12,17,27,31,
    11,10,9,14,13,
    # Pista horizontal e restinga; morro sul contido em 29 m.
    8,8,8,8,8,10,11,6,6,7,12,26,29,25,18,20,20,21,26,28,
    # Represa a 15 m, crista a 17 m, vale descendente até a vila.
    15,18,19,18,17,17,11,25,30,24,21,21,26,19,17,15,10,8,6,4,3,1,
    # Cruzeiro mantém identidade de morro habitado, topo de 24 m.
    24,21,20,17,19,15,21,14,12,17,10,7,8,6,10,7,12,
    # Fazenda: campos largos e quase planos, casarão a 11 m.
    11,12,10,9,10,11,14,7,15,12,
    # Praia, restinga, planície sul e vila costeira.
    3,2,3,4,6,5,6,8,9,12,15,11,9,10,4,4,5,6,7,2,5,8,7,5,
]
data = json.loads((BACKUP / 'docs/design/ilha_layout.json').read_text(encoding='utf-8'))
assert len(COTAS) == len(data['terreno']['pontos_altura']) == 180
for point, height in zip(data['terreno']['pontos_altura'], COTAS):
    point['z'] = height
data['terreno']['interpolacao'] = ('Spline sobre 180 cotas autorais revisadas para planícies; '
    'cume 48 m, morro sul 29 m, Cruzeiro 24 m; costa em zero. Revisão planícies 2026-09-26.')
data['terreno']['revisao'] = 'planicies_01'
for cliff, limits in zip(data['terreno']['falesias'], [[9,14],[12,14],[5,7]]):
    cliff['altura_topo_m'] = limits
for section, levels in zip(data['agua']['rio']['trechos'], [[32,25,19,15],[12,11,10,8,6,4,3,2,1,0]]):
    assert len(section['pontos']) == len(levels)
    for point, height in zip(section['pontos'], levels):
        point[2] = height
reservoir = data['agua']['represa']
reservoir['nivel_agua_m'] = 15
reservoir['profundidade_max_m'] = 3
reservoir['barragem']['altura_crista_m'] = 17
reservoir['barragem']['altura_face_m'] = 6
for landmark in data.get('marcos', []):
    if landmark['id'] == 'pico_taua':
        landmark['altura_m'] = [45,48]
        for loot in landmark.get('saque', []):
            if 'z_abs_m' in loot:
                loot['z_abs_m'] = 48
for relative in ['docs/design/ilha_layout.json', 'game/maps/ilha/ilha_layout.json']:
    (ROOT / relative).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('180 cotas autorais aplicadas. Represa 15 m; crista 17 m; pico 48 m.')
