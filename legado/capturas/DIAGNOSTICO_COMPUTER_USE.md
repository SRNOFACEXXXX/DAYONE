# Falha de captura do Blender no Computer Use

## Evidências verificadas

- Windows instalado: Windows 10 Pro 22H2, build 19045.6466 (registro do sistema).
- Blender detectado: Blender 4.5.13 LTS.
- O conector lista a janela e consulta sua árvore de acessibilidade.
- A captura visual falha repetidamente, inclusive após reiniciar a sessão JavaScript e recuperar a janela.
- Erro: `SetIsBorderRequired failed: Não há suporte para esta interface (0x80004002)`.
- A Microsoft documenta `GraphicsCaptureSession.IsBorderRequired` como introduzida no build 20348, contrato UniversalApiContract v12.

Fonte: https://learn.microsoft.com/en-us/uwp/api/windows.graphics.capture.graphicscapturesession.isborderrequired

## Diagnóstico

As evidências apontam para uma chamada a uma interface indisponível no Windows instalado, no componente nativo de captura do conector. O erro acontece antes de retornar uma imagem do Blender; não indica defeito da cena 3D nem diferença de capacidade entre modelos de linguagem.

Não foi inspecionado o código-fonte do componente nativo, portanto o local exato da implementação ainda não foi identificado.

## Correção necessária no conector

Verificar a disponibilidade de IsBorderRequired antes de acessá-la. Em sistemas sem essa interface, manter a borda de captura padrão e usar um caminho de captura compatível, caso suportado pelo restante do componente. Tratar E_NOINTERFACE nessa propriedade opcional sem encerrar toda a captura.

A API pública instalada de @oai/sky não documenta opção de backend alternativo ou de omissão dessa chamada. Nenhum executável foi modificado, nenhuma configuração de segurança foi alterada e nenhum caminho de captura alternativo foi implementado.

## Estado do trabalho no carro

Os modelos anteriores são protótipos rejeitados pelo usuário, não entregas fotorrealistas. A reconstrução visual do zero ainda não começou, porque não há captura funcional da interface. Os arquivos existentes foram preservados.
