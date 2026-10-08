# Revisão visual 02 — sobrevivência, hotbar e mira

Escopo revisto: capturas `raw/ads_review/02_iron.png`, `03_acog.png`, `04_inventory.png` e `raw/menu_review/01_menu.png`, `02_configuracoes.png`, comparadas às referências recebidas e a `docs/REFINAMENTO_REFERENCIAS.md`.

## Diagnóstico

- **AK e pegada (reprovado):** a linha de mira aproxima o centro, mas a mão de apoio parece espalmada, não envolve o guarda-mão; o braço ocupa a borda inferior. Critério de aceite: duas mãos inteiras, pegada contínua e ao menos 16 px entre arma/mãos e hotbar; retícula e munição sempre desobstruídas.
- **ACOG (parcial):** o círculo e o retículo estão legíveis, mas a ampliação não é convincente na captura e a arma invade a área da lente. Critério: comparar um marco fixo com hip-fire; o marco deve ficar pelo menos 2× maior dentro da lente, com centro estável e sem a arma bloquear o alvo. A escuridão externa também deve ser reduzida sem perder a silhueta da lente.
- **Inventário (parcial):** a estrutura em três colunas está clara, mas o sobrevivente é retrato 2D; faltam preview 3D, painel de mãos/equipamento e tooltip demonstrado. Critério: um item de saque visível, transferido e mostrado no inventário; preview equipado e controles acessíveis em 1024×768 e 1280×720.
- **Menu/configurações (parcial):** hierarquia do menu funciona, mas o fundo estático não apresenta personagem e há uma linha de controle parcialmente cortada na captura. Critério: operador 3D no cenário e conteúdo rolável sem texto cortado; abrir, voltar e ESC nos dois tamanhos de teste.
- **Desempenho:** uma leitura da captura mostra 15 FPS em um quadro, insuficiente para avaliar sustentação. Critério: benchmark de 60 s a 1024×768, Compatibility/GT 730, registrando média e p95 de frame time; meta média de 60 FPS.

## Mudança desta rodada

A hotbar 1–4 foi adicionada ao HUD e usa slots, nomes e munição reais de `Soldier`. Armas podem ser atribuídas a F1–F4 pelo botão do meio no inventário; os UIDs são serializados no snapshot da mochila e as teclas equipam a arma atribuída. Durante ADS em primeira pessoa a hotbar reduz a opacidade para 0,28 para disputar menos atenção com a mão/arma. O estado de mãos permanece reprovado; não foi escondido sob uma alegação de correção.

## Evidência e testes

- `tests/ads_capture.tscn`: passou; iniciou no chão, força uma configuração de teste sem bots, verificou a transição iron sight/ACOG e salvou as capturas. FOV reportado: iron 56°, ACOG 30°.
- `tests/br_inventory_check.tscn`: passou (parse, cena, atribuição F1/F2 e persistência do inventário).
- O log visual ainda registra avisos GLES3 `Parameter material is null` durante a montagem; aparecem em testes anteriores e não impediram a captura. A origem segue aberta.
- A tentativa de curvatura de dedos no eixo X foi descartada após piorar a silhueta. O build anterior do AK FP foi restaurado.
