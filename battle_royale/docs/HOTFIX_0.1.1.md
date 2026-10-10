# Hotfix 0.1.1 — notas de atualização

Correções desde a 0.1.0. Cada item tem teste no jogo real (`game/tests/`). Build 0.1.1 ainda não gerado.

## Correções
- **Zumbis empilhados**: zumbis se afastam uns dos outros (`zombie._afastar_vizinhos`). Teste `zumbi_horda_separacao`.
- **Atravessar objetos**: fardos, cercas e pedras bloqueiam o jogador em terceira pessoa. Topo fino (trilho/ripa) não aguenta o jogador em pé (`Soldier._topo_largo`). Teste `terceira_colisao`.
- **Animais**: tombam de lado ao morrer (`animal._cair`). Teste `animais_morte`.
- **Carro**: dica de saque não aparece por cima do aviso do veículo. Câmera estável a 98 km/h (`tests/carro_camera`).
- **Carro**: kit de reparo, jogo de chaves e fita consertam (F). Teste `combustivel_barco`.
- **Itens novos**: arco e flecha, dinamite, mina, frigideira, cofrinho, celular, mochila de trilha, escada telescópica. Teste `props_real`.
- **Cosméticos no corpo**: chapéu, fones, coroa, máscara de mergulho, chuteira e amuleto (`core/cosmeticos.gd`).
- **Itens de animal**: pele, gordura e osso com modelo e definição.
- **Mineração, água e doença**: picareta, beber com T, carne crua e antibiótico. Teste `agua_doenca_pedra`.
- **Som**: fogueira em laço. Teste `fogueira_real`.

## Regressão
Passando: `combustivel_barco`, `inventario_real`, `troca_armas`, `base_bau_cura`, `sobrevivencia_real`, `corte_arvore`, `fogueira_real`, `agua_doenca_pedra`, `som_real`, `props_real`, `animais_real`, `zumbi_horda_separacao`.
Falha conhecida: `zumbi_dano` só no critério de FPS (render por CPU, não vale).

## Como publicar (SteamPipe)
1. Versão `config/version="0.1.1"` já está em `game/project.godot`.
2. Exportar o build Windows a partir do Godot 4.7.1.
3. Enviar com steamcmd para o depot da app, na branch `hotfix`.
4. Colar esta lista como nota de atualização.

## Fora desta versão (vai para 0.2)
- Escada e cofrinho: reação de sons ainda não ouvida no jogo.
- Régua de torre: sem uso no jogo.
- Pesca, roupas com isolamento e salvar progresso.
