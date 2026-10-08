# Estudo de desenvolvimento e economia de tokens (o que aprendemos trabalhando com IA neste projeto)

## Princípios
1. **Triagem barata antes do trabalho pesado.** Leia o mínimo: `AGENTS.md`, o item do backlog, os 1–3 arquivos tocados. Liste o estado em JSON/tabela curta (`raw/triagem/*.json`) e só então edite.
2. **Leia por faixas, não arquivos inteiros.** `Grep`/`sed -n a,bp` nas funções certas. Arquivos de 1500+ linhas (`trailer.gd`, `br_match.gd`) nunca devem ser lidos inteiros.
3. **Medir > opinar.** Um teste curto com número (FPS, ms, px, cm) vale mais que 10 mensagens de análise. Capturas PNG pequenas (folha de contato 640×360 com tempos) em vez de dezenas de imagens.
4. **Um processo por vez.** Rodar vários Godot em paralelo trava a máquina (GT 730) e gera processos órfãos que mentem nas medições.
5. **Subagentes: só 1, com escopo e saída JSON.** Vários agentes baratos brigaram pelo Godot e entregaram relatórios sem prova. Use um crítico independente (QA) que tenta provar que NÃO está resolvido, com critérios escritos (`docs/trailer/CRITERIOS_QA.md`).
6. **Blocos de 1–2 h.** Termine cada bloco com relatório curto: feito / medido / pendente / próximo. Nunca gastar o limite inteiro em um prompt.
7. **Escreva o estado no disco, não na conversa.** Contexto some; `docs/ATUALIZACAO_DAYONE.md` e este handoff não. Memória compacta, uma linha por fato.
8. **Scripts grandes via arquivo, não heredoc.** Heredocs enormes no bash quebraram (EOF). Use Write/Edit ou um `.py` de patch aplicado (padrão `aplica_*.py`).
9. **Previews em tempo real com o preview do jogo** (`tools/trailer/prev.sh`, `tests/*_capture`) antes de renderizar qualquer coisa longa. Render completo de 2 min leva ~6 min e a pós ~55 min: só renderize quando as folhas de contato estiverem aprovadas.
10. **Reutilize o jogo real** (Soldier, inputs, ADS, inventário) em testes e cinemáticas: falsificar estado gera bugs visuais (ex.: forçar `_ads_amount` desalinhou mira e arma).

## Custos típicos (referência nesta máquina i7-3770 / GT 730)
- Teste Godot curto: 20–60 s. Preview de tomada: 1–2 min. Render do trailer: ~6 min a 1280×720/30 fps.
- Pós com IA (Depth Anything V2 Small ONNX na CPU, ~1,5 s por inferência a cada 10 quadros): ~0,9 s/quadro (~55 min para 3600 quadros).
- Conversão Blender → OGV (Theora) do trailer: ~12 min.

## Padrões que economizam
- Backlog com caixas `[ ] [~] [x]` e evidência (arquivo/captura) ao lado.
- Testes pequenos com `print("TESTE_OK ...")` para `grep` na saída (`| grep -E "OK|SCRIPT|Parse|Invalid"`).
- Registrar `class_name` novo: `godot --headless --editor --quit` (senão "class not found").
- Ferramentas de renderização/pós são **parametrizadas por tomada** (`--teste t1,t2`, `--max N`) para iterar sem refazer tudo.
- Modelos: tarefas visuais/físicas/3D exigem o modelo mais forte disponível; modelo pequeno só para triagem, listagem e edição mecânica.
