# Crítica visual — inventário, ciclo 01

## Primeira impressão

A hierarquia agora comunica três funções paralelas: saque ao redor à esquerda, sobrevivente/equipamento vestido no centro e mochila à direita. A grade deixou de ocupar uma pequena caixa flutuante e os rótulos continuam legíveis na captura de 1024×720. A paleta escura com detalhes areia combina com o cenário low-poly e mantém o jogo visível sob o painel.

## Leitura em relação à referência DayZ 0.58

- **Composição:** aproxima a estrutura de três colunas da referência; vizinhança, personagem e inventário ficam visíveis juntos.
- **Ações:** clique recolhe/transfere; botão direito equipa ou acopla a ACOG; arrastar reorganiza. Peso, limite e mochila permanecem visíveis.
- **Identidade visual:** linhas finas, títulos compactos e paleta oliva/areia foram mantidos coerentes com a direção low-poly.
- **Diferença principal:** o sobrevivente central ainda é uma ilustração 2D low-poly desenhada pela UI, não o modelo 3D equipado. Não há tooltip de item, silhueta de slots no corpo nem hotbar de sobrevivência integrada.
- **Adaptação:** a captura validada é 1024×720. Ainda falta medir 1024×768 e 1280×720 com conteúdo longo, mochila grande e painel de saque cheio.

## Prioridades seguintes

1. Trocar a ilustração pelo personagem real em preview 3D isolado, incluindo roupa/mochila e estado da arma nas mãos.
2. Adicionar slots por região corporal e tooltip com calibre, peso, condição e compatibilidade do acessório.
3. Ligar a hotbar de sobrevivência ao inventário, arma equipada, carregador e munição de reserva.
4. Fazer capturas nas duas resoluções de aceite e testar transferência, arraste e troca de mochila durante uma partida.

## Evidência

- Captura: `raw/ads_review/04_inventory.png`.
- Verificações: importação Godot 4.7.1 aprovada; `tests/br_inventory_check.tscn` aprovado; `tests/ads_capture.tscn` chegou ao painel e gravou a captura.
