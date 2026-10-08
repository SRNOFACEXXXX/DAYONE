# Crítica visual — menu survival, ciclo 01

## Primeira impressão

A ilha aparece de imediato e o menu deixa de parecer uma caixa de teste isolada. O título ocupa a área esquerda; jogar, explorar, configurações e sair formam uma coluna curta à direita. O painel de configurações abre sobre a composição e tem rolagem vertical, com os controles existentes expostos sem serem comprimidos na coluna estreita.

## Hierarquia, consistência e uso

- **Hierarquia:** “Jogar” recebe o destaque principal; exploração e configurações são secundárias; teclas importantes ficam no rodapé.
- **Consistência:** areia, oliva e carvão conectam os painéis ao cenário low-poly da ilha.
- **Acessibilidade:** contraste adequado nos botões e texto principal; configurações menores podem exigir ajuste de escala em telas menores.
- **Limite da referência:** esta passada usa uma captura aérea estática do jogo. Não há personagem 3D animado no menu, estatísticas persistentes nem transição cinematográfica como no DayZ.
- **Gate:** `tests/menu_capture.tscn` gravou menu e configurações a 1024×720 e validou abrir/fechar. Jogar, explorar, ESC e 1024×768/1280×720 ainda precisam do teste integrado.

## Próximos ajustes

1. Adicionar personagem 3D animado em segundo plano, mantendo a paisagem e a taxa de quadros do PC-alvo.
2. Validar navegação real por mouse e teclado e o retorno após partida/exploração.
3. Ajustar responsividade e escala de texto nas duas resoluções de aceite.

## Evidência

- `raw/menu_review/01_menu.png`
- `raw/menu_review/02_configuracoes.png`
