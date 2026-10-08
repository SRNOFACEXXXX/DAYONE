# Atualização DAYONE — backlog (fonte da verdade do /loop)
Projeto ativo a partir de 2026-10-02: C:\Users\satoshi\Documents\ChatGPT\teste\teste GPT\battle_royale (mapa do Codex).
Regra: item só sai da lista com medição/captura que prove. Cada volta grava docs/qa/LOOP_LOG.md.

## Combate
- [x] C1 Ponto da holográfica acompanha a arma (colimador): tests/holo_reticulo.tscn 0 falhas nas 5 armas (parado 0 px, erro vs eixo do cano ≤0,01 px, desloc 24–67 px na rajada). raw/holo_reticulo
- [x] C2 Mira no mundo: 3ª pessoa, bot e chão com holo/ACOG assentada (core/optica_assento.gd; tests/mira_mundo_check). Pendente: bots não recebem mira no saque; captura limpa de 3ª pessoa
- [ ] C3 AK e Uzi no esqueleto do pack (recarga/quadril)
- [~] C4 Mosin: braço ≤13,4% da tela, ferrolho 0,97 s, clip 3,18 s, 0 quadros rosa no jogo real (tests/sniper_jogo), ADS bloqueado durante o ferrolho. FALTA: dono ainda sente travada; 1º equipar 143 ms; clip visível só 9%
- [x] C5 Coice: mola por tiro; rajada 10 pico AK 1,08°/M4 1,1°; M107/Mosin voltam em 0,48 s; M4 0,63°/tiro (tests/combate_coice). Spray do CS encolhido 0,35x (weapon_def.SPRAY_ESCALA)
- [~] C6 (QA v1: pico 80–104 ms ao iniciar sprint; arma sumia no sprint da AK → pose suavizada) Sprint Shift 1,25x, 0 tiros/ADS no sprint, 0,25 s até atirar, ADS 55%, t90 0,25 s (tests/combate_mov). Arma abaixa no sprint (viewmodel _sprint_w); walk=Alt em settings.BINDINGS
- [x] C7 Balística: projétil com gravidade+arrasto por calibre, zero por arma; queda M4 400 m 86,8 cm (ref 87,3), erro ≤1% (tests/combate_balistica). FPS fogo 143→140. Pendente: dano por velocidade, seletor de zeragem
- [~] C8 (áudio feito: 8 armas em camadas perto/100 m/500 m, rajada AK/M4 pico 0,95 limitado, cauda 1,2–2,4 s, propagação 1000 m com atraso 343 m/s, sinal Audio.barulho p/ zumbis; tests/audio_armas 0 falhas. Falta: ouvir no jogo, oclusão, peso visual) Som simulador (AK/M4 auto ensurdecedor, cauda/eco por distância, propagação p/ zumbis) + peso (impacto, coice visual)
- [x] C9 Ícones: uzi/m249/m107 faltavam; + mosin/acog/reddot/granada com miniatura 3D (ui/item_icons.gd, tests/icones_sheet|icones_inv). raw/icones/inventario.png
## Mapa
- [~] M1 Paleta global (céu azul, menos névoa, verdes vivos, 24 copas de outono): notas vilas 4–6 → 4,5–7 (raw/mundo/vilas_depois). FALTA: paredes teal/verde das casas, Pedreira/Morro, árvores MultiMesh, FPS quartel_garagem 49. Revisão por vilarejo contra as referências (C:\Users\satoshi\Downloads\ref) com nota e lista de correções
## Assets (C:\Users\satoshi\Desktop\Assets\atualização)
- [x] A1 Inventário do pack e plano: raw/triagem/atualizacao.json (+ folhas atualizacao_*.png, vilas/*.png com nota 4–6)
- [~] A2 (vilas: +68 peças do pack nas 8 vilas, 237 tambores→Barrel_005, 3 Apocalypse_Car, galinha/cão/cervo/gato estáticos; draws iguais; notas +0,5) Pack mundo: 49 glb (bases militares+apocalípticos), Quartel 52 e Pista 30 peças à mão (cenario_atualizacao.json), colisão convexa; custo ≤1 FPS. FALTA: apocalípticos nas outras vilas, loot alto, guaritas/torre antigas
- [x] A3 Interiores do pack (47 glb; tools/importar_props_interiores.py), lootáveis 367→439; casa_alcance/sv_movel/sv_smoke OK; FPS casa 58→59,9. raw/interiores/depois. Pendente: item médico, banheiro, fogão/rádio/telefone antigos
## Menu
- [x] U1 DAYONE no título, janela, carregamento e explorador (raw/menu/menu_dayone.png)
- [~] U2 (QA v1: 6,6 s com 8 s no criador; 4 quadros >100 ms; 3ª pessoa −25 fps e sem arma na mão → em correção) Criador PERSONAGEM aplicado ao jogador (3ª pessoa + retrato; mão–cabo ≤1,8 cm; tests/personagem_corpo); partida pré-montada atrás do criador: clique→controle 23,5 s → 0,48 s (≥20 s no criador), 0 quadros >100 ms. Pendente: menu irregular durante a pré-montagem; Mosin mão esquerda no corpo

## Achados do QA v1 (raw/triagem/qa_v1.json)
- [~] Q1 Interior v2: lambri/rodapé/cor por cômodo, piso de tábuas, banheiro com loot (496 lootáveis), móveis fundidos (4 draws/casa), casa_alcance PASS; nota própria 7 (raw/interiores/v2_depois). FPS da casa ~38 depende da otimização do mundo
- [ ] Q2 M107 não cabe na mochila média (inventário)
- [ ] Q3 Capim alto e postes dominando as vistas; Quartel andando 53 fps (mín 12)
- [ ] Q4 Som nunca ouvido no jogo real (só teste)
- [ ] Q5 Uzi/AK em ADS: mãos bege em blocos cobrindo a mira
- [~] U3 Fundo do menu: acampamento com caminhonete, props do pack, sangue, Doberman, fogueira (66 FPS, máx 21,8 ms a 1024x768; nota 7). FALTA: sangue mais vermelho, lago mais visível
- [x] M2 Pontes: 8/8 travessias com o Soldier real andando por Input (tests/pontes_check reescrito); crista corrigida (2 muretas na estrada E10); QA v2 tinha z espelhado no teste dele
- [~] P1 (QA v2: média 20,4 ms/p99 29 ms; criador a 22 fps com congelamento de 3,2 s na pré-montagem; zumbis 0 dano a 3–8 m) Desempenho (fluxo real, 1600x900 MSAA 4x do usuário): média 22,8→16,6 ms, p99 41→22 ms, física 6,2→1,3 ms, quadros >50 ms 20→0, pior 110→25 ms (zumbi LOD, capim 1 bloco/quadro, vegetação 125→65 draws, Blockout fundido). GPU-bound: sem MSAA 13,8 ms. Zumbis agora atacam o jogador na partida
- [x] Q6 Testes verdes: sv_smoke (granadas), mira_mundo_check (mochila no teste) MIRA_MUNDO_OK, combate_mov OK sozinho (falha do QA era contenção)
- [x] Q7 Não é HUD da partida: são os painéis do próprio main_menu (EQUIPAMENTO/COLETE)
- [x] Z1 Zumbis: ouvem passos ≤10 m, visão 35 m, tiro atrai até 150 m, pulam mureta; zumbi 6 m atrás ataca em 2,8 s, a 25 m ouvindo tiro ataca em 9,8 s (perf_d2 --percepcao); física ≤2,5 ms; sv_smoke corrigido (granadas)
- [~] U4 Criador liso: 22→55,8 fps, pior quadro 3.173→228 ms, 6 quadros >100 ms; clique→controle 3,3 s (partida 1º min p99 21,9 ms, 0 >50 ms)

## Volta 2026-10-07 (sessão manual, sem subagentes — testes no jogo real com capturas)
- [x] W1 Troca de armas bugada (mão mostrava a AK com a M4 equipada): `Soldier.remove_slot` deixava `active_slot` apontando para o slot vazio quando não havia pistola/faca e `switch_to` ignorava equipar no mesmo slot → viewmodel/corpo ficavam com o modelo antigo. Corrigido (`active_slot=-1` + `weapon_switched(null)`, `announced_id` detecta troca no mesmo slot, viewmodel e corpo limpam a mão). tests/troca_armas.tscn (nasce sem nada, pega/solta/troca 10 armas, confere soldado=viewmodel=corpo): TROCA_ARMAS_OK.
- [x] W2 Inventário no jogo real com mouse: tests/inventario_real.tscn (UI de verdade: mochila no slot, AK/M4 da proximidade para a mão, troca, soltar a arma da mão, pegar de volta, peso, teclas 2/3) INVENTARIO_REAL_OK. Achado: o kit inicial de 120 madeira + 40 pedra pesava 8 kg dos 12 kg do bolso e impedia pegar qualquer arma → removido no modo de construção livre. Soltar a arma da mão agora volta para a pistola (antes: faca).
- [x] W3 Tiro em zumbi por distância no jogo real (tests/tiro_zumbi_real.tscn): dano registra a 2, 4, 8, 15, 60 e 100 m (a 30 m o alvo estava atrás de uma crista do terreno, impactos "stone" a 13 m). Não reproduzi "bala some a 2 m"; se acontecer de novo, mandar posição/arma.
- [x] W4 Morte do zumbi: flutuava ~0,9 m (retarget só de rotação deixava os quadris na altura de pé) → `_ajustar_corpo_ao_chao`; 4 variações de queda pela direção do golpe (frente/costas/lado/cabeça) com velocidade variável. Capturas raw/triagem/morte_folha.png (corpo encostado no chão em todas).
- [x] W5 Mãos vazias em 3ª pessoa: ficavam na pose de faca (cotovelos dobrados no peito) → agora braços soltos (`upper/blend_amount=0`). raw/triagem/maos3p_zoom2.png.
- [x] W6 Som: zumbis tinham 3 grunhidos baixos a cada 8–15 s; carros só tinham porta. Agora voz do zumbi (grunhido, alerta, rosnado correndo, ataque, ferido, morte; CC0 OpenGameArt: zombienoises, monster-sounds-volume-2) e MOTOR do carro (3 laços CC0 domasx2, pitch pela rotação com 4 marchas e crossfade). tests/som_real.tscn mede no jogo real: eventos de áudio + pico do Master −7,4 dB: SOM_REAL_OK. NÃO OUVIDO por mim — o dono precisa julgar a qualidade.
- [~] W7 "Jogador atravessa props": tests/andar_mundo.tscn (Soldier real de sprint por 60 trajetos nos 10 POIs) mediu 0 quadros com a cápsula dentro de geometria, exceto 1 início dentro de um Blockout da usina (teleporte do teste). Props das áreas: tests/props_andar 0/10. Não reproduzi o atravessar; falta repro do dono (qual prop/onde).
- Pendente: spawn no litoral, ambiente/passos/armas "ruins" (julgar de ouvido), baú/cura (agente anterior implementou, não revisei), playtester/sobrevivente (agente morreu no limite de sessão).
- [x] W8 Spawn: antes SEMPRE o mesmo ponto (adro da Capela, em cima de um telhado/laje cinza) virado para o mesmo lado. Agora (jogo real) sorteia uma praia ao redor da ilha (`BRMatch.escolher_spawn_costa`: 14–60 m para dentro da costa do layout, altura 0,6–9 m, declive <12°, cápsula livre, vista livre 5 m à frente, zumbi a >45 m, >80 m do spawn anterior, olhando para o interior), também no renascimento. Em testes automatizados continua fixo (usar `--spawn_costa`). tests/spawn_costa.tscn: 60 sorteios, 0 fallback, 47 regiões distintas, 8 renascimentos reais fora da água/geometria/zumbis. Capturas raw/spawn/fp_comp3.png (praia com palmeiras, campo com casa).
- [x] W9 Colisão: 57 trimesh (casas do pacote/Blockout e cercas fiéis) só bloqueavam pelo lado da normal (`backface_collision=false`) → agora 0 de 710 (tests/trimesh_lados.tscn). tests/cerca_dois_lados.tscn: Soldier real contra cercas/muros pela frente e pelas costas (portões excluídos: têm vão): 1/21 pela frente (aglomerado de muros), 0/21 pelas costas.
