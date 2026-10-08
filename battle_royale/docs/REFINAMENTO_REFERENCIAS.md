# Refinamento visual e de sobrevivência — Ilha Brava

## Referências recebidas

- **DeadPoly:** câmera externa próxima, personagem baixo no quadro e espaço visível à frente; hotbar e indicadores de sobrevivência ficam nas bordas inferiores.
- **DayZ:** menu de apresentação sobre um cenário com personagem em destaque; inventário escuro em painéis simultâneos para proximidade, personagem/equipamento e mochila.
- **AK low-poly e Mosin:** silhueta legível, mãos completas, arma alinhada com o eixo de mira; no ADS, alça/mira/retículo devem convergir ao centro.
- A imagem de scope realista serve para enquadramento e leitura da lente; a direção de arte geral permanece low-poly.

## Etapas e gates

| Etapa | Escopo | Critério de aceite | Estado |
|---|---|---|---|
| 1. Perspectiva e salto | C alterna primeira/terceira pessoa; câmera de ombro com colisão; avião, queda e paraquedas em terceira pessoa; retorna à escolha do jogador ao pousar. | Capturas de avião/queda/paraquedas/pouso; sem viewmodel na câmera externa; corpo visível; nenhuma transição perde controle. | **Passou no smoke gráfico.** Alternância testada de ida/volta; câmera externa forçada no avião e queda; pouso devolve FP; viewmodel oculto. Falta velame, animação/vento e capturas em voo com controle manual. |
| 2. Armas e ADS | Calibrar AK/M4/Mosin, mãos, iron sights e ACOG; recuo e recarga sem clipping. | Pares de capturas hip-fire/ADS com a mesma câmera; retículo e tiro coincidem; mãos inteiras; ACOG só quando instalada. | **Gate funcional passou:** `ads_capture.tscn` confirma iron FOV 56°, ACOG 30° e captura em 1024×720. A revisão da imagem reprova a pose atual: mão de apoio aberta/cortada, arma grande e braço entra na área da HUD. A tentativa de curvatura no eixo X foi descartada; build da AK voltou ao eixo estável Z. `raw/ads_review/02_iron.png` e `03_acog.png` são a evidência atual. |
| 3. Inventário e hotbar | Aproximar DayZ 0.58: vizinhança, personagem/equipamento, grade de mochila, mãos e tooltip; hotbar persistente estilo DeadPoly. | Coletar, transferir, equipar, dividir pilhas, recarregar e fechar/reabrir sem perda; hotbar refletindo slots e munição; 1280×720 e 1024×768. | **Passo visual 01 aprovado em 1024×720:** três colunas (saque, sobrevivente, mochila), peso/capacidade e ações; API/transferência/munição/ACOG passam. **Hotbar 1–4 reflete slots e munição; F1–F4 aceitam atribuição persistente de armas** via clique do meio + tecla no inventário. Testes de API e de uso de F1 foram adicionados; a captura ADS mostra a hotbar esmaecida. Ainda faltam preview 3D, slots corporais, tooltip, consumíveis na hotbar e gates da própria tela de inventário em 1024×768/1280×720. Crítica em `docs/criteria/INVENTARIO_CRITICA_01.md`. |
| 4. Menu | Apresentação 3D com personagem e painel lateral; manter controles responsivos e configurações funcionais. | Jogar/Explorar/Configurações/retorno testados; sem corte ou tela cinza; 1280×720 e 1024×768. | **Gate de layout/configurações passou em 1024×768 e 1280×720:** abrir/fechar validado; o painel cresceu para exibir integralmente as opções sem cortar a linha inferior. Capturas em `raw/menu_review/1024x768_*` e `1280x720_*`. O fundo é da ilha, mas ainda estático e sem operador 3D animado; falta o fluxo integral de Jogar/Explorar. |
| 5. Áudio e acabamento da queda | Separar motor, vento, velame e pouso; tratar mix, loops e ganho. | IDs válidos, eventos distintos, espacialização e volume sem clipping, durante uma partida completa. | **Passo 02 passou no smoke gráfico completo:** o loop CC0 da hélice inicia após o carregamento do BR, o vento substitui o motor no salto, reduz quando abre o paraquedas e a ambiência da ilha volta no pouso. Os quatro estados do voo, pouso, C/FP/TP, frenagem e coleta passaram. Ainda falta SFX próprio de abertura/tecido do velame e avaliação auditiva de mix/nível em voo. Créditos em `docs/ASSET_CREDITS.md`. |
| 6. Gate comparativo | Capturas equivalentes às referências e medição no Compatibility/GT 730. | Checklist em `docs/criteria/REVISAO_VISUAL_REFERENCIAS_01.md`; sem erros de console e alvo de 60 FPS a 1024×768. | Em andamento. |

## Implementação da etapa 1 — ciclo 01

- `PlayerController` aceita **C** para alternar a perspectiva durante o jogo.
- Terceira pessoa segue o personagem por cima do ombro, verifica colisão do mundo para não atravessar paredes e suaviza posição/orientação.
- O modo externo torna o corpo visível, esconde o viewmodel de primeira pessoa e desliga o ADS de tela.
- `BRMatch.is_player_airborne()` força a terceira pessoa durante avião/queda/paraquedas. Ao pousar, a perspectiva retorna à preferência escolhida com C.
- `ViewModel.set_viewmodel_enabled()` impede que o processamento de cada quadro reative a arma FP durante a câmera externa.
- **V** alterna a ACOG instalada sem conflitar com **F** (inspecionar); a transição de FOV usa o tempo configurado na arma.
- `tests/br_smoke.gd` espera a inicialização assíncrona correta e verifica câmera afastada do jogador no salto e retorno ao pousar.

## Evidência e estado da rodada

- Parse/import Godot 4.7.1: aprovado.
- `tests/br_smoke.tscn`: aprovado; partida montou 12 jogadores, 255 armas e 28 caches; pousou em ~17 s, verificou câmera distante durante a queda, voltou à primeira pessoa e coletou um item.
- Capturas da rodada final em `raw/refinement_camera_final/`: `br_aviao.png`, `br_queda.png`, `br_para.png`, `br_pouso.png`, `br_chao_3p.png` e `br_chao_1p.png`. O viewmodel não aparece em terceira pessoa; personagem inteiro fica no quadro no chão e durante a queda.
- Revisão de áudio local não encontrou arquivos de vento/avião/paraquedas nos assets fornecidos. Removi o som incorreto de pouso no momento da abertura do paraquedas; o evento `parachute_open` toca quando o asset existir.
- A auditoria técnica completa e a crítica das referências estão em `docs/qa/AUDITORIA_REFINAMENTO_01.md` e `docs/criteria/REVISAO_VISUAL_REFERENCIAS_01.md`.

## Próxima rodada

1. Melhorar composição no ar e adicionar velame/vento com eventos de áudio distintos.
2. Criar uma cena de captura jogável que permita registrar C em primeiro/terceira pessoa no chão, sem depender de posição de bot ou teste estático.
3. Fazer passe de IK da mão de apoio e de enquadramento do AK/Mosin; comparar hip-fire/iron/ACOG no gate visual.
4. Integrar a hotbar ao inventário DayZ com atribuição, ações de consumíveis e persistência por partida.
5. Completar personagem 3D no menu/inventário, velame e áudio de avião/abertura, depois executar o gate total.
