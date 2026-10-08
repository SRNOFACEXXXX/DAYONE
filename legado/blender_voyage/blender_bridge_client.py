"""Client for the installed Blender MCP addon null-delimited JSON bridge."""
import argparse
import json
import socket
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--file', type=Path)
args = parser.parse_args()
code = args.file.read_text(encoding='utf-8') if args.file else "import bpy\nresult = {'version': bpy.app.version_string, 'file': bpy.data.filepath, 'objects': [{'name': o.name, 'type': o.type} for o in bpy.context.scene.objects], 'workspace': bpy.context.workspace.name if bpy.context.workspace else None}"
request = json.dumps({'type': 'execute', 'code': code, 'strict_json': True}).encode() + b'\0'
with socket.create_connection(('127.0.0.1', 9876), timeout=10) as connection:
    connection.settimeout(120)
    connection.sendall(request)
    chunks = bytearray()
    while b'\0' not in chunks:
        chunk = connection.recv(65536)
        if not chunk:
            break
        chunks.extend(chunk)
response = json.loads(bytes(chunks).split(b'\0', 1)[0])
print(json.dumps(response, ensure_ascii=True, indent=2))
if response.get('status') != 'ok':
    raise SystemExit(1)
