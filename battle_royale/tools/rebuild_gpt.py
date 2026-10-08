"""Recomposes the copied island from its frozen baseline. No random placement.
Hand-authored grove centres expand a fixed planting template; all placements are
baked to JSON and checked against roads, water, houses and existing trunks.
Run from anywhere: python tools/rebuild_gpt.py. Original project is never read/written.
"""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / 'game/maps/ilha'
BASE = ROOT.parent / 'comparacao/mapa_original'
assert ROOT.parent.name == 'teste GPT'

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

layout = read(BASE / 'ilha_layout.json')
vegetation = read(BASE / 'vegetacao.json')
height = np.fromfile(BASE / 'height.bin', dtype='<f4').reshape(601, 601)
splat = np.asarray(Image.open(BASE / 'splat.png').convert('RGB'))
roads = layout['estradas']
river = layout['agua']['rio']['trechos']
SITES = [(-231,-340),(-34,-176),(200,268)]
buildings = []
adjust = read(BASE / 'casas_ajuste.json')
for poi in layout['pois'] + layout.get('marcos', []):
    for b in poi.get('predios', []):
        a = adjust.get(b['id'], {})
        buildings.append((b['pos'][0] + a.get('dx', 0), b['pos'][1] + a.get('dy', 0),
                          max(12, b['tamanho_m'][0] / 2 + 5), max(13, b['tamanho_m'][1] / 2 + 5)))
for i, c in enumerate(read(BASE / 'casas_pacote.json')['casas']):
    a = adjust.get(f'extra_{i}', {})
    buildings.append((c['x'] + a.get('dx', 0), c['y'] + a.get('dy', 0), 15, 15))

def h(x, y):
    c, r = (x + 600) / 2, (600 - y) / 2
    i, j = int(c), int(r)
    u, v = c - i, r - j
    return float((height[j, i]*(1-u)+height[j, i+1]*u)*(1-v)
                 + (height[j+1, i]*(1-u)+height[j+1, i+1]*u)*v)

def distance(x, y, points):
    best = float('inf')
    for a, b in zip(points, points[1:]):
        dx, dy = b[0]-a[0], b[1]-a[1]
        t = max(0, min(1, ((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy or 1)))
        best = min(best, math.hypot(x-a[0]-dx*t, y-a[1]-dy*t))
    return best

def clear(x, y, margin=4):
    if not (-540 < x < 540 and -540 < y < 540) or h(x, y) < 3:
        return False
    px, py = int((x+600)/1200*splat.shape[1]), int((600-y)/1200*splat.shape[0])
    if splat[py, px, 1] < 130:
        return False
    if any(distance(x, y, r['pontos']) < r['largura_m']/2 + margin for r in roads):
        return False
    if any(distance(x, y, r['pontos']) < r['largura_m']/2 + 5 for r in river):
        return False
    if any(abs(x-bx) < rx and abs(y-by) < ry for bx, by, rx, ry in buildings):
        return False
    if any(abs(x-bx)<8 and abs(y-by)<7 for bx,by in SITES):
        return False
    return max(abs(h(x+2, y)-h(x-2, y)), abs(h(x,y+2)-h(x,y-2))) < 3.0

# Groves frame roads rather than filling all the meadows. Identity remains coastal.
GROVES = [
    ('entrada_vila', -314,-368, 28, .64), ('quintais', -365,-405, -18,.58),
    ('vila_norte', -365,-265, 33,.7), ('travessia', -290,-285, -20,.72),
    ('estrada_fazenda', -236,-350, 14,.78), ('campo_oeste', -305,-205, 45,.85),
    ('vale_vila', -375,-170, 70,.84), ('bosque_fazenda', -165,-365, -15,.74),
    ('represa_sul', -160,-187, 20,.86), ('represa_leste', -24,-137, 0,.9),
    ('trilha_morro', -267,-85, 30,.75), ('cruzeiro_sul', -351,-108, 5,.72),
    ('campo_central', 50,-234, -30,.83), ('estrada_praia', 79,-373, 40,.68),
    ('pista_oeste', 228,-203, 10,.8), ('pedreira_sul', 330,-112, 50,.85),
    ('costa_leste', 376,92, 0,.73), ('quartel_sul', 302,171, 35,.9),
    ('quartel_oeste', 193,235, -10,.95), ('farol_sul', 59,380, 25,.78),
    ('usina_sul', -270,230, 35,.8), ('usina_leste', -174,289, -15,.82),
    ('campina_norte', -31,322, 60,.83), ('rio_central', -207,-82, 0,.8),
]
TEMPLATE = [(0,0),(-13,2),(14,-3),(-7,15),(10,17),(-5,-14),(12,-19),
            (-24,-10),(-24,15),(26,9),(25,-12),(-17,29),(6,32),(-32,2),
            (34,-3),(-13,-31),(9,-33),(30,26),(-34,-25)]
existing = [(p['x'], p['y']) for p in vegetation['instancias'] if p['tipo'] in ('arvore_mata_a','arvore_mata_b','coqueiro')]
added = []
min_road = float('inf')
for name, cx, cy, angle, size in GROVES:
    ang = math.radians(angle)
    for i,(dx,dy) in enumerate(TEMPLATE):
        x = round(cx+dx*math.cos(ang)-dy*math.sin(ang),2)
        y = round(cy+dx*math.sin(ang)+dy*math.cos(ang),2)
        if not clear(x,y,5) or any(math.hypot(x-a,y-b)<7 for a,b in existing):
            continue
        existing.append((x,y))
        min_road = min(min_road, min(distance(x,y,r['pontos'])-r['largura_m']/2 for r in roads))
        added.append(dict(tipo='arvore_mata_a' if i%3 else 'arvore_mata_b', x=x,y=y,z=round(h(x,y),2),
                          escala=round(size*(.9,.99,1.08,1.02)[i%4],2), rot_deg=(i*47+angle)%360, mancha=f'GPT/{name}'))
        # Understorey is on the field side of trunks and cannot obstruct the carriageway.
        for j,(ox,oy) in enumerate(((3.1,2.5),(-3.2,-2.1))):
            bx,by=round(x+ox,2),round(y+oy,2)
            if clear(bx,by,2):
                added.append(dict(tipo='arbusto' if j==0 else 'pedra_pequena',x=bx,y=by,z=round(h(bx,by),2),
                                  escala=.72 if j==0 else .85,rot_deg=i*29%360,mancha=f'GPT/{name}'))
vegetation['instancias'].extend(added)
vegetation['total'] = len(vegetation['instancias'])
vegetation['fonte'] += ' + tools/rebuild_gpt.py (groves authored offline)'
vegetation['contagem_por_tipo'] = {t:sum(p['tipo']==t for p in vegetation['instancias']) for t in vegetation['tipos']}
(MAP/'vegetacao.json').write_text(json.dumps(vegetation,ensure_ascii=False),encoding='utf-8')

# Woodland floor follows the authored groves, with soft borders instead of giant hard circles.
floor = Image.open(BASE/'mata.png').convert('RGB')
red,green,blue = floor.split()
d = ImageDraw.Draw(red)
for p in added:
    if not p['tipo'].startswith('arvore'): continue
    x,y=(p['x']+600)/1200*floor.width,(600-p['y'])/1200*floor.height
    rr=8/1200*floor.width
    d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=220)
