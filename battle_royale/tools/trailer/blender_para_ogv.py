"""Rodar dentro do Blender (CLI): converte o MP4 em OGG Theora+Vorbis (formato de vídeo do Godot).
blender -b --python tools/trailer/blender_para_ogv.py -- entrada.mp4 saida.ogv"""
import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
ent, sai = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.sequence_editor_create()
st = sc.sequence_editor.sequences.new_movie("v", ent, 1, 1) if hasattr(sc.sequence_editor, "sequences") else sc.sequence_editor.strips.new_movie("v", ent, 1, 1)
sd = sc.sequence_editor.sequences.new_sound("a", ent, 2, 1) if hasattr(sc.sequence_editor, "sequences") else sc.sequence_editor.strips.new_sound("a", ent, 2, 1)
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 1280, 720, 100
sc.render.fps = 30
sc.frame_start, sc.frame_end = 1, st.frame_final_duration
r = sc.render
r.image_settings.file_format = "FFMPEG"
r.ffmpeg.format = "OGG"
r.ffmpeg.codec = "THEORA"
r.ffmpeg.constant_rate_factor = "MEDIUM"
r.ffmpeg.audio_codec = "VORBIS"
r.ffmpeg.audio_bitrate = 160
r.filepath = sai
bpy.ops.render.render(animation=True)
print("PRONTO", sai)
