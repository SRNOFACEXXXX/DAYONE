# CRITICA UPGRADE 03

Notas: armas 3/10, mundo 6/10, interior de casas 4/10, coerência 5/10. Geral: 4.5/10.

## Armas 1a pessoa (3/10)
- ak47_quadril/m107_quadril: o modelo é de blocos bege/cinza desconexos; a leitura é "tijolos", não AK. Sem silhueta (coronha, carregador curvo, cano) como em ak47_fps.
- Sem braços/mãos legíveis (referência mostra mãos cor de pele e antebraço verde). Aqui laranja/bege sem forma.
- m4_iron: cobre ~35% da tela, mira de ferro quase opaca, cena não visível. Modelo parece grade de caixas.
- Cena de teste está num telhado cinza borrado (textura de baixa resolução).

## Mundo (6/10)
- Aérea: ilha legível (estradas, lago, bosques), mas plana e uniforme, poucas construções (~30) e sem relevo.
- Rua da vila: casas brancas repetidas com a mesma planta; grama alta sem variação de cor; estrada marrom lisa sem textura/sombra/poças.
- Pontos fortes: caixa d'água, cruzeiro, fios, palmeiras. Referência tem árvores low-poly maiores e galpões variados.

## Interior (4/10)
- Paredes e teto com textura de ruído borrada (pixels grandes), mal casada com o low-poly limpo exterior.
- Móveis ok em volume (geladeira, mesa), mas sem props pequenos, sem luz/sombras; teto cinza vazio.
- Arma de mão cobre o corredor; ventilador de teto cortado.

## Coerência (5/10)
- Exterior limpo flat-shaded x interior texturizado borrado; HUD consistente, mas armas destoam do restante.

## Correções priorizadas
1. Remodelar AK47/M4/M107 com silhueta reconhecível (carregador, coronha, cano; >=40 caixas distintas, cor madeira+aço em 2-3 tons), escala <=25% da tela em quadril.
2. Mãos/antebraços FPS: 2 mãos low-poly cor de pele + manga verde, ligadas à arma (como ak47_fps).
3. ADS iron: mira ocupa <=15% da largura, mostrando a cena; M4 hoje oculta o alvo.
4. Texturas interiores: trocar ruído borrado por cor chapada + rodapé/lambril; resolução mínima 256 px, nearest ou sem textura.
5. Adicionar >=10 props por cômodo (quadros, tapete, louça, cama, lixo) e luz interior (OmniLight quente por cômodo).
6. Variar casas: >=4 plantas/cores de parede/telhado; hoje as vilas parecem clones.
7. Vegetação: >=3 tons de grama por zona, árvores low-poly grandes e facetadas como nas referências, arbustos nas bordas de estrada.
8. Estrada e terreno: textura/rodas, valas, relevo suave (altura +-3 m) na ilha; teste de cena sem o telhado cinza.