Image.merge('RGB',(red,green,blue)).save(MAP/'mata.png')

trails = Image.open(BASE/'trilhas.png').convert('RGB')
tr, ruts, unused = trails.split()
draw = ImageDraw.Draw(tr)
spurs = [[(-236,-320),(-238,-330),(-231,-340)],
         [(-51,-158),(-43,-164),(-34,-176)],
         [(240,282),(222,275),(209,272),(200,268)]]
for route in spurs:
    pixels=[((x+600)/1200*tr.width,(600-y)/1200*tr.height) for x,y in route]
    draw.line(pixels,fill=255,width=max(2,round(2.4/1200*tr.width)),joint='curve')
Image.merge('RGB',(tr,ruts,unused)).save(MAP/'trilhas.png')

# Human traces between existing destinations; authored props, never placed on the road.
areas=[]
def area(name, intention, items):
    props=[]
    for tipo,x,y,rot,scale in items:
        if clear(x,y,1):
            props.append(dict(tipo=tipo,x=x,y=y,rot_deg=rot,escala=scale))
    areas.append(dict(nome=name,intencao=intention,props=props))
area('Pomar abandonado','Cobertura lateral na saída da Vila, caminho livre até a fazenda',[
    ('cenario/natureza/tronco_caido',-314,-357,25,1.1),
    ('cenario/natureza/lenha',-306,-357,12,1),
    ('cenario/natureza/pilha_troncos',-285,-345,80,1),
    ('cenario/natureza/cerca_madeira',-299,-352,15,1),
    ('cenario/natureza/cerca_madeira_curta',-293,-350,15,1),
    ('cenario/natureza/cerca_madeira',-278,-344,15,1),
    ('barril',-281,-345,0,1), ('caixote_peixe',-280,-348,20,1)])
area('Mata ciliar','Abrigo baixo e clareiras que conservam a leitura do rio',[
    ('cenario/natureza/tronco_caido',-286,-280,55,1.3),
    ('cenario/natureza/raiz',-295,-274,12,1.1),
    ('cenario/natureza/rocha_media',-279,-276,20,1.2),
    ('cenario/natureza/muro_ruina',-226,-180,40,1),
    ('cenario/natureza/rocha_grande',-214,-172,30,1),
    ('cenario/natureza/rocha_media',-219,-180,0,.8)])
area('Vestígios de lenhadores','Quebra a exposição da rota no campo central',[
    ('cenario/natureza/pilha_troncos',42,-216,25,1.2),
    ('cenario/natureza/toco',48,-208,0,1),
    ('cenario/natureza/toco_baixo',33,-218,20,1),
    ('cenario/natureza/tronco_caido',58,-219,70,1.2),
    ('cenario/natureza/pilha_tabuas',44,-223,5,1)])
(MAP/'cenario_areas_03.json').write_text(json.dumps(dict(areas=areas),ensure_ascii=False,indent=1),encoding='utf-8')
# Tiny pads under new refuges; terrain visual and physics share the same height data.
xx,yy = np.meshgrid(np.linspace(-600,600,601),np.linspace(600,-600,601))
for sx,sy in SITES:
    assert not any(abs(sx-bx)<rx+8 and abs(sy-by)<ry+7 for bx,by,rx,ry in buildings)
    level = h(sx,sy)
    dist = np.hypot(np.maximum(abs(xx-sx)-5.7,0),np.maximum(abs(yy-sy)-4.8,0))
    t = np.clip(dist/5,0,1)
    weight = 1-t*t*(3-2*t)
    height = height*(1-weight)+level*weight
height.astype('<f4').tofile(MAP/'height.bin')
report=dict(added_trees=sum(p['tipo'].startswith('arvore') for p in added),added_understorey=sum(not p['tipo'].startswith('arvore') for p in added),
            added_props=sum(len(a['props']) for a in areas),minimum_tree_clearance_from_road_edge_m=round(min_road,2),
            groves=len(GROVES),terrain_changes='three local refuge pads only',existing_loot_preserved=True)
assert report['added_trees']>150 and min_road>=5
(ROOT.parent/'comparacao/placement_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
