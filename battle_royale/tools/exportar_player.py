"""Exporta o personagem modular (creative_character_free.blend) para glb do Godot.

Uso (Blender 4.5, sem interface):
  blender.exe -b "C:/Users/satoshi/Desktop/Assets/atualização/player/creative_character_free.blend" \
      --python tools/exportar_player.py

Saída: game/assets/models/atualizacao/player/dayone_base.glb
  - Armature 'Skeleton' (44 ossos) -> Skeleton3D
  - TODAS as peças skinned (corpo, rostos, cabelos, chapéus, óculos, roupas, calçados...) como MeshInstance3D
    filhas do mesmo Skeleton3D: trocar peça = alternar visible (sem re-skin)
  - todas as actions (Idle_Breathing, Walk/Run 4 dir, Crouch, Jump, Death...) como animações
Não altera o .blend de origem (não salva).
"""
import os
import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "game", "assets", "models", "atualizacao", "player", "dayone_base.glb"))
os.makedirs(os.path.dirname(SAIDA), exist_ok=True)

# objetos que não são peças do boneco: moldura da cena e as 3 cabeças soltas de vitrine
for o in list(bpy.data.objects):
    if o.name == "Frame" or (o.type == "MESH" and o.parent is None):
        bpy.data.objects.remove(o, do_unlink=True)

# action importada duplicada do FBX: fora
for a in list(bpy.data.actions):
    if a.name.startswith("Armature|"):
        bpy.data.actions.remove(a)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in bpy.data.objects:
    o.hide_set(False)
    o.hide_render = False
    o.hide_viewport = False
    for c in o.users_collection:
        c.hide_viewport = False
        c.hide_render = False
# coleções excluídas da view layer não exportam: inclui todas
def _incluir(lc):
    lc.exclude = False
    for c in lc.children:
        _incluir(c)
_incluir(bpy.context.view_layer.layer_collection)

# No .blend as peças ficam numa "vitrine" ao lado do boneco (só a location do objeto é deslocada; os vértices já
# estão no lugar do corpo). Zera a location e aplica rotação/escala (Hat_057 vem girado e em escala 0,092).
for o in bpy.data.objects:
    if o.type == "MESH" and o.parent == arm:
        o.location = (0.0, 0.0, 0.0)
        if tuple(o.rotation_euler) != (0.0, 0.0, 0.0) or tuple(o.scale) != (1.0, 1.0, 1.0):
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# subdivisão do corpo: nível 1 basta (low poly)
for o in bpy.data.objects:
    for m in o.modifiers:
        if m.type == "SUBSURF":
            m.levels = min(m.levels, 1)

if arm.animation_data is None:
    arm.animation_data_create()
arm.animation_data.action = bpy.data.actions.get("Idle_Breathing")

bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm

bpy.ops.export_scene.gltf(
    filepath=SAIDA,
    export_format="GLB",
    use_selection=False,
    export_apply=True,
    export_skins=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_force_sampling=True,
    export_def_bones=False,
    export_yup=True,
    export_image_format="AUTO",
    export_materials="EXPORT",
)
print("EXPORT_OK", SAIDA, os.path.getsize(SAIDA))
print("PECAS", sorted(o.name for o in bpy.data.objects if o.type == "MESH"))
print("ACOES", sorted(a.name for a in bpy.data.actions))
