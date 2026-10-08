# Bloco 1 (2026-10-02): combate antes dos zumbis

## Feito
- LEI salva na memória: triagem JSON antes do trabalho pesado, saídas estruturadas, subagentes com QA crítico, blocos de 1–2 h.
- Holográfica e ACOG assentadas automaticamente pela malha (core/viewmodel.gd `_assentar_mira`/`_medir_assento`).
- Gate novo: game/tests/holo_offset.tscn (+ tools/perfil_mira.py para a silhueta com régua de 1 cm).
- 4 subagentes: pesquisa (packs/GitHubs com licença), triagem de recarga/coice/quadril, triagem de movimentação, QA crítico.

## Medido (holo_offset, holográfica)
| arma | folga no ponto mais alto | folga no centro | lateral ponto x cano | ponto em ADS (máx. 60 quadros) |
|---|---|---|---|---|
| m4 | 0,00 cm | 0,00 | 0,00 cm | 0,40 px |
| m249 | 0,00 | 0,32 | 0,00 | 0,40 |
| m107 | 0,00 | 0,00 | 0,00 | 0,24 |
| ak47 | 0,00 | 0,00 | −0,26 | 0,52 |
| uzi | 0,00 | 0,65 (fenda do ferrolho no topo; mediana 0,00) | −0,26 | 0,53 |
Antes da correção: M249 +2,15 cm (riser solto), Uzi +0,69, AK −0,55 (afundada), M107 1,8 cm fora do eixo, M249 0,82 fora.
ACOG (m4, m107, ak47): folga 0,00; ponto ≤1,06 px no FOV do quadril (2,0–3,6 px na tela com zoom 4x).
QA independente (game/tests/qa_holo_anim.tscn): folga 0,00 e atraso 0,00 cm em todos os quadros de idle, rajada de 30, recarga,
andando, ADS andando, troca de arma, retirar/recolocar a mira (m4, m249, ak47, uzi; m107 só idle/ADS). Veredito dele: "parcial",
pelas pendências abaixo.
Ponto 6,5–8,8 cm acima do eixo do cano = altura normal de óptica sobre trilho (não é folga).

## Pendente
1. A mira não aparece no modelo de 3ª pessoa, nos outros jogadores nem na arma solta no chão (body_model.gd, br_drop.gd).
2. Recarga: AK e Uzi com carregador de 40 cm cobrindo a tela e mão fora 75%/23% do tempo; Mosin usa a recarga de carregador da M4
   (sem clip/ferrolho); M249 com carregador sobre a janela; Glock com mão de apoio fora 39%.
3. Coice: acumula 1,2–2,7° em 10 tiros; M107/Mosin não recuperam em 1,6 s; M4/M249 com coice de câmera de só 0,09°.
4. Quadril: AK/Uzi com o cano 3° fora da mira e AK baixa demais.
5. Movimentação: não há sprint (corre armado e atira em 31 ms), ADS não reduz velocidade, aceleração/frenagem 0,39 s,
   sem lean/slide, aterrissagem fraca (1,7 cm), arma atravessa parede.

## Próximo bloco (ordem)
1. Migrar AK e Uzi para o rig do pack (como a M249) → resolve a recarga e o quadril delas.
2. Sprint com arma baixa + ADS 55% da velocidade + aceleração 0,25 s (soldier.gd/player_controller.gd), com teste.
3. Coice: view_kick/recover por arma, medido pelo triagem_arma.
4. Mira no modelo de 3ª pessoa e no chão.
5. Mosin: ferrolho/clip. Avaliar packs: Low Poly Firearms (CC0, peças separadas), CC0 Flat Guns East; código de referência:
   COBRA FPS Feel Kit e Jeh3no Advanced FP Controller (MIT).

Dados: raw/holo_offset/holo_offset.json, raw/triagem/{recarga_coice_quadril,movimentacao_corrigido,pesquisa_packs,qa_holo}.json
