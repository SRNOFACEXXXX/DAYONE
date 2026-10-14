# Gerar o instalador do DAYONE (Windows)

O instalador é gerado a partir do export do Godot 4.7.1 com o Inno Setup 6. Nada disso precisa de Steam.

## Pré-requisitos (uma vez)
1. **Godot 4.7.1** (versão padrão, não a .NET). `winget install GodotEngine.GodotEngine`.
2. **Export templates 4.7.1**: no editor, *Editor → Manage Export Templates → Download and Install*. O script avisa se faltarem.
3. **Inno Setup 6** (`winget install JRSoftware.InnoSetup`). O `ISCC.exe` fica em `Program Files (x86)\Inno Setup 6`.
4. **Git LFS**: `git lfs install` antes de clonar. Sem o LFS, alguns `.fbx` viram ponteiros de texto (a build não usa esses arquivos).

## Passo a passo
Dentro da pasta `battle_royale\tools\instalador`:

```powershell
powershell -ExecutionPolicy Bypass -File .\exportar_windows.ps1
```

O script:
1. Faz `Godot --headless --export-release "Windows Desktop"` do projeto em `game\`, gerando `build\DAYONE\DAYONE.exe` e `DAYONE.pck`.
2. Copia `LEIA-ME.txt` para `build\DAYONE\`.
3. Compila `dayone.iss` com o ISCC e gera `build\DAYONE_Setup.exe`.
4. Gera também `build\DAYONE_portatil.zip`, que roda sem instalar (descompacte e abra `DAYONE.exe`).

Para enviar a um colega, mande `build\DAYONE_Setup.exe` (ou o zip). Não mande a pasta `game\` nem o `.godot\`.

## Versão
A versão fica em `game\project.godot` (`config/version`) e em `dayone.iss` (`#define Versao`). Atualize as duas juntas.
