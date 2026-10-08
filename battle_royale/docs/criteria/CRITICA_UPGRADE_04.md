# CRITICA UPGRADE 04

Notas: armas 5/10, mundo 7.5/10, interior 5.5/10, coerência 6/10. Geral: 6.0/10 (antes 4.5).
Revisadas: ak47/m4/m107/m249 (quadril+iron+acog+dot = 16 PNG), 11 de casa_demo (existem 11, não 14; porta_fechada.png é tela "Preparando a ilha 95%", inútil), 15 de tour18.

## O que melhorou
- Armas: M4 e M249 agora têm silhueta (trilho picatinny, fita de munição dourada, ACOG octogonal, mira em anel). Mãos cor de pele existem. Mira de ferro AK/M107 já mostra a cena.
- Mundo: aérea mostra ilha com lagoa, rio, pista, 2 bosques, estradas em anel e canavial. Chão com grama alta facetada em 3D, árvores low-poly facetadas (pinheiros, copas grandes), nuvens poligonais, fios, cruzeiro, caixa d'água, moinho, guarda-sóis. Vilas com casas de cores distintas (verde, rosa, creme, azul).
- Interior: piso de madeira legível, cozinha com bancada/pia/fogão, portas com vidro, janela com paisagem, ventilador, luminária, cama. Sem ruído borrado nas paredes (agora cor chapada).

## O que continua errado
- Armas: AK-47 em quadril é só um cano laranja liso + blocos bege (sem carregador curvo, sem coronha); em iron é um tubo branco/cinza gigante cobrindo ~25% da largura. "Mãos" são caixas marrons retangulares, não mãos (ref: dedos facetados e antebraço verde). M107 iron: bloco cinza no canto + cano de ~30% da tela.
- A cena de teste das armas continua num telhado cinza borrado (textura em baixa resolução) ocupando ~25% inferior.
- FPS na captura variando 5-23 FPS (quadril) vs 54-70 (ADS).
- Interior: teto cinza liso e enorme em todos os cômodos; paredes só 2 tons (creme/oliva) sem rodapé; texturas de móveis em pixels grandes (estante, cômoda, sofá rosa-quadriculado); texturas de tábuas das fachadas borradas com listras (porta_aberta, vila_ruas). Sofá e quadros parecem blocos.
- Mundo: estrada marrom lisa, sem textura nem bordas; capim em primeiro plano tapa ~50% da tela em praia/canavial/bosque; aérea mostra ~35 prédios sobre ilha grande e vazia, patches bege idênticos; leste/oeste sem relevo.
- Arma de mão na casa (Glock) continua blocada e com mão em cubos.

## Correções (prioridade)
1. Mãos FPS: substituir cubos por 2 mãos facetadas (>=12 faces/dedos) + manga verde em todas as armas; largura <=12% da tela.
2. AK-47: adicionar carregador curvo (>=3 segmentos inclinados), coronha de madeira, cano com guarda-mão; cano laranja liso removido; ADS iron <=15% da largura.
3. Telhado de teste: trocar por cenário real (campo/vila) nas capturas; textura >=512 px ou cor chapada.
4. Teto interior: cor distinta das paredes (branco-gelo) + sanca/rodapé de 10 cm; >=3 cores de parede por casa.
5. Props interiores: >=8 itens pequenos por cômodo, texturas de móveis em cor chapada/>=128 px (corrigir quadro xadrez, sofá, estante).
6. Capim: altura máxima 0,5 m perto da câmera ou densidade -40%, para não cobrir praia/canavial.
7. Estrada: textura de terra com sulcos, bordas e 2 tons; sombra/poças; fachadas de madeira sem listras borradas (mip/filtro nearest).
8. Densidade e relevo: >=60 prédios/POIs na aérea, relevo +-3 m e variação de patches; corrigir FPS quadril >=45.
